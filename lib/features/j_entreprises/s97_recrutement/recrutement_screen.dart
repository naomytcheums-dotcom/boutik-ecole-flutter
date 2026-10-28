import '../j_widgets.dart';

/// 97 · Recrutement (offres de stage, d’emploi et d’alternance).
class RecrutementScreen extends ConsumerStatefulWidget {
  const RecrutementScreen({super.key});

  @override
  ConsumerState<RecrutementScreen> createState() => _RecrutementScreenState();
}

class _RecrutementScreenState extends ConsumerState<RecrutementScreen> {
  int _filter = 0;

  void _publish() => context.toast('Nouvelle offre : complétez l’intitulé, la durée et les compétences.');

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final items = d.jobs.where((j) => j.category == d.jobFilters[_filter]).toList();
    return JNavPage(
      title: 'Recrutement',
      trailing: HHeaderAction(AppIcons.plus, label: 'Publier une offre', onTap: _publish),
      children: [
        const SizedBox(height: 1),
        HChips(labels: d.jobFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          HEmpty('Aucune offre « ${d.jobFilters[_filter]} » publiée.')
        else
          JItemList(items, onTap: (_) => context.openScreen('75')),
        gap12,
        PrimaryButton(label: 'Publier une offre', icon: AppIcons.plus, height: 50, onPressed: _publish),
        gap16,
        const JNote(
          'Les candidatures vous sont envoyées avec le portfolio vérifié de l’étudiant.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
