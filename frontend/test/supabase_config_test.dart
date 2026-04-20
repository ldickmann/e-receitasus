/// Testes da configuração centralizada do Supabase.
///
/// Garantem que a Fase 3.1 da refatoração (AB#129) não introduza regressão
/// silenciosa: credenciais agora vêm de `--dart-define`, então em ambiente
/// de teste padrão (sem defines) ambas as constantes ficam vazias e
/// `initialize()` deve falhar explicitamente.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:e_receitasus/config/supabase_config.dart';

void main() {
  group('SupabaseConfig — credenciais via --dart-define', () {
    test(
        'constantes devem ficar vazias quando build não fornece --dart-define',
        () {
      // ASSERT — `flutter test` sem --dart-define gera defaults vazios.
      // Esse comportamento é desejado: forçar o build a declarar as vars.
      expect(SupabaseConfig.supabaseUrl, isEmpty);
      expect(SupabaseConfig.supabaseAnonKey, isEmpty);
    });

    test('initialize() deve lançar StateError quando credenciais ausentes',
        () async {
      // ACT + ASSERT — falha cedo com mensagem clara em vez de subir contra
      // projeto incorreto silenciosamente.
      expect(
        () => SupabaseConfig.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('mensagem de erro deve orientar a usar --dart-define', () async {
      // ASSERT — a mensagem precisa ser acionável para o desenvolvedor.
      try {
        await SupabaseConfig.initialize();
        fail('initialize() deveria ter lançado StateError');
      } on StateError catch (e) {
        expect(e.message, contains('--dart-define'));
        expect(e.message, contains('SUPABASE_URL'));
        expect(e.message, contains('SUPABASE_ANON_KEY'));
      }
    });
  });
}
