import '../../common/common.dart';
import '../f_widgets.dart';

/// 54 · Conversation liée à une commande (article prêt au retrait).
class ConversationCommandeScreen extends ConsumerWidget {
  const ConversationCommandeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sectionFDataProvider).orderChat;
    return FChatView(conversation: c, onOpenCard: () => context.openScreen(c.card!.target!));
  }
}
