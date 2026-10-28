import '../../common/common.dart';
import '../ai_widgets.dart';

/// 233 · WhatsApp : suivi de mission avec photo de preuve et réponses rapides.
class WhatsappSuiviScreen extends ConsumerWidget {
  const WhatsappSuiviScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAIDataProvider);
    return AiWhatsAppScaffold(
      messages: d.followUpChat,
      incomingWidth: 300,
      onAction: (context, label) {
        if (label == 'Voir les propositions') {
          context.openScreen('234');
          return true;
        }
        return false;
      },
    );
  }
}
