import '../../common/common.dart';
import '../f_widgets.dart';

/// 55 · Conversation avec une entreprise partenaire, à propos d'un besoin publié.
class ConversationEntrepriseScreen extends ConsumerWidget {
  const ConversationEntrepriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(sectionFDataProvider).companyChat;
    return FChatView(conversation: c);
  }
}
