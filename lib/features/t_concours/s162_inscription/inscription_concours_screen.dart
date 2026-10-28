import '../t_widgets.dart';

/// 162 · Inscription d’une équipe à un concours.
class InscriptionConcoursScreen extends ConsumerStatefulWidget {
  const InscriptionConcoursScreen({super.key});

  @override
  ConsumerState<InscriptionConcoursScreen> createState() => _InscriptionConcoursScreenState();
}

class _InscriptionConcoursScreenState extends ConsumerState<InscriptionConcoursScreen> {
  late final d = ref.read(sectionTDataProvider);
  int _mode = 1;
  late String _theme = d.themes.first;
  bool _accepted = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return GPage(
      title: 'Inscription',
      actions: [
        GOutlineButton('Retour', onPressed: () => ScreenHeader.back(context)),
        PrimaryButton(
          label: 'Valider l’inscription',
          height: 54,
          onPressed: () {
            setState(() => _submitted = true);
            if (_accepted) context.openScreen('164');
          },
        ),
      ],
      children: [
        GStepper(labels: d.registrationSteps, current: 1),
        gap12,
        Row(
          children: [
            for (final (i, t) in ['Individuelle', 'En équipe'].indexed)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == _mode,
                  child: InkWell(
                    onTap: () => setState(() => _mode = i),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: i == _mode ? AppColors.accent : Colors.transparent, width: 2),
                        ),
                      ),
                      child: Text(
                        t,
                        style: AppText.small.copyWith(
                          color: AppColors.ink,
                          fontWeight: i == _mode ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        gap12,
        if (_mode == 1) ...[
          TextFieldWithError(label: 'Nom de l’équipe', initialValue: d.teamName, prefixIcon: AppIcons.users),
          gap12,
          GListCard(
            children: [
              for (final m in d.teamMembers)
                GThumbRow(image: m.$3, title: m.$1, subtitle: m.$2, trailing: GBadge(m.$4, m.$5)),
            ],
          ),
          gap12,
        ],
        SelectField(
          label: 'Thématique',
          icon: AppIcons.lightbulb,
          options: d.themes,
          value: _theme,
          onChanged: (v) => setState(() => _theme = v),
        ),
        gap8,
        CheckRow(
          label: 'J’accepte le règlement du concours.',
          value: _accepted,
          onChanged: (v) => setState(() => _accepted = v),
        ),
        if (_submitted && !_accepted)
          Text(
            'Vous devez accepter le règlement pour vous inscrire.',
            style: AppText.small.copyWith(color: AppColors.error),
          ),
      ],
    );
  }
}
