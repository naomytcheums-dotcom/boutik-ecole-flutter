import '../h_widgets.dart';

/// 76 · Ma candidature (état, suivi, informations).
class MaCandidatureScreen extends ConsumerStatefulWidget {
  const MaCandidatureScreen({super.key});

  @override
  ConsumerState<MaCandidatureScreen> createState() => _MaCandidatureScreenState();
}

class _MaCandidatureScreenState extends ConsumerState<MaCandidatureScreen> {
  bool _withdrawn = false;

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer la candidature ?', style: AppText.h3),
        content: Text('L’entreprise ne pourra plus consulter votre dossier.', style: AppText.secondary),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) setState(() => _withdrawn = true);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionHDataProvider);
    final a = d.application;
    return HPage(
      title: 'Ma candidature',
      actions: [
        _DangerOutlineButton('Retirer', onPressed: _withdrawn ? null : _withdraw),
        PrimaryButton(label: 'Contacter', height: 54, onPressed: () => context.openScreen('53')),
      ],
      children: [
        const SizedBox(height: 6),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
          child: Row(
            children: [
              const HIconTile(AppIcons.briefcase),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${a.company} · ${a.city} · ${a.duration}', style: AppText.small.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              _withdrawn ? const HBadge('Retirée', HBadgeKind.pending) : HBadge(d.applicationStatus, HBadgeKind.accent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 60,
            child: OverflowBox(
              minWidth: c.maxWidth + 62,
              maxWidth: c.maxWidth + 62,
              alignment: Alignment.topCenter,
              child: GStepper(labels: d.applicationSteps, current: d.applicationStep),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(header: true, child: Text('Suivi', style: AppText.h3.copyWith(fontSize: 16))),
        const SizedBox(height: 16),
        for (final (i, s) in d.applicationTrack.indexed) _TrackItem(s, last: i == d.applicationTrack.length - 1),
        const SizedBox(height: 46),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Informations', style: AppText.h3.copyWith(fontSize: 15))),
              const SizedBox(height: 6),
              for (final (i, (k, v)) in d.applicationInfos.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFEDEBEF)),
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Expanded(child: Text(k, style: AppText.secondary.copyWith(fontSize: 13))),
                      Text(v, style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
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

/// Étape du suivi : pastille (faite, en cours, à venir) reliée par un trait vertical.
class _TrackItem extends StatelessWidget {
  const _TrackItem(this.step, {required this.last});

  final HTrackStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final dot = switch (step.state) {
      HStepState.done => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A06A)),
        alignment: Alignment.center,
        child: const AppIcon(AppIcons.check, size: 12, color: Colors.white),
      ),
      HStepState.current => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
      ),
      HStepState.todo => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2DEE8)),
        ),
      ),
    };
    return Semantics(
      label:
          '${step.title}${step.detail == null ? '' : ', ${step.detail}'}, ${switch (step.state) {
            HStepState.done => 'terminé',
            HStepState.current => 'en cours',
            HStepState.todo => 'à venir',
          }}',
      excludeSemantics: true,
      child: SizedBox(
        height: last ? 30 : 62,
        child: Stack(
          children: [
            if (!last)
              Positioned(
                left: 9.25,
                top: 20,
                bottom: 0,
                child: Container(
                  width: 1.5,
                  color: step.state == HStepState.done ? const Color(0xFFBFE8D6) : const Color(0xFFE4E8EE),
                ),
              ),
            Positioned(left: 0, top: 0, child: dot),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (step.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(step.detail!, style: AppText.small.copyWith(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton blanc bordé de rouge (action destructive secondaire).
class _DangerOutlineButton extends StatelessWidget {
  const _DangerOutlineButton(this.label, {required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    child: Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE5484D), width: 1.2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 54,
          child: Center(
            child: Text(label, style: AppText.button.copyWith(color: AppColors.error)),
          ),
        ),
      ),
    ),
  );
}
