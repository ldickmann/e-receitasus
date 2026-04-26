/// Configuração centralizada da URL base do backend REST E-ReceitaSUS.
///
/// Permite trocar o host em build/dev sem editar código:
/// `flutter run --dart-define=BACKEND_BASE_URL=https://api.exemplo.com`
///
/// Fallback `http://localhost:3000` é usado apenas em desenvolvimento local.
/// Em produção, sempre injetar via `--dart-define`.
class ApiConfig {
  /// URL base do backend (sem barra final).
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Endpoint de listagem de UBS por município (TASK #213 do PBI #198).
  static const String healthUnitsPath = '/health-units';
}
