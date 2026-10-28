import '../../common/common.dart';
import '../ai_widgets.dart';

/// 231 · Accueil Kéla : raccourcis vocaux, thèmes, missions et suggestion de talents.
class AccueilKelaScreen extends ConsumerStatefulWidget {
  const AccueilKelaScreen({super.key});

  @override
  ConsumerState<AccueilKelaScreen> createState() => _AccueilKelaScreenState();
}

class _AccueilKelaScreenState extends ConsumerState<AccueilKelaScreen> {
  int _theme = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAIDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 30),
        Row(
          children: [
            const SizedBox(width: 56),
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour ${d.firstName}', style: AppText.secondary.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('Que fait-on aujourd’hui ?', style: AppText.h3.copyWith(fontSize: 16.5)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AiRoundButton(icon: AppIcons.bell, label: 'Notifications', onTap: () => context.openScreen('50')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 208,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 170,
                child: Column(
                  children: [
                    Expanded(
                      child: _ShortcutCard(
                        title: 'Brief express',
                        detail: 'Décris ton besoin à voix haute',
                        detailWidth: 130,
                        onTap: () => context.openScreen('230'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _ShortcutCard(
                        title: 'Voix en texte',
                        detail: 'Tes notes en transcription',
                        detailWidth: 96,
                        onTap: () => context.openScreen('232'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 162, child: _TalkCard(name: d.assistantName)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(header: true, child: Text('Thèmes', style: AppText.h3.copyWith(fontSize: 16))),
            ),
            TextLink(
              'Tout voir',
              color: AppColors.textSecondary,
              onTap: () => context.toast('Tous les thèmes de Kéla'),
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: OverflowBox(
            maxWidth: 366,
            minWidth: 366,
            alignment: Alignment.centerLeft,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              itemCount: d.themes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) =>
                  _ThemeChip(label: d.themes[i], selected: i == _theme, onTap: () => setState(() => _theme = i)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 170,
                child: _MissionCard(
                  title: 'Déposer un besoin',
                  detail: 'Logo, affiche, vidéo : ${d.assistantName} t’oriente vers les bons talents.',
                  onTap: () => context.openScreen('230'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 162,
                child: _MissionCard(
                  title: 'Suivre ma mission',
                  detail: 'Étapes, preuves et paiement par jalons.',
                  onTap: () => context.openScreen('233'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _TalentBanner(
          text: '${d.matchingTalents} talents de ${d.matchingDepartment} correspondent à ton brief ${d.briefSubject}.',
          onTap: () => context.openScreen('152'),
        ),
      ],
    );
  }
}

/// Carte blanche arrondie cliquable.
class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.onTap, this.label});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: child),
      ),
    );
  }
}

/// Petite pastille grise contenant une flèche.
class _ArrowDot extends StatelessWidget {
  const _ArrowDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: const BoxDecoration(color: Color(0xFFF0EEEC), shape: BoxShape.circle),
    alignment: Alignment.center,
    child: const AppIcon(AppIcons.arrowRight, size: 14),
  );
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.title, required this.detail, required this.onTap, this.detailWidth});

  final String title;
  final String detail;
  final double? detailWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 19, 7, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, textAlign: TextAlign.end, style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                ),
                const SizedBox(width: 6),
                const _ArrowDot(),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: detailWidth,
              child: Text(detail, maxLines: 2, style: AppText.small.copyWith(fontSize: 11.5, height: 1.25)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalkCard extends StatelessWidget {
  const _TalkCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 5),
            Semantics(header: true, child: Text('Parle à $name', style: AppText.h3.copyWith(fontSize: 17))),
            const SizedBox(height: 4),
            Text('Essaie dès maintenant', style: AppText.small.copyWith(fontSize: 12)),
            const Spacer(flex: 2),
            Semantics(
              button: true,
              child: Material(
                color: AppColors.ink,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.openScreen('230'),
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: Center(
                      child: Text('Commencer', style: AppText.body.copyWith(fontSize: 14.5, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 34,
            constraints: const BoxConstraints(minWidth: 70),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: ShapeDecoration(color: selected ? AppColors.ink : Colors.white, shape: const StadiumBorder()),
            child: Text(
              label,
              style: AppText.body.copyWith(fontSize: 14, color: selected ? Colors.white : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.title, required this.detail, required this.onTap});

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      onTap: onTap,
      label: '$title, découvrir',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(title, style: AppText.h3.copyWith(fontSize: 15)),
            const SizedBox(height: 24),
            SizedBox(
              height: 31,
              child: Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(fontSize: 11.5, height: 1.3),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              height: 28,
              padding: const EdgeInsets.only(left: 16, right: 10),
              decoration: BoxDecoration(color: const Color(0xFFF0EEEC), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Découvrir', style: AppText.body.copyWith(fontSize: 13)),
                  const SizedBox(width: 18),
                  const AppIcon(AppIcons.arrowRight, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TalentBanner extends StatelessWidget {
  const _TalentBanner({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$text Voir les profils',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(66, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: AppText.body.copyWith(fontSize: 13.5, height: 1.3)),
              const SizedBox(height: 1),
              Text(
                'Voir les profils',
                style: AppText.small.copyWith(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
