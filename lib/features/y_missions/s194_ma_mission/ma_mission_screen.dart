import '../y_widgets.dart';

/// 194 · Ma mission : avancement de la mission côté client.
class MaMissionScreen extends ConsumerWidget {
  const MaMissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionYDataProvider);
    final (heroTitle, heroSubtitle) = d.missionHero;
    final (stage, stageDetail) = d.missionStage;
    return GPage(
      title: 'Ma mission',
      trailing: RoundIconButton(
        icon: AppIcons.messageCircle,
        label: 'Messages de la mission',
        bordered: false,
        background: Colors.transparent,
        onTap: () => context.openScreen('196'),
      ),
      actions: [
        YOutlineButton('Écrire à l’équipe', onPressed: () => context.openScreen('196')),
        PrimaryButton(label: 'Voir le dossier', onPressed: () => context.openScreen('196')),
      ],
      children: [
        YHero(title: heroTitle, subtitle: heroSubtitle, height: 170),
        const SizedBox(height: 14),
        AppCard(
          radius: 26,
          borderColor: null,
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              GGauge(percent: d.missionPercent, size: 92),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stage, style: AppText.bodyStrong.copyWith(fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(stageDetail, style: AppText.small.copyWith(fontSize: 12.5, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const YTitle('Avancement', top: 13, bottom: 18),
        YVTimeline(
          spacing: 84,
          onProof: (_) => context.openScreen('197'),
          steps: [for (final (t, dt, s, p) in d.missionSteps) YVStep(t, dt, s, proof: p)],
        ),
        const SizedBox(height: 24),
        YKvCard(rows: [('Paiement', d.missionPayment), ('Prochain point', d.nextMeeting)]),
      ],
    );
  }
}
