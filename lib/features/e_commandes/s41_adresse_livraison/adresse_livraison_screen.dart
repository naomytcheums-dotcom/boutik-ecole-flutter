import '../../../core/utils/validators.dart';
import '../../../core/utils/validators_e.dart';
import '../../common/common.dart';
import '../e_widgets.dart';

/// 41 · Adresse de livraison (étape 2 du tunnel d'achat).
class AdresseLivraisonScreen extends ConsumerStatefulWidget {
  const AdresseLivraisonScreen({super.key});

  @override
  ConsumerState<AdresseLivraisonScreen> createState() => _AdresseLivraisonScreenState();
}

class _AdresseLivraisonScreenState extends ConsumerState<AdresseLivraisonScreen> {
  final _form = GlobalKey<FormState>();
  late final SectionEData _d = ref.read(sectionEDataProvider);
  late final _name = TextEditingController(text: _d.recipient);
  final _phone = TextEditingController();
  late final _city = TextEditingController(text: _d.city);
  late final _address = TextEditingController(text: _d.address);
  late final _landmark = TextEditingController(text: _d.landmark);
  bool _save = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _address, _landmark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Ville et quartier', style: AppText.h3),
            ),
            for (final o in _d.cities)
              ListTile(
                title: Text(o, style: AppText.body),
                trailing: o == _city.text ? const AppIcon(AppIcons.check, size: 18) : null,
                onTap: () => Navigator.pop(c, o),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _city.text = picked);
  }

  void _continue() {
    if (_form.currentState!.validate()) {
      if (_save) context.toast('Adresse enregistrée dans votre carnet.');
      context.openScreen('08');
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14.75);
    return EScaffold(
      title: 'Adresse de livraison',
      actions: [EButton('Continuer', onPressed: _continue)],
      children: [
        ECheckoutStepper(labels: _d.checkoutSteps, current: 1),
        const SizedBox(height: 14.5),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EField(
                label: 'Nom du destinataire',
                icon: AppIcons.user,
                controller: _name,
                validator: ValidatorsE.recipient,
                keyboardType: TextInputType.name,
              ),
              gap,
              EField(
                label: 'Téléphone',
                icon: AppIcons.smartphone,
                controller: _phone,
                hint: _d.phoneMask,
                validator: Validators.phoneCm,
                keyboardType: TextInputType.phone,
              ),
              gap,
              EField(
                label: 'Ville et quartier',
                icon: AppIcons.mapPin,
                controller: _city,
                validator: ValidatorsE.city,
                onTap: _pickCity,
                trailing: const AppIcon(AppIcons.chevronDown, size: 20),
              ),
              gap,
              EField(
                label: 'Adresse précise',
                icon: AppIcons.map,
                controller: _address,
                validator: ValidatorsE.address,
                keyboardType: TextInputType.streetAddress,
              ),
              gap,
              EField(label: 'Point de repère', icon: AppIcons.flag, controller: _landmark),
            ],
          ),
        ),
        const SizedBox(height: 7),
        ECheckRow(
          label: 'Enregistrer cette adresse dans mon carnet',
          value: _save,
          onChanged: (v) => setState(() => _save = v),
        ),
      ],
    );
  }
}
