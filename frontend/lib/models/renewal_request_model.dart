/// Modelo de pedido de renovação de prescrição médica.
///
/// Espelha o model `RenewalRequest` e o enum `RenewalStatus` do schema Prisma
/// (`backend/prisma/schema.prisma`). Qualquer alteração no schema deve ser
/// refletida aqui para manter o contrato cross-stack.
///
/// Fluxo de estados: PENDING_TRIAGE → TRIAGED → PRESCRIBED | REJECTED.
library;

import 'prescription_type.dart';

// ---------------------------------------------------------------------------
// Enum RenewalStatus
// ---------------------------------------------------------------------------

/// Representa os estados possíveis de um pedido de renovação.
///
/// Os valores de [value] correspondem exatamente às strings armazenadas no
/// banco (enum Prisma `RenewalStatus`), garantindo serialização correta.
/// O campo [label] é o texto exibido ao usuário em PT-BR.
enum RenewalStatus {
  /// Pedido criado pelo paciente — aguardando triagem pela enfermagem.
  pendingTriage('PENDING_TRIAGE', 'Aguardando triagem'),

  /// Pedido triado pela enfermagem — médico designado, aguardando emissão.
  triaged('TRIAGED', 'Triado'),

  /// Médico emitiu a nova prescrição — fluxo concluído com sucesso.
  prescribed('PRESCRIBED', 'Prescrição emitida'),

  /// Pedido rejeitado pela enfermagem ou médico — fluxo encerrado sem renovação.
  rejected('REJECTED', 'Rejeitado');

  /// Valor canônico persistido no banco (maiúsculas com underline).
  final String value;

  /// Rótulo em PT-BR para exibição na interface do usuário.
  final String label;

  const RenewalStatus(this.value, this.label);

  /// Converte uma string vinda do banco/API para o enum correspondente.
  ///
  /// Usa fallback para [pendingTriage] quando o valor não é reconhecido,
  /// evitando erros silenciosos em versões com dados legados.
  static RenewalStatus fromString(String value) {
    return RenewalStatus.values.firstWhere(
      (e) => e.value == value,
      // Fallback seguro: mantém o pedido visível em vez de quebrar a tela
      orElse: () => RenewalStatus.pendingTriage,
    );
  }
}

// ---------------------------------------------------------------------------
// RenewalRequestModel
// ---------------------------------------------------------------------------

/// Representa um pedido de renovação de prescrição feito por um paciente SUS.
///
/// Os campos seguem camelCase espelhando as colunas do model Prisma `RenewalRequest`.
/// Os campos [medicineName] e [prescriptionType] são desnormalizados — vindos de
/// join com a tabela `Prescription` — e são opcionais para suportar respostas
/// sem o join (ex.: listagem resumida).
class RenewalRequestModel {
  /// Identificador único do pedido (UUID gerado pelo Supabase/Postgres).
  final String id;

  /// ID da prescrição original que está sendo renovada.
  final String prescriptionId;

  /// ID do paciente que solicitou a renovação (FK para `User`).
  final String patientUserId;

  /// ID do médico designado pelo enfermeiro para emitir a renovação.
  /// Null até a transição para o estado [RenewalStatus.triaged].
  final String? doctorUserId;

  /// ID do enfermeiro que realizou ou rejeitou a triagem.
  /// Null até a triagem ser executada.
  final String? nurseUserId;

  /// Estado atual do pedido no ciclo de vida de renovação.
  final RenewalStatus status;

  /// Observações opcionais fornecidas pelo paciente no momento da solicitação.
  /// Limite de 500 caracteres — validação aplicada nas camadas superiores.
  final String? patientNotes;

  /// Notas do enfermeiro; obrigatórias quando o status é [RenewalStatus.rejected].
  final String? nurseNotes;

  /// ID da nova prescrição emitida ao concluir o fluxo (soft reference).
  /// Null enquanto o médico ainda não emitiu a renovação.
  final String? renewedPrescriptionId;

  /// Data e hora de criação do pedido (UTC).
  final DateTime createdAt;

  /// Data e hora da última atualização do pedido (UTC).
  final DateTime updatedAt;

  // ---- Campos desnormalizados (vindos de join com Prescription) ----

  /// Nome do medicamento da prescrição original.
  /// Presente apenas quando a API retorna o join com `Prescription`.
  final String? medicineName;

  /// Tipo ANVISA da prescrição original (Branca, Controlada, Amarela, Azul).
  /// Presente apenas quando a API retorna o join com `Prescription`.
  final PrescriptionType? prescriptionType;

  const RenewalRequestModel({
    required this.id,
    required this.prescriptionId,
    required this.patientUserId,
    this.doctorUserId,
    this.nurseUserId,
    required this.status,
    this.patientNotes,
    this.nurseNotes,
    this.renewedPrescriptionId,
    required this.createdAt,
    required this.updatedAt,
    this.medicineName,
    this.prescriptionType,
  });

  /// Desserializa um [RenewalRequestModel] a partir de um mapa JSON.
  ///
  /// Suporta resposta plana da API e resposta com join da tabela `Prescription`
  /// (quando o backend inclui os campos `medicineName` e `prescriptionType`
  /// ou um objeto aninhado `prescription`).
  factory RenewalRequestModel.fromJson(Map<String, dynamic> json) {
    // Extrai dados desnormalizados da prescrição — vindos diretamente
    // no root do JSON (quando o backend faz o join e projeta os campos)
    // ou do objeto aninhado `prescription` (caso de expansão via include).
    final Map<String, dynamic>? nestedPrescription =
        json['prescription'] as Map<String, dynamic>?;

    final String? rawMedicineName =
        json['medicineName'] as String? ??
        nestedPrescription?['medicine'] as String?;

    // Converte o tipo de prescrição de string para o enum PrescriptionType;
    // usa null quando o campo não está presente na resposta.
    final String? rawType =
        json['prescriptionType'] as String? ??
        nestedPrescription?['type'] as String?;

    final PrescriptionType? resolvedType = rawType != null
        ? _parsePrescriptionType(rawType)
        : null;

    return RenewalRequestModel(
      id: json['id'] as String,
      prescriptionId: json['prescriptionId'] as String,
      patientUserId: json['patientUserId'] as String,
      doctorUserId: json['doctorUserId'] as String?,
      nurseUserId: json['nurseUserId'] as String?,
      status: RenewalStatus.fromString(json['status'] as String? ?? ''),
      patientNotes: json['patientNotes'] as String?,
      nurseNotes: json['nurseNotes'] as String?,
      renewedPrescriptionId: json['renewedPrescriptionId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      medicineName: rawMedicineName,
      prescriptionType: resolvedType,
    );
  }

  /// Serializa o modelo para mapa JSON (usado em requisições de criação/atualização).
  ///
  /// Campos nulos são omitidos para evitar sobrescrever valores existentes no
  /// backend com null desnecessário.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescriptionId': prescriptionId,
      'patientUserId': patientUserId,
      if (doctorUserId != null) 'doctorUserId': doctorUserId,
      if (nurseUserId != null) 'nurseUserId': nurseUserId,
      'status': status.value,
      if (patientNotes != null) 'patientNotes': patientNotes,
      if (nurseNotes != null) 'nurseNotes': nurseNotes,
      if (renewedPrescriptionId != null)
        'renewedPrescriptionId': renewedPrescriptionId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// ---------------------------------------------------------------------------
// Helpers privados
// ---------------------------------------------------------------------------

/// Converte uma string de tipo de prescrição para o enum [PrescriptionType].
///
/// Retorna null quando o valor não corresponde a nenhum tipo conhecido,
/// evitando falha silenciosa ao processar dados legados ou de outro sistema.
PrescriptionType? _parsePrescriptionType(String raw) {
  final String normalized = raw.toUpperCase();
  return PrescriptionType.values.firstWhere(
    (t) => t.value.toUpperCase() == normalized,
    orElse: () => PrescriptionType.branca, // fallback ao tipo mais permissivo
  );
}
