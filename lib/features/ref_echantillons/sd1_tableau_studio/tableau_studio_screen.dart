import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';

/// D1 · Tableau de bord « Performance de mon studio » présenté sur l'affiche « Nouvelle vue ».
/// En dessous de 1000 px de large, seul le tableau de bord (responsive) est affiché.
class TableauStudioScreen extends ConsumerWidget {
  const TableauStudioScreen({super.key});

  static const designSize = Size(1424, 1045);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1000) return const StudioDashboard();
        final scale = c.maxWidth / designSize.width;
        return Scaffold(
          backgroundColor: const Color(0xFFF9CB66),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3C8), Color(0xFFFFE9AA), Color(0xFFF9CB66)],
              ),
            ),
            child: SingleChildScrollView(
              child: SizedBox(
                width: c.maxWidth,
                height: designSize.height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(size: designSize, child: const _Poster()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster();

  @override
  Widget build(BuildContext context) {
    final big = AppText.web(AppText.display)
        .copyWith(fontSize: 120, fontWeight: FontWeight.w500, height: 0.92, letterSpacing: -4);
    return Stack(
      children: [
        Positioned(
          left: 64,
          top: 70,
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nouvelle', style: big),
                ShaderMask(
                  shaderCallback: (r) =>
                      const LinearGradient(colors: [Color(0xFFEC7C14), Color(0xFFF7A93C)]).createShader(r),
                  child: Text('vue', style: big.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 68,
          top: 62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TABLEAU DE BORD',
                style: AppText.web(AppText.h1).copyWith(fontSize: 27, fontWeight: FontWeight.w500, letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Performance de mon studio',
                style: AppText.web(AppText.h2)
                    .copyWith(fontSize: 23, fontWeight: FontWeight.w400, color: const Color(0xFF6E6A62)),
              ),
            ],
          ),
        ),
        Positioned(
          left: 90,
          right: 92,
          top: 312,
          bottom: -60,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(color: const Color(0xFF0B0B0D), borderRadius: BorderRadius.circular(44)),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              child: const FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(width: 1527, height: 905, child: StudioDashboard()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tableau de bord web du studio (WebShell responsive).
class StudioDashboard extends ConsumerWidget {
  const StudioDashboard({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: 'D1', section: 'Principal'),
    WebNavItem('Missions', AppIcons.layers, target: '201', section: 'Principal'),
    WebNavItem('Analytique', AppIcons.chartColumn, target: 'D1', section: 'Principal'),
    WebNavItem('Mbella SARL', AppIcons.user, target: 'P3', section: 'Contacts'),
    WebNavItem('Mairie de Douala', AppIcons.user, target: 'P3', section: 'Contacts'),
    WebNavItem('Équipe studio', AppIcons.users, target: 'P1', section: 'Contacts'),
    WebNavItem('Messages', AppIcons.messageCircle, target: 'A3', section: 'Autres'),
    WebNavItem('Insights de performance', AppIcons.chartColumn, target: 'D1', section: 'Autres'),
    WebNavItem('Paramètres', AppIcons.sun, target: 'P5', section: 'Compte'),
    WebNavItem('Aide et retours', AppIcons.circleHelp, target: 'A1', section: 'Compte'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionREFDataProvider);
    return WebShell(
      title: 'Aperçu des performances',
      subtitle: 'Tes ventes, ta croissance et tes avis, tout au même endroit.',
      navItems: nav,
      selected: 0,
      accountName: d.studioOwner,
      accountSubtitle: d.studioEmail,
      topAction: _TopActions(avatars: d.teamAvatars, onExport: () => context.toast('Export du rapport en cours')),
      children: [
        _Split(
          flex: (36, 65),
          left: const OpsHeroCard(headline: 'Fais rayonner\nton talent', height: 290),
          right: OpsTrendCard(
            title: 'Tendance des revenus',
            total: fcfa(d.revenueTotal),
            delta: d.revenueDelta,
            deltaNote: '+ ${fcfa(d.revenueGain, withUnit: false)} vs période précédente',
            bars: d.revenueBars,
            curve: d.revenueCurve,
            highlight: d.revenueHighlight,
            tooltipValue: d.revenueTooltip.$1,
            tooltipLabel: d.revenueTooltip.$2,
            months: d.revenueMonths,
            height: 290,
            onFilter: () => context.toast('Filtres de période'),
          ),
        ),
        const SizedBox(height: 12),
        _Split(
          flex: (63, 39),
          left: OpsListCard(
            title: 'Performance des produits',
            columns: const ['Produit', 'Total commandes', 'Statut', 'Prix'],
            rows: [
              for (final (image, name, ref, orders, status, available, price) in d.studioProducts)
                OpsListRow(
                  image: image,
                  title: name,
                  subtitle: ref,
                  middle: '$orders unités',
                  status: status,
                  statusTone: available ? OpsTone.lime : OpsTone.grey,
                  amount: '${fcfa(price, withUnit: false)}${nbsp}F',
                ),
            ],
            onSort: () => context.toast('Tri par commandes'),
            onFilter: () => context.toast('Filtres produits'),
            onRowTap: (_) => context.openScreen('V1'),
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OpsGoalCard(
                title: 'Progression de l’objectif',
                percent: d.studioGoal,
                caption: 'de l’objectif atteint',
                progress: d.studioGoalProgress,
              ),
              const SizedBox(height: 12),
              OpsAssistantCard(
                avatar: d.kelaDashAvatar,
                question: d.kelaDashQuestion,
                answer: d.kelaDashAnswer,
                onAsk: () => context.openScreen('A1'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({required this.avatars, required this.onExport});

  final List<String> avatars;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 900) {
      return RoundIconButton(
        icon: AppIcons.externalLink,
        label: 'Exporter',
        background: AppColors.ink,
        foreground: Colors.white,
        bordered: false,
        onTap: onExport,
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final export = Semantics(
          button: true,
          child: Material(
            color: AppColors.ink,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onExport,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Exporter', style: AppText.button.copyWith(fontSize: 14)),
                      const SizedBox(width: 28),
                      const AppIcon(AppIcons.externalLink, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22.0 * avatars.length + 10,
              height: 30,
              child: Stack(
                children: [
                  for (var i = 0; i < avatars.length; i++)
                    Positioned(
                      left: i * 18.0,
                      child: Container(
                        width: 30,
                        height: 30,
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: ClipOval(child: Image.asset(avatars[i], fit: BoxFit.cover, excludeFromSemantics: true)),
                      ),
                    ),
                ],
              ),
            ),
            Text('+3', style: AppText.small.copyWith(color: AppColors.ink)),
            const SizedBox(width: 24),
            Semantics(
              label: 'Mon compte',
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 40),
            export,
          ],
        );
      },
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right, required this.flex});

  final Widget left;
  final Widget right;
  final (int, int) flex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 12), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: flex.$1, child: left),
            const SizedBox(width: 14),
            Expanded(flex: flex.$2, child: right),
          ],
        );
      },
    );
  }
}
