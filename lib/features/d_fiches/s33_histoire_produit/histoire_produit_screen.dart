import '../../common/common.dart';
import '../d_widgets.dart';

/// 33 · Histoire du produit (créateur et étapes de fabrication).
class HistoireProduitScreen extends ConsumerWidget {
  const HistoireProduitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Histoire du produit',
      actions: [DButton('Contacter le créateur', onPressed: () => context.openScreen('39'))],
      children: [
        const SizedBox(height: 2),
        _StoryHero(title: d.storyHeadline, subtitle: d.storyTagline),
        const SizedBox(height: 17),
        Center(child: DAvatar(d.creatorAvatar, size: 84, label: 'Photo de ${d.creatorName}')),
        const SizedBox(height: 10),
        Center(
          child: Text(d.creatorName, style: AppText.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 3),
        Center(child: Text(d.storyCreatorMeta, style: DTxt.kvLabel)),
        const SizedBox(height: 9),
        const Center(
          child: DBadge('Créateur vérifié', background: DColors.doneSoft, foreground: DColors.doneText, height: 22),
        ),
        const SizedBox(height: 27),
        const DSectionTitle('Son histoire'),
        const SizedBox(height: 20),
        Text(d.storyText, style: DTxt.body.copyWith(height: 1.54)),
        const SizedBox(height: 14),
        const DSectionTitle('Étapes de fabrication'),
        const SizedBox(height: 19),
        for (final (i, s) in d.storySteps.indexed)
          _StepRow(
            title: s.$1,
            subtitle: s.$2,
            state: s.$3,
            last: i == d.storySteps.length - 1,
            nextDone: i + 1 < d.storySteps.length && d.storySteps[i + 1].$3 != DStepState.todo,
          ),
      ],
    );
  }
}

/// Bandeau titre sur dégradé gris (maquette sans photo).
class _StoryHero extends StatelessWidget {
  const _StoryHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD3D2D4), Color(0xFF8E8C91), Color(0xFF424045)],
          stops: [0, .5, 1],
        ),
      ),
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: DTxt.meta.copyWith(color: const Color(0xE6FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

/// Étape de la frise verticale : pastille d'état reliée par un trait.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.last,
    required this.nextDone,
  });

  final String title;
  final String subtitle;
  final DStepState state;
  final bool last;
  final bool nextDone;

  static const _doneLine = Color(0xFFBFE8D6);
  static const _todoLine = Color(0xFFE4E1EA);

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      DStepState.done => 'terminée',
      DStepState.current => 'en cours',
      DStepState.todo => 'à venir',
    };
    return Semantics(
      label: '$title, $subtitle, étape $label',
      excludeSemantics: true,
      child: SizedBox(
        height: 62,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 62,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!last)
                    Positioned(
                      top: 20,
                      bottom: 0,
                      child: Container(width: 2, color: state == DStepState.done && nextDone ? _doneLine : _todoLine),
                    ),
                  _Dot(state),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DTxt.item.copyWith(height: 1.15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: DTxt.meta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.state);

  final DStepState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: switch (state) {
          DStepState.done => DColors.done,
          DStepState.current => AppColors.ink,
          DStepState.todo => Colors.white,
        },
        border: state == DStepState.todo ? Border.all(color: _StepRow._todoLine, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: state == DStepState.done ? const AppIcon(AppIcons.check, size: 12, color: Colors.white) : null,
    );
  }
}
