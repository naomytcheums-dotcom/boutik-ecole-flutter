import '../../common/common.dart';
import '../e_widgets.dart';

/// 49 · Aide et support : recherche, sujets populaires, FAQ, contact.
class AideSupportScreen extends ConsumerStatefulWidget {
  const AideSupportScreen({super.key});

  @override
  ConsumerState<AideSupportScreen> createState() => _AideSupportScreenState();
}

class _AideSupportScreenState extends ConsumerState<AideSupportScreen> {
  String _query = '';
  int? _open;

  bool _match(String s) => _query.trim().isEmpty || s.toLowerCase().contains(_query.trim().toLowerCase());

  void _openTopic(int i) {
    switch (i) {
      case 0:
        context.openScreen('45');
      case 1:
        context.openScreen('43');
      default:
        context.toast('Rubrique « Compte et sécurité » : bientôt disponible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionEDataProvider);
    final topics = [
      for (final (i, t) in d.helpTopics.indexed)
        if (_match(t.$1)) (i, t),
    ];
    final faqs = [
      for (final (i, f) in d.faqs.indexed)
        if (_match(f.$1) || _match(f.$2)) (i, f),
    ];
    return EScaffold(
      title: 'Aide et support',
      showNav: true,
      children: [
        const SizedBox(height: 2),
        ESearchField(hint: 'Comment pouvons-nous vous aider ?', onChanged: (v) => setState(() => _query = v)),
        if (topics.isEmpty && faqs.isEmpty) ...[
          const SizedBox(height: 24),
          Semantics(
            liveRegion: true,
            child: ECard(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                children: [
                  const ETile(AppIcons.search, size: 48, iconSize: 24),
                  gap12,
                  Text('Aucun résultat pour « ${_query.trim()} »', style: ETxt.cardTitle, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    'Reformulez votre question ou contactez le support.',
                    style: ETxt.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 14.75),
          Semantics(header: true, child: Text('Sujets populaires', style: ETxt.section)),
          const SizedBox(height: 17.75),
          ECard(
            child: Column(
              children: [
                for (final (k, (i, t)) in topics.indexed) ...[
                  if (k > 0) const EDivider(indent: 64, endIndent: 12),
                  ERow(
                    height: k == 0 ? 52 : 51,
                    leading: ETile(t.$2),
                    title: t.$1,
                    titleStyle: ETxt.itemRegular,
                    chevron: true,
                    onTap: () => _openTopic(i),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (faqs.isNotEmpty) ...[
          const SizedBox(height: 14.75),
          Semantics(header: true, child: Text('Questions fréquentes', style: ETxt.section)),
          const SizedBox(height: 17.75),
          ECard(
            child: Column(
              children: [
                for (final (k, (i, f)) in faqs.indexed) ...[
                  if (k > 0) const EDivider(indent: 16, endIndent: 12),
                  _FaqRow(
                    question: f.$1,
                    answer: f.$2,
                    first: k == 0,
                    open: _open == i,
                    onTap: () => setState(() => _open = _open == i ? null : i),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14.5),
        _SupportCard(text: d.supportDelay, image: d.supportImage),
      ],
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    required this.first,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool first;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      label: question,
      excludeSemantics: !open,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: first ? 52 : 51,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(question, style: ETxt.itemRegular, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: open ? .25 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const AppIcon(AppIcons.chevronRight, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 40, 14),
                child: Text(answer, style: ETxt.body.copyWith(color: EColors.noteText, height: 1.45)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte bleu nuit « Besoin d'aide ? » avec photo à droite.
class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.text, required this.image});

  final String text;
  final String image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 131,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF0F2F51), Color(0xFF153961), Color(0xFF1B3F6D)]),
        boxShadow: const [BoxShadow(color: EColors.shadow, blurRadius: 28, offset: Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 198.5,
            top: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(image, fit: BoxFit.cover, excludeFromSemantics: true),
            ),
          ),
          Positioned(
            left: 18,
            top: 16,
            width: 175,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Besoin d’aide ?', style: ETxt.section.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: 26.75),
                SizedBox(
                  width: 156,
                  child: Text(
                    text,
                    style: AppText.small.copyWith(fontSize: 11, color: const Color(0xFFDCE3EE), height: 1.32),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            top: 83.5,
            width: 170,
            height: 44,
            child: Semantics(
              button: true,
              label: 'Contacter le support',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.openScreen('51'),
                child: Center(
                  child: Container(
                    height: 28,
                    decoration: const ShapeDecoration(color: AppColors.ink, shape: StadiumBorder()),
                    alignment: Alignment.center,
                    child: Text(
                      'Contacter le support',
                      style: ETxt.badge.copyWith(fontSize: 11.6, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
