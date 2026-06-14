import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Registro do token FCM do dispositivo (TASK #258 / PBI #244)
// ---------------------------------------------------------------------------
//
// Persiste o token do Firebase Cloud Messaging na tabela do usuário
// (patients ou professionals, coluna fcmToken) para que a Edge Function
// `send-push-notification` saiba para qual dispositivo enviar o push.
//
// Toda a API é "best effort": falhas aqui NUNCA devem quebrar o fluxo de
// login — sem token, o usuário simplesmente não recebe push (o in-app via
// Realtime continua funcionando).

/// Contrato do registro de token FCM.
///
/// Implementação concreta: [FcmTokenService].
/// Mock de teste: gerado por `@GenerateMocks([IFcmTokenService])`.
abstract class IFcmTokenService {
  /// Obtém o token FCM do dispositivo e o persiste na tabela do usuário.
  ///
  /// [userId] é o `auth.uid()` do usuário autenticado.
  /// [isPatient] decide a tabela alvo: `patients` ou `professionals`.
  ///
  /// Também assina `onTokenRefresh` para persistir tokens rotacionados pelo
  /// FCM — chamadas repetidas substituem a assinatura anterior (idempotente).
  Future<void> register({required String userId, required bool isPatient});

  /// Cancela a assinatura de refresh (ex.: no logout). Não apaga o token do
  /// banco — o dispositivo continua sendo o destino de push do último usuário
  /// logado até outro login sobrescrever.
  Future<void> dispose();
}

/// Implementação de [IFcmTokenService] sobre FirebaseMessaging + Supabase.
///
/// Plataformas: efetiva apenas em Android/iOS. Em web e desktop o [register]
/// é no-op silencioso — o fluxo de desenvolvimento (Chrome/Windows) não
/// depende do Firebase e não deve quebrar por ausência de configuração.
class FcmTokenService implements IFcmTokenService {
  final SupabaseClient _supabase;

  StreamSubscription<String>? _refreshSubscription;

  /// Aceita [SupabaseClient] opcional para injeção em testes (mesmo padrão
  /// de [RenewalService]/[NotificationService]).
  FcmTokenService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// FCM só está configurado para mobile neste projeto (google-services.json
  /// no Android; PBI #244 tem o Samsung A55 como dispositivo de referência).
  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> register({
    required String userId,
    required bool isPatient,
  }) async {
    if (!_isSupportedPlatform) return;

    final table = isPatient ? 'patients' : 'professionals';

    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ exige permissão de runtime para exibir notificações.
      // Negada → getToken ainda funciona, mas o push não é exibido; mantemos
      // o registro mesmo assim (usuário pode conceder depois nas configurações).
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(table: table, userId: userId, token: token);
      }

      // Tokens FCM são rotacionados pelo Firebase — persistir cada novo valor
      // garante que o push continue chegando (critério de aceite da TASK #258).
      await _refreshSubscription?.cancel();
      _refreshSubscription = messaging.onTokenRefresh.listen(
        (newToken) => _saveToken(table: table, userId: userId, token: newToken),
        // Stream de refresh não pode derrubar o app por erro de rede.
        onError: (Object e) => developer.log(
          'onTokenRefresh falhou',
          name: 'FcmTokenService',
          error: e.toString(),
        ),
      );
    } catch (e) {
      // Best effort: registra o problema e segue — login nunca é bloqueado.
      developer.log(
        'registro de token FCM falhou',
        name: 'FcmTokenService',
        error: e.toString(),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }

  /// Persiste o token via PostgREST. O RLS da tabela permite que o próprio
  /// usuário atualize sua linha (policy de update own profile).
  Future<void> _saveToken({
    required String table,
    required String userId,
    required String token,
  }) async {
    try {
      await _supabase.from(table).update({'fcmToken': token}).eq('id', userId);
    } on PostgrestException catch (e) {
      // Loga apenas o código — sem token nem userId (evita vazamento em logs).
      developer.log(
        'persistência do token FCM falhou',
        name: 'FcmTokenService',
        error: 'code=${e.code}',
      );
    }
  }
}
