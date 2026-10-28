import '../l_widgets.dart';

/// 115 · Événements et initiatives du département.
class EvenementsDepartementScreen extends ConsumerWidget {
  const EvenementsDepartementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionLDataProvider);
    return LDepartmentShell(
      title: 'Événements et initiatives',
      selected: 7,
      children: [
        OpsSplit(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpsCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    for (final (i, e) in d.events.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                      IIconRow(
                        icon: e.$3,
                        title: e.$1,
                        subtitle: e.$2,
                        trailing: OpsBadge(e.$4, tone: opsToneOf(e.$5)),
                        onTap: () => context.openScreen('101'),
                      ),
                    ],
                  ],
                ),
              ),
              gap16,
              SizedBox(
                width: 200,
                child: OpsBigButton(
                  label: 'Créer un événement',
                  icon: AppIcons.plus,
                  onTap: () => context.toast('Nouvel événement créé (brouillon).'),
                ),
              ),
            ],
          ),
          right: Column(
            children: [
              for (var r = 0; r < d.eventKpis.length; r += 2) ...[
                if (r > 0) gap12,
                Row(
                  children: [
                    for (final k in d.eventKpis.sublist(r, r + 2)) ...[
                      if (k != d.eventKpis[r]) const SizedBox(width: 12),
                      Expanded(
                        child: OpsCard(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(k.$1, style: AppText.small)),
                                  AppIcon(k.$3, size: 15),
                                ],
                              ),
                              Text(k.$2, style: AppText.h2.copyWith(fontWeight: FontWeight.w700)),
                              if (k.$4.isNotEmpty)
                                Text(k.$4, style: AppText.small.copyWith(color: AppColors.warning, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

