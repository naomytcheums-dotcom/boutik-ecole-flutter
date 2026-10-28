import '../../n_admin_globale/n_widgets.dart' show OpsSplit;
import '../../l_departement/l_widgets.dart' show lBadge;
import '../../n_admin_globale/n_widgets.dart' show nAdminNav;
import '../t_widgets.dart';

/// 169 · Modération des concours et des offres (web, administration globale).
class ModerationConcoursScreen extends ConsumerStatefulWidget {
  const ModerationConcoursScreen({super.key});

  @override
  ConsumerState<ModerationConcoursScreen> createState() => _ModerationConcoursScreenState();
}

class _ModerationConcoursScreenState extends ConsumerState<ModerationConcoursScreen> {
  int _tab = 0;
  final _decided = <String, (String, Tone)>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionTDataProvider);
    return WebShell(
      title: 'Modération des concours et des offres',
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: nAdminNav,
      selected: 3,
      accountName: 'Modérateur',
      accountSubtitle: 'Administration globale',
      children: [
        OpsTabs(labels: d.moderationTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        gap16,
        OpsTable(
          columns: const ['Élément', 'Organisateur', 'Type', 'Soumis', 'Décision'],
          flex: const [4, 3, 2, 2, 2],
          emptyLabel: 'Aucun élément dans cet onglet.',
          rows: [
            for (final m in d.moderation)
              if (_tab == 0 || (_tab == 1 && m.$3 == 'Stage') || (_tab == 2 && m.$3 == 'Défi'))
                [
                  OpsCell(m.$1, strong: true),
                  OpsCell(m.$2),
                  OpsCell(m.$3),
                  OpsCell(m.$4),
                  Builder(
                    builder: (_) {
                      final (label, tone) = _decided[m.$1] ?? (m.$5, m.$6);
                      if (label != 'À valider') return lBadge(label, tone);
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: OpsBadge(
                          label,
                          tone: OpsTone.info,
                          onTap: () => setState(() => _decided[m.$1] = ('Validé', Tone.success)),
                        ),
                      );
                    },
                  ),
                ],
          ],
        ),
        gap16,
        OpsSplit(
          left: OpsKvCard(title: 'Indicateurs', rows: d.moderationIndicators),
          right: const OpsInfoNote(
            'Toute offre ou tout concours doit mentionner l’organisateur, les conditions et une date limite claire.',
          ),
        ),
      ],
    );
  }
}
