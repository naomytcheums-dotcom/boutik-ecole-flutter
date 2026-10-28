import '../g_widgets.dart';

/// 60 · Modifier l’annonce (onglet Prévisualiser : aperçu client).
class ModifierAnnonceScreen extends ConsumerStatefulWidget {
  const ModifierAnnonceScreen({super.key});

  @override
  ConsumerState<ModifierAnnonceScreen> createState() => _ModifierAnnonceScreenState();
}

class _ModifierAnnonceScreenState extends ConsumerState<ModifierAnnonceScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    return GPage(
      title: 'Modifier l’annonce',
      actions: [
        GOutlineButton('Modifier', onPressed: () => context.openScreen('58')),
        PrimaryButton(label: 'Publier', height: 54, onPressed: () => context.toast('Annonce envoyée en validation.')),
      ],
      children: [
        Row(
          children: [
            for (final (i, t) in ['Modifier', 'Prévisualiser'].indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _tab,
                  child: InkWell(
                    onTap: () => i == 0 ? context.openScreen('58') : setState(() => _tab = i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: i == _tab ? AppColors.accent : Colors.transparent, width: 2)),
                      ),
                      child: Text(t, style: AppText.secondary.copyWith(color: i == _tab ? AppColors.ink : AppColors.textSecondary, fontWeight: i == _tab ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap12,
        PhotoTile(image: d.previewImage, aspectRatio: 342 / 200, radius: 24, semanticLabel: d.previewTitle),
        gap16,
        Text(d.previewTitle, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${fcfa(d.previewPrice)} · Aperçu client', style: AppText.small),
        gap12,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in d.previewTags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: ShapeDecoration(color: Colors.white, shape: const StadiumBorder(side: BorderSide(color: AppColors.cardBorder))),
                child: Text(t, style: AppText.small.copyWith(fontSize: 11.5, color: AppColors.ink)),
              ),
          ],
        ),
        gap12,
        Text(d.previewDescription, style: AppText.small.copyWith(fontSize: 12.5, height: 1.5)),
        gap12,
        KeyValueCard(rowGap: 14, rows: [
          KV('Stock', '${d.previewStock} unités'),
          KV('Retrait', d.pickupPoint),
          KV('Statut', d.previewStatus),
        ]),
        gap16,
        const GNote('Aperçu tel qu’il apparaîtra aux clients de la marketplace.', icon: AppIcons.eye),
      ],
    );
  }
}