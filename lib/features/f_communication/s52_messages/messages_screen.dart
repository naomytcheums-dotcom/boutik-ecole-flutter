import '../../common/common.dart';
import '../f_widgets.dart';

/// 52 · Messages : recherche et liste des conversations.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String _query = '';
  final _opened = <String>{};

  bool _matches(FConversation c) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || c.name.toLowerCase().contains(q) || c.preview.toLowerCase().contains(q);
  }

  void _open(FConversation c) {
    setState(() => _opened.add(c.id));
    if (c.screen != null) {
      context.openScreen(c.screen!);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FChatView(conversation: c)));
    }
  }

  void _compose(List<FConversation> all) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(header: true, child: Text('Nouveau message', style: FTxt.section)),
            ),
            for (final c in all)
              FRow(
                leftPadding: 24,
                leading: c.avatar == null ? null : FPhoto(c.avatar!, round: true, alignment: c.avatarAlignment),
                title: c.name,
                subtitle: c.status,
                onTap: () {
                  Navigator.pop(sheet);
                  _open(c);
                },
              ),
            gap8,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionFDataProvider);
    final list = d.conversations.where(_matches).toList();
    return FScaffold(
      title: 'Messages',
      showNav: true,
      trailing: FHeaderButton(AppIcons.pencil, label: 'Nouveau message', onTap: () => _compose(d.conversations)),
      children: [
        const SizedBox(height: 2),
        FSearchField(hint: 'Rechercher une conversation', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 14),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                const ChromeIcon(AppIcons.messageCircle, size: 72),
                gap16,
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text('Aucune conversation trouvée', style: FTxt.section),
                ),
                gap8,
                Text('Vérifiez l’orthographe ou essayez un autre nom.', style: FTxt.body, textAlign: TextAlign.center),
              ],
            ),
          )
        else
          FCardList(
            dividerIndent: 74,
            children: [
              for (final c in list)
                Builder(
                  builder: (context) {
                    final unread = _opened.contains(c.id) ? 0 : c.unread;
                    return FRow(
                      leading: c.avatar == null ? null : FPhoto(c.avatar!, round: true, alignment: c.avatarAlignment),
                      title: c.name,
                      subtitle: c.preview,
                      semanticLabel: unread > 0
                          ? '$unread message${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''}'
                          : null,
                      trailing: unread > 0
                          ? FBadge('$unread', height: 22, padding: 4, style: FTxt.badge.copyWith(fontSize: 12))
                          : null,
                      chevron: unread == 0,
                      onTap: () => _open(c),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}
