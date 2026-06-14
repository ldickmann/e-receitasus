// =============================================================================
// Edge Function: send-push-notification (TASK #257 / PBI #244)
//
// Envia notificações push via Firebase Cloud Messaging (FCM HTTP v1) quando o
// status de um pedido de renovação muda. É acionada por um Database Webhook na
// tabela public."RenewalRequest" (evento UPDATE) — ver README.md.
//
// Regras de roteamento (por transição de status):
//   - * -> TRIAGED    : push para o MÉDICO designado (doctorUserId)
//   - * -> PRESCRIBED  : push para o PACIENTE (patientUserId) — receita emitida
//   - * -> REJECTED    : push para o PACIENTE (patientUserId) — solicitação negada
//   - demais transições: ignoradas (o in-app via Realtime já cobre o restante)
//
// Privacidade (LGPD): o corpo da notificação é genérico — NÃO carrega nome de
// medicamento, dados clínicos ou de outros pacientes. A função resolve um único
// destinatário a partir da própria linha alterada e lê apenas o token dele.
//
// Robustez: destinatário sem token FCM cadastrado resulta em 200 (skip), nunca
// em erro 500 — cumpre o critério de aceite.
//
// Segredos (Supabase Secrets, nunca no código):
//   - FIREBASE_SERVICE_ACCOUNT : JSON da conta de serviço do Firebase
//   - WEBHOOK_SECRET (opcional) : defesa extra; se definido, exige o header
//                                 x-webhook-secret igual no request do webhook
//   - SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY : injetados automaticamente
// =============================================================================

import { createClient } from "@supabase/supabase-js";
import { importPKCS8, SignJWT } from "jose";

// ---------------------------------------------------------------------------
// Tipos
// ---------------------------------------------------------------------------

interface RenewalRow {
  id: string;
  status: string;
  patientUserId: string;
  doctorUserId: string | null;
  [key: string]: unknown;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: RenewalRow | null;
  old_record: RenewalRow | null;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

interface PushTarget {
  table: "patients" | "professionals";
  recipientId: string;
  title: string;
  body: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/// Decide o destinatário e a mensagem a partir do novo status. Retorna null
/// quando a transição não é notificável por push.
function resolveTarget(row: RenewalRow): PushTarget | null {
  switch (row.status) {
    case "TRIAGED":
      // Médico designado avalia o pedido triado. Sem médico, nada a enviar.
      if (!row.doctorUserId) return null;
      return {
        table: "professionals",
        recipientId: row.doctorUserId,
        title: "Nova renovação para avaliar",
        body: "Um pedido de renovação foi triado e aguarda sua decisão.",
      };
    case "PRESCRIBED":
      return {
        table: "patients",
        recipientId: row.patientUserId,
        title: "Renovação aprovada",
        body: "Sua nova receita foi emitida. Confira no aplicativo.",
      };
    case "REJECTED":
      return {
        table: "patients",
        recipientId: row.patientUserId,
        title: "Solicitação não aprovada",
        body: "Sua solicitação de renovação foi avaliada. Veja os detalhes no aplicativo.",
      };
    default:
      return null;
  }
}

/// Troca a conta de serviço por um access token OAuth2 com escopo do FCM.
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const privateKey = await importPKCS8(sa.private_key, "RS256");

  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!resp.ok) {
    throw new Error(`oauth_token_failed_${resp.status}`);
  }
  const tok = (await resp.json()) as { access_token: string };
  return tok.access_token;
}

/// Envia a mensagem ao dispositivo via FCM HTTP v1.
async function sendFcm(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  target: PushTarget,
  data: Record<string, string>,
): Promise<Response> {
  return await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title: target.title, body: target.body },
          data,
          android: { priority: "HIGH" },
        },
      }),
    },
  );
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // Hardening #3 — Problema: o WEBHOOK_SECRET era opcional (só checado quando
  // definido) e a função confiava no `record` do corpo (status e destinatário
  // controlados pelo chamador), permitindo push forjado com a anon key pública.
  // Solução (parte 1): exigir SEMPRE o segredo compartilhado. Sem ele, 401.
  const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
  if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: WebhookPayload;
  try {
    payload = (await req.json()) as WebhookPayload;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (payload.type !== "UPDATE") {
    return json({ skipped: "not_an_update" }, 200);
  }

  // Do corpo aproveitamos APENAS o id — status e destinatário são relidos do
  // banco (fonte da verdade), nunca confiados a partir do payload do chamador.
  const renewalId = payload.record?.id;
  if (!renewalId) return json({ skipped: "no_record" }, 200);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Solução (parte 2): relê a linha pelo id com service role. O status e o
    // destinatário vêm do banco — impossível forjar a transição pelo corpo.
    const { data: row, error: rowError } = await supabase
      .from("RenewalRequest")
      .select("id, status, patientUserId, doctorUserId")
      .eq("id", renewalId)
      .maybeSingle();

    if (rowError) {
      console.error("renewal_lookup_failed", rowError.message);
      return json({ error: "renewal_lookup_failed" }, 500);
    }
    if (!row) return json({ skipped: "renewal_not_found" }, 200);

    const target = resolveTarget(row as RenewalRow);
    if (!target) return json({ skipped: "status_not_notifiable" }, 200);

    // Lê APENAS o token do único destinatário resolvido (minimização de dados).
    const { data, error } = await supabase
      .from(target.table)
      .select("fcmToken")
      .eq("id", target.recipientId)
      .maybeSingle();

    if (error) {
      console.error("recipient_lookup_failed", error.message);
      return json({ error: "recipient_lookup_failed" }, 500);
    }

    const deviceToken = (data?.fcmToken as string | null) ?? null;
    // Destinatário sem token cadastrado: nada a enviar — 200, nunca 500.
    if (!deviceToken) return json({ skipped: "no_token" }, 200);

    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      console.error("missing_FIREBASE_SERVICE_ACCOUNT");
      return json({ error: "missing_service_account" }, 500);
    }
    const serviceAccount = JSON.parse(serviceAccountRaw) as ServiceAccount;

    const accessToken = await getAccessToken(serviceAccount);
    const fcmResp = await sendFcm(
      serviceAccount.project_id,
      accessToken,
      deviceToken,
      target,
      {
        renewalRequestId: String(row.id),
        status: String(row.status),
      },
    );

    if (!fcmResp.ok) {
      const detail = await fcmResp.text();
      console.error("fcm_send_failed", fcmResp.status, detail);
      // 502: falha no provedor externo; o webhook pode reagir/retentar.
      return json({ error: "fcm_send_failed", status: fcmResp.status }, 502);
    }

    return json({ sent: true, audience: target.table }, 200);
  } catch (err) {
    console.error("unexpected_error", err instanceof Error ? err.message : err);
    return json({ error: "internal_error" }, 500);
  }
});
