import '../../common/common.dart';

/// 282 · QR de transfert (borne → téléphone), signé, valable 5 minutes, usage unique.
/// Le QR est ici un visuel de démonstration ; la signature réelle est côté serveur (docs/BACKEND_PLAN.md).
class QrTransfertScreen extends ConsumerWidget {
  const QrTransfertScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'QR de transfert',
      subtitle: d.qrKiosk,
      action: 'Programmer l’événement',
      onAction: () => context.toast('Événement programmé.'),
      children: [
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            alignment: Alignment.center,
            child: const ChromeIcon(AppIcons.qrCode, size: 120, semanticLabel: 'QR code de transfert du panier'),
          ),
        ),
        gap16,
        Text('Expire dans ${d.qrExpiry}', style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Signé · valable 5 minutes · usage unique', style: AppText.secondary, textAlign: TextAlign.center),
        gap16,
        KeyValueCard(rowGap: 12, rows: [for (final v in d.qrSecurity) kvOf(v)]),
        gap16,
        KeyValueCard(title: 'Mode événement programmable', rowGap: 12, rows: [for (final v in d.qrEvent) kvOf(v)]),
      ],
    );
  }
}
