import '../../gdata.dart' show gNetImage;
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../../i18n.dart' show Text;
import '../tp_ui.dart' show GlassBack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../gsound.dart' show GAnim, GSound;
import '../offer_types.dart' show offerTypeBadges;
import '../product_card.dart';
import 'marche_data.dart';

/// Éléments communs de la marketplace : cadre de produit (grande photo, coins modérés, texte hors du cadre), défilement automatique des
/// photos toutes les 3 secondes, lecteur de vidéo, compte à rebours, boutons.

/// Délai de défilement automatique des photos d'un produit.
const kCarouselInterval = Duration(seconds: 3);

Widget mButton(String label, VoidCallback? onTap, {bool dark = true, bool busy = false, double? width, IconData? icon}) {
  final fg = dark ? Colors.white : kInk;
  return Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: busy ? null : onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onTap == null ? const Color(0xFFB9B4C7) : (dark ? kInk : Colors.white), borderRadius: BorderRadius.circular(4), border: dark ? null : Border.all(color: kLine)),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
          Flexible(child: Text(busy ? 'Un instant…' : label, textAlign: TextAlign.center, style: mst(14, w: FontWeight.w700, c: fg))),
        ]),
      ),
    ),
  );
}

Widget mNote(String text) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(text, textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5))));

Widget mSectionTitle(String t, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(children: [Expanded(child: Text(t, style: mst(17, w: FontWeight.w800))), if (trailing != null) trailing]),
    );

/// Page type : fond uni, barre de titre avec retour, contenu défilant.
class MarchePage extends StatelessWidget {
  const MarchePage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Retour',
                  excludeSemantics: true,
                  child: GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03')),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(20, w: FontWeight.w800))),
                ...actions,
              ]),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}

/// Photo réseau avec repli neutre (jamais la photo d'un autre produit).
class MImage extends StatelessWidget {
  const MImage(this.url, {super.key, this.fit = BoxFit.cover, this.icon = Icons.image_outlined});
  final String url;
  final BoxFit fit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Widget neutral() => Container(color: const Color(0xFFEEE9F5), alignment: Alignment.center, child: Icon(icon, color: const Color(0xFFB9B4C7), size: 36));
    if (url.isEmpty) return neutral();
    return gNetImage(url, fit: fit, errorBuilder: (_, _, _) => neutral(), loadingBuilder: (c, child, p) => p == null ? child : neutral());
  }
}

/// Cadre de produit de la maquette : grande photo (4:5), coins arrondis modérés (14), texte placé HORS du cadre.
class MarcheProductTile extends ConsumerWidget {
  const MarcheProductTile({super.key, required this.card, this.onTap, this.compareMode = false});
  final Map<String, dynamic> card;
  final VoidCallback? onTap;
  final bool compareMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = mInt(card['price']);
    final before = card['price_before'] == null ? null : mInt(card['price_before']);
    final flash = card['flash_price'] == null ? null : mInt(card['flash_price']);
    final shown = flash ?? price;
    final ref0 = flash != null ? price : before;
    final off = ref0 != null && ref0 > shown ? ((ref0 - shown) * 100 / ref0).round() : 0;
    final rating = card['rating_avg'];
    final inCompare = ref.watch(marcheCompareProvider).contains('${card['id']}');
    final soldOut = mInt(card['stock']) <= 0;
    final open = onTap ?? () => context.push('/marche/produit/${card['id']}');
    final shop = [if ('${card['shop_name'] ?? ''}'.isNotEmpty) '${card['shop_name']}', if ('${card['city'] ?? ''}'.isNotEmpty) '${card['city']}'].join(' · ');
    return ProductCardView(
      photo: MImage(mImageUrl(card['image'])),
      title: '${card['title']}',
      price: mFcfa(shown),
      oldPrice: ref0 != null && ref0 > shown ? mFcfa(ref0) : null,
      priceColor: flash != null ? kRed : kInk,
      shop: shop,
      extra: rating != null ? '★ $rating · ${mInt(card['rating_count'])} avis' : '',
      buttonLabel: soldOut ? 'Épuisé' : 'Voir le produit',
      onTap: open,
      overlays: [
        if (off > 0 || flash != null)
          Positioned(left: 8, top: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: flash != null ? kRed : kInk, borderRadius: BorderRadius.circular(10)), child: Text(flash != null ? 'Flash −$off %' : '−$off %', style: mst(11, w: FontWeight.w700, c: Colors.white)))),
        if (offerTypeBadges['${card['offer_type']}'] != null)
          Positioned(left: 8, bottom: soldOut ? 36 : 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)), child: Text(offerTypeBadges['${card['offer_type']}']!, style: mst(11, w: FontWeight.w700)))),
        if (soldOut) Positioned(left: 8, bottom: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Text('Épuisé', style: mst(11, w: FontWeight.w700)))),
        Positioned(
          right: 2,
          top: 2,
          child: Semantics(
            button: true,
            toggled: inCompare,
            label: inCompare ? 'Retirer de la comparaison : ${card['title']}' : 'Comparer : ${card['title']}',
            excludeSemantics: true,
            onTap: () => _toggleCompare(context, ref),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleCompare(context, ref),
              child: SizedBox(width: 48, height: 48, child: Center(child: Container(width: 30, height: 30, decoration: BoxDecoration(color: inCompare ? kInk : Colors.white, shape: BoxShape.circle), child: Icon(Icons.compare_arrows_rounded, size: 18, color: inCompare ? Colors.white : kInk)))),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleCompare(BuildContext context, WidgetRef ref) {
    final ok = ref.read(marcheCompareProvider.notifier).toggle('${card['id']}');
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comparaison limitée à 2 offres : retirez-en une pour en choisir une autre.')));
  }
}

/// Grille de produits (2 colonnes sur téléphone, davantage sur grand écran).
class MarcheGrid extends StatelessWidget {
  const MarcheGrid({super.key, required this.cards, this.shrink = true});
  final List<Map<String, dynamic>> cards;
  final bool shrink;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 600 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: shrink,
          physics: shrink ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 20, childAspectRatio: productCardAspect((c.maxWidth - 24 - 10 * (cols - 1)) / cols)),
          itemBuilder: (_, i) => MarcheProductTile(card: cards[i]),
        );
      });
}

/// Défilement horizontal de produits (tendances, carrousel de vitrine).
class MarcheRail extends StatelessWidget {
  const MarcheRail({super.key, required this.cards, this.width = 150});
  final List<Map<String, dynamic>> cards;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: width * 5 / 4 + kProductCardBodyHeight + 6,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: width, child: MarcheProductTile(card: cards[i])),
        ),
      );
}

/// Photos d’un produit (4 au plus) qui défilent seules toutes les 3 secondes ; un doigt posé sur la galerie suspend le défilement.
class AutoCarousel extends StatefulWidget {
  const AutoCarousel({super.key, required this.urls, this.aspect = 1.0, this.radius = 14, this.interval = kCarouselInterval, this.autoplay});
  final List<String> urls;
  final double aspect, radius;
  final Duration interval;

  /// Forcé dans les tests ; par défaut, uniquement quand les animations sont actives (jamais dans les tests automatisés).
  final bool? autoplay;

  @override
  State<AutoCarousel> createState() => _AutoCarouselState();
}

class _AutoCarouselState extends State<AutoCarousel> {
  final _ctrl = PageController();
  Timer? _timer;
  int _page = 0;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay ?? GAnim.enabled) _timer = Timer.periodic(widget.interval, (_) => _next());
  }

  void _next() {
    final count = widget.urls.length.clamp(0, 4);
    if (!mounted || _held || count < 2 || !_ctrl.hasClients) return;
    final n = (_page + 1) % count;
    _ctrl.animateToPage(n, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls.take(4).toList();
    return AspectRatio(
      aspectRatio: widget.aspect,
      child: Stack(children: [
        Listener(
          onPointerDown: (_) => _held = true,
          onPointerUp: (_) => _held = false,
          onPointerCancel: (_) => _held = false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: urls.isEmpty
                ? const MImage('')
                : PageView.builder(controller: _ctrl, itemCount: urls.length, onPageChanged: (i) => setState(() => _page = i), itemBuilder: (_, i) => MImage(urls[i])),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < urls.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == _page ? 18 : 7, height: 7, decoration: BoxDecoration(color: i == _page ? Colors.white : const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(4))),
            ]),
          ),
      ]),
    );
  }
}

/// Lecteur de la vidéo du produit (touchez pour lire ou mettre en pause).
class MarcheVideo extends StatefulWidget {
  const MarcheVideo({super.key, required this.url});
  final String url;

  @override
  State<MarcheVideo> createState() => _MarcheVideoState();
}

class _MarcheVideoState extends State<MarcheVideo> {
  VideoPlayerController? _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_failed || c == null) return Container(height: 120, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEEE9F5), borderRadius: BorderRadius.circular(14)), child: Text('Vidéo indisponible', style: mst(13, c: kGrey)));
    if (!c.value.isInitialized) return Container(height: 200, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEEE9F5), borderRadius: BorderRadius.circular(14)), child: const CircularProgressIndicator());
    return Semantics(
      button: true,
      label: c.value.isPlaying ? 'Mettre la vidéo en pause' : 'Lire la vidéo du produit',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(aspectRatio: c.value.aspectRatio, child: Stack(alignment: Alignment.center, children: [VideoPlayer(c), if (!c.value.isPlaying) const Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white)])),
        ),
      ),
    );
  }
}

/// Compte à rebours qui se met à jour chaque seconde (aucun minuteur dans les tests : valeur figée).
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.end, this.style, this.prefix = ''});
  final DateTime end;
  final TextStyle? style;
  final String prefix;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (GAnim.enabled) _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${widget.prefix}${mCountdown(widget.end.toLocal(), _now)}', style: widget.style ?? mst(13, w: FontWeight.w800, c: kRed));
}

/// Lien discret vers une page de la marketplace (zone tactile de 48 dp).
class MarcheLink extends StatelessWidget {
  const MarcheLink(this.label, this.route, {super.key});
  final String label, route;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: () => context.push(route),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { GSound.play('click'); context.push(route); },
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(12.5, w: FontWeight.w700, c: Colors.white))), const SizedBox(width: 4), const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white)]),
            ),
          ),
        ),
      );
}

/// Pastille de choix (filtre, tri, onglet) : zone tactile d'au moins 48 dp de haut.
class MChip extends StatelessWidget {
  const MChip(this.label, {super.key, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: selected ? kInk : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: selected ? kInk : kLine)), child: Text(label, style: mst(12.5, w: FontWeight.w600, c: selected ? Colors.white : kInk)))),
          ),
        ),
      );
}

/// Liste déroulante carrée : l'utilisateur choisit son filtre dans une liste plutôt que parmi une rangée de pastilles.
class MDropdown extends StatelessWidget {
  const MDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.containsKey(value) ? value : items.keys.first,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kInk),
              borderRadius: BorderRadius.circular(4),
              dropdownColor: Colors.white,
              style: mst(13, w: FontWeight.w600),
              items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13, w: FontWeight.w600)))],
              onChanged: (v) {
                if (v != null) {
                  GSound.play('click');
                  onChanged(v);
                }
              },
            ),
          ),
        ),
      );
}

/// Vendeur vérifié d'une offre : photo, nom, filière et année à l'IUT, enseignant encadrant et badge « Projet validé par l'IUT ».
/// Rien n'est inventé : une information absente n'est pas affichée.
class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.seller, this.supervisor = '', this.validated = false, this.onTap});
  final Map<String, dynamic> seller;
  final String supervisor;
  final bool validated;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = '${seller['name'] ?? ''}'.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    final avatar = '${seller['avatar_url'] ?? ''}';
    final line = [for (final k in ['department', 'study_level', 'institution']) if ('${seller[k] ?? ''}'.trim().isNotEmpty) '${seller[k]}'.trim()].join(' · ');
    return Semantics(
      button: onTap != null,
      label: 'Vendeur : $name',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipOval(child: SizedBox(width: 52, height: 52, child: MImage(avatar, icon: Icons.person_outline))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14.5, w: FontWeight.w800))),
                    if (seller['certified'] == true) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, size: 18, color: kViolet)],
                  ]),
                  Text(seller['certified'] == true ? 'Vendeur vérifié' : 'Étudiant vendeur', style: mst(11.5, w: FontWeight.w700, c: seller['certified'] == true ? kViolet : kGrey)),
                  if (line.isNotEmpty) Text(line, style: mst(12, c: kGrey)),
                ]),
              ),
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: kGrey),
            ]),
            if (supervisor.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Encadré par ${supervisor.trim()}', style: mst(12.5, w: FontWeight.w600))),
            if (validated)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(3)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.verified_outlined, size: 16, color: kGreen), const SizedBox(width: 6), Flexible(child: Text('Projet validé par l’IUT de Douala', style: mst(12, w: FontWeight.w700, c: kGreen)))]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Contenu asynchrone : chargement, erreur lisible, état vide.
Widget mAsync<T>(AsyncValue<T> v, Widget Function(T) builder) => v.when(
      data: builder,
      loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => mNote(e is MarcheException ? e.toString() : marcheErrorText('$e')),
    );
