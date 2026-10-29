import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// P4 · Nouvelle publication : médias, légende et diffusion sur les réseaux connectés.
class NouvellePublicationScreen extends ConsumerStatefulWidget {
  const NouvellePublicationScreen({super.key});

  @override
  ConsumerState<NouvellePublicationScreen> createState() => _NouvellePublicationScreenState();
}

class _NouvellePublicationScreenState extends ConsumerState<NouvellePublicationScreen> {
  late final List<bool> _enabled = [for (final n in ref.read(sectionREFDataProvider).postNetworks) n.$3];

  void _publish() {
    final count = _enabled.where((e) => e).length;
    context.toast(
      count == 0 ? 'Publication enregistrée sur ton profil uniquement' : 'Publication propulsée sur $count réseaux',
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      header: RefHeader(
        title: 'Nouvelle publication',
        leadingIcon: AppIcons.x,
        leadingLabel: 'Fermer',
        trailing: Semantics(
          button: true,
          child: GestureDetector(
            onTap: _publish,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
              child: Text('Publier', style: AppText.label.copyWith(color: Colors.white, fontSize: 12.5)),
            ),
          ),
        ),
      ),
      bottomBarHeight: 52,
      bottomBar: Row(
        children: [
          Expanded(
            child: RefPillButton(
              label: 'Planifier',
              icon: AppIcons.clock,
              dark: false,
              height: 40,
              fontSize: 13,
              onTap: () => context.toast('Choisis la date de publication'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RefPillButton(label: 'Propulser ce post', height: 40, fontSize: 13, onTap: _publish),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 170, child: RefPhoto(d.postMedia[0], radius: 26, semanticLabel: 'Média principal')),
              const SizedBox(width: 10),
              Expanded(
                flex: 162,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 104,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 80, child: RefPhoto(d.postMedia[1], radius: 22)),
                          const SizedBox(width: 10),
                          Expanded(flex: 72, child: RefPhoto(d.postMedia[2], radius: 22)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      flex: 106,
                      child: RefCard(
                        radius: 22,
                        padding: EdgeInsets.zero,
                        onTap: () => context.toast('Ajouter une photo ou une vidéo'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const AppIcon(AppIcons.plus, size: 22),
                            const SizedBox(height: 14),
                            Text('Photo ou vidéo', style: AppText.small),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        RefCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.postCaption, style: AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(d.postHashtags, style: AppText.body.copyWith(fontSize: 13, color: AppColors.accent)),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Semantics(
          header: true,
          child: Text(
            'Publier aussi sur mes réseaux',
            style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < d.postNetworks.length; i++) ...[
          RefCard(
            radius: 23,
            padding: const EdgeInsets.fromLTRB(12, 1, 8, 1),
            child: Row(
              children: [
                RefToolLogo(image: d.postNetworks[i].$2, size: 28, radius: 7),
                const SizedBox(width: 12),
                Expanded(child: Text(d.postNetworks[i].$1, style: AppText.body)),
                RefSwitch(
                  key: Key('ref-switch-$i'),
                  value: _enabled[i],
                  label: 'Publier sur ${d.postNetworks[i].$1}',
                  onChanged: (v) => setState(() => _enabled[i] = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
