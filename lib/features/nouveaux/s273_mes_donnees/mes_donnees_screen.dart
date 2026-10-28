import '../../common/common.dart';

/// 273 · Mes données (export et suppression de compte).
class MesDonneesScreen extends ConsumerWidget {
  const MesDonneesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(nouveauxDataProvider);
    return DetailScreen(
      title: 'Mes données',
      subtitle: 'Confidentialité et droits',
      children: [
        const HeroMessage(
          icon: AppIcons.download,
          title: 'Vous gardez le contrôle',
          message: 'Téléchargez ou supprimez vos données à tout moment.',
        ),
        gap24,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exporter mes données', style: AppText.h3),
              const SizedBox(height: 6),
              Text('Profil, projets, commandes, messages · ZIP + JSON', style: AppText.small),
              Text('Prêt sous 24 h · lien envoyé par e-mail', style: AppText.small),
              gap12,
              PrimaryButton(
                label: 'Demander l’export',
                expand: false,
                height: 44,
                onPressed: () => context.toast('Export demandé : lien envoyé par e-mail sous 24 h.'),
              ),
            ],
          ),
        ),
        gap16,
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supprimer mon compte', style: AppText.h3.copyWith(color: AppColors.error)),
              const SizedBox(height: 6),
              Text(
                'Délai de rétractation de 30 jours. Les certificats émis et les factures sont conservés (obligation légale).',
                style: AppText.small,
              ),
              gap16,
              _OutlineDanger(onTap: () => _confirmDelete(context)),
            ],
          ),
        ),
        gap24,
        Text(d.lastExport, style: AppText.small),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text('Votre compte sera supprimé dans 30 jours. Vous pouvez annuler pendant ce délai.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true && context.mounted) context.toast('Suppression programmée dans 30 jours.');
  }
}

class _OutlineDanger extends StatelessWidget {
  const _OutlineDanger({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.error, width: 1.4)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text('Supprimer le compte', style: AppText.label.copyWith(color: AppColors.error, fontSize: 14)),
            ),
          ),
        ),
      ),
    );
  }
}
