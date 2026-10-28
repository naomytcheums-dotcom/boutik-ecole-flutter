import '../../common/common.dart';
import '../d_widgets.dart';

/// 32 · Détail du produit « Lampe en bois recyclé ».
class DetailProduitScreen extends ConsumerStatefulWidget {
  const DetailProduitScreen({super.key});

  @override
  ConsumerState<DetailProduitScreen> createState() => _DetailProduitScreenState();
}

class _DetailProduitScreenState extends ConsumerState<DetailProduitScreen> {
  int _tab = 0;
  int _variant = 0;
  bool _favorite = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Détail du produit',
      headerActions: [
        DHeaderAction(AppIcons.share, label: 'Partager', onTap: () => context.toast('Lien du produit copié.')),
        DHeaderAction(
          AppIcons.heart,
          label: _favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          color: _favorite ? AppColors.error : null,
          onTap: () => setState(() => _favorite = !_favorite),
        ),
      ],
      actions: [
        DButton(
          'Ajouter au panier',
          onPressed: () {
            final variant = d.productVariants[_variant];
            ref
                .read(cartProvider.notifier)
                .add(CartLine('${d.productTitle} · $variant', d.creatorName, d.productPrice, d.productHero));
            context.toast('Ajouté au panier ($variant).');
          },
        ),
      ],
      children: [
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () => context.openScreen('34'),
          child: DPhoto(d.productHero, height: 230, label: 'Photo du produit, ouvrir la galerie'),
        ),
        const SizedBox(height: 15),
        Semantics(
          header: true,
          child: Text(d.productTitle, style: AppText.h1.copyWith(fontSize: 23, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 5),
        Text('${fcfa(d.productPrice)} · ${d.productStock}', style: DTxt.kvLabel.copyWith(fontSize: 13.5)),
        const SizedBox(height: 7),
        _Tabs(labels: d.productTabs, selected: _tab, onSelect: (i) => setState(() => _tab = i)),
        const SizedBox(height: 16),
        Text(d.productTabTexts[_tab], style: DTxt.body),
        const SizedBox(height: 14),
        const DSectionTitle('Variantes'),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          children: [
            for (final (i, v) in d.productVariants.indexed)
              DChoiceChip(v, selected: i == _variant, onTap: () => setState(() => _variant = i)),
          ],
        ),
        const SizedBox(height: 10),
        DKvCard(title: 'Caractéristiques', rows: d.productSpecs),
        const SizedBox(height: 17),
        DSummaryCard(
          height: 64,
          leading: DAvatar(d.creatorAvatar, size: 50),
          title: d.creatorName,
          subtitle: d.sellerSubtitle,
          trailing: const DBadge('Voir', background: AppColors.accentSoft, foreground: AppColors.accent),
          onTap: () => context.openScreen('38'),
        ),
      ],
    );
  }
}

/// Onglets texte avec soulignement violet sous l'onglet actif.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DColors.divider)),
      ),
      child: Row(
        children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: SizedBox(
                    height: 44,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l,
                          style: AppText.body.copyWith(
                            fontSize: 14,
                            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                            color: i == selected ? AppColors.ink : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 60,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == selected ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
