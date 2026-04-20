import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/renewal_request_model.dart';
import '../models/user_model.dart';
import '../providers/triage_provider.dart';
import '../theme/app_colors.dart';

/// Tela de detalhes de um pedido de renovação para triagem pelo enfermeiro.
///
/// Recebe o [request] selecionado na [NurseHomeScreen] e apresenta 4 seções:
/// 1. Dados da prescrição original (medicamento, tipo ANVISA, validade).
/// 2. Observações do paciente (read-only — LGPD: sem CPF).
/// 3. Notas do enfermeiro (obrigatórias ao rejeitar).
/// 4. Seleção do médico responsável (obrigatória ao aprovar).
///
/// Ações:
/// - [APROVAR]: exige médico selecionado → diálogo → [TriageProvider.approveTriage].
/// - [REJEITAR]: exige notas preenchidas → diálogo → [TriageProvider.rejectTriage].
///
/// Sucesso: SnackBar informativo + [Navigator.pop].
/// Erro: SnackBar genérico sem expor detalhes internos (OWASP A03/A09).
class TriageDetailScreen extends StatefulWidget {
  /// Pedido de renovação a ser avaliado pelo enfermeiro.
  final RenewalRequestModel request;

  const TriageDetailScreen({super.key, required this.request});

  @override
  State<TriageDetailScreen> createState() => _TriageDetailScreenState();
}

class _TriageDetailScreenState extends State<TriageDetailScreen> {
  /// Controlador do campo de notas do enfermeiro.
  final TextEditingController _nurseNotesController = TextEditingController();

  /// Médico selecionado no dropdown para encaminhar o pedido.
  UserModel? _selectedDoctor;

  /// Future memoizado no [initState] para evitar nova chamada a cada rebuild.
  late final Future<List<UserModel>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    // Busca a lista de médicos uma única vez ao montar a tela
    _doctorsFuture = context.read<TriageProvider>().fetchDoctors();
  }

  @override
  void dispose() {
    _nurseNotesController.dispose();
    super.dispose();
  }

  // ── Ações principais ──────────────────────────────────────────────────────

  /// Executa o fluxo de aprovação da triagem.
  ///
  /// Exige médico selecionado, exibe confirmação e chama
  /// [TriageProvider.approveTriage]. Notas do enfermeiro são opcionais ao aprovar.
  Future<void> _handleApprove() async {
    // Validação de domínio: médico é pré-requisito para aprovar
    if (_selectedDoctor == null) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Confirmar aprovação',
      content:
          'Encaminhar pedido para Dr(a). ${_selectedDoctor!.name}?\n\nEsta ação não pode ser desfeita.',
      confirmLabel: 'Aprovar',
      confirmColor: AppColors.primary,
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<TriageProvider>();
    final nurseNotes = _nurseNotesController.text.trim();

    final success = await provider.approveTriage(
      id: widget.request.id,
      // Notas são opcionais ao aprovar — envia apenas se preenchidas
      nurseNotes: nurseNotes.isNotEmpty ? nurseNotes : null,
      doctorUserId: _selectedDoctor!.id,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido aprovado e encaminhado ao médico.'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context);
    } else {
      // Exibe mensagem genérica — sem stack trace (OWASP A09 / segurança)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Não foi possível aprovar o pedido.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      provider.clearError();
    }
  }

  /// Executa o fluxo de rejeição da triagem.
  ///
  /// Exige notas do enfermeiro (necessário para auditoria — LGPD art. 11),
  /// exibe confirmação e chama [TriageProvider.rejectTriage].
  Future<void> _handleReject() async {
    final nurseNotes = _nurseNotesController.text.trim();

    // Validação de domínio: motivo obrigatório para rastreabilidade do dado de saúde
    if (nurseNotes.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Confirmar rejeição',
      content:
          'Rejeitar este pedido de renovação?\n\nO paciente será notificado com o motivo informado.',
      confirmLabel: 'Rejeitar',
      confirmColor: Colors.red,
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<TriageProvider>();

    final success = await provider.rejectTriage(
      id: widget.request.id,
      nurseNotes: nurseNotes,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pedido rejeitado com sucesso.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Não foi possível rejeitar o pedido.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      provider.clearError();
    }
  }

  /// Exibe um diálogo de confirmação e retorna [true] se o usuário confirmar.
  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: confirmColor),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triagem de Pedido'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seção 1 — dados da prescrição original
            _PrescriptionDataSection(request: widget.request),
            const SizedBox(height: 16),
            // Seção 2 — observações do paciente (read-only)
            _PatientNotesSection(notes: widget.request.patientNotes),
            const SizedBox(height: 16),
            // Seção 3 — campo de notas do enfermeiro
            _NurseNotesSection(controller: _nurseNotesController),
            const SizedBox(height: 16),
            // Seção 4 — dropdown de seleção do médico
            _DoctorSelectionSection(
              doctorsFuture: _doctorsFuture,
              selectedDoctor: _selectedDoctor,
              onDoctorSelected: (doctor) {
                setState(() => _selectedDoctor = doctor);
              },
            ),
            const SizedBox(height: 32),
            // Botões de ação: Rejeitar + Aprovar
            _ActionButtons(
              nurseNotesController: _nurseNotesController,
              selectedDoctor: _selectedDoctor,
              onApprove: _handleApprove,
              onReject: _handleReject,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Seção 1: Dados da prescrição original ─────────────────────────────────

/// Exibe o medicamento, tipo ANVISA (badge colorido), validade e data do pedido.
///
/// LGPD: não exibe CPF nem dados pessoais identificáveis do paciente.
class _PrescriptionDataSection extends StatelessWidget {
  final RenewalRequestModel request;

  const _PrescriptionDataSection({required this.request});

  @override
  Widget build(BuildContext context) {
    final medicine = request.medicineName ?? 'Medicamento não informado';
    final type = request.prescriptionType;

    // Formata a data sem depender do pacote 'intl' (padrão do projeto)
    final date = request.createdAt;
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DADOS DA PRESCRIÇÃO ORIGINAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // Nome do medicamento em destaque
            Text(
              medicine,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Badge de tipo ANVISA com cor característica da receita
            if (type != null) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: type.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: type.foregroundColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Validade em dias conforme tabela ANVISA
                  Text(
                    'Validade: ${type.validityDays} dias',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            // Data de criação do pedido de renovação
            Text(
              'Solicitado em: $dateFormatted',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seção 2: Observações do paciente ──────────────────────────────────────

/// Exibe as notas que o paciente incluiu ao solicitar a renovação (read-only).
///
/// Campo informativo — o enfermeiro não pode editar as notas do paciente.
/// LGPD: apenas o conteúdo da observação é exibido, sem dados identificadores.
class _PatientNotesSection extends StatelessWidget {
  final String? notes;

  const _PatientNotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OBSERVAÇÕES DO PACIENTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              notes ?? 'Sem observações',
              style: TextStyle(
                fontSize: 14,
                // Tom atenuado para indicar ausência de informação
                color: notes != null ? null : AppColors.onSurfaceVariant,
                fontStyle:
                    notes == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seção 3: Notas do enfermeiro ───────────────────────────────────────────

/// Campo de texto para o enfermeiro registrar observações ou o motivo de rejeição.
///
/// Obrigatório ao rejeitar — a validação é feita nos botões de ação.
/// O limite de 500 caracteres evita sobrecarga no campo de banco de dados.
class _NurseNotesSection extends StatelessWidget {
  final TextEditingController controller;

  const _NurseNotesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NOTAS DO ENFERMEIRO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText:
                    'Registre suas observações ou o motivo da rejeição (obrigatório para rejeitar).',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Seção 4: Seleção do médico ─────────────────────────────────────────────

/// Dropdown para selecionar o médico responsável por emitir a nova prescrição.
///
/// Carrega a lista via [FutureBuilder] a partir do [_doctorsFuture] memoizado
/// no `initState` — evita chamada repetida ao Supabase a cada rebuild.
///
/// A seleção é obrigatória para habilitar o botão [APROVAR].
class _DoctorSelectionSection extends StatelessWidget {
  final Future<List<UserModel>> doctorsFuture;
  final UserModel? selectedDoctor;
  final ValueChanged<UserModel?> onDoctorSelected;

  const _DoctorSelectionSection({
    required this.doctorsFuture,
    required this.selectedDoctor,
    required this.onDoctorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ENCAMINHAR PARA MÉDICO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<UserModel>>(
              future: doctorsFuture,
              builder: (context, snapshot) {
                // Aguardando resposta do Supabase
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Erro ao buscar — mensagem genérica sem stack trace (OWASP A09)
                if (snapshot.hasError) {
                  return const Text(
                    'Não foi possível carregar a lista de médicos.',
                    style: TextStyle(color: Colors.red),
                  );
                }

                final doctors = snapshot.data ?? [];

                // Nenhum médico disponível no sistema
                if (doctors.isEmpty) {
                  return const Text(
                    'Nenhum médico disponível no momento.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  );
                }

                return DropdownButtonFormField<UserModel>(
                  value: selectedDoctor,
                  decoration: const InputDecoration(
                    labelText: 'Selecione o médico responsável',
                    border: OutlineInputBorder(),
                  ),
                  items: doctors.map((doctor) {
                    return DropdownMenuItem<UserModel>(
                      value: doctor,
                      // Exibe nome + especialidade quando disponível — sem CPF (LGPD)
                      child: Text(
                        doctor.specialty != null
                            ? '${doctor.name} — ${doctor.specialty}'
                            : doctor.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onDoctorSelected,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botões de ação ─────────────────────────────────────────────────────────

/// Par de botões [REJEITAR] e [APROVAR] da tela de triagem.
///
/// Usa [Selector] para reagir apenas ao [TriageProvider.isLoading],
/// evitando rebuild de toda a tela em outros estados do provider.
///
/// Usa [ListenableBuilder] para reagir ao conteúdo do [nurseNotesController]
/// e habilitar/desabilitar os botões conforme regras de negócio:
/// - [REJEITAR]: habilitado somente quando há notas preenchidas.
/// - [APROVAR]: habilitado somente quando um médico foi selecionado.
class _ActionButtons extends StatelessWidget {
  final TextEditingController nurseNotesController;
  final UserModel? selectedDoctor;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ActionButtons({
    required this.nurseNotesController,
    required this.selectedDoctor,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    // Selector cirúrgico — reage apenas à mudança de isLoading no TriageProvider
    return Selector<TriageProvider, bool>(
      selector: (_, provider) => provider.isLoading,
      builder: (context, isLoading, _) {
        // ListenableBuilder reage ao conteúdo do campo de notas para habilitar botões
        return ListenableBuilder(
          listenable: nurseNotesController,
          builder: (context, _) {
            final hasNurseNotes = nurseNotesController.text.trim().isNotEmpty;
            final hasDoctor = selectedDoctor != null;

            return Row(
              children: [
                // Botão REJEITAR — habilitado apenas com notas preenchidas
                Expanded(
                  child: Semantics(
                    label: 'Rejeitar pedido de renovação',
                    child: OutlinedButton(
                      onPressed:
                          isLoading || !hasNurseNotes ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                          color: isLoading || !hasNurseNotes
                              ? Colors.grey.shade300
                              : Colors.red,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Rejeitar'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botão APROVAR — habilitado apenas com médico selecionado
                Expanded(
                  child: Semantics(
                    label:
                        'Aprovar pedido e encaminhar ao médico selecionado',
                    child: ElevatedButton(
                      onPressed: isLoading || !hasDoctor ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Aprovar'),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
