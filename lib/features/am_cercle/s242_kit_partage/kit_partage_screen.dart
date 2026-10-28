import '../am_widgets.dart';

/// 242 · Kit à partager : visuels prêts à poster, primes par publication validée.
class KitPartageScreen extends ConsumerWidget {
  const KitPartageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      header: ScreenHeader(
        title: 'Kit à partager',
        subtitle: 'Poste, fais connaître l’appli, gagne',
        actions: [AmHeaderButton(AppIcons.share, label: 'Partager le kit', onTap: () => context.openScreen('240'))],
      ),
      children: [
        for (var r = 0; r < d.shareKit.length; r += 2) ...[
          Row(
            children: [
              for (var i = r; i < r + 2 && i < d.shareKit.length; i++) ...[
                if (i > r) const SizedBox(width: 10),
                Expanded(child: _KitCard(d.shareKit[i])),
              ],
            ],
          ),
          gap12,
        ],
        AmHeroCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gagne à chaque publication validée',
                style: AppText.h3.copyWith(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Poste le visuel sur tes réseaux, ajoute ton lien de parrainage, puis envoie la preuve. '
                'Le paiement arrive sur ton Mobile Money.',
                style: AppText.small.copyWith(color: Colors.white, fontSize: 12),
              ),
              gap12,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const ShapeDecoration(color: Color(0x33FFFFFF), shape: StadiumBorder()),
                child: Text(
                  'Preuve = capture ou lien de la publication',
                  style: AppText.small.copyWith(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard(this.item);

  final (String, int, String, bool) item;

  @override
  Widget build(BuildContext context) => AmCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    radius: 24,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmPhoto(item.$3, radius: 18, height: 128, children: [if (item.$4) const Center(child: AmPlayButton())]),
        const SizedBox(height: 10),
        Text(item.$1, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            AmChip('+ ${fcfaF(item.$2)}', height: 28, fontSize: 11),
            const Spacer(),
            AmChip('Poster', dark: true, height: 26, fontSize: 11, onTap: () => context.openScreen('250')),
          ],
        ),
      ],
    ),
  );
}
