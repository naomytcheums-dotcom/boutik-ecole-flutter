import '../i_widgets.dart';

/// 87 · Registre des innovations (propriété intellectuelle).
class RegistreInnovationsScreen extends ConsumerStatefulWidget {
  const RegistreInnovationsScreen({super.key});

  @override
  ConsumerState<RegistreInnovationsScreen> createState() => _RegistreInnovationsScreenState();
}

class _RegistreInnovationsScreenState extends ConsumerState<RegistreInnovationsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionIDataProvider);
    final items = d.innovations.where((x) => x.title.toLowerCase().contains(_query.toLowerCase())).toList();
    return GPage(
      title: 'Registre des innovations',
      actions: [PrimaryButton(label: 'Déclarer une innovation', height: 54, onPressed: () => context.openScreen('80'))],
      children: [
        SearchField(hint: 'Rechercher une innovation', onChanged: (v) => setState(() => _query = v)),
        gap16,
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Aucune innovation trouvée.', textAlign: TextAlign.center, style: AppText.secondary),
          )
        else
          GListCard(
            children: [
              for (final x in items)
                IIconRow(
                  icon: x.icon,
                  title: x.title,
                  subtitle: x.detail,
                  trailing: GBadge(x.status, x.tone),
                  onTap: () => context.openScreen('283'),
                ),
            ],
          ),
        gap16,
        const GNote(
          'La propriété intellectuelle reste à l’étudiant ; l’IUT conserve un droit d’usage pédagogique.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
