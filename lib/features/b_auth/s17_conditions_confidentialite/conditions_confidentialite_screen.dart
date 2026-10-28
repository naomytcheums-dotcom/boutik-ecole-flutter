import '../auth_common.dart';

/// 17 · Conditions et confidentialité (onglets + consentements).
class ConditionsConfidentialiteScreen extends ConsumerStatefulWidget {
  const ConditionsConfidentialiteScreen({super.key});

  @override
  ConsumerState<ConditionsConfidentialiteScreen> createState() => _ConditionsConfidentialiteScreenState();
}

class _ConditionsConfidentialiteScreenState extends ConsumerState<ConditionsConfidentialiteScreen> {
  int _tab = 0;
  late final _consents = [for (final c in ref.read(sectionBDataProvider).consents) c.$3];
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionBDataProvider);
    return AppScaffold(
      showNav: false,
      header: const TitleHeader('Conditions et confidentialité'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      bottomBar: PrimaryButton(
        label: 'Accepter et continuer',
        onPressed: _accepted ? () => ScreenHeader.back(context) : null,
      ),
      children: [
        Row(
          children: [
            for (final (i, t) in d.termsTabs.indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _tab,
                  child: InkWell(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: i == _tab ? AppColors.ink : Colors.transparent, width: 2)),
                      ),
                      child: Text(
                        t,
                        style: AppText.small.copyWith(
                          color: AppColors.ink,
                          fontWeight: i == _tab ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap16,
        if (_tab < 2)
          for (final t in d.terms) ...[
            Text(t.$1, style: AppText.bodyStrong),
            gap12,
            Text(t.$2, style: AppText.small.copyWith(height: 1.6)),
            gap16,
          ],
        Text('Vos consentements', style: AppText.bodyStrong),
        gap12,
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: Column(
            children: [
              for (final (i, c) in d.consents.indexed)
                ToggleRow(
                  title: c.$1,
                  subtitle: c.$2,
                  value: _consents[i],
                  onChanged: (v) => setState(() => _consents[i] = v),
                ),
            ],
          ),
        ),
        gap12,
        CheckRow(
          label: 'J’ai lu et j’accepte les Conditions d’utilisation et la Politique de confidentialité.',
          value: _accepted,
          onChanged: (v) => setState(() => _accepted = v),
        ),
      ],
    );
  }
}
