import '../../common/common.dart';

/// 286 · Soumissions et équipe d'un département.
class SoumissionsEquipeScreen extends ConsumerStatefulWidget {
  const SoumissionsEquipeScreen({super.key});

  @override
  ConsumerState<SoumissionsEquipeScreen> createState() => _SoumissionsEquipeScreenState();
}

class _SoumissionsEquipeScreenState extends ConsumerState<SoumissionsEquipeScreen> {
  final _decided = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    final pending = d.submissions.where((s) => !_decided.contains(s.title)).toList();
    void decide(StatusItem s, bool ok) {
      setState(() => _decided.add(s.title));
      context.toast('${s.title} : ${ok ? 'validé' : 'refusé'}.');
    }

    return DetailScreen(
      title: 'Soumissions et équipe',
      subtitle: 'Département ${d.departmentName}',
      action: 'Inviter un membre',
      onAction: () => context.toast('Invitation envoyée.'),
      children: [
        Text('Soumissions en attente (${pending.length})', style: AppText.h3),
        gap8,
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucune soumission en attente.', style: AppText.secondary),
          ),
        for (final s in pending) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: AppText.bodyStrong),
                      Text(s.detail, style: AppText.small),
                    ],
                  ),
                ),
                PrimaryButton(label: 'Valider', expand: false, height: 34, onPressed: () => decide(s, true)),
                TextLink('Refuser', color: AppColors.error, onTap: () => decide(s, false)),
              ],
            ),
          ),
          gap8,
        ],
        gap16,
        Text('Équipe et permissions', style: AppText.h3),
        gap8,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in d.team)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${m.name} · ${m.role}', style: AppText.bodyStrong),
                      Text(m.rights, style: AppText.small),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
