import '../../../core/utils/validators_am.dart';
import '../am_widgets.dart';

/// 250 · Nouvelle publication : visuel, légende, type de contenu et diffusion sur les réseaux.
class NouvellePublicationAmScreen extends ConsumerStatefulWidget {
  const NouvellePublicationAmScreen({super.key});

  @override
  ConsumerState<NouvellePublicationAmScreen> createState() => _NouvellePublicationAmScreenState();
}

class _NouvellePublicationAmScreenState extends ConsumerState<NouvellePublicationAmScreen> {
  late final _caption = TextEditingController(text: ref.read(sectionAMDataProvider).newPostCaption);
  late final _enabled = {for (final n in ref.read(sectionAMDataProvider).publishNetworks) n.$1: n.$4 ?? false};
  int _type = 0;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _publish() {
    setState(() => _error = validateCaption(_caption.text));
    if (_error == null) {
      context.toast('Publication en ligne');
      context.openScreen('244');
    }
  }

  void _insert(String s) {
    _caption.text = '${_caption.text.trimRight()} $s';
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      showNav: false,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.only(left: 6), child: BrandMark(size: 22)),
            Row(
              children: [
                AmHeaderButton(AppIcons.x, label: 'Fermer', onTap: () => ScreenHeader.back(context)),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Nouvelle publication',
                      textAlign: TextAlign.center,
                      style: AppText.h2.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                AmChip('Publier', dark: true, height: 30, fontSize: 13, onTap: _publish),
              ],
            ),
          ],
        ),
      ),
      bottomBarHeight: 60,
      bottomBar: Row(
        children: [
          Expanded(
            child: _BottomPill(
              label: 'Planifier',
              icon: AppIcons.clock,
              color: Colors.white,
              foreground: AppColors.ink,
              onTap: () => context.toast('Publication planifiée'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _BottomPill(
              label: 'Propulser',
              icon: AppIcons.zap,
              color: AppColors.accentSoft,
              foreground: AppColors.accent,
              onTap: () => context.openScreen('253'),
            ),
          ),
        ],
      ),
      children: [
        AmPhoto(
          d.newPostImage,
          height: 210,
          radius: 28,
          children: [
            Positioned(
              left: 14,
              top: 14,
              child: AmChip(
                'Modifier',
                tone: Tone.neutral,
                height: 26,
                onTap: () => context.toast('Modifier le visuel'),
              ),
            ),
            const Positioned(right: 14, top: 14, child: AmDarkTag('Couverture', color: Color(0xCC45444B))),
          ],
        ),
        gap12,
        AmCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _caption,
                maxLines: 3,
                minLines: 2,
                style: AppText.body.copyWith(fontSize: 13.5),
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(
                  filled: false,
                  hintText: 'Écris une légende…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final s in ['#', '@'])
                    Semantics(
                      button: true,
                      label: s == '#' ? 'Ajouter un hashtag' : 'Mentionner un compte',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _insert(s),
                        child: Container(
                          width: 34,
                          height: 44,
                          alignment: Alignment.center,
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                            child: Text(s, style: AppText.bodyStrong.copyWith(color: AppColors.accent)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error)),
            ),
          ),
        gap8,
        Row(
          children: [
            for (var i = 0; i < d.postTypes.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Pill(d.postTypes[i], dense: true, selected: i == _type, onTap: () => setState(() => _type = i)),
            ],
          ],
        ),
        gap12,
        Semantics(
          header: true,
          child: Text(
            'Publier aussi sur mes réseaux',
            style: AppText.h3.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        gap8,
        for (final n in d.publishNetworks) ...[
          AmCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  AmNetworkLogo(n.$3, size: 30, radius: 7, label: n.$1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.$1, style: AppText.bodyStrong.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        Text(n.$2, style: AppText.small.copyWith(fontSize: 10.5)),
                      ],
                    ),
                  ),
                  if (n.$4 == null)
                    AmChip('Connecter', height: 24, fontSize: 11, onTap: () => context.toast('Connexion à ${n.$1}'))
                  else
                    Toggle(
                      value: _enabled[n.$1]!,
                      label: 'Publier sur ${n.$1}',
                      onChanged: (v) => setState(() => _enabled[n.$1] = v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BottomPill extends StatelessWidget {
  const _BottomPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color color;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(icon, size: 18, color: foreground),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppText.body.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
