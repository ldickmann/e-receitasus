import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/patient_search_result.dart';
import '../models/prescription_model.dart';

/// Exceção tipada para falhas na busca de pacientes (RPC
/// `search_patients_for_prescription`).
///
/// Permite que a UI distinga falhas de busca de outras exceções e exiba
/// feedback ao médico sem vazar detalhes internos do Supabase ou da query.
class PatientSearchException implements Exception {
  /// Mensagem genérica destinada à UI (não contém dados sensíveis).
  final String message;

  const PatientSearchException(this.message);

  @override
  String toString() => 'PatientSearchException: $message';
}

class PrescriptionService {
  final _supabase = Supabase.instance.client;

  static const String _table = 'prescriptions';

  // ---------------------------------------------------------------------------
  // Streams em tempo real
  // ---------------------------------------------------------------------------

  /// Stream das receitas do paciente autenticado (para HomeScreen).
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
  Future<PrescriptionModel> savePrescription(
      PrescriptionModel prescription) async {
    final data = prescription.toJson();
    final response =
        await _supabase.from(_table).insert(data).select().single();
    return PrescriptionModel.fromJson(response);
  }

  /// Busca uma prescrição pelo id.
  Future<PrescriptionModel?> getPrescriptionById(String id) async {
    final response =
        await _supabase.from(_table).select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return PrescriptionModel.fromJson(response);
  }

  /// Atualiza o status de uma prescrição (ativa, utilizada, cancelada).
  Future<void> updateStatus(String id, String status) async {
    await _supabase.from(_table).update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }

  /// Lista histórico completo de receitas do paciente (sem stream).
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
  ///
  /// Em caso de falha (rede, RLS, RPC ausente, payload inválido), lança
  /// [PatientSearchException] com mensagem genérica para a UI exibir feedback,
  /// e registra o erro técnico via `developer.log` no canal interno —
  /// nunca logando o texto da `query` nem o payload retornado, em conformidade
  /// com a LGPD (dados pessoais de pacientes).
  Future<List<PatientSearchResult>> searchPatients(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final List<dynamic> response;
    try {
      // Chamada à RPC: protegida por SECURITY DEFINER + checagem de profissional.
      final raw = await _supabase.rpc(
        'search_patients_for_prescription',
        params: {'name_query': trimmed},
      );
      // RPC sempre retorna List (mesmo vazia); defensivo contra tipo inesperado.
      if (raw is! List) {
        throw const PatientSearchException(
          'Resposta inesperada do servidor ao buscar pacientes.',
        );
      }
      response = raw;
    } on PostgrestException catch (e) {
      // Loga apenas código + mensagem do Postgrest (sem query, sem payload do paciente).
      developer.log(
        'Falha Postgrest em search_patients_for_prescription',
        name: 'PrescriptionService.searchPatients',
        error: '${e.code}: ${e.message}',
      );
      throw const PatientSearchException(
        'Não foi possível buscar pacientes no momento. Tente novamente.',
      );
    } catch (e) {
      // Erros de rede / parsing / desconhecidos: loga sem expor a query.
      developer.log(
        'Falha inesperada em search_patients_for_prescription',
        name: 'PrescriptionService.searchPatients',
        error: e.runtimeType.toString(),
      );
      throw const PatientSearchException(
        'Erro ao consultar pacientes. Verifique sua conexão e tente novamente.',
      );
    }

    try {
      // Mapeamento explícito: full_name (RPC) → fullName (modelo).
      return response
          .map((row) =>
              PatientSearchResult.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Schema da RPC mudou ou veio um campo nulo onde não deveria.
      developer.log(
        'Falha ao mapear resultado de search_patients_for_prescription',
        name: 'PrescriptionService.searchPatients',
        error: e.runtimeType.toString(),
      );
      throw const PatientSearchException(
        'Resultado da busca em formato inválido.',
      );
    }
  }
}
