import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 264 · Pages éditoriales (pages, bannières, FAQ).
class PagesEditorialesScreen extends ConsumerStatefulWidget {
  const PagesEditorialesScreen({super.key});

  @override
  ConsumerState<PagesEditorialesScreen> createState() => _PagesEditorialesScreenState();
}

class _PagesEditorialesScreenState extends ConsumerState<PagesEditorialesScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(nouveauxDataProvider).editorialPages;
    final page = pages[_selected];
    return WebShell(
      title: 'Pages éditoriales',
      subtitle: 'Gérez les pages, bannières et contenus d’aide.',
      navItems: adminNav([
        ('Tableau de bord', AppIcons.layoutGrid, '127'),
        ('Pages éditoriales', AppIcons.fileText, '264'),
        ('Bannières', AppIcons.image, null),
        ('FAQ', AppIcons.circleHelp, null),
      ]),
      selected: 1,
      children: [
        TwoColumns(
          flex: (11, 8),
          left: WebPanel(
            title: 'Pages',
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              children: [
                _row(['Page', 'Dernière modif.', 'Statut'], header: true),
                for (final (i, p) in pages.indexed)
                  InkWell(
                    onTap: () => setState(() => _selected = i),
                    child: _row([p.$1, p.$2, p.$3], selected: i == _selected),
                  ),
              ],
            ),
          ),
          right: WebPanel(
            title: 'Page : ${page.$1}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field('Titre : ${page.$1 == 'Accueil' ? 'Les talents de l’IUT de Douala' : page.$1}'),
                gap12,
                _field('Bloc héros · texte · liste de produits en vedette…', height: 170, hint: true),
                gap24,
                Row(
                  children: [
                    PrimaryButton(label: 'Publier', expand: false, height: 44, onPressed: () => context.toast('${page.$1} publiée.')),
                    const SizedBox(width: 10),
                    PrimaryButton(label: 'Aperçu', expand: false, height: 44, variant: ButtonVariant.secondary, onPressed: () {}),
                  ],
                ),
                gap16,
                Text('Historique des versions conservé', style: AppText.small),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String text, {double? height, bool hint = false}) => Container(
    height: height,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.webBackground, borderRadius: BorderRadius.circular(14)),
    alignment: Alignment.topLeft,
    child: Text(text, style: hint ? AppText.small : AppText.body.copyWith(fontWeight: FontWeight.w400)),
  );

  Widget _row(List<String> c, {bool header = false, bool selected = false}) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: header
        ? BoxDecoration(color: AppColors.webBackground, borderRadius: BorderRadius.circular(10))
        : BoxDecoration(
            color: selected ? AppColors.accentSoft.withValues(alpha: .4) : null,
            border: const Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text(c[0], style: header ? AppText.small : AppText.bodyStrong.copyWith(fontSize: 13))),
        Expanded(flex: 3, child: Text(c[1], style: header ? AppText.small : AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w400))),
        Expanded(flex: 2, child: Text(c[2], style: header ? AppText.small : AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w400))),
      ],
    ),
  );
}
