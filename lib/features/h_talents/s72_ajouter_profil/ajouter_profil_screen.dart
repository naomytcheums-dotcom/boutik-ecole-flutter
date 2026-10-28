import '../../../core/utils/validators_h.dart';
import '../h_widgets.dart';

/// 72 · Ajouter à mon profil (compétence, expérience ou réalisation).
class AjouterProfilScreen extends ConsumerStatefulWidget {
  const AjouterProfilScreen({super.key});

  @override
  ConsumerState<AjouterProfilScreen> createState() => _AjouterProfilScreenState();
}

class _AjouterProfilScreenState extends ConsumerState<AjouterProfilScreen> {
  final _form = GlobalKey<FormState>();
  int _tab = 2;
  late String _category = ref.read(sectionHDataProvider).achievementCategories.first;
  String _level = 'Intermédiaire';
  int _medias = 0;

  void _submit() {
    if (!_form.currentState!.validate()) return;
    context.toast(_tab == 2 ? 'Réalisation ajoutée à votre portfolio.' : 'Élément ajouté à votre profil.');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionHDataProvider);
    return Form(
      key: _form,
      child: HPage(
        title: 'Ajouter à mon profil',
        actions: [
          PrimaryButton(
            label: _tab == 2 ? 'Ajouter à mon portfolio' : 'Ajouter à mon profil',
            height: 54,
            onPressed: _submit,
          ),
        ],
        children: [
          _UnderlineTabs(labels: d.profileTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
          const SizedBox(height: 18),
          ...switch (_tab) {
            0 => _skill(d),
            1 => _experience(),
            _ => _achievement(d),
          },
        ],
      ),
    );
  }

  List<Widget> _achievement(SectionHData d) => [
    PillTextField(
      key: const ValueKey('achievement-title'),
      label: 'Titre de la réalisation',
      icon: AppIcons.pencil,
      initialValue: d.achievementTitle,
      validator: (v) => ValidatorsH.heading(v, 'Le titre'),
    ),
    gap16,
    PillSelectField(
      label: 'Catégorie',
      icon: AppIcons.layoutGrid,
      options: d.achievementCategories,
      value: _category,
      onChanged: (v) => setState(() => _category = v),
    ),
    gap16,
    PillTextField(label: 'Date', icon: AppIcons.calendar, initialValue: d.achievementDate),
    gap16,
    const PillTextField(
      key: ValueKey('achievement-description'),
      label: 'Description',
      hint: 'Contexte, rôle, résultats obtenus…',
      maxLines: 3,
      minHeight: 96,
      validator: ValidatorsH.description,
    ),
    const SizedBox(height: 14),
    AppCard(
      onTap: () => setState(() => _medias = (_medias + 1).clamp(0, d.maxMedias)),
      padding: const EdgeInsets.fromLTRB(12, 12.5, 16, 12.5),
      child: Row(
        children: [
          const HIconTile(AppIcons.image, color: hLavender),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _medias == 0
                      ? 'Ajouter des médias'
                      : '$_medias média${_medias > 1 ? 's' : ''} ajouté${_medias > 1 ? 's' : ''}',
                  style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('Photos, captures, vidéo (${d.maxMedias} max)', style: AppText.small.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          const AppIcon(AppIcons.chevronRight, size: 18),
        ],
      ),
    ),
  ];

  List<Widget> _skill(SectionHData d) => [
    PillTextField(
      key: const ValueKey('skill-name'),
      label: 'Compétence',
      icon: AppIcons.sparkles,
      hint: 'Ex. React, montage vidéo…',
      validator: (v) => ValidatorsH.heading(v, 'La compétence'),
    ),
    gap16,
    PillSelectField(
      label: 'Niveau',
      icon: AppIcons.gauge,
      options: const ['Débutant', 'Intermédiaire', 'Avancé', 'Expert'],
      value: _level,
      onChanged: (v) => setState(() => _level = v),
    ),
    gap16,
    PillSelectField(
      label: 'Catégorie',
      icon: AppIcons.layoutGrid,
      options: d.achievementCategories,
      value: _category,
      onChanged: (v) => setState(() => _category = v),
    ),
  ];

  List<Widget> _experience() => [
    PillTextField(
      key: const ValueKey('experience-role'),
      label: 'Poste occupé',
      icon: AppIcons.briefcase,
      hint: 'Ex. Stagiaire développeur',
      validator: (v) => ValidatorsH.heading(v, 'Le poste'),
    ),
    gap16,
    PillTextField(
      key: const ValueKey('experience-company'),
      label: 'Entreprise',
      icon: AppIcons.building2,
      hint: 'Ex. Orange Cameroun',
      validator: (v) => ValidatorsH.heading(v, 'L’entreprise'),
    ),
    gap16,
    const PillTextField(label: 'Période', icon: AppIcons.calendar, hint: 'Ex. Juin – Août 2026'),
    gap16,
    const PillTextField(label: 'Missions', hint: 'Missions, outils, résultats…', maxLines: 3, minHeight: 96),
  ];
}

/// Onglets texte soulignés d'un trait violet sous l'onglet actif.
class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x80FFFFFF))),
      ),
      child: Row(
        children: [
          for (final (i, l) in labels.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: SizedBox(
                    height: 42,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l,
                          style: AppText.body.copyWith(
                            fontSize: 14.5,
                            color: i == selected ? AppColors.ink : const Color(0xFF66636E),
                            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 80,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == selected ? const Color(0xFF6A4DFF) : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
