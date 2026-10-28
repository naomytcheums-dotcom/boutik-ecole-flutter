import '../t_concours/t_widgets.dart';

export '../../data/demo/section_u_demo.dart';
export '../t_concours/t_widgets.dart';

/// Barre latérale de l'administration des missions et des certificats (213).
const uAdminNav = [
  WebNavItem('Tableau de bord', AppIcons.layoutGrid, target: '262', section: 'Principal'),
  WebNavItem('Briefs reçus', AppIcons.fileText, target: '198', section: 'Principal'),
  WebNavItem('Attribution', AppIcons.users, target: '199', section: 'Principal'),
  WebNavItem('Missions', AppIcons.layers, target: '200', section: 'Principal'),
  WebNavItem('Paiements et séquestre', AppIcons.wallet, target: '140', section: 'Gestion'),
  WebNavItem('Commissions', AppIcons.percent, target: '135', section: 'Gestion'),
  WebNavItem('Litiges', AppIcons.triangleAlert, target: '133', section: 'Gestion'),
  WebNavItem('Certificats', AppIcons.circleCheck, target: '213', section: 'Gestion'),
];

/// Couleur des barres d'indicateurs (décoratives, sans texte posé dessus).
Color uToneColor(Tone tone) => switch (tone) {
  Tone.success => const Color(0xFF1E9E6A),
  Tone.accent => const Color(0xFF244884),
  Tone.warning => const Color(0xFFD98A00),
  Tone.error => const Color(0xFFE5484D),
  Tone.neutral => AppColors.textSecondary,
};

/// Indicateurs web soulignés d'une barre de couleur (213).
class UKpiBars extends StatelessWidget {
  const UKpiBars(this.items, {super.key});

  final List<(String, String, Tone)> items;

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      columns: items.length,
      minItemWidth: 150,
      children: [
        for (final k in items)
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.$1, style: AppText.small.copyWith(color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(k.$2, style: AppText.amount.copyWith(fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(color: uToneColor(k.$3), borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Carte « annonce » : vignette + titre + détail.
class UListingCard extends StatelessWidget {
  const UListingCard({super.key, required this.image, required this.title, required this.subtitle});

  final String image;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: GThumbRow(image: image, title: title, subtitle: subtitle, thumb: 54),
    );
  }
}
