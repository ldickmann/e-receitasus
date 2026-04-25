import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/patient_search_result.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../providers/auth_provider.dart';
import '../services/prescription_service.dart';
import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Dados opcionais para pré-preenchimento (modo renovação)
// ---------------------------------------------------------------------------

/// Valores iniciais opcionais para os campos do formulário de prescrição.
///
/// Usado pelo fluxo de renovação ([RenewalPrescriptionScreen]) para pré-preencher
/// os dados do paciente e do medicamento a partir da prescrição original,
/// evitando retrabalho e reduzindo erros de transcrição.
///
/// Campos do prescritor não são incluídos pois já são lidos via [AuthProvider].
/// CPF do paciente também é omitido intencionalmente — o médico deve confirmar
/// o dado em cada emissão (princípio de minimização — LGPD art. 6º).
class PrescriptionFormPrefill {
  /// Nome do paciente da prescrição original.
  final String? patientName;

  /// Nome do medicamento prescrito originalmente.
  final String? medicineName;

  /// Posologia (dosagem) do medicamento original.
  final String? dosage;

  /// Instruções de uso da prescrição original.
  final String? instructions;

  /// Forma farmacêutica (ex: comprimido, solução).
  final String? pharmaceuticalForm;

  /// Via de administração (ex: oral, sublingual).
  final String? route;

  /// Quantidade numérica da prescrição original.
  final String? quantity;

  /// Quantidade por extenso (obrigatório em notificações).
  final String? quantityWords;

  const PrescriptionFormPrefill({
    this.patientName,
    this.medicineName,
    this.dosage,
    this.instructions,
    this.pharmaceuticalForm,
    this.route,
    this.quantity,
    this.quantityWords,
  });
}

// ---------------------------------------------------------------------------
// Formulário de prescrição
// ---------------------------------------------------------------------------

/// Formulário para preenchimento de receitas médicas digitais.
///
/// Adapta os campos exibidos de acordo com o [PrescriptionType] selecionado,
/// pré-preenchendo os dados do médico autenticado via [AuthProvider].
///
/// Aceita [prefill] opcional para o fluxo de renovação (pré-preenche dados
/// do paciente e medicamento) e [onSaved] para notificar o chamador após
/// salvar com sucesso — evitando a navegação padrão para [PrescriptionViewScreen].
class PrescriptionFormScreen extends StatefulWidget {
  const PrescriptionFormScreen({
    super.key,
    required this.type,
    this.prefill,
    this.onSaved,
    this.prescriptionService,
  });

  final PrescriptionType type;

  /// Valores iniciais opcionais para os campos do formulário (modo renovação).
  final PrescriptionFormPrefill? prefill;

  /// Callback chamado após salvar a prescrição com sucesso.
  ///
  /// Quando fornecido, o formulário retorna para a tela anterior (Navigator.pop)
  /// em vez de navegar para [PrescriptionViewScreen], delegando a navegação
  /// ao chamador. Usado pelo fluxo de renovação para capturar o ID da nova
  /// prescrição e chamar [RenewalService.markAsPrescribed].
  final void Function(PrescriptionModel)? onSaved;

  /// Serviço opcional para testes de widget.
  ///
  /// Em produção permanece `null`, preservando o uso do singleton do Supabase.
  /// Nos testes, uma subclasse controlada evita rede real e permite simular a
  /// RPC de autocomplete sem expor dados sensíveis de pacientes.
  final PrescriptionService? prescriptionService;

  @override
  State<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends State<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isContinuousUse = false;
  int _continuousMonths = 6;

  /// ID do paciente selecionado via autocomplete — null quando o médico digita
  /// o nome manualmente sem selecionar da lista (paciente não cadastrado no sistema).
  String? _selectedPatientUserId;

  // Controladores — Médico
  late final TextEditingController _doctorNameCtrl;
  late final TextEditingController _doctorCouncilCtrl;
  late final TextEditingController _doctorCouncilStateCtrl;
  final _doctorSpecialtyCtrl = TextEditingController();
  final _doctorAddressCtrl = TextEditingController();
  final _doctorCityCtrl = TextEditingController();
  final _doctorStateCtrl = TextEditingController();
  final _doctorPhoneCtrl = TextEditingController();
  final _clinicNameCtrl = TextEditingController();

  // Controladores — Paciente
  final _patientNameCtrl = TextEditingController();
  final _patientCpfCtrl = TextEditingController();
  final _patientAddressCtrl = TextEditingController();
  final _patientCityCtrl = TextEditingController();
  final _patientAgeCtrl = TextEditingController();

  // Controladores — Prescrição
  final _medicineCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _pharmaceuticalFormCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _quantityWordsCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();

  // Controladores — Notificação (Amarela/Azul)
  final _notificationNumberCtrl = TextEditingController();
  final _notificationUfCtrl = TextEditingController();

  late final PrescriptionService _prescriptionService;

  @override
  void initState() {
    super.initState();
    _prescriptionService = widget.prescriptionService ?? PrescriptionService();
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    // Preenche dados do prescritor a partir do perfil autenticado
    _doctorNameCtrl = TextEditingController(text: user?.name ?? '');
    _doctorCouncilCtrl = TextEditingController(
      text: user?.formattedRegistration != null
          ? '${user!.professionalType.councilName} ${user.formattedRegistration}'
          : '',
    );
    _doctorCouncilStateCtrl =
        TextEditingController(text: user?.professionalState ?? '');
    _doctorSpecialtyCtrl.text = user?.specialty ?? '';

    // Aplica pré-preenchimento opcional (modo renovação) — evita retrabalho e
    // garante continuidade dos dados do medicamento e paciente da receita original.
    // CPF não é pré-preenchido intencionalmente (LGPD — princípio da minimização).
    final prefill = widget.prefill;
    if (prefill != null) {
      _patientNameCtrl.text = prefill.patientName ?? '';
      _medicineCtrl.text = prefill.medicineName ?? '';
      _dosageCtrl.text = prefill.dosage ?? '';
      _instructionsCtrl.text = prefill.instructions ?? '';
      _pharmaceuticalFormCtrl.text = prefill.pharmaceuticalForm ?? '';
      _routeCtrl.text = prefill.route ?? '';
      _quantityCtrl.text = prefill.quantity ?? '';
      _quantityWordsCtrl.text = prefill.quantityWords ?? '';
    }
  }

  @override
  void dispose() {
    _doctorNameCtrl.dispose();
    _doctorCouncilCtrl.dispose();
    _doctorCouncilStateCtrl.dispose();
    _doctorSpecialtyCtrl.dispose();
    _doctorAddressCtrl.dispose();
    _doctorCityCtrl.dispose();
    _doctorStateCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _clinicNameCtrl.dispose();
    _patientNameCtrl.dispose();
    _patientCpfCtrl.dispose();
    _patientAddressCtrl.dispose();
    _patientCityCtrl.dispose();
    _patientAgeCtrl.dispose();
    _medicineCtrl.dispose();
    _dosageCtrl.dispose();
    _pharmaceuticalFormCtrl.dispose();
    _routeCtrl.dispose();
    _quantityCtrl.dispose();
    _quantityWordsCtrl.dispose();
    _instructionsCtrl.dispose();
    _notificationNumberCtrl.dispose();
    _notificationUfCtrl.dispose();
    super.dispose();
  }

  /// Preenche os campos do paciente ao selecionar uma sugestão do autocomplete.
  ///
  /// Armazena o [PatientSearchResult.id] em [_selectedPatientUserId] para que
  /// a prescrição seja vinculada ao perfil real do paciente no Supabase.
  /// Respeita LGPD: apenas campos já cadastrados são preenchidos, sem inferência.
  void _onPatientSelected(PatientSearchResult patient) {
    setState(() {
      _selectedPatientUserId = patient.id;
      _patientNameCtrl.text = patient.fullName;
      if (patient.cpf != null) _patientCpfCtrl.text = patient.cpf!;
      if (patient.address != null) _patientAddressCtrl.text = patient.address!;
      if (patient.city != null) _patientCityCtrl.text = patient.city!;
      if (patient.ageText != null) _patientAgeCtrl.text = patient.ageText!;
    });
  }

  Future<void> _handleSubmit() async {
    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;

      final prescription = PrescriptionModel.create(
        type: widget.type,
        doctorName: _doctorNameCtrl.text.trim(),
        doctorCouncil: _doctorCouncilCtrl.text.trim(),
        doctorCouncilState: _doctorCouncilStateCtrl.text.trim().toUpperCase(),
        doctorSpecialty: _doctorSpecialtyCtrl.text.trim().isNotEmpty
            ? _doctorSpecialtyCtrl.text.trim()
            : null,
        doctorAddress: _doctorAddressCtrl.text.trim(),
        doctorCity: _doctorCityCtrl.text.trim(),
        doctorState: _doctorStateCtrl.text.trim().toUpperCase(),
        doctorPhone: _doctorPhoneCtrl.text.trim().isNotEmpty
            ? _doctorPhoneCtrl.text.trim()
            : null,
        clinicName: _clinicNameCtrl.text.trim().isNotEmpty
            ? _clinicNameCtrl.text.trim()
            : null,
        patientName: _patientNameCtrl.text.trim(),
        patientCpf: _patientCpfCtrl.text.trim().isNotEmpty
            ? _patientCpfCtrl.text.trim()
            : null,
        patientAddress: _patientAddressCtrl.text.trim().isNotEmpty
            ? _patientAddressCtrl.text.trim()
            : null,
        patientCity: _patientCityCtrl.text.trim().isNotEmpty
            ? _patientCityCtrl.text.trim()
            : null,
        patientAge: _patientAgeCtrl.text.trim().isNotEmpty
            ? _patientAgeCtrl.text.trim()
            : null,
        medicineName: _medicineCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        pharmaceuticalForm: _pharmaceuticalFormCtrl.text.trim().isNotEmpty
            ? _pharmaceuticalFormCtrl.text.trim()
            : null,
        route:
            _routeCtrl.text.trim().isNotEmpty ? _routeCtrl.text.trim() : null,
        quantity: _quantityCtrl.text.trim(),
        quantityWords: _quantityWordsCtrl.text.trim().isNotEmpty
            ? _quantityWordsCtrl.text.trim()
            : null,
        instructions: _instructionsCtrl.text.trim(),
        notificationNumber: _notificationNumberCtrl.text.trim().isNotEmpty
            ? _notificationNumberCtrl.text.trim()
            : null,
        notificationUf: _notificationUfCtrl.text.trim().isNotEmpty
            ? _notificationUfCtrl.text.trim().toUpperCase()
            : null,
        isContinuousUse: _isContinuousUse,
        continuousValidityMonths: _isContinuousUse ? _continuousMonths : null,
        doctorUserId: userId,
        // Vincula ao perfil do paciente quando selecionado via autocomplete;
        // null é aceito para pacientes não cadastrados no sistema.
        patientUserId: _selectedPatientUserId,
      );

      // Salva no Supabase — qualquer erro propaga para o catch externo
      // que exibe o SnackBar com a mensagem real da falha.
      final saved = await _prescriptionService.savePrescription(prescription);

      if (!mounted) return;

      // Modo renovação: notifica o chamador (RenewalPrescriptionScreen) e
      // retorna para a tela anterior em vez de abrir PrescriptionViewScreen.
      // O fluxo de renovação é responsável por chamar markAsPrescribed e exibir
      // o SnackBar de confirmação com o contexto correto.
      if (widget.onSaved != null) {
        widget.onSaved!(saved);
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      // Modo normal (criação avulsa): navega para a visualização da receita emitida
      // pushReplacement garante que o formulário seja removido da pilha de navegação
      Navigator.pushReplacementNamed(
        context,
        '/prescription_view',
        arguments: saved,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar receita: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build principal
  // ---------------------------------------------------------------------------

  Color _appBarBg() {
    switch (widget.type) {
      case PrescriptionType.branca:
      case PrescriptionType.controlada:
        // Receitas comuns/controle especial usam o verde-menta institucional
        return AppColors.primary;
      case PrescriptionType.amarela:
        return const Color(0xFFF9A825);
      case PrescriptionType.azul:
        return const Color(0xFF1565C0);
    }
  }

  Color _appBarFg() {
    return widget.type == PrescriptionType.amarela
        ? const Color(0xFF212121)
        : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.displayName),
        backgroundColor: _appBarBg(),
        foregroundColor: _appBarFg(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TypeBadge(type: widget.type),
              const SizedBox(height: 16),

              // Seção Notificação (apenas Amarela/Azul)
              if (widget.type.requiresNotificationNumber) ...[
                _SectionHeader(
                  title: 'Numeração da Notificação',
                  icon: Icons.numbers,
                  color: widget.type.foregroundColor,
                ),
                const SizedBox(height: 8),
                _NotificationSection(
                  numberCtrl: _notificationNumberCtrl,
                  ufCtrl: _notificationUfCtrl,
                  type: widget.type,
                ),
                const SizedBox(height: 20),
              ],

              // Seção Estabelecimento / Médico
              const _SectionHeader(
                title: 'Dados do Prescritor',
                icon: Icons.person,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              _DoctorSection(
                nameCtrl: _doctorNameCtrl,
                councilCtrl: _doctorCouncilCtrl,
                councilStateCtrl: _doctorCouncilStateCtrl,
                specialtyCtrl: _doctorSpecialtyCtrl,
                addressCtrl: _doctorAddressCtrl,
                cityCtrl: _doctorCityCtrl,
                stateCtrl: _doctorStateCtrl,
                phoneCtrl: _doctorPhoneCtrl,
                clinicCtrl: _clinicNameCtrl,
              ),
              const SizedBox(height: 20),

              // Seção Paciente
              const _SectionHeader(
                title: 'Dados do Paciente',
                icon: Icons.people,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              _PatientSection(
                nameCtrl: _patientNameCtrl,
                cpfCtrl: _patientCpfCtrl,
                addressCtrl: _patientAddressCtrl,
                cityCtrl: _patientCityCtrl,
                ageCtrl: _patientAgeCtrl,
                requireCpf: widget.type.isNotification ||
                    widget.type == PrescriptionType.controlada,
                requireAddress: widget.type.isNotification,
                onPatientSelected: _onPatientSelected,
                prescriptionService: _prescriptionService,
              ),
              const SizedBox(height: 20),

              // Seção Medicamento
              const _SectionHeader(
                title: 'Prescrição',
                icon: Icons.medication,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              _MedicineSection(
                medicineCtrl: _medicineCtrl,
                dosageCtrl: _dosageCtrl,
                pharmaceuticalFormCtrl: _pharmaceuticalFormCtrl,
                routeCtrl: _routeCtrl,
                quantityCtrl: _quantityCtrl,
                quantityWordsCtrl: _quantityWordsCtrl,
                instructionsCtrl: _instructionsCtrl,
                requireQuantityWords: widget.type.isNotification,
              ),
              const SizedBox(height: 20),

              // Receita Contínua (apenas Branca)
              if (widget.type == PrescriptionType.branca) ...[
                const _SectionHeader(
                  title: 'Uso Contínuo (RDC 471/2021)',
                  icon: Icons.repeat,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                _ContinuousUseSection(
                  isContinuousUse: _isContinuousUse,
                  continuousMonths: _continuousMonths,
                  onChanged: (val) => setState(() => _isContinuousUse = val),
                  onMonthsChanged: (val) =>
                      setState(() => _continuousMonths = val),
                ),
                const SizedBox(height: 20),
              ],

              // Aviso legal
              _LegalWarning(type: widget.type),
              const SizedBox(height: 20),

              // Botão de emissão
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _handleSubmit,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text(
                        'Emitir Receita',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        // Botão de emissão usa a cor primária do tema
                        backgroundColor: AppColors.primary,
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
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets auxiliares do formulário
// =============================================================================

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: type.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: type.foregroundColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(type.icon, color: type.foregroundColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: type.foregroundColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${type.copiesLabel} • Validade: ${type.validityDays} dias',
                  style: TextStyle(
                    color: type.foregroundColor.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção: Numeração da Notificação
// ---------------------------------------------------------------------------

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.numberCtrl,
    required this.ufCtrl,
    required this.type,
  });
  final TextEditingController numberCtrl;
  final TextEditingController ufCtrl;
  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: type.backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: type.foregroundColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            'O número de notificação é pré-impresso e emitido pela '
            'Secretaria de Saúde Estadual (SCTIE/DAF). '
            'Informe o número constante no formulário oficial.',
            style: TextStyle(
              fontSize: 12,
              color: type.foregroundColor.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: numberCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Número da Notificação *',
                  hintText: 'Ex: 000123456',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) {
                    return 'Informe o número da notificação';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: ufCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'UF *',
                  hintText: 'SP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) {
                  if ((v ?? '').trim().length != 2) return 'UF inválida';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção: Dados do Médico
// ---------------------------------------------------------------------------

class _DoctorSection extends StatelessWidget {
  const _DoctorSection({
    required this.nameCtrl,
    required this.councilCtrl,
    required this.councilStateCtrl,
    required this.specialtyCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.stateCtrl,
    required this.phoneCtrl,
    required this.clinicCtrl,
  });

  final TextEditingController nameCtrl;
  final TextEditingController councilCtrl;
  final TextEditingController councilStateCtrl;
  final TextEditingController specialtyCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController clinicCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome do Prescritor *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe o nome do prescritor' : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: councilCtrl,
                decoration: const InputDecoration(
                  labelText: 'Conselho/Nº de Registro *',
                  hintText: 'CRM 123456',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Informe o conselho profissional'
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: councilStateCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'UF *',
                  hintText: 'SP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) {
                  if ((v ?? '').trim().length != 2) return 'UF inválida';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: specialtyCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Especialidade',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.medical_services),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: clinicCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome do Estabelecimento / UBS / Hospital',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_hospital),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: addressCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Endereço do Prescritor *',
            hintText: 'Rua, número, bairro',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe o endereço' : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Cidade *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe a cidade' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: stateCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'UF *',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                validator: (v) {
                  if ((v ?? '').trim().length != 2) return 'UF inválida';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefone do Consultório',
            hintText: '(11) 99999-9999',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção: Dados do Paciente
// ---------------------------------------------------------------------------

/// Seção do formulário com os dados do paciente.
///
/// O campo de nome usa [RawAutocomplete] para sugerir pacientes cadastrados
/// no banco enquanto o médico digita. Ao selecionar, os demais campos são
/// preenchidos automaticamente via [onPatientSelected].
/// O médico pode também digitar livremente quando o paciente não está cadastrado.
class _PatientSection extends StatefulWidget {
  const _PatientSection({
    required this.nameCtrl,
    required this.cpfCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.ageCtrl,
    required this.requireCpf,
    required this.requireAddress,
    required this.onPatientSelected,
    required this.prescriptionService,
  });

  final TextEditingController nameCtrl;
  final TextEditingController cpfCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController ageCtrl;
  final bool requireCpf;
  final bool requireAddress;

  /// Chamado quando o médico seleciona um paciente da lista de sugestões.
  final void Function(PatientSearchResult) onPatientSelected;

  /// Serviço injetado pela tela pai para permitir testes sem rede real.
  final PrescriptionService prescriptionService;

  @override
  State<_PatientSection> createState() => _PatientSectionState();
}

class _PatientSectionState extends State<_PatientSection> {
  /// FocusNode obrigatório para uso com [RawAutocomplete] e controller externo.
  final _nameFocusNode = FocusNode();

  /// Evita exibir múltiplos SnackBars consecutivos quando o autocomplete
  /// dispara várias buscas seguidas e todas falham (ex.: rede instável).
  /// É reabilitado assim que ocorrer uma busca bem-sucedida.
  bool _errorShown = false;

  @override
  void dispose() {
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// Exibe SnackBar de erro de busca, agendado para o próximo frame para evitar
  /// disparar UI durante o `optionsBuilder` do [RawAutocomplete].
  void _showSearchError(String message) {
    if (_errorShown) return;
    _errorShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Campo de nome com autocomplete: busca pacientes cadastrados em tempo real.
        // Requer mínimo de 2 caracteres para acionar a RPC e evitar consultas ruidosas.
        RawAutocomplete<PatientSearchResult>(
          textEditingController: widget.nameCtrl,
          focusNode: _nameFocusNode,
          displayStringForOption: (patient) => patient.fullName,
          optionsBuilder: (textEditingValue) async {
            final query = textEditingValue.text;
            if (query.trim().length < 2) return const [];
            try {
              final results =
                  await widget.prescriptionService.searchPatients(query.trim());
              // Sucesso → reabilita SnackBar para futuras falhas.
              _errorShown = false;
              return results;
            } on PatientSearchException catch (e) {
              // Falha controlada da RPC: feedback visual ao médico, mas o campo
              // continua editável para preenchimento manual.
              _showSearchError(e.message);
              return const [];
            } catch (_) {
              // Qualquer outra falha: mensagem genérica (sem detalhes técnicos).
              _showSearchError(
                'Erro ao buscar pacientes. Você pode digitar manualmente.',
              );
              return const [];
            }
          },
          onSelected: widget.onPatientSelected,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome Completo do Paciente *',
                hintText: 'Digite para buscar pacientes cadastrados',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                suffixIcon: Icon(Icons.search, color: Colors.grey),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Informe o nome do paciente'
                  : null,
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final patient = options.elementAt(index);
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person, size: 20),
                        ),
                        title: Text(patient.fullName),
                        subtitle: patient.cpf != null
                            ? Text('CPF: ${patient.cpf}')
                            : null,
                        onTap: () => onSelected(patient),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.cpfCtrl,
          keyboardType: TextInputType.number,
          // CPF tem exatamente 11 dígitos numéricos. Restringimos a entrada
          // para apenas dígitos e bloqueamos qualquer caractere além do 11º
          // — proteção contra colagem de strings inválidas e contra digitação
          // acidental (ex.: usuário segurando tecla). Mantém integridade do
          // dado antes mesmo da validação posterior.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: InputDecoration(
            labelText:
                widget.requireCpf ? 'CPF do Paciente *' : 'CPF do Paciente',
            hintText: '00000000000',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.credit_card),
          ),
          validator: widget.requireCpf
              ? (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe o CPF do paciente' : null
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.ageCtrl,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Idade / Data de Nascimento',
            hintText: 'Ex: 45 anos',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.cake),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.addressCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.requireAddress
                ? 'Endereço do Paciente *'
                : 'Endereço do Paciente',
            hintText: 'Rua, número, bairro',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.home),
          ),
          validator: widget.requireAddress
              ? (v) => (v ?? '').trim().isEmpty
                  ? 'Endereço obrigatório para este tipo de receita'
                  : null
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.cityCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Cidade do Paciente',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção: Medicamento e Posologia
// ---------------------------------------------------------------------------

class _MedicineSection extends StatelessWidget {
  const _MedicineSection({
    required this.medicineCtrl,
    required this.dosageCtrl,
    required this.pharmaceuticalFormCtrl,
    required this.routeCtrl,
    required this.quantityCtrl,
    required this.quantityWordsCtrl,
    required this.instructionsCtrl,
    required this.requireQuantityWords,
  });

  final TextEditingController medicineCtrl;
  final TextEditingController dosageCtrl;
  final TextEditingController pharmaceuticalFormCtrl;
  final TextEditingController routeCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController quantityWordsCtrl;
  final TextEditingController instructionsCtrl;
  final bool requireQuantityWords;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: medicineCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome do Medicamento (DCI) *',
            hintText: 'Ex: Clonazepam',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.medication),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe o medicamento' : null,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: dosageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosagem / Concentração *',
                  hintText: 'Ex: 2mg',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe a dosagem' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: pharmaceuticalFormCtrl,
                decoration: const InputDecoration(
                  labelText: 'Forma Farmacêutica',
                  hintText: 'Comprimido',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: routeCtrl,
          decoration: const InputDecoration(
            labelText: 'Via de Administração',
            hintText: 'Ex: Oral, Sublingual',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.route),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: quantityCtrl,
          decoration: const InputDecoration(
            labelText: 'Quantidade *',
            hintText: 'Ex: 30 comprimidos',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.numbers),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe a quantidade' : null,
        ),
        if (requireQuantityWords) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: quantityWordsCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText:
                  'Quantidade por Extenso ${requireQuantityWords ? "*" : ""}',
              hintText: 'Ex: Trinta comprimidos',
              border: const OutlineInputBorder(),
              helperText:
                  'Obrigatório para Notificações de Receita (Amarela/Azul)',
            ),
            validator: requireQuantityWords
                ? (v) => (v ?? '').trim().isEmpty
                    ? 'Informe a quantidade por extenso'
                    : null
                : null,
          ),
        ],
        const SizedBox(height: 10),
        TextFormField(
          controller: instructionsCtrl,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Posologia / Modo de Uso *',
            hintText:
                'Ex: Tomar 1 comprimido pela manhã em jejum, por 30 dias.',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe a posologia' : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção: Uso Contínuo (RDC 471/2021 — Receita Branca)
// ---------------------------------------------------------------------------

class _ContinuousUseSection extends StatelessWidget {
  const _ContinuousUseSection({
    required this.isContinuousUse,
    required this.continuousMonths,
    required this.onChanged,
    required this.onMonthsChanged,
  });

  final bool isContinuousUse;
  final int continuousMonths;
  final ValueChanged<bool> onChanged;
  final ValueChanged<int> onMonthsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Medicamento de Uso Contínuo'),
          subtitle: const Text(
            'Permite validade de até 6 meses conforme RDC 471/2021',
            style: TextStyle(fontSize: 12),
          ),
          value: isContinuousUse,
          onChanged: onChanged,
          // activeThumbColor: substitui activeColor (depreciado no Flutter 3.0+)
          activeThumbColor: AppColors.primary,
        ),
        if (isContinuousUse) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Validade (meses): ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Slider(
                  value: continuousMonths.toDouble(),
                  min: 1,
                  max: 6,
                  divisions: 5,
                  label: '$continuousMonths meses',
                  onChanged: (v) => onMonthsChanged(v.round()),
                  activeColor: AppColors.primary,
                ),
              ),
              Text(
                '$continuousMonths',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Aviso legal
// ---------------------------------------------------------------------------

class _LegalWarning extends StatelessWidget {
  const _LegalWarning({required this.type});
  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Banner de aviso legal usando os tokens 'warning' da paleta oficial
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
              SizedBox(width: 6),
              Text(
                'Aviso Legal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            type.legalFooter,
            // onWarningContainer garante contraste sobre o fundo âmbar
            style: const TextStyle(
                fontSize: 11, color: AppColors.onWarningContainer, height: 1.5),
          ),
        ],
      ),
    );
  }
}
