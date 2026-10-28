import '../../common/common.dart';
import '../f_widgets.dart';

/// 50 · Notifications : filtres par catégorie, groupes « Aujourd’hui » / « Plus tôt », tout marquer comme lu.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filter = 0;
  final _read = <String>{};

  // Largeurs des pastilles relevées sur la maquette (le texte reste centré).
  static const _chipWidths = [70.0, 92.5, 85.0, 99.5];

  bool _matches(FNotification n) => switch (_filter) {
    1 => n.kind == FNotifKind.orders,
    2 => n.kind == FNotifKind.messages,
    3 => n.kind == FNotifKind.promotions,
    _ => true,
  };

  void _open(FNotification n) {
    setState(() => _read.add(n.id));
    if (n.target != null) context.openScreen(n.target!);
  }

  Widget _group(List<FNotification> items) => FCardList(
    dividerIndent: 64,
    children: [
      for (final n in items)
        FRow(
          leading: FTile(n.icon, color: n.iconColor ?? AppColors.ink),
          title: n.title,
          subtitle: n.subtitle,
          semanticLabel: n.isNew && !_read.contains(n.id) ? 'Nouveau' : null,
          trailing: n.isNew && !_read.contains(n.id) ? const FBadge('Nouveau', padding: 9.2) : null,
          trailingGap: 0,
          chevron: !n.isNew || _read.contains(n.id),
          onTap: () => _open(n),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionFDataProvider);
    final list = d.notifications.where(_matches).toList();
    final today = list.where((n) => n.today).toList();
    final earlier = list.where((n) => !n.today).toList();
    final unread = d.notifications.any((n) => n.isNew && !_read.contains(n.id));
    return FScaffold(
      title: 'Notifications',
      showNav: true,
      trailing: FHeaderButton(
        AppIcons.sun,
        label: 'Paramètres des notifications',
        onTap: () => context.openScreen('56'),
      ),
      children: [
        Transform.translate(
          offset: const Offset(0, -3),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final (i, f) in d.notifFilters.indexed) ...[
                  if (i > 0) const SizedBox(width: 8.5),
                  FChip(
                    label: f,
                    selected: i == _filter,
                    minWidth: i < _chipWidths.length ? _chipWidths[i] : 0,
                    onTap: () => setState(() => _filter = i),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (list.isEmpty) ...[const SizedBox(height: 60), const _EmptyState()],
        if (today.isNotEmpty) ...[
          Transform.translate(
            offset: const Offset(0, -6),
            child: FSectionTitle(
              'Aujourd’hui',
              action: 'Tout lire',
              onAction: unread
                  ? () {
                      setState(() => _read.addAll(d.notifications.map((n) => n.id)));
                      context.toast('Toutes les notifications sont marquées comme lues.');
                    }
                  : null,
            ),
          ),
          _group(today),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 13.5),
          const SizedBox(height: 22, child: FSectionTitle('Plus tôt')),
          const SizedBox(height: 16.5),
          _group(earlier),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ChromeIcon(AppIcons.bell, size: 72),
        gap16,
        Semantics(header: true, child: Text('Aucune notification', style: FTxt.section)),
        gap8,
        Text('Vous êtes à jour dans cette catégorie.', style: FTxt.body, textAlign: TextAlign.center),
      ],
    );
  }
}
