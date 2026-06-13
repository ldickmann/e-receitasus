import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/health_unit_model.dart';

// ---------------------------------------------------------------------------
// Exceção tipada — UI/Provider não devem inspecionar status HTTP cru (LGPD).
// ---------------------------------------------------------------------------

/// Exceção lançada quando uma operação de [IHealthUnitService] falha de
/// forma previsível (rede, 4xx/5xx do backend, JSON inválido).
///
/// A mensagem já é humanizada e em PT-BR, podendo ser exibida ao usuário.
/// `statusCode` é opcional e serve apenas a logs internos — nunca deve ser
/// renderizado na UI.
class HealthUnitServiceException implements Exception {
  /// Mensagem amigável em PT-BR, sem dados sensíveis.
  final String message;

  /// Status HTTP original, quando aplicável (apenas telemetria).
  final int? statusCode;

  HealthUnitServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'HealthUnitServiceException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Interface abstrata — obrigatória para Mockito/TDD (regra do projeto).
// ---------------------------------------------------------------------------

/// Contrato da camada de acesso à listagem de UBS via backend REST.
///
/// O endpoint é público (a lista de UBS é informação pública e precisa carregar
/// na tela de cadastro, antes de existir sessão). Quando há sessão Supabase, o
/// service ainda injeta o token de `Supabase.instance.client.auth.currentSession`
/// no header `Authorization: Bearer <jwt>`; sem sessão, a requisição segue sem o
/// header.
///
/// Implementação concreta: [HealthUnitService].
/// Mock de teste: gerado via `@GenerateMocks([IHealthUnitService])`.
abstract class IHealthUnitService {
  /// Lista as UBS do município informado, opcionalmente filtrando por UF.
  ///
  /// Parâmetros:
  /// - [city]: nome do município (ex: "Navegantes"). Obrigatório.
  /// - [state]: sigla da UF (ex: "SC"). Opcional — quando informado,
  ///   restringe ainda mais o resultado.
  ///
  /// Lança [HealthUnitServiceException] em qualquer falha (rede, 4xx, 5xx,
  /// JSON inválido). Não exige sessão: o endpoint é público.
  ///
  /// Observação: o backend (TASK #213) ainda não suporta `cityCode` IBGE —
  /// a especificação original do PBI #198 será revisitada em uma TASK
  /// futura quando a coluna `city_code` for adicionada à tabela
  /// `health_units`. Por ora, o filtro é por nome de cidade + UF.
  Future<List<HealthUnitModel>> listByCity(String city, {String? state});
}

// ---------------------------------------------------------------------------
// Implementação concreta — usa `package:http` (já no pubspec) e Supabase SDK
// para obter o JWT. Não acessa `flutter_secure_storage` diretamente porque o
// token de sessão é gerenciado pelo próprio supabase_flutter.
// ---------------------------------------------------------------------------

/// Implementação padrão de [IHealthUnitService] consumindo o backend REST
/// `GET /health-units?city=...&state=...`.
class HealthUnitService implements IHealthUnitService {
  /// Cliente HTTP injetável — facilita mock em testes (TDD).
  final http.Client _client;

  /// Função que devolve o JWT atual (ou `null` quando não há sessão). Por
  /// padrão lê o `accessToken` da sessão Supabase. O token é opcional — só é
  /// enviado quando presente. Tornar isto injetável evita acoplamento direto
  /// ao SDK em testes unitários.
  final Future<String?> Function() _tokenProvider;

  /// URL base do backend — injetável para testes apontarem a um mock server.
  final String _baseUrl;

  /// Construtor padrão. Em produção basta `HealthUnitService()`.
  HealthUnitService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _defaultTokenProvider,
        _baseUrl = baseUrl ?? ApiConfig.backendBaseUrl;

  /// Provedor padrão de token: extrai do `currentSession` do Supabase.
  static Future<String?> _defaultTokenProvider() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken;
  }

  @override
  Future<List<HealthUnitModel>> listByCity(
    String city, {
    String? state,
  }) async {
    // Validação local antecipada — evita request desnecessário se a chamada
    // já viola o contrato (defense-in-depth; o backend também valida).
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      throw HealthUnitServiceException('Município é obrigatório.');
    }

    // Endpoint público (a lista de UBS é informação pública e precisa carregar
    // na tela de cadastro, antes de existir sessão). O token é OPCIONAL: quando
    // há sessão (ex.: tela de prescrição), enviamos o header `Authorization`
    // para preservar contexto; sem sessão (cadastro), a chamada segue sem ele.
    final token = await _tokenProvider();

    // Monta URI com query params; `state` é opcional.
    final uri = Uri.parse('$_baseUrl${ApiConfig.healthUnitsPath}').replace(
      queryParameters: <String, String>{
        'city': trimmedCity,
        if (state != null && state.trim().isNotEmpty)
          'state': state.trim().toUpperCase(),
      },
    );

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: <String, String>{
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Timeout específico — UI pode oferecer retry sem expor stack.
      throw HealthUnitServiceException(
        'Tempo de resposta excedido. Verifique sua conexão.',
      );
    } catch (e) {
      // Falha de rede genérica — log apenas com tipo, sem dados sensíveis.
      developer.log(
        'Falha de rede em listByCity: ${e.runtimeType}',
        name: 'HealthUnitService',
      );
      throw HealthUnitServiceException(
        'Não foi possível conectar ao servidor.',
      );
    }

    if (response.statusCode != 200) {
      // Não propaga corpo cru para evitar vazar mensagens internas (LGPD).
      developer.log(
        'GET /health-units retornou ${response.statusCode}',
        name: 'HealthUnitService',
      );
      throw HealthUnitServiceException(
        _humanizedMessageFor(response.statusCode),
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Resposta não é uma lista');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(HealthUnitModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      throw HealthUnitServiceException('Resposta inválida do servidor.');
    }
  }

  /// Mapeia status HTTP para mensagens amigáveis em PT-BR.
  String _humanizedMessageFor(int status) {
    if (status == 401 || status == 403) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (status == 400) {
      return 'Parâmetros inválidos para listagem de UBS.';
    }
    if (status >= 500) {
      return 'Serviço indisponível no momento. Tente novamente.';
    }
    return 'Falha ao listar UBS.';
  }
}
