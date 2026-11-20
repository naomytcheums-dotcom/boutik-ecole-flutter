import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import 'auth.dart';
import 'reels.dart';

/// 253 / 253b : série, présence du jour, défi de la semaine, points et badges lus sur le serveur (my_challenges). Aucune valeur de maquette :
/// chaque pastille, barre et bouton reflète l'état réel du compte.
class ChallengesPanel extends ConsumerWidget {
  const ChallengesPanel({super.key, this.badgesOnly = false});
  final bool badgesOnly;

  static const _ink = Color(0xFF111015);
  static const _grey = Color(0xFF57545F);
  static const _violet = Color(0xFF5A3FE0);

  static TextStyle _st(double s, {Color c = _ink, FontWeight w = FontWeight.w500}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: s, height: 1.35, color: c, fontWeight: w);

  static const _badges = [
    ('first_sale', 'Première vente', 'Une vente payée sur une de vos annonces', Icons.storefront_rounded, Color(0xFFE8590C)),
    ('followers_100', 'Cent abonnés', '100 personnes vous suivent', Icons.groups_rounded, _violet),
    ('live_star', 'Live star', 'Un live avec 10 spectateurs en même temps', Icons.live_tv_rounded, Color(0xFFE5365C)),
    ('top10', 'Top dix', 'Parmi les dix membres avec le plus de points', Icons.emoji_events_rounded, Color(0xFFB26A00)),
  ];

  Widget _card({required Widget child, Color color = Colors.white}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x14122640), offset: Offset(0, 6), blurRadius: 16)]),
        child: child,
      );

  Widget _button(String label, VoidCallback? onTap, {bool dark = true}) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 96),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: onTap == null ? const Color(0xFFE6E2EE) : (dark ? _ink : Colors.white), borderRadius: BorderRadius.circular(22)),
            child: Text(label, style: _st(12.5, w: FontWeight.w700, c: onTap == null ? _grey : (dark ? Colors.white : _ink))),
          ),
        ),
      );

  Widget _badgesCard(Challenges c) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mes badges', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final b in _badges)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(b.$4, size: 32, color: (c.badges[b.$1] ?? false) ? b.$5 : const Color(0xFFC9C4D6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.$2, style: _st(13, w: FontWeight.w700)),
                    Text(b.$3, style: _st(11, c: _grey)),
                  ]),
                ),
                Text((c.badges[b.$1] ?? false) ? 'Obtenu' : 'À débloquer', style: _st(11, w: FontWeight.w700, c: (c.badges[b.$1] ?? false) ? const Color(0xFF1B8A4B) : _grey)),
              ]),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text('Connectez-vous pour suivre votre série, vos défis et vos badges.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))),
      );
    }
    final c = ref.watch(challengesProvider);
    if (c == null) {
      if (!ref.watch(challengesFailedProvider)) return const Center(child: CircularProgressIndicator());
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Vos défis ne peuvent pas être chargés pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey)),
            const SizedBox(height: 12),
            _button('Réessayer', () => ref.read(challengesProvider.notifier).refresh()),
          ]),
        ),
      );
    }
    if (badgesOnly) return ListView(padding: const EdgeInsets.fromLTRB(24, 6, 24, 20), children: [_badgesCard(c)]);
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final marks = c.weekMarks.length == 7 ? c.weekMarks : List<bool>.filled(7, false);
    final progress = (c.postsWeek / 3).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1B1630), Color(0xFF4A38B8)]),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.streakLabel, style: _st(22, w: FontWeight.w700, c: Colors.white)),
            const SizedBox(height: 4),
            Text(c.nextLabel, style: _st(11.5, c: const Color(0xCCFFFFFF))),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < 7; i++)
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: marks[i] ? const Color(0xF2FFFFFF) : const Color(0x29FFFFFF),
                    border: i == c.todayIndex ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: marks[i] ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF1B1630)) : Text(days[i], style: _st(11, w: FontWeight.w600, c: const Color(0xB2FFFFFF))),
                ),
            ]),
            const SizedBox(height: 14),
            _button(c.checkedToday ? 'Présence pointée aujourd’hui ✓' : 'Pointer ma présence', c.checkedToday ? null : () => dailyCheckIn(context, ref), dark: false),
          ]),
        ),
        _card(
          child: Row(children: [
            const Icon(Icons.stars_rounded, size: 30, color: Color(0xFFB26A00)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.points} point${c.points > 1 ? 's' : ''}', style: _st(15, w: FontWeight.w700)),
                Text('Les points récompensent votre activité ; ils ne se convertissent pas en argent.', style: _st(11, c: _grey)),
              ]),
            ),
          ]),
        ),
        _card(
          child: Row(children: [
            const Icon(Icons.bolt_rounded, size: 34, color: _violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Récompense du jour', style: _st(13.5, w: FontWeight.w700)),
                Text('Un boost gratuit de 24 h sur votre dernière publication du fil, à 6 jours de série (un boost tous les 6 jours).', style: _st(11, c: _grey)),
                if (c.boostNote != null) _hint(context, ref, c.boostNote!, c.certified),
              ]),
            ),
            const SizedBox(width: 8),
            _button(c.streakClaimed ? 'Récupérée ✓' : 'Récupérer', c.streakClaimable ? () => claimReward(context, ref, streak: true) : null),
          ]),
        ),
        _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Défi de la semaine', style: _st(15, w: FontWeight.w700))),
              Text('Se termine dans ${c.weekEndDays} j', style: _st(11, w: FontWeight.w600, c: _violet)),
            ]),
            const SizedBox(height: 12),
            Text('Publier 3 publications', style: _st(13, w: FontWeight.w700)),
            Text('Les republications et remix ne comptent pas.', style: _st(11, c: _grey)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFECE8F6), color: const Color(0xFF6A4DFF))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('${c.postsWeek.clamp(0, 3)} / 3 · + 200 points', style: _st(11.5, c: _grey))),
              _button(c.postsClaimed ? 'Récupérée ✓' : 'Récupérer', c.postsClaimable ? () => claimReward(context, ref, streak: false) : null),
            ]),
            if (c.pendingNote != null) _hint(context, ref, c.pendingNote!, c.certified),
          ]),
        ),
        _badgesCard(c),
      ],
    );
  }

  /// Message d'attente de validation, avec le chemin pour obtenir la certification (publication immédiate) quand le compte ne l'a pas.
  Widget _hint(BuildContext context, WidgetRef ref, String text, bool certified) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: _st(11.5, c: const Color(0xFFB26A00))),
          if (!certified)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => requestCertificationFlow(ref, context),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Les comptes certifiés publient sans attente : demander la certification', style: _st(11.5, w: FontWeight.w700, c: _violet))),
            ),
        ]),
      );
}
