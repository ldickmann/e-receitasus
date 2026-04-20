import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/patient_search_result.dart';
import '../models/prescription_model.dart';

/// Contrato público da camada de acesso a prescrições.
///
/// Por que abstrair (Fase 4 da refatoração AB#129):
/// - Permite mockar via Mockito nos testes de providers/screens sem precisar
///   stubar o `SupabaseClient` (que é frágil e acopla os testes ao SDK).
/// - Mantém a regra do projeto: "toda service expõe interface abstrata".
/// - Facilita futura troca da implementação (ex.: mock para offline-first ou
///   gateway REST do backend) sem alterar consumidores.
abstract class IPrescriptionService {
  /// Stream em tempo real das prescrições do paciente autenticado.
  Stream<List<Map<String, dynamic>>> streamPrescriptions();

  /// Stream em tempo real das prescrições emitidas pelo médico autenticado.
  Stream<List<Map<String, dynamic>>> streamDoctorPrescriptions();

  /// Persiste uma nova prescrição e devolve o modelo com `id` preenchido.
  Future<PrescriptionModel> savePrescription(PrescriptionModel prescription);

  /// Busca uma prescrição pelo identificador. Retorna `null` se não existir.
  Future<PrescriptionModel?> getPrescriptionById(String id);

  /// Atualiza somente o status (ativa, utilizada, cancelada).
  Future<void> updateStatus(String id, String status);

  /// Histórico completo (sem stream) das prescrições do paciente autenticado.
  Future<List<PrescriptionModel>> fetchPatientHistory();

  /// Histórico completo (sem stream) das prescrições emitidas pelo médico.
  Future<List<PrescriptionModel>> fetchDoctorHistory();

  /// Busca pacientes para o autocomplete do formulário de prescrição.
  ///
  /// Retorna lista vazia para `query` com menos de 2 caracteres a fim de
  /// evitar chamadas desnecessárias e exposição de dados (LGPD).
  Future<List<PatientSearchResult>> searchPatients(String query);
}

/// Implementação concreta usando o SDK do Supabase.
///
/// Mantém compatibilidade com o construtor sem args atualmente usado pelas
/// telas (HomeScreen, DoctorHomeScreen, HistoryScreen, PrescriptionFormScreen,
/// RenewalPrescriptionScreen, RequestRenewalScreen). O parâmetro [client]
/// permite injeção em testes.
class PrescriptionService implements IPrescriptionService {
  final SupabaseClient _supabase;

  PrescriptionService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static const String _table = 'prescriptions';

  // ---------------------------------------------------------------------------
  // Streams em tempo real
  // ---------------------------------------------------------------------------

  /// Stream das receitas do paciente autenticado (para HomeScreen).
  @override
  Stream<List<Map<String, dynamic>>> streamPrescriptions() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('patient_user_id', myId)
        .order('issued_at', ascending: false);
  }

  /// Stream das receitas emitidas pelo médico autenticado (para DoctorHomeScreen).
  @override
  Stream<List<Map<String, dynamic>>> streamDoctorPrescriptions() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('doctor_user_id', myId)
        .order('issued_at', ascending: false);
  }

  // ---------------------------------------------------------------------------
  // Operações CRUD
  // ---------------------------------------------------------------------------

  /// Salva uma nova prescrição no Supabase.
  /// Retorna o modelo com o id preenchido após inserção.
  @override
  Future<PrescriptionModel> savePrescription(
      PrescriptionModel prescription) async {
    final data = prescription.toJson();
    final response =
        await _supabase.from(_table).insert(data).select().single();
    return PrescriptionModel.fromJson(response);
  }

  /// Busca uma prescrição pelo id.
  @override
  Future<PrescriptionModel?> getPrescriptionById(String id) async {
    final response =
        await _supabase.from(_table).select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return PrescriptionModel.fromJson(response);
  }

  /// Atualiza o status de uma prescrição (ativa, utilizada, cancelada).
  @override
  Future<void> updateStatus(String id, String status) async {
    await _supabase.from(_table).update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }

  /// Lista histórico completo de receitas do paciente (sem stream).
  @override
  Future<List<PrescriptionModel>> fetchPatientHistory() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _supabase
        .from(_table)
        .select()
        .eq('patient_user_id', myId)
        .order('issued_at', ascending: false);

    return (response as List)
        .map((row) => PrescriptionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Lista histórico completo de receitas emitidas pelo médico.
  @override
  Future<List<PrescriptionModel>> fetchDoctorHistory() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _supabase
        .from(_table)
        .select()
        .eq('doctor_user_id', myId)
        .order('issued_at', ascending: false);

    return (response as List)
        .map((row) => PrescriptionModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Busca de pacientes (autocomplete)
  // ---------------------------------------------------------------------------

  /// Busca pacientes cadastrados pelo nome para o autocomplete do formulário
  /// de prescrição.
  ///
  /// Usa a RPC `search_patients_for_prescription` (SECURITY DEFINER) que
  /// verifica internamente se o chamador é um profissional de saúde antes de
  /// retornar qualquer dado. Retorna no máximo 10 resultados.
  /// Consultas com menos de 2 caracteres retornam lista vazia sem acionar a RPC.
  @override
  Future<List<PatientSearchResult>> searchPatients(String query) async {
    if (query.trim().length < 2) return [];

    final response = await _supabase.rpc(
      'search_patients_for_prescription',
      params: {'name_query': query.trim()},
    );

    return (response as List)
        .map((row) => PatientSearchResult.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
