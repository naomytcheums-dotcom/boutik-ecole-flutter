import '../../common/common.dart';

/// 270 · Showroom national (projets des établissements du réseau).
class ShowroomNationalScreen extends ConsumerStatefulWidget {
  const ShowroomNationalScreen({super.key});

  @override
  ConsumerState<ShowroomNationalScreen> createState() => _ShowroomNationalScreenState();
}

class _ShowroomNationalScreenState extends ConsumerState<ShowroomNationalScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    final city = d.showroomFilters[_filter];
    final items = _filter == 0 ? d.showroom : d.showroom.where((p) => p.institution.endsWith(city)).toList();
    return AppScaffold(
      showNav: false,
      padding: EdgeInsets.zero,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: PageIntro('Showroom national', subtitle: 'Les projets des établissements du réseau', display: true),
        ),
        PillBar(labels: d.showroomFilters, selected: _filter, onSelected: (i) => setState(() => _filter = i)),
        gap24,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Aucun projet partagé pour $city.', style: AppText.secondary, textAlign: TextAlign.center),
                )
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.72,
                  children: [
                    for (final p in items)
                      GestureDetector(
                        onTap: () => context.openScreen('33'),
                        child: Semantics(
                          button: true,
                          label: '${p.title}, ${p.institution} · ${p.department}',
                          excludeSemantics: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: PhotoTile(image: p.image, aspectRatio: 1, semanticLabel: p.title)),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(p.title, style: AppText.h3.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text('${p.institution} · ${p.department}', style: AppText.small),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
