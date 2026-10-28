import '../q_widgets.dart';

/// 150 (4/4) · Mes commandes, état vide.
class CommandesVideScreen extends ConsumerStatefulWidget {
  const CommandesVideScreen({super.key});

  @override
  ConsumerState<CommandesVideScreen> createState() => _CommandesVideScreenState();
}

class _CommandesVideScreenState extends ConsumerState<CommandesVideScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionQDataProvider);
    return AppScaffold(
      tab: NavTab.profile,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const QTitle('Mes commandes'),
      children: [
        GTabs(labels: d.orderTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 150),
        Semantics(
          header: true,
          child: Text(
            'Aucune commande pour le moment',
            textAlign: TextAlign.center,
            style: AppText.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        gap12,
        Text(
          'Vos commandes apparaîtront ici dès votre\npremier achat sur Boutik-École.',
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(fontSize: 12.5),
        ),
        gap24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: PrimaryButton(label: 'Découvrir la boutique', height: 48, onPressed: () => context.goScreen('04')),
        ),
      ],
    );
  }
}
