import 'package:flutter/services.dart';

import '../u_widgets.dart';

/// 173 · Partager une annonce.
class PartagerScreen extends ConsumerWidget {
  const PartagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(sectionUDataProvider).listing;
    Widget chevron() => const AppIcon(AppIcons.chevronRight, size: 18);
    return CPage(
      title: 'Partager',
      showNav: false,
      children: [
        UListingCard(image: l.darkImage, title: l.title, subtitle: '${fcfa(l.price)} · ${l.link}'),
        const GSectionTitle('Partager via'),
        QCard(
          children: [
            QRow(
              icon: AppIcons.messageCircle,
              title: 'WhatsApp',
              subtitle: 'Envoyer à un contact ou un groupe',
              trailing: chevron(),
              onTap: () => context.toast('Ouverture de WhatsApp…'),
            ),
            QRow(
              icon: AppIcons.mail,
              title: 'E-mail',
              trailing: chevron(),
              onTap: () => context.toast('Ouverture de la messagerie…'),
            ),
            QRow(
              icon: AppIcons.messageSquare,
              title: 'SMS',
              trailing: chevron(),
              onTap: () => context.toast('Ouverture des SMS…'),
            ),
            QRow(
              icon: AppIcons.link,
              title: 'Copier le lien',
              trailing: const GBadge('Copier', Tone.accent),
              onTap: () {
                Clipboard.setData(ClipboardData(text: 'https://${l.link}'));
                context.toast('Lien copié.');
              },
            ),
          ],
        ),
        gap16,
        const GNote('Le lien partagé ouvre directement l’annonce, même sans compte.', icon: AppIcons.link),
        gap16,
        GOutlineButton('Fermer', onPressed: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}
