import '../ad_widgets.dart';

/// 217 · Fiche d'un vœu (seuil de précommandes, conditions, étapes).
class FicheVoeuScreen extends ConsumerStatefulWidget {
  const FicheVoeuScreen({super.key});

  @override
  ConsumerState<FicheVoeuScreen> createState() => _FicheVoeuScreenState();
}

class _FicheVoeuScreenState extends ConsumerState<FicheVoeuScreen> {
  bool _ordered = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final w = d.wishes.first;
    final count = w.count + (_ordered ? 1 : 0);
    final percent = (count * 100 / w.target).round();
    return AdPage(
      header: AdBackHeader(
        w.title,
        action: adHeaderIcon(context, AppIcons.share, 'Partager', () => context.toast('Lien du vœu copié.')),
      ),
      actions: [
        PrimaryButton(
          label: _ordered ? 'Précommande confirmée' : 'Précommander · ${fcfa(w.price)}',
          height: 54,
          onPressed: _ordered
              ? null
              : () {
                  setState(() => _ordered = true);
                  context.toast('Précommande enregistrée : ${fcfa(w.price)} en séquestre.');
                },
        ),
      ],
      children: [
        AdHero(image: w.image, title: d.wishHeadline, subtitle: d.wishByline, height: 190),
        const SizedBox(height: 14),
        AdCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            children: [
              AdGauge(percent: percent, size: 88),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count sur ${w.target}', style: AppText.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                      'Encore ${w.target - count} précommandes pour lancer la production.',
                      style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF5E5B66)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdKvCard(
          title: 'Conditions',
          rows: [('Prix', fcfa(w.price)), ('Livraison estimée', d.wishDelivery), ('Remboursement', d.wishRefund)],
        ),
        const AdSectionTitle('Étapes', top: 16, bottom: 14),
        for (final (i, s) in d.wishSteps.indexed)
          _Step(title: s.$1, detail: s.$2, state: s.$3, last: i == d.wishSteps.length - 1),
        const SizedBox(height: 52),
        AdNote(d.escrowNote, icon: AppIcons.shieldCheck),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.detail, required this.state, required this.last});

  final String title;
  final String detail;
  final int state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final node = switch (state) {
      0 => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF209E6C)),
        alignment: Alignment.center,
        child: const AppIcon(AppIcons.check, size: 12, color: Colors.white),
      ),
      1 => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
      ),
      _ => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E0EA)),
        ),
      ),
    };
    final status = switch (state) {
      0 => 'terminée',
      1 => 'en cours',
      _ => 'à venir',
    };
    return Semantics(
      label: '$title, étape $status${detail.isEmpty ? '' : ', $detail'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  node,
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: state == 0 ? const Color(0xFFBFE8D6) : const Color(0xFFE4E0EA),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detail, style: AppText.small.copyWith(fontSize: 11.5)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
