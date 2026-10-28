import '../j_widgets.dart';

/// 95 · Devis et négociations.
class DevisNegociationsScreen extends ConsumerStatefulWidget {
  const DevisNegociationsScreen({super.key});

  @override
  ConsumerState<DevisNegociationsScreen> createState() => _DevisNegociationsScreenState();
}

class _DevisNegociationsScreenState extends ConsumerState<DevisNegociationsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionJDataProvider);
    final items = switch (_tab) {
      0 => d.quotes,
      1 => d.quotes.where((q) => q.tone == Tone.success).toList(),
      _ => d.quotes.where((q) => q.tone == Tone.error).toList(),
    };
    return JRootPage(
      title: 'Devis et négociations',
      children: [
        JUnderlineTabs(labels: d.quoteTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 14),
        if (items.isEmpty)
          HEmpty(_tab == 1 ? 'Aucun devis accepté.' : 'Aucun devis refusé.')
        else
          JItemList(items, onTap: (_) => context.openScreen('95b')),
        const JSectionTitle('Dernier échange'),
        for (final (i, m) in d.lastExchange.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          FBubble(FMessage(m.text, m.time, mine: m.mine)),
        ],
      ],
    );
  }
}
