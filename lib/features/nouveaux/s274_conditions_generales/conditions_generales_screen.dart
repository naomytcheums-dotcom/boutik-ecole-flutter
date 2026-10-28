import '../../common/common.dart';

/// 274 · Conditions générales (CGU / CGV).
class ConditionsGeneralesScreen extends ConsumerStatefulWidget {
  const ConditionsGeneralesScreen({super.key});

  @override
  ConsumerState<ConditionsGeneralesScreen> createState() => _ConditionsGeneralesScreenState();
}

class _ConditionsGeneralesScreenState extends ConsumerState<ConditionsGeneralesScreen> {
  bool _cgu = true;
  bool _cgv = true;

  static const _sections = [
    ('CGU · Utilisation de la plateforme', 'Comptes, contenus publiés, propriété intellectuelle des productions étudiantes, modération.'),
    ('CGV · Ventes et services', 'Prix en FCFA, paiement Orange Money / MTN MoMo, ventilation 70 / 20 / 10, retours et remboursements.'),
    ('Données personnelles', 'Hébergement, durée de conservation, vos droits d’accès et de suppression.'),
  ];

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Conditions générales',
      subtitle: d.termsVersion,
      action: 'Accepter et continuer',
      onAction: _cgu && _cgv ? () => context.goScreen('03') : null,
      children: [
        const HeroMessage(icon: AppIcons.fileText),
        gap24,
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in _sections) ...[
                Text(s.$1, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(s.$2, style: AppText.small),
                gap24,
              ],
            ],
          ),
        ),
        gap16,
        CheckRow(label: 'J’ai lu et j’accepte les CGU', value: _cgu, onChanged: (v) => setState(() => _cgu = v)),
        CheckRow(label: 'J’ai lu et j’accepte les CGV', value: _cgv, onChanged: (v) => setState(() => _cgv = v)),
      ],
    );
  }
}
