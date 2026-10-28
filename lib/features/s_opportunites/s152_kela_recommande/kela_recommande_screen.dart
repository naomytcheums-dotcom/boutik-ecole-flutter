import '../s_widgets.dart';

/// 152 · Kéla te recommande.
class KelaRecommandeScreen extends ConsumerStatefulWidget {
  const KelaRecommandeScreen({super.key});

  @override
  ConsumerState<KelaRecommandeScreen> createState() => _KelaRecommandeScreenState();
}

class _KelaRecommandeScreenState extends ConsumerState<KelaRecommandeScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionSDataProvider);
    final items = _filter == 0
        ? d.recommendations
        : d.recommendations.where((i) => i.rubric == d.recoFilters[_filter]).toList();
    return CPage(
      title: 'Kéla te recommande',
      tab: NavTab.kela,
      trailing: HeaderIcon(AppIcons.slidersHorizontal, label: 'Préférences', onTap: () => context.openScreen('156')),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1ECFB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCD2F4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 20, backgroundImage: AssetImage(d.kelaAvatar)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kéla · ton assistante IA', style: AppText.label),
                    const SizedBox(height: 2),
                    Text(d.kelaIntro, style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap12,
        GTabs(labels: d.recoFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        SItemList(items),
      ],
    );
  }
}
