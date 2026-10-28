import '../../common/common.dart';

/// 283 · Registre des certificats (émission réservée aux rôles autorisés).
class RegistreCertificatsScreen extends ConsumerWidget {
  const RegistreCertificatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(nouveauxDataProvider).certificates;
    return DetailScreen(
      title: 'Registre des certificats',
      subtitle: 'Émission réservée aux rôles autorisés',
      action: 'Émettre un certificat',
      onAction: () => context.openScreen('174'),
      children: [
        const HeroMessage(icon: AppIcons.award, iconSize: 60),
        gap16,
        for (final c in certs) ...[
          AppCard(
            onTap: () => context.openScreen('173'),
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(c.title, style: AppText.bodyStrong)),
                    const SizedBox(width: 8),
                    Text(c.status, style: AppText.label.copyWith(color: toneToColor(c.tone))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(c.detail, style: AppText.secondary),
                const SizedBox(height: 4),
                Text('Journalisé · empreinte SHA-256 ancrée', style: AppText.small),
              ],
            ),
          ),
          gap12,
        ],
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Émission journalisée', style: AppText.bodyStrong),
              const SizedBox(height: 4),
              Text(
                'Chaque émission, remplacement ou révocation enregistre l’auteur, la date et le motif.',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
