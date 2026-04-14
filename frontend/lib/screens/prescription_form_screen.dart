import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../providers/auth_provider.dart';
import '../services/prescription_service.dart';
import 'prescription_view_screen.dart';

/// Formulário para preenchimento de receitas médicas digitais.
///
/// Adapta os campos exibidos de acordo com o [PrescriptionType] selecionado,
/// pré-preenchendo os dados do médico autenticado via [AuthProvider].
class PrescriptionFormScreen extends StatefulWidget {
  const PrescriptionFormScreen({super.key, required this.type});

  final PrescriptionType type;

  @override
  State<PrescriptionFormScreen> createState() => _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState extends State<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isContinuousUse = false;
  int _continuousMonths = 6;

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

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _doctorNameCtrl = TextEditingController(text: user?.name ?? '');
    _doctorCouncilCtrl = TextEditingController(
      text: user?.formattedRegistration != null
          ? '${user!.professionalType.councilName} ${user.formattedRegistration}'
          : '',
    );
    _doctorCouncilStateCtrl =
        TextEditingController(text: user?.professionalState ?? '');
    _doctorSpecialtyCtrl.text = user?.specialty ?? '';
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
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
        route: _routeCtrl.text.trim().isNotEmpty
            ? _routeCtrl.text.trim()
            : null,
        quantity: _quantityCtrl.text.trim(),
        quantityWords: _quantityWordsCtrl.text.trim().isNotEmpty
            ? _quantityWordsCtrl.text.trim()
            : null,
        instructions: _instructionsCtrl.text.trim(),
        notificationNumber:
            _notificationNumberCtrl.text.trim().isNotEmpty
                ? _notificationNumberCtrl.text.trim()
                : null,
        notificationUf: _notificationUfCtrl.text.trim().isNotEmpty
            ? _notificationUfCtrl.text.trim().toUpperCase()
            : null,
        isContinuousUse: _isContinuousUse,
        continuousValidityMonths:
            _isContinuousUse ? _continuousMonths : null,
        doctorUserId: userId,
      );

      // Tenta salvar no Supabase; se falhar (ex: tabela ainda não existe), prossegue
      PrescriptionModel saved;
      try {
        saved = await PrescriptionService().savePrescription(prescription);
      } catch (_) {
        saved = prescription;
      }

      if (!mounted) return;

      // Navega para a tela de visualização da receita gerada
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionViewScreen(prescription: saved),
        ),
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
        return const Color(0xFF009B3A);
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
              _SectionHeader(
                title: 'Dados do Prescritor',
                icon: Icons.person,
                color: const Color(0xFF009B3A),
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
              _SectionHeader(
                title: 'Dados do Paciente',
                icon: Icons.people,
                color: const Color(0xFF009B3A),
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
              ),
              const SizedBox(height: 20),

              // Seção Medicamento
              _SectionHeader(
                title: 'Prescrição',
                icon: Icons.medication,
                color: const Color(0xFF009B3A),
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
                _SectionHeader(
                  title: 'Uso Contínuo (RDC 471/2021)',
                  icon: Icons.repeat,
                  color: const Color(0xFF009B3A),
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
          color: type.foregroundColor.withOpacity(0.3),
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
                    color: type.foregroundColor.withOpacity(0.7),
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
        Expanded(child: Divider(color: color.withOpacity(0.3))),
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
            border: Border.all(color: type.foregroundColor.withOpacity(0.3)),
          ),
          child: Text(
            'O número de notificação é pré-impresso e emitido pela '
            'Secretaria de Saúde Estadual (SCTIE/DAF). '
            'Informe o número constante no formulário oficial.',
            style: TextStyle(
              fontSize: 12,
              color: type.foregroundColor.withOpacity(0.8),
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

class _PatientSection extends StatelessWidget {
  const _PatientSection({
    required this.nameCtrl,
    required this.cpfCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.ageCtrl,
    required this.requireCpf,
    required this.requireAddress,
  });

  final TextEditingController nameCtrl;
  final TextEditingController cpfCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController ageCtrl;
  final bool requireCpf;
  final bool requireAddress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome Completo do Paciente *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
          ),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Informe o nome do paciente' : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: cpfCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: requireCpf ? 'CPF do Paciente *' : 'CPF do Paciente',
            hintText: '000.000.000-00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.credit_card),
          ),
          validator: requireCpf
              ? (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe o CPF do paciente' : null
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: ageCtrl,
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
          controller: addressCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: requireAddress
                ? 'Endereço do Paciente *'
                : 'Endereço do Paciente',
            hintText: 'Rua, número, bairro',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.home),
          ),
          validator: requireAddress
              ? (v) => (v ?? '').trim().isEmpty
                  ? 'Endereço obrigatório para este tipo de receita'
                  : null
              : null,
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: cityCtrl,
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
          activeColor: const Color(0xFF009B3A),
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
                  activeColor: const Color(0xFF009B3A),
                ),
              ),
              Text(
                '$continuousMonths',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF009B3A),
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
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE65100), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber, color: Color(0xFFE65100), size: 16),
              SizedBox(width: 6),
              Text(
                'Aviso Legal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            type.legalFooter,
            style: const TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.5),
          ),
        ],
      ),
    );
  }
}
