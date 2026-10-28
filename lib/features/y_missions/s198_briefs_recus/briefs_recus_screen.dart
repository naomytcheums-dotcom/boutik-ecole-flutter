import '../y_web.dart';

const _needColor = Color(0xFF3D4A6B);

/// 198 · Briefs reçus (web admin) : indicateurs et boîte de réception des besoins clients.
class BriefsRecusScreen extends ConsumerStatefulWidget {
  const BriefsRecusScreen({super.key});

  @override
  ConsumerState<BriefsRecusScreen> createState() => _BriefsRecusScreenState();
}

class _BriefsRecusScreenState extends ConsumerState<BriefsRecusScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    // « Nouveaux » regroupe tous les briefs non encore attribués (y compris ceux à qualifier).
    final briefs = switch (_tab) {
      0 || 1 => d.briefs,
      2 => d.briefs.where((b) => b.$6 == 'À qualifier').toList(),
      _ => const <(String, String, int, int, String, String)>[],
    };
    return YAdminShell(
      title: 'Briefs reçus',
      selected: 1,
      children: [
        YWebKpiRow([for (final (l, v, c) in d.briefKpis) YWebKpi(label: l, value: v, bar: Color(c))]),
        const SizedBox(height: 18),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 162,
              child: Semantics(
                header: true,
                child: Text('Boîte de réception', style: AppText.h3.copyWith(fontSize: 16)),
              ),
            ),
            _Chips(labels: d.briefTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
          ],
        ),
        const SizedBox(height: 16),
        if (briefs.isEmpty)
          YWebCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const AppIcon(AppIcons.inbox, size: 28, color: AppColors.textSecondary),
                const SizedBox(height: 10),
                Text('Aucun devis envoyé en attente de réponse.', style: AppText.secondary),
              ],
            ),
          )
        else
          for (final b in briefs) ...[_BriefCard(brief: b), const SizedBox(height: 14)],
      ],
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final (i, l) in labels.indexed)
        Semantics(
          button: true,
          selected: i == selected,
          child: GestureDetector(
            onTap: () => onSelected(i),
            child: SizedBox(
              height: 44,
              child: Center(
                widthFactor: 1,
                child: Container(
                  width: 97,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: i == selected ? AppColors.ink : const Color(0xFFEDEBF3),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    l,
                    style: AppText.small.copyWith(
                      fontSize: 12.5,
                      color: i == selected ? Colors.white : const Color(0xFF4A4752),
                      fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _BriefCard extends StatelessWidget {
  const _BriefCard({required this.brief});

  final (String, String, int, int, String, String) brief;

  @override
  Widget build(BuildContext context) {
    final (client, need, min, max, fields, status) = brief;
    return YWebCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 640;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client, style: AppText.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(need, style: AppText.body.copyWith(fontSize: 13.5, color: _needColor)),
              const SizedBox(height: 8),
              Text(
                'Budget $min–$max k FCFA · filières suggérées : $fields',
                style: AppText.small.copyWith(fontSize: 12.5),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              YWebButton('Qualifier', width: 110, onTap: () => context.toast('$client : brief à qualifier.')),
              const SizedBox(width: 10),
              YWebButton('Attribuer', width: 124, dark: true, onTap: () => context.openScreen('199')),
            ],
          );
          final badge = YWebBadge(status, tone: status == 'Nouveau' ? Tone.accent : Tone.warning);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [badge, const SizedBox(height: 8), info, const SizedBox(height: 12), actions],
            );
          }
          return SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 156),
                Expanded(
                  child: Padding(padding: const EdgeInsets.only(top: 2), child: info),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [badge, actions],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
