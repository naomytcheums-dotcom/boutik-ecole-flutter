import '../../../core/utils/validators.dart';
import '../g_widgets.dart';

/// 59 · Nouveau service (étape Infos).
class NouveauServiceScreen extends ConsumerStatefulWidget {
  const NouveauServiceScreen({super.key});

  @override
  ConsumerState<NouveauServiceScreen> createState() => _NouveauServiceScreenState();
}

class _NouveauServiceScreenState extends ConsumerState<NouveauServiceScreen> {
  final _form = GlobalKey<FormState>();
  late final d = ref.read(sectionGDataProvider);
  late String _category = d.serviceCategory;
  late String _delay = d.serviceDelay;
  late String _mode = d.serviceMode;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: GPage(
        title: 'Nouveau service',
        actions: [
          GOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
          PrimaryButton(
            label: 'Publier',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) context.toast('Service envoyé en validation.');
            },
          ),
        ],
        children: [
          GStepper(labels: d.serviceSteps, current: 0),
          gap12,
          TextFieldWithError(
            label: 'Titre du service',
            hint: 'Ex. Développement web sur mesure',
            prefixIcon: AppIcons.zap,
            validator: Validators.title,
          ),
          gap16,
          SelectField(label: 'Catégorie', icon: AppIcons.layoutGrid, options: d.serviceCategories, value: _category, onChanged: (v) => setState(() => _category = v)),
          gap16,
          TextFieldWithError(
            label: 'Tarif à partir de (FCFA)',
            initialValue: d.servicePrice,
            prefixIcon: AppIcons.banknote,
            keyboardType: TextInputType.number,
            validator: Validators.priceFcfa,
          ),
          gap16,
          SelectField(label: 'Délai moyen', icon: AppIcons.clock, options: d.serviceDelays, value: _delay, onChanged: (v) => setState(() => _delay = v)),
          gap16,
          SelectField(label: 'Mode de prestation', icon: AppIcons.mapPin, options: d.serviceModes, value: _mode, onChanged: (v) => setState(() => _mode = v)),
          gap16,
          const TextFieldWithError(label: 'Description du service', hint: 'Ce que vous proposez, livrables, méthode…', maxLines: 4),
        ],
      ),
    );
  }
}