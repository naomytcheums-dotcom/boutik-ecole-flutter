import '../../common/common.dart';
import '../f_widgets.dart';

/// 56 · Notifications et confidentialité : préférences et export des données.
class NotificationsConfidentialiteScreen extends ConsumerStatefulWidget {
  const NotificationsConfidentialiteScreen({super.key});

  @override
  ConsumerState<NotificationsConfidentialiteScreen> createState() => _NotificationsConfidentialiteScreenState();
}

class _NotificationsConfidentialiteScreenState extends ConsumerState<NotificationsConfidentialiteScreen> {
  // Valeurs modifiées par l'utilisateur (titre → activé).
  final _values = <String, bool>{};

  Widget _card(List<FPref> prefs) => FCardList(
    children: [
      for (final p in prefs)
        FRow(
          leftPadding: 16,
          rightPadding: 16,
          title: p.title,
          subtitle: p.subtitle,
          trailing: FSwitch(
            label: p.title,
            value: _values[p.title] ?? p.enabled,
            onChanged: (v) => setState(() => _values[p.title] = v),
          ),
        ),
    ],
  );

  void _export(SectionFData d) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(header: true, child: Text('Télécharger mes données', style: FTxt.section)),
              gap8,
              Text(
                'Profil, commandes, messages et préférences au format JSON. ${d.dataExportDelay}',
                style: FTxt.body,
                textAlign: TextAlign.center,
              ),
              gap16,
              FButton(
                'Demander l’archive',
                onPressed: () {
                  Navigator.pop(sheet);
                  context.toast('Demande enregistrée. ${d.dataExportDelay}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionFDataProvider);
    return FScaffold(
      title: 'Notifications et confidentialité',
      children: [
        const SizedBox(height: 2),
        const FSectionTitle('Notifications'),
        const SizedBox(height: 17.5),
        _card(d.notificationPrefs),
        const SizedBox(height: 14.5),
        const FSectionTitle('Confidentialité'),
        const SizedBox(height: 18),
        _card(d.privacyPrefs),
        const SizedBox(height: 15),
        _DownloadButton(onTap: () => _export(d)),
      ],
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(side: BorderSide(color: FColors.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppIcon(AppIcons.download, size: 20),
                const SizedBox(width: 7),
                Text(
                  'Télécharger mes données',
                  style: FTxt.button.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
