import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Endereço retornado pela API ViaCEP, normalizado para uso no app.
///
/// Modelo imutável e desacoplado do JSON cru — usar `final` em todos os
/// campos garante que telas não mutem o resultado por engano e evita
/// surpresa quando o mesmo endereço é compartilhado entre widgets.
class ViaCepAddress {
  final String cep;
  final String logradouro;
  final String bairro;
  final String localidade;
  final String uf;

  const ViaCepAddress({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.localidade,
    required this.uf,
  });

  /// Constrói a partir do JSON do ViaCEP, normalizando campos ausentes
  /// para string vazia — o endpoint pode omitir `complemento`/`bairro`
  /// em CEPs genéricos (rurais ou de cidades pequenas).
  factory ViaCepAddress.fromJson(Map<String, dynamic> data) {
    return ViaCepAddress(
      cep: (data['cep'] as String?) ?? '',
      logradouro: (data['logradouro'] as String?) ?? '',
      bairro: (data['bairro'] as String?) ?? '',
      localidade: (data['localidade'] as String?) ?? '',
      // UF em maiúsculas para casar com a lista de UFs usada nos dropdowns.
      uf: ((data['uf'] as String?) ?? '').toUpperCase(),
    );
  }
}

/// Exceção lançada quando a consulta ViaCEP falha de forma identificável.
///
/// Telas devem mostrar `message` em SnackBar — texto já é amigável
/// e em PT-BR, garantindo que nenhum stack trace ou detalhe técnico
/// vaze para o usuário (requisito LGPD/UX do PBI #200).
class ViaCepServiceException implements Exception {
  final String message;
  final int? statusCode;

  const ViaCepServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'ViaCepServiceException: $message';
}

/// Contrato para consulta de endereço por CEP.
///
/// Existe como interface abstrata para permitir injeção de mocks nos
/// widget tests (Mockito) sem precisar abrir sockets reais — TASK #222.
abstract class IViaCepService {
  /// Consulta o endereço de um [cep] (somente dígitos ou com máscara).
  ///
  /// Lança [ViaCepServiceException] quando:
  ///   - CEP é inválido (≠ 8 dígitos);
  ///   - ViaCEP retorna `{"erro": true}` (CEP inexistente);
  ///   - resposta HTTP fora de 200;
  ///   - timeout ou falha de rede.
  Future<ViaCepAddress> fetch(String cep);
}

/// Implementação real do [IViaCepService] usando `package:http`.
///
/// Permite injetar um [http.Client] customizado — usado em testes para
/// substituir por `MockClient` e simular respostas determinísticas.
/// Em produção, `null` faz o serviço criar o cliente padrão sob demanda.
class ViaCepService implements IViaCepService {
  /// Cliente HTTP injetável; em produção mantemos `null` e usamos
  /// `http.get` global para não vazar conexões (cada chamada cria/encerra
  /// seu próprio socket).
  final http.Client? _client;

  /// Timeout aplicado apenas quando o cliente injetado é `null`.
  /// Em testes com `MockClient` o timer sintético do flutter_test pode
  /// gerar comportamento indefinido — por isso só ativamos o timeout
  /// no caminho de produção.
  final Duration _timeout;

  /// Constrói o serviço; [client] e [timeout] são opcionais.
  const ViaCepService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = client,
        _timeout = timeout;

  @override
  Future<ViaCepAddress> fetch(String cep) async {
    // Aceita CEP com máscara ("01001-000") ou apenas dígitos — normaliza
    // antes de validar para reduzir fricção na camada de UI.
    final clean = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length != 8) {
      throw const ViaCepServiceException('CEP inválido. Informe 8 dígitos.');
    }

    final uri = Uri.parse('https://viacep.com.br/ws/$clean/json/');

    try {
      // Cliente injetado (testes) ou cliente padrão com timeout (produção).
      final responseFuture =
          _client != null ? _client.get(uri) : http.get(uri).timeout(_timeout);
      final response = await responseFuture;

      if (response.statusCode != 200) {
        throw ViaCepServiceException(
          'Não foi possível consultar o CEP. Tente novamente.',
          statusCode: response.statusCode,
        );
      }

      // Decodifica como UTF-8 explicitamente — ViaCEP às vezes responde
      // sem charset no Content-Type e response.body usa latin1 como fallback,
      // corrompendo "ç", "ã", "é"…
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      // ViaCEP devolve {"erro": true} (HTTP 200) para CEP inexistente —
      // é a única forma de detectar; status code não basta.
      if (data['erro'] == true) {
        throw const ViaCepServiceException(
          'CEP não encontrado. Preencha o endereço manualmente.',
        );
      }

      return ViaCepAddress.fromJson(data);
    } on ViaCepServiceException {
      // Re-lança a exceção semântica sem envelopar — telas tratam pela mensagem.
      rethrow;
    } on TimeoutException {
      throw const ViaCepServiceException(
        'Tempo esgotado ao consultar o CEP. Tente novamente.',
      );
    } catch (_) {
      // Qualquer outro erro (socket, DNS, JSON malformado) vira mensagem
      // amigável — nunca expor stack trace ao usuário (LGPD/UX).
      throw const ViaCepServiceException(
        'Não foi possível consultar o CEP. Verifique a conexão.',
      );
    }
  }
}
