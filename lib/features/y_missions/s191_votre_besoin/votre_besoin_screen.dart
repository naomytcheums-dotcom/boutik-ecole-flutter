import '../../../core/utils/validators_y.dart';
import '../y_widgets.dart';

/// 191 · Votre besoin : choix du type de création, description, budget et date souhaitée.
class VotreBesoinScreen extends ConsumerStatefulWidget {
  const VotreBesoinScreen({super.key});

  @override
  ConsumerState<VotreBesoinScreen> createState() => _VotreBesoinScreenState();
}

class _VotreBesoinScreenState extends ConsumerState<VotreBesoinScreen> {
  final _form = GlobalKey<FormState>();
  final _need = TextEditingController();
  int _category = 0;
  int? _budget;
  String? _date;

  @override
  void dispose() {
    _need.dispose();
    super.dispose();
  }

  String _range((int, int) b) => '${fcfa(b.$1, withUnit: false)} – ${fcfa(b.$2)}';

  Future<void> _pick(String title, List<String> options, String current, ValueChanged<int> onPicked) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: AppText.h3),
            ),
            for (final (i, o) in options.indexed)
              ListTile(
                title: Text(o, style: AppText.body),
                trailing: o == current ? const AppIcon(AppIcons.check, size: 18) : null,
                onTap: () => Navigator.pop(c, i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      context.toast('Besoin envoyé : l’administrateur prépare votre devis.');
      context.openScreen('192');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final budget = d.budgets[_budget ?? d.defaultBudget];
    final date = _date ?? d.wishedDate;
    return GPage(
      title: 'Votre besoin',
      actions: [PrimaryButton(label: 'Envoyer mon besoin', onPressed: _submit)],
      children: [
        YStepper(labels: d.needSteps, current: 0),
        const YTitle('Que voulez-vous faire créer ?', top: 10, bottom: 18),
        _CategoryGrid(
          categories: d.needCategories,
          selected: _category,
          onSelected: (i) => setState(() => _category = i),
        ),
        const SizedBox(height: 14),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const YLabel('Décrivez votre besoin'),
              YTextArea(
                controller: _need,
                label: 'Décrivez votre besoin',
                hint: 'Ex. identité visuelle complète pour ma marque de parfums…',
                validator: validateNeedDescription,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const YLabel('Budget estimé'),
        YPillValue(
          icon: AppIcons.wallet,
          label: 'Budget estimé',
          value: _range(budget),
          chevron: true,
          onTap: () => _pick(
            'Budget estimé',
            [for (final b in d.budgets) _range(b)],
            _range(budget),
            (i) => setState(() => _budget = i),
          ),
        ),
        const SizedBox(height: 14),
        const YLabel('Date souhaitée'),
        YPillValue(
          icon: AppIcons.calendar,
          label: 'Date souhaitée',
          value: date,
          onTap: () => _pick('Date souhaitée', d.dateOptions, date, (i) => setState(() => _date = d.dateOptions[i])),
        ),
        const SizedBox(height: 14),
        const YNote(
          'Paiement sécurisé par Boutik-École : votre argent est gardé en séquestre et libéré à chaque étape validée.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories, required this.selected, required this.onSelected});

  final List<(String, String, String)> categories;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < categories.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (final i in [r, r + 1]) ...[
                if (i > r) const SizedBox(width: 10),
                Expanded(
                  child: _CategoryTile(category: categories[i], selected: i == selected, onTap: () => onSelected(i)),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  final (String, String, String) category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, detail, image) = category;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $detail',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 102,
          foregroundDecoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6A4CF0), width: 3),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(image, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [.25, 1],
                      colors: [Color(0x00000000), Color(0xB3141216)],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 8,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: AppText.small.copyWith(color: Colors.white.withValues(alpha: .9), fontSize: 11),
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
