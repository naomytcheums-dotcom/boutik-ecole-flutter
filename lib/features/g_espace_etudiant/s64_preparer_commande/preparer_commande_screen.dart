import '../g_widgets.dart';

/// 64 · Préparer une commande (liste de contrôle et remise).
class PreparerCommandeScreen extends ConsumerStatefulWidget {
  const PreparerCommandeScreen({super.key});

  @override
  ConsumerState<PreparerCommandeScreen> createState() => _PreparerCommandeScreenState();
}

class _PreparerCommandeScreenState extends ConsumerState<PreparerCommandeScreen> {
  late final _done = [...ref.read(sectionGDataProvider).checklistDone];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionGDataProvider);
    final complete = !_done.contains(false);
    return GPage(
      title: 'Préparer ${d.saleRef}',
      actions: [
        GOutlineButton('Signaler un souci', onPressed: () => context.openScreen('48')),
        PrimaryButton(
          label: 'Marquer prête',
          height: 54,
          onPressed: () => complete ? context.openScreen('65') : context.toast('Cochez tous les points de la liste de contrôle.'),
        ),
      ],
      children: [
        GStepper(labels: d.prepareSteps, current: 1),
        gap16,
        AppCard(
          padding: const EdgeInsets.all(10),
          child: GThumbRow(image: d.prepareImage, title: d.prepareProduct, subtitle: d.prepareDetail),
        ),
        const GSectionTitle('Liste de contrôle'),
        for (final (i, c) in d.checklist.indexed)
          CheckRow(label: c, value: _done[i], onChanged: (v) => setState(() => _done[i] = v)),
        gap12,
        KeyValueCard(
          title: 'Remise',
          rowGap: 14,
          rows: [KV('Remise prévue', d.pickupPoint), KV('Avant le', d.handoverDeadline)],
        ),
        gap16,
        const GNote('Le client est averti automatiquement quand la commande est marquée prête.', icon: AppIcons.bell),
      ],
    );
  }
}