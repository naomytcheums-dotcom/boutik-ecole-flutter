import '../u_widgets.dart';

/// 212 · Vérifier un certificat (page publique après scan du QR).
class VerifierCertificatScreen extends ConsumerWidget {
  const VerifierCertificatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    return GPage(
      title: 'Vérifier un certificat',
      showBack: false,
      actions: [PrimaryButton(label: 'Scanner un autre QR', height: 54, onPressed: () => context.openScreen('206'))],
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(12)),
                child: const AppIcon(AppIcons.qrCode, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.certificateId, style: AppText.bodyStrong),
                    Text('Scanné à l’instant', style: AppText.small),
                  ],
                ),
              ),
              const GBadge('Authentique', Tone.success),
            ],
          ),
        ),
        gap12,
        IHeroBanner(
          image: d.passportImage,
          title: d.listing.title,
          subtitle: 'Émis par l’IUT de Douala · GC',
          height: 160,
        ),
        gap12,
        KeyValueCard(title: 'Résultat de la vérification', rows: [for (final r in d.verification) KV(r.$1, r.$2)]),
        gap16,
        const GNote(
          'Cette page est publique : n’importe qui peut vérifier l’authenticité en scannant le QR code.',
          icon: AppIcons.circleCheck,
        ),
      ],
    );
  }
}
