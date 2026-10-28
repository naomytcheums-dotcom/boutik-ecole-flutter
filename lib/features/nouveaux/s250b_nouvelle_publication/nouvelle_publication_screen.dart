import '../../common/common.dart';

/// 250b · Nouvelle publication : légende, mentions @ suggérées, réseaux de diffusion.
class NouvellePublicationScreen extends ConsumerStatefulWidget {
  const NouvellePublicationScreen({super.key});

  @override
  ConsumerState<NouvellePublicationScreen> createState() => _NouvellePublicationScreenState();
}

class _NouvellePublicationScreenState extends ConsumerState<NouvellePublicationScreen> {
  final _caption = TextEditingController(
    text: 'Spot promo pour le parfum Mbella : tournage, montage et étalonnage. #vidéo @mb',
  );
  final _channels = {'TikTok': false, 'Facebook': true};

  static const _suggestions = [
    ('@mbella.parfum', 'Mbella SARL · Client', Color(0xFFF4B48E)),
    ('@mbella.studio', 'Atelier Mbella · Douala', Color(0xFFCDB8F5)),
    ('@mbarga.carine', 'Carine Mbarga · Génie civil', Color(0xFFA9DDC8)),
  ];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _mentioning => RegExp(r'@\w*$').hasMatch(_caption.text);

  void _mention(String handle) {
    setState(() => _caption.text = _caption.text.replaceFirst(RegExp(r'@\w*$'), '$handle '));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      showNav: false,
      header: ScreenHeader(
        title: 'Nouvelle publication',
        actions: [
          PrimaryButton(label: 'Publier', expand: false, height: 34, onPressed: () => context.openScreen('251')),
        ],
        onBack: () => ScreenHeader.back(context),
        close: true,
      ),
      bottomBar: Row(
        children: [
          Expanded(
            child: PrimaryButton(
              label: 'Planifier',
              icon: AppIcons.clock,
              variant: ButtonVariant.secondary,
              onPressed: () => context.openScreen('252'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: AppColors.accentSoft,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => context.openScreen('253'),
                child: SizedBox(
                  height: AppSizes.buttonHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(AppIcons.zap, size: 18, color: AppColors.accent),
                      const SizedBox(width: 10),
                      Text('Propulser', style: AppText.button.copyWith(color: AppColors.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            const Pill('Modifier', dense: true),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: ShapeDecoration(color: const Color(0xFF55545B), shape: const StadiumBorder()),
              child: Text('Couverture', style: AppText.label.copyWith(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 170),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _caption,
                maxLines: 3,
                minLines: 2,
                onChanged: (_) => setState(() {}),
                style: AppText.body,
                decoration: const InputDecoration(
                  filled: false,
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
                      child: InkWell(
                        onTap: () => setState(() => _caption.text = '${_caption.text} $s'),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Container(
                            width: 30,
                            height: 30,
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
        if (_mentioning) ...[
          gap8,
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comptes suggérés', style: AppText.secondary),
                for (final s in _suggestions)
                  ListRow(
                    title: s.$1,
                    subtitle: s.$2,
                    showChevron: false,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: s.$3,
                      child: Text('M', style: AppText.bodyStrong),
                    ),
                    onTap: () => _mention(s.$1),
                  ),
              ],
            ),
          ),
        ],
        gap8,
        for (final c in _channels.keys) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            radius: 20,
            child: Row(
              children: [
                _NetworkBadge(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c, style: AppText.bodyStrong),
                      Text(c == 'TikTok' ? '@aminata.vid' : 'Aminata Bello Studio', style: AppText.small),
                    ],
                  ),
                ),
                Toggle(value: _channels[c]!, label: 'Publier sur $c', onChanged: (v) => setState(() => _channels[c] = v)),
              ],
            ),
          ),
          gap8,
        ],
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          radius: 20,
          child: Row(
            children: [
              const _NetworkBadge('LinkedIn'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LinkedIn', style: AppText.bodyStrong),
                    Text('Connecter ce compte', style: AppText.small),
                  ],
                ),
              ),
              StatusBadge('Connecter', tone: BadgeTone.accent),
            ],
          ),
        ),
      ],
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge(this.network);

  final String network;

  @override
  Widget build(BuildContext context) {
    final (bg, label) = switch (network) {
      'TikTok' => (AppColors.ink, 'TT'),
      'Facebook' => (const Color(0xFF1877F2), 'f'),
      _ => (const Color(0xFF0A66C2), 'in'),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      alignment: Alignment.center,
      child: Text(label, style: AppText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}
