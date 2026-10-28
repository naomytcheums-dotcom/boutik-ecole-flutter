import '../h_widgets.dart';

/// 73 · Mes documents (CV, diplômes, attestations, certifications).
class MesDocumentsScreen extends ConsumerStatefulWidget {
  const MesDocumentsScreen({super.key});

  @override
  ConsumerState<MesDocumentsScreen> createState() => _MesDocumentsScreenState();
}

class _MesDocumentsScreenState extends ConsumerState<MesDocumentsScreen> {
  int _tab = 0;

  void _upload() => context.toast('Choisissez un fichier PDF, JPG ou PNG (5 Mo max).');

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionHDataProvider);
    final items = d.documents.where((x) => _tab == 0 || x.type == d.documentTabs[_tab]).toList();
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: HHeader(
        'Mes documents',
        trailing: HHeaderAction(AppIcons.plus, label: 'Ajouter un document', onTap: _upload),
      ),
      children: [
        HChips(labels: d.documentTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        const SizedBox(height: 9),
        if (items.isEmpty)
          const HEmpty('Aucun document dans cette catégorie.')
        else
          HListCard(
            indent: 52,
            children: [
              for (final doc in items)
                HRow(
                  leading: HIconTile(doc.icon),
                  title: doc.name,
                  subtitle: doc.detail,
                  trailing: doc.status == HDocStatus.verified
                      ? const HBadge('Vérifié', HBadgeKind.success)
                      : const HBadge('En attente', HBadgeKind.pending),
                  onTap: () => context.toast('Aperçu de « ${doc.name} »'),
                ),
            ],
          ),
        gap16,
        PrimaryButton(label: 'Téléverser un document', icon: AppIcons.upload, height: 50, onPressed: _upload),
        gap16,
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.shieldCheck, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Les documents vérifiés affichent un badge de confiance sur votre profil.',
                  style: AppText.small.copyWith(fontSize: 12.5, color: const Color(0xFF4A4752)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
