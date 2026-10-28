import '../../common/common.dart';
import '../ai_widgets.dart';

/// 234 · WhatsApp : validation d'un jalon et libération du paiement en séquestre.
class WhatsappJalonScreen extends ConsumerWidget {
  const WhatsappJalonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAIDataProvider);
    return AiWhatsAppScaffold(
      messages: d.milestoneChat,
      cardBuilder: (context, m) =>
          _MilestoneCard(photo: m.text, title: 'Jalon ${d.milestoneNumber} · ${fcfa(d.milestoneAmount)}'),
    );
  }
}

/// Carte du jalon terminé : visuel, montant, statut du séquestre.
class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.photo, required this.title});

  final String photo;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              photo,
              height: 84,
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Aperçu des propositions de logo',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('Paiement bloqué en séquestre', style: AppText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
