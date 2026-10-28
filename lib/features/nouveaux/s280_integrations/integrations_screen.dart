import '../../common/common.dart';

/// 280 · Intégrations (API publique, clés, webhooks) — réservé aux administrateurs.
class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    Widget listCard(String title, List<StatusItem> items, {bool action = false}) => AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
          gap8,
          for (final it in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.title, style: AppText.bodyStrong),
                        Text(it.detail, style: AppText.small, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  action
                      ? TextLink(it.status, color: toneToColor(it.tone), onTap: () => context.toast('Clé « ${it.title} » révoquée.'))
                      : Text(it.status, style: AppText.label.copyWith(color: toneToColor(it.tone))),
                ],
              ),
            ),
        ],
      ),
    );
    return DetailScreen(
      title: 'Intégrations',
      subtitle: 'Réservé aux administrateurs',
      action: 'Créer une clé',
      onAction: () => context.toast('Nouvelle clé créée (affichée une seule fois).'),
      children: [
        const HeroMessage(icon: AppIcons.keyRound, iconSize: 60),
        gap16,
        KeyValueCard(title: 'API publique', rowGap: 12, rows: [for (final v in d.api) kvOf(v)]),
        gap16,
        listCard('Clés d’intégration', d.apiKeys, action: true),
        gap16,
        listCard('Webhooks', d.webhooks),
      ],
    );
  }
}
