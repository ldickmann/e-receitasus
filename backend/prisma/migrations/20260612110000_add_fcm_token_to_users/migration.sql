-- Adiciona coluna fcmToken em patients e professionals para registro
-- do token FCM do dispositivo, usado pela Edge Function send-push-notification
-- para enviar notificações push via Firebase Cloud Messaging HTTP v1.
-- Nullable: usuários sem app instalado ou que não concederam permissão de
-- notificação não terão token — a Edge Function trata ausência como skip (200).

ALTER TABLE "patients"
  ADD COLUMN IF NOT EXISTS "fcmToken" TEXT;

ALTER TABLE "professionals"
  ADD COLUMN IF NOT EXISTS "fcmToken" TEXT;
