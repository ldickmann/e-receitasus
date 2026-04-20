import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuracao centralizada do Supabase para o E-ReceitaSUS.
///
/// Por que centralizar:
/// - Evita duplicacao de URL/anonKey em main.dart e em testes
/// - Facilita troca de ambiente (dev/staging/prod) num unico ponto
/// - Permite que testes inicializem o cliente sem replicar literais
///
/// Sobre seguranca (LGPD/segurança):
/// - `anonKey` é projetada para ser pública no client (com RLS aplicado no
///   banco). Nunca inclua a `service_role` aqui — ela jamais deve sair do
///   backend (regra do projeto).
/// - URL e anonKey só devem ser trocadas via novo build do app.
class SupabaseConfig {
  /// Construtor privado — esta classe expõe apenas membros estáticos.
  const SupabaseConfig._();

  /// URL do projeto Supabase em produção.
  ///
  /// Mantida como constante para permitir uso em const contexts e para que
  /// o linter consiga detectar referências incorretas em tempo de análise.
  static const String supabaseUrl =
      'https://shnahlongybxxilworck.supabase.co';

  /// Chave anônima publicável do Supabase.
  ///
  /// Pública por design — protege os dados via Row Level Security (RLS).
  /// NÃO confundir com `service_role` (que jamais pode ser embarcada no app).
  static const String supabaseAnonKey =
      'sb_publishable_NMJeKsT7rEJ8-l7vefZcDA_ggy3EKAj';

  /// Inicializa o SDK do Supabase de forma idempotente.
  ///
  /// O `Supabase.initialize` lança se chamado duas vezes; este wrapper
  /// captura o cenário e simplesmente retorna a instância existente —
  /// evita falhas em hot-restart durante o desenvolvimento e em testes
  /// que reusam a mesma engine Flutter.
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } on AssertionError {
      // Já inicializado em chamada anterior — comportamento desejado.
    }
  }
}
