import '../u_widgets.dart';

/// 211 · Passeport du produit (traçabilité et certificat).
class PasseportProduitScreen extends ConsumerWidget {
  const PasseportProduitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionUDataProvider);
    return GPage(
      title: 'Passeport du produit',
      trailing: cIcon(context, AppIcons.share, 'Partager', '173'),
      actions: [PrimaryButton(label: 'Voir le certificat', height: 54, onPressed: () => context.openScreen('212'))],
      children: [
        IHeroBanner(
          image: d.passportImage,
          title: d.listing.title,
          subtitle: 'Certifié par l’IUT de Douala',
          height: 164,
        ),
        gap12,
        KeyValueCard(title: 'Origine', rows: [for (final r in d.origin) KV(r.$1, r.$2)]),
        const GSectionTitle('Étapes de fabrication'),
        IMilestones([for (final s in d.fabrication) IMilestone(s.$1, s.$2, 0)]),
        gap16,
        const GNote(
          'Le certificat est ancré par empreinte numérique ; aucune donnée personnelle n’est publiée.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
