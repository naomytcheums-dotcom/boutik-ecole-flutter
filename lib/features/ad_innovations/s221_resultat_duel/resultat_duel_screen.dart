import '../ad_widgets.dart';

/// 221 · Résultat du duel (paiement versé, classement des participants).
class ResultatDuelScreen extends ConsumerWidget {
  const ResultatDuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADDataProvider);
    return AdPage(
      header: const AdBackHeader('Résultat du duel'),
      actions: [
        PrimaryButton(label: 'Voir le dossier du gagnant', height: 54, onPressed: () => context.openScreen('229')),
      ],
      children: [
        AdHero(image: d.duelHero, title: d.duelWinner, subtitle: d.duelWinnerDetail, height: 180, titleSize: 18),
        const SizedBox(height: 14),
        AdKvCard(
          title: 'Paiement',
          rows: [
            ('Prix versé', fcfa(d.duelPaidPrize)),
            ('Primes de participation', fcfa(d.duelPaidBonuses)),
            ('Participants', d.duelParticipants),
          ],
        ),
        const AdSectionTitle('Classement', top: 18, bottom: 12),
        AdCard(
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          child: Column(
            children: [
              for (final (i, r) in d.duelRanking.indexed) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 62),
                    child: Divider(height: 1, color: Color(0xFFEDEBF0)),
                  ),
                SizedBox(
                  height: 66,
                  child: Row(
                    children: [
                      AdAvatar(r.avatar, size: 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(r.detail, style: AppText.small.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      GBadge(r.badge, r.tone),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
