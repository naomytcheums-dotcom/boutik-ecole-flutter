import '../q_widgets.dart';

/// 150 (2/4) · Session expirée (et autres états système).
class SessionExpireeScreen extends StatelessWidget {
  const SessionExpireeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: const QTitle('Session expirée'),
      children: [
        const SizedBox(height: 50),
        QStateView(
          icon: AppIcons.lock,
          title: 'Votre session a expiré',
          message: 'Pour votre sécurité, veuillez vous reconnecter pour continuer.',
          action: 'Se reconnecter',
          onAction: () => context.goScreen('11'),
        ),
        gap16,
        Text('Autres états système', style: AppText.bodyStrong.copyWith(fontSize: 15)),
        gap8,
        QCard(
          children: [
            QRow(
              icon: AppIcons.search,
              title: 'Page introuvable',
              subtitle: 'Erreur 404 · Le lien est invalide',
              onTap: () => context.openScreen('introuvable'),
            ),
            QRow(icon: AppIcons.lock, title: 'Accès refusé', subtitle: 'Erreur 403 · Droits insuffisants'),
          ],
        ),
      ],
    );
  }
}
