/// Exceções tipadas do fluxo de cadastro (PBI #201 / TASK #207).
///
/// Distinguem **falha real** de **sucesso parcial** para que a UI exiba
/// a mensagem correta e não confunda o usuário (alerta vermelho quando o
/// cadastro deu certo).
///
/// LGPD: nenhuma destas classes carrega e-mail, CPF, telefone, mensagens
/// brutas do Supabase ou stack trace — somente metadados de diagnóstico.
library;

/// Falha **real** do cadastro: o `signUp` no Supabase NÃO foi concluído.
///
/// O usuário não foi criado em `auth.users`. A UI deve exibir alerta vermelho
/// com a mensagem mapeada (e-mail duplicado, senha fraca, sem rede, etc.).
///
/// O campo [code] traz apenas o `statusCode` do `AuthException` (quando
/// disponível) ou `'unknown'`. Não inclui `message` para evitar vazar PII
/// que o Supabase às vezes coloca na mensagem (ex.: o próprio e-mail tentado).
class RegisterException implements Exception {
  /// Mensagem amigável já mapeada para o usuário final (sem PII).
  final String userMessage;

  /// Código curto do erro original (ex.: `400`, `422`, `email_exists`,
  /// `weak_password`) — útil para telemetria, jamais para a UI.
  final String code;

  /// Etapa do fluxo onde a falha ocorreu (ex.: `before_signup`,
  /// `after_signup_no_user`). Espelha os marcadores de log da TASK 206.
  final String step;

  const RegisterException({
    required this.userMessage,
    this.code = 'unknown',
    this.step = 'before_signup',
  });

  @override
  String toString() => 'RegisterException(step=$step, code=$code)';
}

/// Sucesso parcial: `signUp` foi OK, mas a etapa subsequente
/// (`update` em `professionals`/`patients`) falhou.
///
/// O usuário **JÁ EXISTE** em `auth.users`; o cadastro está apenas com o
/// perfil incompleto. A UI deve mostrar mensagem amigável (laranja/info)
/// orientando o usuário a fazer login e completar o perfil — nunca alerta
/// de erro vermelho.
class ProfileIncompleteException implements Exception {
  /// Identificador do usuário recém-criado em `auth.users` — exposto apenas
  /// para telemetria interna; **não** deve ser exibido na UI.
  final String userId;

  /// Indica se a sessão veio ativa do `signUp` (false quando há confirmação
  /// de e-mail pendente). Usado pela UI para decidir o texto exato.
  final bool sessionPresent;

  /// Etapa do fluxo onde a falha ocorreu (ex.: `before_update_patients`).
  final String step;

  /// Código curto do erro original (ex.: `PostgrestException.code`).
  final String code;

  const ProfileIncompleteException({
    required this.userId,
    required this.sessionPresent,
    this.step = 'before_update',
    this.code = 'unknown',
  });

  @override
  String toString() =>
      'ProfileIncompleteException(step=$step, code=$code, sessionPresent=$sessionPresent)';
}
