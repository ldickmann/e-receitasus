/// Testes da configuração centralizada do Supabase.
///
/// Garantem que a Fase 3 da refatoração (AB#129) não introduza regressão
/// silenciosa nas credenciais — evita o cenário em que alguém renomeia ou
/// limpa as constantes e o app sobe contra um Supabase inexistente.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:e_receitasus/config/supabase_config.dart';

void main() {
  group('SupabaseConfig — constantes', () {
    test('supabaseUrl deve ser HTTPS e apontar para um projeto Supabase', () {
      // ASSERT — nunca aceitar HTTP em produção (LGPD/segurança em trânsito)
      expect(SupabaseConfig.supabaseUrl, startsWith('https://'));
      expect(SupabaseConfig.supabaseUrl, contains('supabase.co'));
    });

    test('supabaseAnonKey deve ser não vazia e parecer uma chave válida', () {
      // ASSERT — sanity check para evitar embarque acidental de string vazia
      expect(SupabaseConfig.supabaseAnonKey, isNotEmpty);
      expect(SupabaseConfig.supabaseAnonKey.length, greaterThan(20));
    });

    test('supabaseAnonKey NÃO pode ser a service_role (proibido no client)',
        () {
      // ASSERT — defesa contra erro grave: service_role bypassa RLS e jamais
      // pode ser embarcada em apps móveis (regra do projeto + LGPD).
      final key = SupabaseConfig.supabaseAnonKey.toLowerCase();
      expect(key.contains('service_role'), isFalse);
      expect(key.contains('sb_secret'), isFalse);
    });
  });
}
