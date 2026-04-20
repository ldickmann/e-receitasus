import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuracao centralizada do Supabase para o E-ReceitaSUS.
///
/// Por que usar `String.fromEnvironment` (Fase 3.1 da refatoração AB#129):
/// - Mantém credenciais FORA do código-fonte e do histórico Git.
/// - Permite trocar entre dev/staging/prod por build (sem alterar código).
/// - Alinha o frontend ao mesmo padrão que o backend já adota com `.env`.
///
/// Como passar as variáveis em build/run:
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<sua_anon_key>
/// ```
/// Em produção/CI, essas variáveis devem vir de secrets do pipeline (nunca
/// commitadas). Veja `frontend/.env.example` para referência.
///
/// Sobre seguranca (LGPD/segurança):
/// - `SUPABASE_ANON_KEY` é projetada para ser pública no client (com RLS
///   aplicado no banco). Mesmo assim, evitamos hardcode para não acoplar o
///   app a um único ambiente e para reduzir superfície de exposição.
/// - Nunca incluir `service_role` aqui — ela jamais deve sair do backend.
class SupabaseConfig {
  /// Construtor privado — esta classe expõe apenas membros estáticos.
  const SupabaseConfig._();

  /// URL do projeto Supabase, lida em compile-time via `--dart-define`.
  ///
  /// Vazia por padrão para que [initialize] falhe explicitamente quando o
  /// build não fornecer a variável — evita conexão silenciosa contra um
  /// projeto incorreto.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Chave anônima publicável do Supabase, lida em compile-time via
  /// `--dart-define`.
  ///
  /// Pública por design — protege os dados via Row Level Security (RLS).
  /// NÃO confundir com `service_role` (que jamais pode ser embarcada no app).
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Inicializa o SDK do Supabase de forma idempotente.
  ///
  /// Lança [StateError] em vez de iniciar contra credenciais vazias — falha
  /// cedo e com mensagem clara é preferível a comportamento silencioso de
  /// "nada funciona" em runtime.
  ///
  /// O `Supabase.initialize` lança se chamado duas vezes; este wrapper
  /// captura o cenário e simplesmente retorna — evita falhas em hot-restart
  /// durante o desenvolvimento e em testes que reusam a mesma engine Flutter.
  static Future<void> initialize() async {
    // Validação de boundary: bloqueia inicialização sem credenciais explícitas
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Credenciais do Supabase ausentes. Forneça --dart-define='
        'SUPABASE_URL=... e --dart-define=SUPABASE_ANON_KEY=... no build/run. '
        'Veja frontend/.env.example.',
      );
    }

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
