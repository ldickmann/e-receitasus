import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../providers/renewal_provider.dart';
import '../services/prescription_service.dart';
import 'renewal_tracking_screen.dart';

/// Tela para o paciente solicitar a renovação de uma prescrição ativa.
///
/// Fluxo:
/// 1. Carrega as prescrições ativas do paciente via [PrescriptionService.streamPrescriptions].
/// 2. Exibe lista com medicamento, tipo ANVISA (chip colorido) e validade.
/// 3. Paciente toca para selecionar a prescrição desejada (destaque visual).
/// 4. Preenche observações opcionais (máx. 500 caracteres).
/// 5. Confirma o envio via [RenewalProvider.requestRenewal].
/// 6. Sucesso: SnackBar verde + retorno para a tela anterior.
/// 7. Erro: SnackBar vermelho com mensagem humanizada (sem stack trace — LGPD).
/// 8. Duplicata ([RenewalProvider.isDuplicate]): AlertDialog com ação
///    "Ver rastreamento" que navega para [RenewalTrackingScreen] — o botão
///    de envio volta a ficar habilitado para nova tentativa em outra receita.
class RequestRenewalScreen extends StatefulWidget {
  /// Serviço de prescrições injetável (opcional).
  ///
  /// Em produção permanece `null` e a tela instancia [PrescriptionService]
  /// com o singleton do Supabase. Em testes, injete um serviço com
  /// [SupabaseClient] falso (ou um stub do stream) para validar a tela sem
  /// rede — mesmo padrão já adotado por [PrescriptionFormScreen].
  final PrescriptionService? prescriptionService;

  const RequestRenewalScreen({super.key, this.prescriptionService});

  @override
  State<RequestRenewalScreen> createState() => _RequestRenewalScreenState();
}

class _RequestRenewalScreenState extends State<RequestRenewalScreen> {
  /// Serviço de prescrições para carregar a lista via stream em tempo real.
  /// Usa o injetado (testes) ou cria o padrão com o singleton do Supabase
  /// (produção) — preserva o comportamento original quando nada é injetado.
  late final PrescriptionService _prescriptionService =
      widget.prescriptionService ?? PrescriptionService();

  /// ID da prescrição selecionada pelo paciente. Nulo enquanto nenhuma for escolhida.
  String? _selectedPrescriptionId;

  /// Controlador do campo de observações opcionais (máx. 500 caracteres).
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Envia o pedido de renovação ao [RenewalProvider].
  ///
  /// Guarda o provider antes do `await` para evitar uso de `context` após
  /// desmontagem do widget (regra de segurança de contexto assíncrono).
  Future<void> _submitRenewal() async {
    // Proteção: botão só ativado quando há seleção, mas validamos por segurança
    if (_selectedPrescriptionId == null) return;

    final provider = context.read<RenewalProvider>();
    final notes = _notesController.text.trim();

    final success = await provider.requestRenewal(
      prescriptionId: _selectedPrescriptionId!,
      // Envia null quando o campo está vazio para evitar string vazia no banco
      notes: notes.isEmpty ? null : notes,
    );

    // Garante que o widget ainda está montado antes de usar o contexto
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido de renovação enviado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      // Captura mensagem e flag ANTES do clearError — ele reseta isDuplicate.
      final isDuplicate = provider.isDuplicate;
      // Mensagem humanizada sem expor detalhes internos (LGPD)
      final errorMessage =
          provider.errorMessage ?? 'Erro ao enviar pedido. Tente novamente.';
      // Limpa o erro após capturar para evitar re-exibição em rebuilds futuros
      provider.clearError();

      if (isDuplicate) {
        // Duplicata: diálogo modal com ação de navegação ao rastreamento —
        // mais visível que SnackBar e dá ao paciente uma escolha clara.
        await _showDuplicateDialog(errorMessage);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exibe o diálogo do cenário de solicitação duplicada, com ação
  /// "Ver rastreamento" que navega para [RenewalTrackingScreen].
  ///
  /// A tela não trava: ao fechar o diálogo (qualquer ação), o botão de envio
  /// já está reabilitado, pois [RenewalProvider.isSubmitting] voltou a false.
  Future<void> _showDuplicateDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitação em andamento'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              // Fecha o diálogo antes de navegar para que o "voltar" da tela
              // de rastreamento retorne direto a esta tela, sem diálogo órfão.
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RenewalTrackingScreen(),
                ),
              );
            },
            child: const Text('Ver rastreamento'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitar Renovação'),
      ),
      // SafeArea: edge-to-edge habilitado em main.dart (PBI #199 / TASK #218).
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Lista de prescrições ativas carregada em tempo real via Supabase
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _prescriptionService.streamPrescriptions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  // Mensagem genérica — o erro técnico não é exibido ao usuário
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Erro ao carregar prescrições. Tente novamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                // Converte os maps brutos para modelos e filtra apenas as ativas
                final prescriptions = (snapshot.data ?? [])
                    .map(PrescriptionModel.fromJson)
                    .where((p) => p.isActive)
                    .toList();

                if (prescriptions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma receita ativa encontrada.\n'
                        'Apenas receitas válidas podem ser renovadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Instrução ao paciente para orientar a seleção
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Selecione a receita que deseja renovar:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: prescriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final prescription = prescriptions[index];
                          return _PrescriptionTile(
                            prescription: prescription,
                            isSelected:
                                prescription.id == _selectedPrescriptionId,
                            onTap: () {
                              setState(() {
                                _selectedPrescriptionId = prescription.id;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Seção inferior com campo de observações e botão de envio
          _BottomSection(
            notesController: _notesController,
            isSelected: _selectedPrescriptionId != null,
            onSubmit: _submitRenewal,
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets privados
// ---------------------------------------------------------------------------

/// Card selecionável de uma prescrição ativa.
///
/// Exibe o medicamento, tipo ANVISA (chip colorido), validade e médico.
/// Destaque visual (borda colorida + fundo suave) quando [isSelected] é verdadeiro.
class _PrescriptionTile extends StatelessWidget {
  const _PrescriptionTile({
    required this.prescription,
    required this.isSelected,
    required this.onTap,
  });

  final PrescriptionModel prescription;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Borda e fundo mudam para indicar seleção sem depender de cor hardcoded
    final borderColor = isSelected ? scheme.primary : Colors.grey.shade300;
    final borderWidth = isSelected ? 2.0 : 1.0;
    final fillColor = isSelected
        ? scheme.primary.withAlpha(13) // ~5% opacity
        : Theme.of(context).cardColor;

    return Semantics(
      // Acessibilidade: descreve ação e estado para leitores de tela
      label: '${prescription.medicineName}, ${prescription.type.displayName}. '
          '${isSelected ? "Selecionada." : "Toque para selecionar."}',
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            color: fillColor,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chip colorido com o tipo ANVISA da receita
              _AnvisaChip(type: prescription.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prescription.medicineName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Válida até: ${_formatDate(prescription.validUntil)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    if (prescription.doctorName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Dr(a). ${prescription.doctorName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              // Ícone de confirmação de seleção — 48dp garantido pelo padding
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? scheme.primary : Colors.grey.shade400,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formata a data de validade no padrão brasileiro (dd/MM/yyyy).
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

/// Chip colorido que exibe o tipo ANVISA da receita.
///
/// Cores definidas em [PrescriptionType.backgroundColor] e
/// [PrescriptionType.foregroundColor] seguindo o padrão visual ANVISA.
class _AnvisaChip extends StatelessWidget {
  const _AnvisaChip({required this.type});

  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        type.value,
        style: TextStyle(
          color: type.foregroundColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Seção inferior fixa com campo de observações e botão de envio.
///
/// Isolada em widget próprio para limitar rebuilds ao escopo necessário.
/// O botão usa [Selector] para reagir somente ao [RenewalProvider.isSubmitting],
/// evitando rebuilds desnecessários da seção de lista ao enviar pedido.
class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.notesController,
    required this.isSelected,
    required this.onSubmit,
  });

  final TextEditingController notesController;

  /// Indica se o paciente já escolheu uma prescrição — habilita o botão.
  final bool isSelected;

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          // Sombra sutil para separar visualmente a seção da lista
          BoxShadow(
            color: Colors.black.withAlpha(15), // ~6% opacity
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: notesController,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Ex.: uso contínuo, preciso com urgência...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Selector cirúrgico: rebuild apenas quando isSubmitting mudar,
          // sem forçar rebuild da lista de prescrições acima
          Selector<RenewalProvider, bool>(
            selector: (_, provider) => provider.isSubmitting,
            builder: (context, isSubmitting, _) {
              return SizedBox(
                height: 48,
                child: ElevatedButton(
                  // Desabilitado enquanto nenhuma receita está selecionada
                  // ou enquanto o pedido estiver sendo processado
                  onPressed: isSelected && !isSubmitting ? onSubmit : null,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar Pedido de Renovação'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
