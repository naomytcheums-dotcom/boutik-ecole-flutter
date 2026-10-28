import '../c_widgets.dart';

/// 22b · Services et prestations.
class ServicesPrestationsScreen extends ConsumerStatefulWidget {
  const ServicesPrestationsScreen({super.key});

  @override
  ConsumerState<ServicesPrestationsScreen> createState() => _ServicesPrestationsScreenState();
}

class _ServicesPrestationsScreenState extends ConsumerState<ServicesPrestationsScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionCDataProvider);
    final items = _filter == 0 ? d.services : d.services.where((s) => s.badge == d.serviceFilters[_filter]).toList();
    return CPage(
      title: 'Services et prestations',
      trailing: cIcon(context, AppIcons.search, 'Rechercher', '21'),
      children: [
        GTabs(labels: d.serviceFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap8,
        CCountRow(_filter == 0 ? '${d.serviceCount} services' : '${items.length} service${items.length > 1 ? 's' : ''}'),
        gap12,
        GListCard(
          children: [
            for (final s in items)
              GThumbRow(
                image: s.image,
                title: s.title,
                subtitle: s.detail,
                trailing: const AppIcon(AppIcons.chevronRight, size: 18),
                onTap: () => context.openScreen('34'),
              ),
          ],
        ),
        gap12,
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 136,
            color: const Color(0xFF14284B),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Un service sur mesure ?', style: AppText.h3.copyWith(color: Colors.white)),
                        const Spacer(),
                        Text(
                          'Décrivez votre besoin, les étudiants vous répondent.',
                          style: AppText.small.copyWith(fontSize: 11, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          button: true,
                          child: GestureDetector(
                            onTap: () => context.openScreen('191'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
                              decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
                              child: Text('Demander un devis', style: AppText.label.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 144, height: 136, child: Image.asset(d.customServiceImage, fit: BoxFit.cover)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
