import '../ad_widgets.dart';

/// 229 · CV vivant (profil vérifié d'un étudiant vu par un recruteur).
class CvVivantScreen extends ConsumerWidget {
  const CvVivantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionADDataProvider);
    return AdPage(
      header: AdRootHeader(
        d.cvName,
        action: adHeaderIcon(context, AppIcons.share, 'Partager le CV', () => context.openScreen('228')),
      ),
      actions: [
        GOutlineButton('Proposer un stage', onPressed: () => context.openScreen('97')),
        PrimaryButton(label: 'Contacter', height: 54, onPressed: () => context.openScreen('53')),
      ],
      children: [
        AdHero(image: d.cvHero, title: d.cvHeadline, subtitle: d.cvSubline, height: 170, titleSize: 17),
        const SizedBox(height: 14),
        AdCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (final (i, s) in d.cvStats.indexed) ...[
                  if (i > 0) const VerticalDivider(width: 1, color: Color(0xFFEDEBF0)),
                  Expanded(
                    child: Semantics(
                      label: '${s.$1} ${s.$2}',
                      excludeSemantics: true,
                      child: Column(
                        children: [
                          Text(s.$1, style: AppText.h3.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(s.$2, style: AppText.small.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const AdSectionTitle('Réalisations vérifiées', top: 22, bottom: 14),
        AdCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          child: Column(
            children: [
              for (final (i, a) in d.cvAchievements.indexed) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 62),
                    child: Divider(height: 1, color: Color(0xFFEDEBF0)),
                  ),
                SizedBox(
                  height: 66,
                  child: Row(
                    children: [
                      AdThumb(a.$3, size: 50, radius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(a.$2, style: AppText.small.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const GBadge('Vérifié', Tone.success),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const AdSectionTitle('Certificats', top: 22, bottom: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final c in d.cvCertificates)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: const ShapeDecoration(
                  color: Colors.white,
                  shape: StadiumBorder(side: BorderSide(color: Color(0xFFE4E0EA))),
                ),
                child: Text(c, style: AppText.small.copyWith(fontSize: 11.5, color: const Color(0xFF4A4752))),
              ),
          ],
        ),
      ],
    );
  }
}
