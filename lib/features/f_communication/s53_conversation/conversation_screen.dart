import '../../common/common.dart';
import '../f_widgets.dart';

/// 53 · Conversation avec un vendeur, à propos d'un article.
class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sectionFDataProvider).productChat;
    return FChatView(
      conversation: c,
      trailing: FHeaderButton(
        AppIcons.smartphone,
        label: 'Appeler ${c.name}',
        onTap: () => context.toast('Appel de ${c.name}…'),
      ),
      onOpenCard: () => context.openScreen(c.card!.target!),
    );
  }
}
