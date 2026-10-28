import '../../../l10n/gen/app_localizations.dart';
import '../w_widgets.dart';

/// 185 · Language : l'écran s'affiche dans la langue choisie (anglais par défaut, comme la maquette)
/// et applique ce choix à toute l'application.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _select('en'));
  }

  void _select(String code) {
    if (!mounted) return;
    setState(() => _lang = code);
    ref.read(appSettingsProvider.notifier).setLocale(Locale(code));
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionWDataProvider);
    return Localizations.override(
      context: context,
      locale: Locale(_lang),
      child: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context);
          final active = GBadge(l.languageActive, Tone.success);
          return AppScaffold(
            tab: NavTab.home,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            header: CHeader(l.languageTitle),
            children: [
              QCard(
                children: [
                  WRow(
                    title: l.languageFrench,
                    subtitle: l.languageDefault,
                    trailing: _lang == 'fr' ? active : null,
                    onTap: () => _select('fr'),
                  ),
                  WRow(
                    title: l.languageEnglish,
                    subtitle: l.languageEnglishRegion,
                    trailing: _lang == 'en' ? active : null,
                    onTap: () => _select('en'),
                  ),
                ],
              ),
              gap16,
              Semantics(header: true, child: Text(l.languagePreview, style: AppText.bodyStrong.copyWith(fontSize: 15))),
              gap12,
              QCard(
                children: [
                  WRow(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(d.previewLampImage, width: 50, height: 50, fit: BoxFit.cover),
                    ),
                    title: l.previewLampTitle,
                    subtitle: l.previewLampDetail(fcfaLocalized(d.previewLampPrice, _lang)),
                    trailing: GBadge(l.previewInStock, Tone.success),
                  ),
                  WRow(
                    leading: const SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(child: AppIcon(AppIcons.trophy, size: 22)),
                    ),
                    title: l.previewChallengeTitle,
                    subtitle: l.previewChallengeDetail,
                    trailing: GBadge(l.previewOpen, Tone.accent),
                  ),
                ],
              ),
              gap16,
              WInfoCard(icon: AppIcons.globe, text: l.languageHint),
            ],
          );
        },
      ),
    );
  }
}
