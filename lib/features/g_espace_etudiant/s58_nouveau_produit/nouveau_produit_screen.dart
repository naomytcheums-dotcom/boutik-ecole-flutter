import '../../../core/utils/validators.dart';
import '../g_widgets.dart';

/// 58 · Nouveau produit (étape Infos).
class NouveauProduitScreen extends ConsumerStatefulWidget {
  const NouveauProduitScreen({super.key});

  @override
  ConsumerState<NouveauProduitScreen> createState() => _NouveauProduitScreenState();
}

class _NouveauProduitScreenState extends ConsumerState<NouveauProduitScreen> {
  final _form = GlobalKey<FormState>();
  late String _category = ref.read(sectionGDataProvider).productCategory;
  int _photos = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    return Form(
      key: _form,
      child: GPage(
        title: 'Nouveau produit',
        actions: [
          GOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
          PrimaryButton(
            label: 'Publier',
            height: 54,
            onPressed: () {
              if (_form.currentState!.validate()) context.openScreen('60');
            },
          ),
        ],
        children: [
          GStepper(labels: d.productSteps, current: 0),
          gap16,
          AppCard(
            onTap: () => setState(() => _photos = (_photos + 1).clamp(0, d.maxPhotos)),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFFBEBC2), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const AppIcon(AppIcons.camera, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_photos == 0 ? 'Ajouter des photos' : '$_photos photo${_photos > 1 ? 's' : ''} ajoutée${_photos > 1 ? 's' : ''}', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                      Text('Jusqu’à ${d.maxPhotos} photos · JPG, PNG', style: AppText.small.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
                const AppIcon(AppIcons.chevronRight, size: 18),
              ],
            ),
          ),
          gap16,
          TextFieldWithError(
            label: 'Titre du produit',
            hint: 'Ex. Lampe en bois recyclé',
            prefixIcon: AppIcons.tag,
            validator: Validators.title,
          ),
          gap16,
          SelectField(
            label: 'Catégorie',
            icon: AppIcons.layoutGrid,
            options: d.productCategories,
            value: _category,
            onChanged: (v) => setState(() => _category = v),
          ),
          gap16,
          TextFieldWithError(
            label: 'Prix (FCFA)',
            initialValue: d.productPrice,
            prefixIcon: AppIcons.banknote,
            keyboardType: TextInputType.number,
            validator: Validators.priceFcfa,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 14, top: 14),
              child: Text('FCFA', style: AppText.secondary.copyWith(color: AppColors.accent)),
            ),
          ),
          gap16,
          TextFieldWithError(
            label: 'Quantité en stock',
            initialValue: d.productStock,
            prefixIcon: AppIcons.package,
            keyboardType: TextInputType.number,
            validator: (v) => int.tryParse(v ?? '') == null ? 'Entrez un nombre entier.' : null,
          ),
          gap16,
          const TextFieldWithError(label: 'Description', hint: 'Matériaux, dimensions, particularités…', maxLines: 4),
        ],
      ),
    );
  }
}