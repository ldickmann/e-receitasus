import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';

// ---------------------------------------------------------------------------
// NotificationProvider — estado de notificações in-app (Supabase Realtime)
// ---------------------------------------------------------------------------

/// Provider que assina o canal Realtime de `RenewalRequest` via
/// [INotificationService] e expõe o estado para a UI reagir em tempo real.
///
/// Segue o padrão do projeto: injeção de [INotificationService] via construtor
/// para permitir mock no TDD (Mockito). Nunca acessa o `SupabaseClient`
/// diretamente — toda a comunicação passa pelo service (separação de camadas).
///
/// O *call site* de [start] (após o login, com o `userId` e o papel do usuário)
/// é responsabilidade das telas — fica a cargo da TASK #256. Aqui entregamos o
/// mecanismo: assinar, acumular o estado e cancelar a inscrição.
class NotificationProvider with ChangeNotifier {
  /// Serviço de notificações injetado — facilita mocks em testes.
  final INotificationService _service;

  /// Inscrição ativa no stream do service. Nula quando não há inscrição.
  StreamSubscription<RenewalNotification>? _subscription;

  /// Contador de notificações ainda não lidas — base do badge da UI.
  int _unreadCount = 0;

  /// Última notificação recebida — usada para feedback imediato (ex.: SnackBar).
  RenewalNotification? _latest;

  /// Verdadeiro enquanto há uma inscrição Realtime ativa.
  bool _isSubscribed = false;

  /// Cria o provider com [service] injetado (em produção, [NotificationService]).
  NotificationProvider(this._service);

  // ── Getters públicos ────────────────────────────────────────────────────

  /// Quantidade de notificações não lidas (exibida como badge).
  int get unreadCount => _unreadCount;

  /// Última notificação recebida, ou nula se nenhuma chegou ainda.
  RenewalNotification? get latest => _latest;

  /// Verdadeiro quando há inscrição Realtime ativa.
  bool get isSubscribed => _isSubscribed;

  /// Atalho de conveniência para a UI decidir se mostra o badge.
  bool get hasUnread => _unreadCount > 0;

  // ── Métodos públicos ────────────────────────────────────────────────────

  /// Inicia a inscrição Realtime para [userId] com o papel [audience].
  ///
  /// Idempotente: cancela qualquer inscrição anterior antes de abrir a nova,
  /// evitando listeners/canais duplicados ao trocar de usuário.
  void start({
    required String userId,
    required NotificationAudience audience,
  }) {
    // Cancela o listener anterior; o próprio service descarta o canal antigo.
    _subscription?.cancel();
    _subscription =
        _service.subscribe(userId: userId, audience: audience).listen(
              _onNotification,
            );
    _isSubscribed = true;
    notifyListeners();
  }

  /// Zera o contador de não lidas (ex.: ao abrir a tela de pedidos).
  void markAllRead() {
    if (_unreadCount == 0) return;
    _unreadCount = 0;
    notifyListeners();
  }

  /// Cancela a inscrição ativa (ex.: no logout) e libera o canal Realtime.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _service.unsubscribe();
    if (_isSubscribed) {
      _isSubscribed = false;
      notifyListeners();
    }
  }

  // ── Helpers privados ────────────────────────────────────────────────────

  /// Reage a cada evento Realtime: guarda como o mais recente, incrementa o
  /// contador de não lidas e notifica os ouvintes para atualizar a UI.
  void _onNotification(RenewalNotification notification) {
    _latest = notification;
    _unreadCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancela a inscrição ao destruir o provider (ex.: logout que remove a
    // árvore) — cumpre o critério "inscrição cancelada ao fazer logout".
    _subscription?.cancel();
    _service.unsubscribe();
    super.dispose();
  }
}
