import '../../data/demo/section_s_demo.dart';
import '../q_parametres/q_widgets.dart';

export '../../data/demo/section_s_demo.dart';
export '../q_parametres/q_widgets.dart';

/// Carte bleu nuit de l’assistante IA : titre, texte, puces.
class SAiCard extends StatelessWidget {
  const SAiCard({
    super.key,
    required this.title,
    this.text,
    this.bullets = const [],
    this.avatar,
    this.subtitle,
  });

  final String title;
  final String? text;
  final List<String> bullets;
  final String? avatar;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [Color(0xFF1B2D5A), Color(0xFF243F7A)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (avatar != null)
                CircleAvatar(radius: 12, backgroundImage: AssetImage(avatar!))
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const AppIcon(AppIcons.sparkles, size: 14),
                ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppText.bodyStrong.copyWith(color: Colors.white))),
            ],
          ),
          if (text != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(text!, style: AppText.small.copyWith(color: const Color(0xFFDCE3F5), fontSize: 11.5)),
            ),
          ],
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 6),
              child: Row(
                children: [
                  const StatusDot(Colors.white, size: 5),
                  const SizedBox(width: 12),
                  Expanded(child: Text(b, style: AppText.small.copyWith(color: Colors.white, fontSize: 11.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste de lignes d’opportunités / alertes (pictogramme, titre, détail, badge).
class SItemList extends StatelessWidget {
  const SItemList(this.items, {super.key, this.chevron = false});

  final List<SItem> items;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return QCard(
      children: [
        for (final i in items)
          QRow(
            icon: i.icon,
            title: i.title,
            subtitle: i.detail,
            trailing: i.badge.isEmpty ? const AppIcon(AppIcons.chevronRight, size: 18) : GBadge(i.badge, i.tone),
            onTap: i.target == null ? null : () => context.openScreen(i.target!),
          ),
      ],
    );
  }
}
