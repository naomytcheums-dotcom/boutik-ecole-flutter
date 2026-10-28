import '../../common/common.dart';
import '../s262_accueil_b2b/web_blocks.dart';

/// 265 · Modèles de notifications (email, SMS, WhatsApp, push).
class ModelesNotificationsScreen extends ConsumerWidget {
  const ModelesNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return WebShell(
      title: 'Modèles de notifications',
      subtitle: 'Messages envoyés par email, SMS et WhatsApp.',
      navItems: adminNav([
        ('Tableau de bord', AppIcons.layoutGrid, '127'),
        ('Modèles', AppIcons.bell, '265'),
        ('Canaux', AppIcons.refreshCw, null),
        ('Historique', AppIcons.history, null),
      ]),
      selected: 1,
      children: [
        TwoColumns(
          flex: (3, 2),
          left: WebTable(
            title: 'Modèles',
            columns: const ['Modèle', 'Canal', 'Langue', 'Statut'],
            flex: const [5, 3, 2, 2],
            rows: [
              for (final t in d.notificationTemplates) [Cell(t.$1, strong: true), Cell(t.$2), Cell(t.$3), Cell(t.$4)],
            ],
          ),
          right: WebPanel(
            title: 'Aperçu : Paiement échoué',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2D9), borderRadius: BorderRadius.circular(16)),
                  child: Text(d.templatePreview, style: AppText.body.copyWith(fontWeight: FontWeight.w400)),
                ),
                gap16,
                Text('Variables : {prénom} {montant} {numéro} {lien}', style: AppText.small),
                gap24,
                PrimaryButton(label: 'Modifier le modèle', expand: false, height: 44, onPressed: () => context.toast('Édition du modèle.')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
