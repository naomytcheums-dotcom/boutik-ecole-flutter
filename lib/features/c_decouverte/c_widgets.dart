import '../../data/demo/section_c_demo.dart';
import '../g_espace_etudiant/g_widgets.dart';

export '../../data/demo/section_c_demo.dart';
export '../g_espace_etudiant/g_widgets.dart';

/// En-tête des écrans de la section C : flèche, titre gras, action à droite (décalé comme la maquette).
class CHeader extends StatelessWidget {
  const CHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 34, 16, 8),
    child: Row(
      children: [
        RoundIconButton(
          icon: AppIcons.arrowLeft,
          label: 'Retour',
          bordered: false,
          background: Colors.transparent,
          onTap: () => ScreenHeader.back(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Page mobile de la section C avec menu bas.
class CPage extends StatelessWidget {
  const CPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.tab = NavTab.search,
    this.showNav = true,
  });

  final bool showNav;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final NavTab tab;

  @override
  Widget build(BuildContext context) => AppScaffold(
    tab: tab,
    showNav: showNav,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    header: CHeader(title, trailing: trailing),
    children: children,
  );
}

/// Tuile produit de grille : photo + cœur, titre, prix, département en accent.
class CProductTile extends StatefulWidget {
  const CProductTile(this.tile, {super.key, this.onTap, this.aspect = 157 / 116});

  final CTile tile;
  final VoidCallback? onTap;
  final double aspect;

  @override
  State<CProductTile> createState() => _CProductTileState();
}

class _CProductTileState extends State<CProductTile> {
  bool _fav = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    return Semantics(
      button: true,
      label: '${t.title}, ${fcfa(t.price)}',
      child: GestureDetector(
        onTap: widget.onTap ?? () => context.openScreen('05'),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhotoTile(
              image: t.image,
              aspectRatio: widget.aspect,
              radius: 18,
              favorite: _fav,
              onFavorite: () => setState(() => _fav = !_fav),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: AppText.label.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(fcfa(t.price), style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                  if (t.department.isNotEmpty)
                    Text(t.department, style: AppText.small.copyWith(fontSize: 11, color: AppColors.accent)),
                  if (t.rating != null)
                    Row(
                      children: [
                        const AppIcon(AppIcons.star, size: 13, color: Color(0xFFF2B33D)),
                        const SizedBox(width: 4),
                        Text(t.rating!, style: AppText.label),
                        Text(' (${t.reviews} avis)', style: AppText.small),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille 2 colonnes de tuiles produit.
class CGrid extends StatelessWidget {
  const CGrid(this.tiles, {super.key, this.aspect = 157 / 116, this.onTap});

  final List<CTile> tiles;
  final double aspect;
  final ValueChanged<CTile>? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Wrap(
        spacing: 18,
        runSpacing: 14,
        children: [
          for (final t in tiles)
            SizedBox(
              width: (c.maxWidth - 18) / 2,
              child: CProductTile(t, aspect: aspect, onTap: onTap == null ? null : () => onTap!(t)),
            ),
        ],
      ),
    );
  }
}

/// Ligne « compteur + Trier → ».
class CCountRow extends StatelessWidget {
  const CCountRow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: AppText.bodyStrong.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
      TextLink('Trier →', onTap: () => context.toast('Tri par pertinence.')),
    ],
  );
}

/// Bouton icône d'en-tête.
Widget cIcon(BuildContext context, String icon, String label, String target) =>
    HeaderIcon(icon, label: label, onTap: () => context.openScreen(target));

/// Pastille de statut de commande client.
(String, Tone) cOrderStatus(String s) => switch (s) {
  'livree' => ('Livrée', Tone.success),
  'en_cours' => ('En cours', Tone.accent),
  _ => ('Annulée', Tone.error),
};
