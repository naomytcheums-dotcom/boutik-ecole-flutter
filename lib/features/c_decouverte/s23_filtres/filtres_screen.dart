import '../c_widgets.dart';

/// 23 · Filtres (feuille plein écran).
class FiltresScreen extends ConsumerStatefulWidget {
  const FiltresScreen({super.key});

  @override
  ConsumerState<FiltresScreen> createState() => _FiltresScreenState();
}

class _FiltresScreenState extends ConsumerState<FiltresScreen> {
  late final d = ref.read(sectionCDataProvider);
  int _type = 0;
  int _availability = 0;
  late String _dept = d.departments.first;
  late String _cat = d.categories.first;
  late RangeValues _price = RangeValues(0, d.defaultPriceMax.toDouble());

  void _reset() => setState(() {
    _type = 0;
    _availability = 0;
    _dept = d.departments.first;
    _cat = d.categories.first;
    _price = RangeValues(0, d.defaultPriceMax.toDouble());
  });

  Widget _chips(List<String> labels, int selected, ValueChanged<int> onTap) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final (i, l) in labels.indexed)
        Semantics(
          button: true,
          selected: i == selected,
          child: GestureDetector(
            onTap: () => onTap(i),
            child: SizedBox(
              height: 46,
              child: Center(
                widthFactor: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 96),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: ShapeDecoration(
                    color: i == selected ? AppColors.ink : const Color(0xFFF1EFF4),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    style: AppText.body.copyWith(
                      color: i == selected ? Colors.white : const Color(0xFF5E5B66),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    Text title(String t) => Text(t, style: AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w600));
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Filtres', style: AppText.h1.copyWith(fontSize: 24, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      HeaderIcon(AppIcons.x, label: 'Fermer', onTap: () => ScreenHeader.back(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text('Type d’offre', style: AppText.body.copyWith(fontSize: 16, color: const Color(0xFF4A4752))),
                      gap8,
                      _chips(d.offerTypes, _type, (i) => setState(() => _type = i)),
                      gap24,
                      title('Département'),
                      SelectField(
                        label: '',
                        options: d.departments,
                        value: _dept,
                        onChanged: (v) => setState(() => _dept = v),
                      ),
                      gap16,
                      title('Prix'),
                      gap8,
                      Row(
                        children: [
                          Expanded(child: Text(fcfa(0), style: AppText.body)),
                          Text('${fcfa(d.maxPrice, withUnit: false)}+ FCFA', style: AppText.body),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: AppColors.ink,
                          thumbColor: AppColors.ink,
                          trackHeight: 3,
                          overlayColor: AppColors.accent.withValues(alpha: .12),
                        ),
                        child: RangeSlider(
                          values: _price,
                          max: d.maxPrice.toDouble(),
                          divisions: 20,
                          labels: RangeLabels(fcfa(_price.start.round()), fcfa(_price.end.round())),
                          semanticFormatterCallback: (v) => fcfa(v.round()),
                          onChanged: (v) => setState(() => _price = v),
                        ),
                      ),
                      gap16,
                      title('Disponibilité'),
                      gap8,
                      _chips(d.availability, _availability, (i) => setState(() => _availability = i)),
                      gap24,
                      title('Catégorie'),
                      SelectField(
                        label: '',
                        options: d.categories,
                        value: _cat,
                        onChanged: (v) => setState(() => _cat = v),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    children: [
                      Expanded(child: GOutlineButton('Réinitialiser', onPressed: _reset)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PrimaryButton(label: 'Appliquer', height: 54, onPressed: () => context.openScreen('20')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
