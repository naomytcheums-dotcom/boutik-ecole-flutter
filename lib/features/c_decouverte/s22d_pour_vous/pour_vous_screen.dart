import '../c_widgets.dart';

/// 22d · Pour vous (recommandations personnalisées).
class PourVousScreen extends ConsumerStatefulWidget {
  const PourVousScreen({super.key});

  @override
  ConsumerState<PourVousScreen> createState() => _PourVousScreenState();
}

class _PourVousScreenState extends ConsumerState<PourVousScreen> {
  final _followed = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    return CPage(
      title: 'Pour vous',
      trailing: cIcon(context, AppIcons.slidersHorizontal, 'Préférences', '23'),
      children: [
        const GNote('Recommandations basées sur vos favoris, vos recherches et vos commandes.', icon: AppIcons.zap),
        const GSectionTitle('Recommandé pour vous'),
        CGrid(d.recommended),
        GSectionTitle('Talents à découvrir', trailing: TextLink('Voir tout →', onTap: () => context.openScreen('70'))),
        GListCard(
          children: [
            for (final t in d.suggestedTalents)
              GThumbRow(
                image: t.image,
                title: t.title,
                subtitle: t.detail,
                onTap: () => context.openScreen('10'),
                trailing: Semantics(
                  button: true,
                  label: '${_followed.contains(t.title) ? 'Ne plus suivre' : 'Suivre'} ${t.title}',
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _followed.contains(t.title) ? _followed.remove(t.title) : _followed.add(t.title),
                    ),
                    child: SizedBox(
                      height: 44,
                      child: Center(child: GBadge(_followed.contains(t.title) ? 'Suivi' : 'Suivre', Tone.accent)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
