import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/renewal_request_model.dart';
import '../models/user_model.dart';

// ---------------------------------------------------------------------------
// Exceção tipada — evita vazar detalhes internos do Postgres na UI (LGPD).
// ---------------------------------------------------------------------------

/// Exceção lançada quando uma operação de [IRenewalService] falha de forma
/// previsível (RLS, constraint, default ausente, etc.).
///
/// A camada de provider/UI deve consumir [message] diretamente — já vem
/// humanizada e em PT-BR. Evita que a tela precise inspecionar `code`/`details`
/// crus de [PostgrestException], cumprindo o princípio de não expor stack
/// traces ou nomes de constraints ao usuário final (segurança + LGPD).
class RenewalRequestException implements Exception {
  /// Mensagem amigável já pronta para exibição (PT-BR, sem dados sensíveis).
  final String message;

  /// Código SQLSTATE original (`23505`, `42501`, ...) preservado apenas para
  /// telemetria/log interno. Nunca deve ser exibido ao usuário.
  final String? code;

  /// Construtor padrão.
  RenewalRequestException(this.message, {this.code});

  @override
  String toString() => 'RenewalRequestException($code): $message';
}

// ---------------------------------------------------------------------------
// Interface abstrata — obrigatória para injeção de dependência e TDD (Mockito)
// ---------------------------------------------------------------------------

/// Contrato da camada de acesso a dados para pedidos de renovação de prescrição.
///
/// Toda a comunicação ocorre via Supabase SDK diretamente — sem passar pelo
/// backend Express. O controle de acesso é garantido pelas políticas RLS
/// configuradas na tabela [public."RenewalRequest"].
///
/// Implementação concreta: [RenewalService].
/// Mock de teste: gerado pelo `@GenerateMocks([IRenewalService])` via Mockito.
abstract class IRenewalService {
  // ---- Métodos do paciente ------------------------------------------------

  /// Retorna um stream das renovações do paciente autenticado, em tempo real.
  ///
  /// O RLS (paciente_ve_proprios_pedidos) garante que apenas os pedidos do
  /// próprio paciente são retornados, sem necessidade de filtro explícito.
  /// Ordenados por data de criação decrescente (mais recente primeiro).
  Stream<List<RenewalRequestModel>> streamMyRenewals();

  /// Solicita a renovação de uma prescrição expirada.
  ///
  /// [prescriptionId] é o ID da prescrição a ser renovada.
  /// [notes] são observações opcionais do paciente (máx. 500 caracteres).
  ///
  /// O campo `patientUserId` é inferido via [SupabaseClient.auth] internamente —
  /// nunca deve ser aceito como parâmetro externo para evitar falsificação de
  /// identidade. O RLS (paciente_insere_pedido) valida que o valor corresponde
  /// ao `auth.uid()` no servidor antes de persistir o registro.
  Future<void> requestRenewal(String prescriptionId, {String? notes});

  // ---- Métodos do enfermeiro ----------------------------------------------

  /// Retorna um stream dos pedidos aguardando triagem (status PENDING_TRIAGE).
  ///
  /// Visível apenas para usuários com `professionalType = ENFERMEIRO` —
  /// o RLS (enfermeiro_ve_pendentes) rejeita silenciosamente para outros perfis.
  /// Ordenados por data de criação crescente (FIFO — mais antigo primeiro).
  Stream<List<RenewalRequestModel>> streamPendingTriage();

  /// Aprova a triagem de um pedido, designando um médico responsável.
  ///
  /// Transição de estado: PENDING_TRIAGE → TRIAGED.
  /// [id] é o identificador do pedido de renovação.
  /// [nurseNotes] são observações opcionais do enfermeiro.
  /// [doctorUserId] é o ID do médico que irá emitir a renovação.
  ///
  /// O RLS (enfermeiro_atualiza_pendente) bloqueia a operação caso o usuário
  /// não seja enfermeiro ou o pedido esteja em estado diferente de PENDING_TRIAGE.
  Future<void> approveTriage(
    String id, {
    String? nurseNotes,
    required String doctorUserId,
  });

  /// Rejeita um pedido de renovação durante a triagem.
  ///
  /// Transição de estado: PENDING_TRIAGE → REJECTED.
  /// [nurseNotes] é obrigatório para registrar o motivo da rejeição
  /// (exigência de auditoria — LGPD, dados de saúde).
  Future<void> rejectTriage(String id, {required String nurseNotes});

  // ---- Métodos do médico --------------------------------------------------

  /// Retorna um stream dos pedidos triados designados ao médico autenticado.
  ///
  /// Visível apenas para o médico cujo ID corresponde a `doctorUserId` do pedido
  /// com status TRIAGED — controlado pelo RLS (medico_ve_triados).
  /// Ordenados por data de criação crescente (FIFO — mais antigo primeiro).
  Stream<List<RenewalRequestModel>> streamTriagedForDoctor();

  /// Marca um pedido como prescrito após emitir a nova prescrição.
  ///
  /// Transição de estado: TRIAGED → PRESCRIBED.
  /// [id] é o identificador do pedido de renovação.
  /// [renewedPrescriptionId] é o ID da nova prescrição emitida.
  Future<void> markAsPrescribed(String id, String renewedPrescriptionId);

  // ---- Método utilitário (enfermeiro) -------------------------------------

  /// Busca a lista de médicos disponíveis para seleção na etapa de triagem.
  ///
  /// Retorna apenas médicos (professionalType = MEDICO), com os campos mínimos
  /// necessários para exibição na UI — CPF, CNS e dados sensíveis são omitidos
  /// (LGPD — princípio da minimização).
  Future<List<UserModel>> fetchDoctors();
}

// ---------------------------------------------------------------------------
// Implementação concreta via Supabase SDK
// ---------------------------------------------------------------------------

/// Implementação de [IRenewalService] usando o Supabase SDK diretamente,
/// sem passar pelo backend Express.
///
/// O controle de acesso é delegado ao RLS do Supabase — cada operação só
/// é executada se o usuário autenticado tiver a política correspondente.
/// Erros de RLS são propagados como exceções do tipo [PostgrestException].
class RenewalService implements IRenewalService {
  final SupabaseClient _supabase;

  /// Nome da tabela no PostgreSQL — PascalCase porque foi criada pelo Prisma
  /// com quoted identifier (`"RenewalRequest"`). O PostgREST do Supabase
  /// preserva o case exato ao converter o path da URL.
  static const String _table = 'RenewalRequest';

  /// Nome da tabela de usuários — também criada via Prisma com quoted identifier.
  /// Tabela de profissionais — alterada na migration split_user_patients_professionals.
  static const String _userTable = 'professionals';

  /// Construtor que aceita [SupabaseClient] opcional para facilitar injeção
  /// em testes unitários sem precisar instanciar o Supabase real.
  RenewalService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ---- Helpers privados ---------------------------------------------------

  /// Retorna o ID do usuário autenticado ou lança [StateError] se não houver sessão.
  ///
  /// Nunca inclui e-mail, nome ou qualquer dado pessoal na mensagem de erro —
  /// apenas uma string opaca para evitar vazamento de informação em logs.
  String get _currentUserId {
    final uid = _supabase.auth.currentUser?.id;
    // Guarda de autenticação — método chamado apenas em contexto protegido;
    // se chegar aqui sem sessão, é um erro de programação, não de fluxo normal.
    if (uid == null) throw StateError('usuario_nao_autenticado');
    return uid;
  }

  /// Converte uma lista de Maps retornada pelo Supabase em [List<RenewalRequestModel>].
  ///
  /// O mapeamento é feito item a item pelo [RenewalRequestModel.fromJson].
  List<RenewalRequestModel> _mapToModels(List<Map<String, dynamic>> rows) {
    return rows.map((row) => RenewalRequestModel.fromJson(row)).toList();
  }

  // ---- Métodos do paciente ------------------------------------------------

  @override
  Stream<List<RenewalRequestModel>> streamMyRenewals() {
    final userId = _supabase.auth.currentUser?.id;
    // Retorna stream vazio sem lançar exceção — a tela exibirá estado "sem dados"
    // em vez de quebrar. O RLS também bloquearia a query sem sessão.
    if (userId == null) return const Stream.empty();

    late StreamController<List<RenewalRequestModel>> controller;
    RealtimeChannel? channel;

    /// Busca os pedidos do paciente com join para obter o nome do medicamento.
    /// O join usa a FK [prescriptionId → prescriptions.id] via PostgREST.
    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from(_table)
            .select('*, prescription:prescriptions(medicine_name, type)')
            .eq('patientUserId', userId)
            .order('createdAt', ascending: false);
        if (!controller.isClosed) {
          controller.add(_mapToModels(List<Map<String, dynamic>>.from(rows)));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<RenewalRequestModel>>(
      onListen: () {
        fetch();
        // Canal Realtime dispara refetch quando a tabela muda — garante UX
        // responsivo sem polling, mesmo com o join não sendo suportado pelo
        // stream nativo do Supabase SDK.
        channel = _supabase
            .channel(
                'my_renewals_${userId}_${DateTime.now().millisecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              callback: (_) => fetch(),
            )
            .subscribe();
      },
      onCancel: () {
        // Limpa o canal para evitar vazamento de subscription ao descartar a tela.
        if (channel != null) _supabase.removeChannel(channel!);
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> requestRenewal(String prescriptionId, {String? notes}) async {
    // patientUserId é obrigatório no INSERT (NOT NULL na tabela) mas NUNCA é
    // aceito como parâmetro externo. É lido de auth.currentUser para garantir
    // que o cliente não pode forjar uma identidade diferente. O RLS
    // (paciente_insere_pedido) faz a validação final no servidor com auth.uid().
    //
    // O try/catch converte PostgrestException em RenewalRequestException
    // tipada com mensagem humanizada — evita expor SQLSTATE/constraint name
    // na UI (segurança + LGPD) e dá feedback acionável ao paciente quando o
    // erro tem causa conhecida (ex.: já existe pedido pendente, RLS negou,
    // FK quebrada, default ausente após bug de migração — caso histórico AB#228).
    try {
      await _supabase.from(_table).insert({
        'prescriptionId': prescriptionId,
        'patientUserId': _currentUserId,
        if (notes != null) 'patientNotes': notes,
      });
    } on PostgrestException catch (e) {
      // Loga apenas código + mensagem técnica (sem prescriptionId nem notes,
      // que podem revelar dados clínicos). LGPD art. 6° VII (segurança).
      developer.log(
        'requestRenewal falhou',
        name: 'RenewalService',
        error: 'code=${e.code} message=${e.message}',
      );
      throw RenewalRequestException(
        _mapPostgrestErrorToUserMessage(e),
        code: e.code,
      );
    }
  }

  /// Converte códigos SQLSTATE conhecidos em mensagens humanizadas em PT-BR.
  ///
  /// Mantém um fallback genérico para qualquer código não mapeado — nunca
  /// retorna a mensagem crua do Postgres, que pode conter nomes de tabelas,
  /// colunas e constraints (vetor de information disclosure).
  String _mapPostgrestErrorToUserMessage(PostgrestException e) {
    switch (e.code) {
      // Trigger PL/pgSQL com RAISE EXCEPTION — mensagem já é humanizada
      // pelo backend (ex.: validações customizadas em triggers futuros).
      case 'P0001':
        return e.message;
      // RLS negou a operação (paciente_insere_pedido) — sessão expirada,
      // tentativa de inserir com patientUserId diferente do auth.uid(), etc.
      case '42501':
        return 'Você não tem permissão para solicitar essa renovação. '
            'Faça login novamente e tente de novo.';
      // FK violada — prescriptionId aponta para registro inexistente.
      // Aconteceria também se a prescrição tivesse sido removida entre o
      // carregamento da tela e o envio do pedido.
      case '23503':
        return 'Receita não encontrada. Atualize a tela e tente novamente.';
      // Unique constraint — paciente já tem pedido ativo para esta prescrição.
      case '23505':
        return 'Você já possui um pedido de renovação ativo para esta prescrição.';
      // NOT NULL violada — caso histórico do AB#228 (id/updatedAt sem default).
      // Hoje resolvido pela migration renewal_request_defaults, mas mantemos
      // o mapeamento como guardrail caso surja nova coluna NOT NULL.
      case '23502':
        return 'Não foi possível enviar o pedido de renovação. '
            'Avise o suporte se o problema persistir.';
      // Tabela inexistente — erro de configuração de ambiente, não do usuário.
      case '42P01':
        return 'Erro de configuração do sistema. Avise o suporte.';
      default:
        return 'Não foi possível enviar o pedido de renovação. Tente novamente.';
    }
  }

  // ---- Métodos do enfermeiro ----------------------------------------------

  @override
  Stream<List<RenewalRequestModel>> streamPendingTriage() {
    late StreamController<List<RenewalRequestModel>> controller;
    RealtimeChannel? channel;

    /// Busca pedidos PENDING_TRIAGE com join para exibir o nome do medicamento
    /// na fila de triagem — essencial para contexto clínico do enfermeiro.
    /// A policy [prescriptions_select_nurse_triage] permite que enfermeiros
    /// leiam a prescrição referenciada sem expor dados além do necessário.
    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from(_table)
            .select('*, prescription:prescriptions(medicine_name, type)')
            .eq('status', RenewalStatus.pendingTriage.value)
            .order('createdAt', ascending: true);
        if (!controller.isClosed) {
          controller.add(_mapToModels(List<Map<String, dynamic>>.from(rows)));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<RenewalRequestModel>>(
      onListen: () {
        fetch();
        // Filtro explícito no status para que a subscription Realtime ignore
        // eventos de outros estados — subscription cirúrgica reduz tráfego.
        channel = _supabase
            .channel('pending_triage_${DateTime.now().millisecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              callback: (_) => fetch(),
            )
            .subscribe();
      },
      onCancel: () {
        if (channel != null) _supabase.removeChannel(channel!);
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> approveTriage(
    String id, {
    String? nurseNotes,
    required String doctorUserId,
  }) async {
    // Transição PENDING_TRIAGE → TRIAGED.
    // nurseUserId é inferido do usuário autenticado — não aceito como parâmetro.
    // updatedAt é gerenciado manualmente pois estamos usando o SDK direto (sem Prisma).
    await _supabase.from(_table).update({
      'status': RenewalStatus.triaged.value,
      'doctorUserId': doctorUserId,
      'nurseUserId': _currentUserId,
      if (nurseNotes != null) 'nurseNotes': nurseNotes,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  @override
  Future<void> rejectTriage(String id, {required String nurseNotes}) async {
    // Transição PENDING_TRIAGE → REJECTED.
    // nurseNotes é obrigatório para garantir rastreabilidade do motivo de
    // rejeição — requisito de auditoria em dados de saúde (LGPD art. 11).
    await _supabase.from(_table).update({
      'status': RenewalStatus.rejected.value,
      'nurseUserId': _currentUserId,
      'nurseNotes': nurseNotes,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ---- Métodos do médico --------------------------------------------------

  @override
  Stream<List<RenewalRequestModel>> streamTriagedForDoctor() {
    final userId = _supabase.auth.currentUser?.id;
    // Retorna stream vazio sem exceção se não houver sessão — tela exibirá
    // estado vazio em vez de quebrar.
    if (userId == null) return const Stream.empty();

    late StreamController<List<RenewalRequestModel>> controller;
    RealtimeChannel? channel;

    /// Busca pedidos TRIAGED com join para exibir o nome do medicamento no card.
    /// A policy [prescriptions_select_doctor_triage] permite que o médico
    /// designado leia a prescrição original mesmo não sendo o autor.
    Future<void> fetch() async {
      try {
        final rows = await _supabase
            .from(_table)
            .select('*, prescription:prescriptions(medicine_name, type)')
            .eq('doctorUserId', userId)
            .order('createdAt', ascending: true);
        if (!controller.isClosed) {
          controller.add(_mapToModels(List<Map<String, dynamic>>.from(rows)));
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<List<RenewalRequestModel>>(
      onListen: () {
        fetch();
        // Canal filtrado por doctorUserId — subscription cirúrgica para o
        // médico autenticado, minimizando eventos Realtime desnecessários.
        channel = _supabase
            .channel(
                'triaged_doctor_${userId}_${DateTime.now().millisecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: _table,
              callback: (_) => fetch(),
            )
            .subscribe();
      },
      onCancel: () {
        if (channel != null) _supabase.removeChannel(channel!);
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> markAsPrescribed(String id, String renewedPrescriptionId) async {
    // Transição TRIAGED → PRESCRIBED.
    // O RLS (medico_atualiza_triado) bloqueia a operação para usuários que não
    // são o médico designado ou para pedidos fora do estado TRIAGED.
    await _supabase.from(_table).update({
      'status': RenewalStatus.prescribed.value,
      'renewedPrescriptionId': renewedPrescriptionId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ---- Método utilitário (enfermeiro) -------------------------------------

  @override
  Future<List<UserModel>> fetchDoctors() async {
    // Projeta apenas os campos necessários para exibição na UI de triagem.
    // Campos sensíveis de saúde (cpf, cns, telefone, endereço) são omitidos
    // intencionalmente — princípio da minimização (LGPD art. 6°, III).
    final rows = await _supabase
        .from(_userTable)
        .select('id, firstName, lastName, email, specialty, professionalType')
        .eq('professionalType', 'MEDICO')
        .order('firstName', ascending: true);

    return rows.map<UserModel>((row) => UserModel.fromJson(row)).toList();
  }
}
