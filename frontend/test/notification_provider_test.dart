/// Testes do NotificationProvider — notificações in-app via Supabase Realtime.
///
/// Isola o Supabase com mock de [INotificationService] (gerado pelo Mockito),
/// cumprindo os critérios de aceite da TASK #258 (PBI #244):
/// - subscribe() chamado ao iniciar o provider (start);
/// - evento Realtime atualiza o estado e dispara notifyListeners();
/// - markAllRead zera o contador de não lidas;
/// - stop()/dispose cancelam a inscrição (unsubscribe).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/providers/notification_provider.dart';
import 'package:e_receitasus/services/notification_service.dart';

import 'notification_provider_test.mocks.dart';

@GenerateMocks([INotificationService])
void main() {
  late MockINotificationService mockService;
  late NotificationProvider provider;
  late StreamController<RenewalNotification> streamController;

  const userId = 'user-123';

  RenewalNotification buildNotification({
    String id = 'renewal-1',
    RenewalStatus status = RenewalStatus.triaged,
    RenewalNotificationKind kind = RenewalNotificationKind.statusChanged,
  }) {
    return RenewalNotification(
      renewalRequestId: id,
      status: status,
      kind: kind,
    );
  }

  setUp(() {
    mockService = MockINotificationService();
    streamController = StreamController<RenewalNotification>.broadcast();

    when(mockService.subscribe(
      userId: anyNamed('userId'),
      audience: anyNamed('audience'),
    )).thenAnswer((_) => streamController.stream);
    when(mockService.unsubscribe()).thenAnswer((_) async {});

    provider = NotificationProvider(mockService);
  });

  tearDown(() async {
    await streamController.close();
  });

  group('start', () {
    test('chama subscribe no service com userId e audience corretos', () {
      provider.start(
        userId: userId,
        audience: NotificationAudience.patient,
      );

      verify(mockService.subscribe(
        userId: userId,
        audience: NotificationAudience.patient,
      )).called(1);
      expect(provider.isSubscribed, isTrue);
    });

    test('é idempotente — segunda chamada reinscreve sem duplicar listeners',
        () async {
      provider.start(userId: userId, audience: NotificationAudience.nurse);
      provider.start(userId: userId, audience: NotificationAudience.nurse);

      verify(mockService.subscribe(
        userId: userId,
        audience: NotificationAudience.nurse,
      )).called(2);

      // Com listener único ativo, um evento conta apenas UMA notificação —
      // prova de que a primeira inscrição foi cancelada pelo start() seguinte.
      streamController.add(buildNotification());
      await Future<void>.delayed(Duration.zero);
      expect(provider.unreadCount, 1);
    });
  });

  group('eventos Realtime', () {
    test('evento atualiza latest, incrementa unreadCount e notifica ouvintes',
        () async {
      var notified = 0;
      provider.addListener(() => notified++);

      provider.start(userId: userId, audience: NotificationAudience.patient);
      final baseline = notified;

      streamController.add(
        buildNotification(id: 'renewal-9', status: RenewalStatus.prescribed),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.unreadCount, 1);
      expect(provider.hasUnread, isTrue);
      expect(provider.latest?.renewalRequestId, 'renewal-9');
      expect(provider.latest?.status, RenewalStatus.prescribed);
      expect(notified, greaterThan(baseline));
    });

    test('eventos consecutivos acumulam o contador de não lidas', () async {
      provider.start(userId: userId, audience: NotificationAudience.doctor);

      streamController.add(buildNotification(id: 'a'));
      streamController.add(buildNotification(id: 'b'));
      streamController.add(buildNotification(id: 'c'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.unreadCount, 3);
      expect(provider.latest?.renewalRequestId, 'c');
    });
  });

  group('markAllRead', () {
    test('zera o contador e notifica ouvintes', () async {
      provider.start(userId: userId, audience: NotificationAudience.patient);
      streamController.add(buildNotification());
      await Future<void>.delayed(Duration.zero);
      expect(provider.unreadCount, 1);

      var notified = 0;
      provider.addListener(() => notified++);

      provider.markAllRead();

      expect(provider.unreadCount, 0);
      expect(provider.hasUnread, isFalse);
      expect(notified, 1);
    });

    test('não notifica quando já não há não lidas (evita rebuild inútil)', () {
      var notified = 0;
      provider.addListener(() => notified++);

      provider.markAllRead();

      expect(notified, 0);
    });
  });

  group('stop', () {
    test('cancela a inscrição e chama unsubscribe no service', () async {
      provider.start(userId: userId, audience: NotificationAudience.patient);
      expect(provider.isSubscribed, isTrue);

      await provider.stop();

      verify(mockService.unsubscribe()).called(1);
      expect(provider.isSubscribed, isFalse);

      // Evento após stop não deve mais alterar o estado.
      streamController.add(buildNotification());
      await Future<void>.delayed(Duration.zero);
      expect(provider.unreadCount, 0);
    });
  });

  group('dispose', () {
    test('cancela a inscrição ao destruir o provider (logout)', () {
      provider.start(userId: userId, audience: NotificationAudience.patient);

      provider.dispose();

      verify(mockService.unsubscribe()).called(1);
    });
  });
}
