import '../../l_departement/l_widgets.dart' show lBadge, OpsSplit;
import '../t_widgets.dart';

/// 168 · Publier un concours (web, organisateur partenaire).
class PublierConcoursScreen extends ConsumerWidget {
  const PublierConcoursScreen({super.key});

  static const nav = [
    WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '262', section: 'Principal'),
    WebNavItem('Mes concours', AppIcons.trophy, target: '168', section: 'Principal'),
    WebNavItem('Inscriptions', AppIcons.users, target: '158', section: 'Principal'),
    WebNavItem('Jury et mentors', AppIcons.award, target: '167', section: 'Principal'),
    WebNavItem('Résultats', AppIcons.chartColumn, target: '166', section: 'Gestion'),
    WebNavItem('Communication', AppIcons.mail, target: '265', section: 'Gestion'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionTDataProvider);
    Widget field(String label, String value, String icon) =>
        TextFieldWithError(label: label, initialValue: value, prefixIcon: icon);
    return WebShell(
      title: 'Publier un concours',
      subtitle: 'Vue d’ensemble · mise à jour aujourd’hui',
      navItems: nav,
      selected: 1,
      accountName: d.organizer,
      accountSubtitle: d.organizerRole,
      children: [
        OpsSplit(
          left: field('Titre du concours', d.draft.title, AppIcons.trophy),
          right: field('Date limite d’inscription', d.draft.deadline, AppIcons.calendar),
        ),
        gap12,
        OpsSplit(
          left: field('Lieu', d.draft.place, AppIcons.mapPin),
          right: field('Dotation (FCFA)', d.draft.prize, AppIcons.wallet),
        ),
        gap12,
        const TextFieldWithError(
          label: 'Description et règlement',
          hint: 'Thématique, critères d’évaluation, conditions de participation…',
          maxLines: 3,
        ),
        gap16,
        OpsSplit(
          left: OpsCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (final (i, j) in d.jury.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                  GThumbRow(image: j.$3, title: j.$1, subtitle: j.$2, trailing: lBadge(j.$4, j.$5)),
                ],
              ],
            ),
          ),
          right: const OpsInfoNote('Un concours publié est relu par l’IUT avant sa diffusion aux étudiants.'),
        ),
        gap16,
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 300,
            child: OpsBigButton(
              label: 'Soumettre pour validation',
              icon: AppIcons.send,
              onTap: () => context.toast('Concours soumis pour validation.'),
            ),
          ),
        ),
      ],
    );
  }
}
