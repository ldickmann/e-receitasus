import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/renewal_request_model.dart';

// ---------------------------------------------------------------------------
// Notificações em tempo real (Supabase Realtime) sobre a tabela RenewalRequest
// ---------------------------------------------------------------------------
//
// Esta camada apenas OUVE mudanças no banco via WebSocket (Realtime) e as
// converte em eventos enxutos para a UI. O envio de push em background (FCM)
// é responsabilidade da Edge Function `send-push-notification` (TASK #257) —
// fora do escopo deste serviço.

/// Público-alvo de uma inscrição — define QUAL coluna e QUAL evento do
/// Realtime são observados na tabela `RenewalRequest`.
enum NotificationAudience {
  /// Paciente: observa mudanças de status dos próprios pedidos.
  patient,

  /// Enfermeiro: observa novas solicitações chegando para triagem.
  nurse,

  /// Médico: observa pedidos triados atribuídos a ele.
  doctor,
}

/// Natureza do evento percebido pelo app.
enum RenewalNotificationKind {
  /// Nova solicitação criada (INSERT) — relevante para o enfermeiro.
  newRequest,

  /// Status de uma solicitação existente mudou (UPDATE) — paciente/médico.
  statusChanged,
}

/// Evento de notificação derivado de uma mudança Realtime em `RenewalRequest`.
///
/// Modelo deliberadamente enxuto e desacoplado do SDK do Supabase: carrega
/// só o necessário para a UI reagir (id do pedido, status atual, natureza do
/// evento). Nenhum dado clínico/PII é transportado aqui (LGPD).
class RenewalNotification {
  /// ID do pedido de renovação que sofreu a mudança.
  final String renewalRequestId;

  /// Status atual do pedido após o evento.
  final RenewalStatus status;

  /// Se o evento foi uma nova solicitação ou uma mudança de status.
  final RenewalNotificationKind kind;

  /// Momento em que o app recebeu o evento (hora local do dispositivo).
  final DateTime receivedAt;

  RenewalNotification({
    required this.renewalRequestId,
    required this.status,
    required this.kind,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();
}

// ---------------------------------------------------------------------------
// Interface abstrata — obrigatória para injeção de dependência e TDD (Mockito)
// ---------------------------------------------------------------------------

/// Contrato da camada de notificações em tempo real.
///
/// Implementação concreta: [NotificationService].
/// Mock de teste: gerado por `@GenerateMocks([INotificationService])`.
abstract class INotificationService {
  /// Abre um canal Realtime na tabela `RenewalRequest` filtrado conforme
  /// [audience] e [userId], devolvendo um stream de [RenewalNotification].
  ///
  /// Chamar novamente cancela a inscrição anterior antes de abrir a nova
  /// (idempotente) — evita canais órfãos acumulando no cliente.
  Stream<RenewalNotification> subscribe({
    required String userId,
    required NotificationAudience audience,
  });

  /// Cancela a inscrição ativa e libera o canal Realtime. Seguro chamar
  /// mesmo sem inscrição ativa (no-op).
  Future<void> unsubscribe();
}

// ---------------------------------------------------------------------------
// Implementação concreta via Supabase Realtime
// ---------------------------------------------------------------------------

/// Implementação de [INotificationService] sobre o Supabase Realtime.
///
/// O escopo de visibilidade (quais linhas chegam ao cliente) é garantido pelas
/// políticas RLS da tabela `RenewalRequest` — o canal apenas filtra por coluna
/// de dono quando ela existe.
class NotificationService implements INotificationService {
  final SupabaseClient _supabase;

  /// Nome da tabela — PascalCase porque criada pelo Prisma com quoted
  /// identifier (`"RenewalRequest"`), preservado pelo PostgREST/Realtime.
  static const String _table = 'RenewalRequest';

  RealtimeChannel? _channel;
  StreamController<RenewalNotification>? _controller;

  /// Aceita [SupabaseClient] opcional para injeção em testes sem instanciar
  /// o Supabase real (mesmo padrão de [RenewalService]).
  NotificationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Stream<RenewalNotification> subscribe({
    required String userId,
    required NotificationAudience audience,
  }) {
    // Garante uma única inscrição ativa — descarta a anterior, se houver,
    // sem aguardar (a limpeza opera sobre as referências antigas capturadas).
    unsubscribe();

    final controller = StreamController<RenewalNotification>.broadcast();
    _controller = controller;

    // INSERT só interessa ao enfermeiro (nova PENDING_TRIAGE chegando à UBS).
    // UPDATE interessa a paciente (status muda) e médico (TRIAGED atribuído).
    final isNurse = audience == NotificationAudience.nurse;
    final event =
        isNurse ? PostgresChangeEvent.insert : PostgresChangeEvent.update;
    final kind = isNurse
        ? RenewalNotificationKind.newRequest
        : RenewalNotificationKind.statusChanged;

    // Filtro por coluna de dono do registro. O enfermeiro NÃO tem filtro de
    // coluna: `RenewalRequest` não modela `healthUnitId`, então o escopo por
    // UBS é garantido pela RLS (policy enfermeiro_ve_pendentes), não pelo
    // canal. Paciente filtra por `patientUserId`; médico por `doctorUserId`.
    final PostgresChangeFilter? filter = switch (audience) {
      NotificationAudience.patient => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'patientUserId',
          value: userId,
        ),
      NotificationAudience.doctor => PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'doctorUserId',
          value: userId,
        ),
      NotificationAudience.nurse => null,
    };

    final channel = _supabase.channel(
      'notif_${audience.name}_${userId}_${DateTime.now().millisecondsSinceEpoch}',
    );

    channel
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: _table,
          filter: filter,
          callback: (payload) {
            final notification = _mapRow(payload.newRecord, kind);
            if (notification != null && !controller.isClosed) {
              controller.add(notification);
            }
          },
        )
        .subscribe();

    _channel = channel;
    return controller.stream;
  }

  @override
  Future<void> unsubscribe() async {
    // Captura as referências ANTES de qualquer await e zera os campos de forma
    // síncrona — assim, se subscribe() chamar unsubscribe() sem aguardar e já
    // reatribuir _channel/_controller, a limpeza atua só sobre os antigos.
    final channel = _channel;
    final controller = _controller;
    _channel = null;
    _controller = null;

    if (channel != null) {
      await _supabase.removeChannel(channel);
    }
    await controller?.close();
  }

  /// Converte a linha bruta do payload Realtime em [RenewalNotification].
  /// Retorna null (e loga) se o payload vier sem `id` — defesa contra
  /// eventos malformados, sem derrubar o stream.
  RenewalNotification? _mapRow(
    Map<String, dynamic> row,
    RenewalNotificationKind kind,
  ) {
    final id = row['id'] as String?;
    if (id == null) {
      developer.log('Payload Realtime sem id', name: 'NotificationService');
      return null;
    }
    return RenewalNotification(
      renewalRequestId: id,
      status: RenewalStatus.fromString(row['status'] as String? ?? ''),
      kind: kind,
    );
  }
}
