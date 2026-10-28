import '../g_widgets.dart';

/// 69 · Validations (conformité du compte vendeur et justificatifs).
class ValidationsScreen extends ConsumerWidget {
  const ValidationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionGDataProvider);
    final next = d.documents.where((x) => x.target != null).firstOrNull;
    return GPage(
      title: 'Validations',
      actions: [
        PrimaryButton(label: 'Compléter mon dossier', height: 54, onPressed: () => context.openScreen(next?.target ?? '18c')),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GGauge(percent: d.compliancePercent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conformité du compte', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${d.validatedDocuments} justificatifs sur ${d.documents.length} validés', style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap12,
        GListCard(
          children: [
            for (final doc in d.documents)
              InkWell(
                onTap: doc.target == null ? null : () => context.openScreen(doc.target!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFF2F0F5), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: AppIcon(doc.icon, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.title, style: AppText.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                            Text(doc.detail, style: AppText.small.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      GBadge(doc.status, doc.tone),
                    ],
                  ),
                ),
              ),
          ],
        ),
        gap16,
        const GNote('Un compte conforme permet de recevoir vos paiements sans délai.', icon: AppIcons.shieldCheck),
      ],
    );
  }
}