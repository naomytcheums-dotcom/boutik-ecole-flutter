import '../y_widgets.dart';

/// 201 · Mes missions (étudiant) : compteurs, missions par statut et revenus.
class MesMissionsScreen extends ConsumerStatefulWidget {
  const MesMissionsScreen({super.key});

  @override
  ConsumerState<MesMissionsScreen> createState() => _MesMissionsScreenState();
}

class _MesMissionsScreenState extends ConsumerState<MesMissionsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final missions = d.myMissions.where((m) => m.$6 == _tab).toList();
    return YRootPage(
      title: 'Mes missions',
      children: [
        YStatsCard(d.myStats),
        const SizedBox(height: 10),
        YTabs(labels: d.myTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 10),
        if (missions.isEmpty)
          const YCard(
            padding: EdgeInsets.all(24),
            children: [Center(child: Text('Aucune mission dans cette liste.'))],
          )
        else
          YCard(
            children: [
              for (final (image, title, detail, badge, tone, _) in missions)
                YIconRow(
                  leading: YThumb(image),
                  title: title,
                  subtitle: detail,
                  trailing: YBadge(badge, tone),
                  onTap: () => context.openScreen(badge == 'Livrer' ? '195' : '194'),
                ),
            ],
          ),
        const SizedBox(height: 14),
        YKvCard(
          title: 'Mes revenus',
          rows: [
            ('Disponible au versement', fcfa(d.availableIncome)),
            ('En attente de validation', fcfa(d.pendingIncome)),
          ],
        ),
      ],
    );
  }
}
