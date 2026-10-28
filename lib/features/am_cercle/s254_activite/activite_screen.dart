import '../am_widgets.dart';

/// 254 · Activité : rappel intelligent de Kéla et notifications du cercle.
class ActiviteScreen extends ConsumerStatefulWidget {
  const ActiviteScreen({super.key});

  @override
  ConsumerState<ActiviteScreen> createState() => _ActiviteScreenState();
}

class _ActiviteScreenState extends ConsumerState<ActiviteScreen> {
  int _filter = 0;

  bool _visible(AmActivity a) => switch (_filter) {
    1 => a.icon == 'userPlus',
    2 => a.icon == 'eye',
    3 => a.icon == 'radio',
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final today = d.today.where(_visible).toList();
    final yesterday = d.yesterday.where(_visible).toList();
    return AppScaffold(
      tab: NavTab.home,
      padding: EdgeInsets.zero,
      header: AmRootHeader(
        'Activité',
        actions: [AmHeaderButton(AppIcons.bell, label: 'Réglages des notifications', onTap: () {})],
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Row(
            children: [
              for (var i = 0; i < d.activityFilters.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Pill(
                  d.activityFilters[i],
                  dense: true,
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white),
                  gradient: const LinearGradient(colors: [Color(0xFFE9E4FA), Color(0xFFF2EEFB)]),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(image: d.kelaAvatar, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kéla · rappel intelligent',
                                style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.only(right: 50),
                                child: Text(d.kelaTip, style: AppText.small.copyWith(fontSize: 11.5)),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      bottom: -9,
                      child: AmChip('Programmer', dark: true, height: 26, onTap: () => context.openScreen('250')),
                    ),
                  ],
                ),
              ),
              if (today.isNotEmpty) ...[
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text('Aujourd’hui', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                ),
                gap8,
                for (final a in today) _ActivityRow(a),
              ],
              if (yesterday.isNotEmpty) ...[
                const SizedBox(height: 10),
                Semantics(
                  header: true,
                  child: Text('Hier', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                ),
                gap8,
                for (final a in yesterday) _ActivityRow(a),
              ],
              if (today.isEmpty && yesterday.isEmpty) ...[
                gap16,
                const InfoNote('Aucune activité dans cette catégorie pour le moment.', icon: AppIcons.bell),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.a);

  final AmActivity a;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AmCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Avatar(image: a.avatar, size: 40),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: AppIcon(amIcon(a.icon), size: 9, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.text, style: AppText.bodyStrong.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(a.time, style: AppText.small.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AmChip(a.action, height: 26, fontSize: 11, onTap: () => context.openScreen(a.target)),
        ],
      ),
    ),
  );
}
