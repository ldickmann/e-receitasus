import 'package:flutter/material.dart';

import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../models/renewal_request_model.dart';
import '../services/prescription_service.dart';
import '../services/renewal_service.dart';
import 'prescription_form_screen.dart';

/// Tela de emissão de renovação de prescrição pelo médico.
///
/// Recebe o [RenewalRequestModel] triado pelo enfermeiro e:
/// 1. Busca a prescrição original via [PrescriptionService.getPrescriptionById].
/// 2. Exibe resumo: medicamento, posologia, tipo ANVISA, validade original e
///    notas do enfermeiro.
/// 3. Permite ao médico emitir a renovação abrindo [PrescriptionFormScreen]
///    pré-preenchido com os dados originais.
/// 4. Após salvar a nova prescrição, chama [RenewalService.markAsPrescribed]
///    para concluir o ciclo TRIAGED → PRESCRIBED.
///
/// Requer [StatefulWidget] para gerenciar o estado de loading/erro da busca
/// assíncrona da prescrição original e o estado de processamento do botão.
class RenewalPrescriptionScreen extends StatefulWidget {
  /// Pedido de renovação triado que será atendido pelo médico.
  final RenewalRequestModel request;

  const RenewalPrescriptionScreen({super.key, required this.request});

  @override
  State<RenewalPrescriptionScreen> createState() =>
      _RenewalPrescriptionScreenState();
}

class _RenewalPrescriptionScreenState extends State<RenewalPrescriptionScreen> {
  /// Future que carrega a prescrição original — inicializado em [initState]
  /// para evitar recriação desnecessária a cada rebuild do widget.
  late final Future<PrescriptionModel?> _prescriptionFuture;

  /// Indica se o botão "Emitir Renovação" está processando (aguardando
  /// markAsPrescribed), evitando duplo toque.
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Busca a prescrição original uma única vez ao montar a tela.
    // O resultado é armazenado no Future para o FutureBuilder.
    _prescriptionFuture = PrescriptionService()
        .getPrescriptionById(widget.request.prescriptionId);
  }

  /// Abre o [PrescriptionFormScreen] pré-preenchido e, após o salvamento,
  /// chama [RenewalService.markAsPrescribed] para finalizar o fluxo.
  ///
  /// O tipo ANVISA é determinado a partir da prescrição original. Se por
  /// algum motivo não estiver disponível, usa [PrescriptionType.branca] como
  /// fallback seguro — o médico pode corrigir no formulário.
  Future<void> _emitirRenovacao(PrescriptionModel original) async {
    // Determina o tipo ANVISA: prioriza o campo desnormalizado do pedido de
    // renovação (já resolvido pelo join), com fallback para o tipo da prescrição.
    final tipo = widget.request.prescriptionType ?? original.type;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionFormScreen(
          type: tipo,
          // Pré-preenche com dados da prescrição original para agilizar a emissão
          // e reduzir erros de transcrição. CPF não é pré-preenchido (LGPD).
          prefill: PrescriptionFormPrefill(
            patientName: original.patientName,
            medicineName: original.medicineName,
            dosage: original.dosage,
            instructions: original.instructions,
            pharmaceuticalForm: original.pharmaceuticalForm,
            route: original.route,
            quantity: original.quantity,
            quantityWords: original.quantityWords,
          ),
          // Callback chamado após salvar a nova prescrição — completa o fluxo
          // de renovação chamando markAsPrescribed com o ID gerado.
          onSaved: _handlePrescricaoSalva,
        ),
      ),
    );
  }

  /// Chamado pelo [PrescriptionFormScreen] imediatamente após salvar a nova
  /// prescrição. Transiciona o pedido de renovação de TRIAGED → PRESCRIBED.
  ///
  /// Exibe SnackBar de sucesso e retorna para [DoctorHomeScreen] via pop.
  /// Em caso de erro, exibe mensagem genérica — sem stack trace (LGPD/OWASP A09).
  Future<void> _handlePrescricaoSalva(PrescriptionModel saved) async {
    final newId = saved.id;

    // Guarda: ID nulo indica que o Supabase não retornou o registro inserido.
    // Não prossegue para evitar marcar renovação com ID inválido.
    if (newId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Prescrição salva, mas não foi possível finalizar a renovação. '
              'Contate o suporte.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      // Transição de estado: TRIAGED → PRESCRIBED, vinculando a nova prescrição.
      await RenewalService().markAsPrescribed(widget.request.id, newId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renovação emitida com sucesso'),
          backgroundColor: Color(0xFF009B3A),
        ),
      );
      // Retorna para DoctorHomeScreen — o pedido some automaticamente da fila
      // via Supabase Realtime (status PRESCRIBED é filtrado pelo stream).
      Navigator.pop(context);
    } catch (_) {
      // Erro genérico — sem stack trace (OWASP A09, LGPD: dados de saúde)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao registrar renovação. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renovar Prescrição'),
        backgroundColor: const Color(0xFF009B3A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<PrescriptionModel?>(
        future: _prescriptionFuture,
        builder: (context, snapshot) {
          // Estado: carregando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Estado: erro na busca — sem expor detalhes (OWASP A09)
          if (snapshot.hasError) {
            return const _ErrorCard(
              message: 'Não foi possível carregar os dados da prescrição. '
                  'Verifique sua conexão e tente novamente.',
            );
          }

          final prescription = snapshot.data;

          // Estado: prescrição não encontrada no banco
          if (prescription == null) {
            return const _ErrorCard(
              message: 'Prescrição original não encontrada. '
                  'O registro pode ter sido removido.',
            );
          }

          // Estado: dados carregados — exibe resumo e botão de ação
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResumoCard(
                  prescription: prescription,
                  nurseNotes: widget.request.nurseNotes,
                ),
                const SizedBox(height: 24),
                _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () => _emitirRenovacao(prescription),
                        icon: const Icon(Icons.receipt_long),
                        label: const Text(
                          'Emitir Renovação',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009B3A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

/// Card de resumo da prescrição original e notas do enfermeiro.
///
/// Exibe as informações necessárias para o médico avaliar se deve renovar:
/// medicamento, posologia, tipo ANVISA, data de emissão original e notas
/// do enfermeiro triador. Dados pessoais do paciente (CPF, endereço) não são
/// exibidos nesta tela — seguindo o princípio de minimização da LGPD.
class _ResumoCard extends StatelessWidget {
  final PrescriptionModel prescription;
  final String? nurseNotes;

  const _ResumoCard({
    required this.prescription,
    required this.nurseNotes,
  });

  /// Formata uma data para o padrão brasileiro dd/MM/yyyy sem dependência do
  /// pacote `intl` — consistente com o restante do projeto.
  String _formatarData(DateTime data) {
    final d = data.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com tipo ANVISA
            Row(
              children: [
                Icon(
                  prescription.type.icon,
                  color: prescription.type.foregroundColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prescription.type.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: prescription.type.foregroundColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Medicamento
            _InfoRow(
              label: 'Medicamento',
              value: prescription.medicineName,
            ),
            const SizedBox(height: 8),

            // Posologia (dosagem + instruções)
            _InfoRow(
              label: 'Posologia',
              value: prescription.dosage,
            ),
            if (prescription.instructions.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                label: 'Instruções',
                value: prescription.instructions,
              ),
            ],
            const SizedBox(height: 8),

            // Validade original da receita
            _InfoRow(
              label: 'Emitida em',
              value: _formatarData(prescription.issuedAt),
            ),
            const SizedBox(height: 8),

            _InfoRow(
              label: 'Válida até',
              value: _formatarData(prescription.validUntil),
            ),

            // Notas do enfermeiro (quando presentes)
            if (nurseNotes != null && nurseNotes!.isNotEmpty) ...[
              const Divider(height: 20),
              const Text(
                'Observações do enfermeiro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nurseNotes!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Linha de informação com rótulo e valor no padrão do card de resumo.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Card de erro exibido quando a prescrição original não pode ser carregada.
///
/// Usa mensagem genérica — sem detalhes internos — seguindo OWASP A09 e LGPD.
class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
