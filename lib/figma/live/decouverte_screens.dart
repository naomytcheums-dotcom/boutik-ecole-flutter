import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'home_live.dart' show LiveTalent, TalentAvatarImage;
import 'marche/marche_catalogue.dart';
import 'marche/marche_data.dart';
import 'marche/decouverte.dart' show marcheFilieres;
import 'marche/marche_screens.dart' show marcheCategoriesProvider;
import 'marche/marche_widgets.dart';
import 'offer_types.dart';
import 'store.dart' show favoritesProvider;
import 'tp_ui.dart' show TpFrame, TpRound, tpBackground, tpSt;

/// Écrans de découverte réels (explorer, recherche, résultats, recherche avancée, filtres, catalogue, tendances, « Pour vous », favoris) :
/// une seule recherche partagée ([marcheFiltersProvider]) interroge le serveur page par page ; le champ, le compteur, le tri et les filtres
/// de tous ces écrans lisent et écrivent le même état. Les maquettes ne servent qu'en démonstration hors connexion.

/// Types proposés par les pastilles « Tous · Produits · Services · Talents · Projets » : type d'offre du serveur, « talent » étant à part.
const kExploreKinds = ['', 'product', 'service', 'talent', 'project'];
const kExploreLabels = ['Tous', 'Produits', 'Services', 'Talents', 'Projets'];

class ExploreTalents extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// Vrai : la recherche porte sur les talents (liste des profils) et non sur les offres.
final exploreTalentsProvider = NotifierProvider<ExploreTalents, bool>(ExploreTalents.new);

/// Index de la pastille allumée, déduit de l'état partagé (jamais d'une valeur locale qui se désynchroniserait).
int exploreKindIndex(MarcheFilters f, bool talents) {
  if (talents) return 3;
  final i = kExploreKinds.indexOf(f.offerType);
  return i < 0 ? 0 : i;
}

void setExploreKind(WidgetRef ref, int i) {
  final talents = kExploreKinds[i] == 'talent';
  ref.read(exploreTalentsProvider.notifier).set(talents);
  if (!talents) {
    final f = ref.read(marcheFiltersProvider);
    ref.read(marcheFiltersProvider.notifier).set(f.copy(offerType: kExploreKinds[i], category: '', shops: false));
  }
}

/// Efface le mot-clé, les filtres et le type : la recherche repart de zéro.
void resetDiscovery(WidgetRef ref) {
  ref.read(exploreTalentsProvider.notifier).set(false);
  ref.read(marcheFiltersProvider.notifier).set(const MarcheFilters());
}

/// Historique local des mots recherchés sur cet appareil (par compte), les plus récents d'abord.
class RecentSearches extends Notifier<List<String>> {
  static const _max = 6;

  String get _key => 'recent_searches_${ref.read(authProvider).current?.serverId ?? 'visiteur'}';

  @override
  List<String> build() {
    ref.watch(authProvider.select((a) => a.current?.serverId));
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      final l = (await SharedPreferences.getInstance()).getStringList(_key) ?? const <String>[];
      if (ref.mounted) state = l;
    } catch (_) {}
  }

  Future<void> add(String q) async {
    final v = q.trim();
    if (v.length < 2) return;
    state = [v, for (final e in state) if (e.toLowerCase() != v.toLowerCase()) e].take(_max).toList();
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key, state);
    } catch (_) {}
  }

  Future<void> clear() async {
    state = const [];
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

// ------------------------------------------------------------------ cadre commun

/// Page de découverte : fond du site, retour, titre, contenu. [search] ajoute la loupe vers l'écran de recherche.
class DiscoPage extends StatelessWidget {
  const DiscoPage({super.key, required this.title, required this.child, this.search = true});
  final String title;
  final Widget child;
  final bool search;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4EFE6),
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: tpBackground,
          child: SafeArea(
            child: TpFrame(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(children: [
                    TpRound(icon: Icons.arrow_back, label: 'Retour', onTap: () => gBack(context)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tpSt(20, w: FontWeight.w700))),
                    if (search) TpRound(icon: Icons.search, label: 'Rechercher', onTap: () => gTab(context, '19')),
                  ]),
                ),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
      );
}

/// Champ de recherche lié au mot-clé partagé : il affiche toujours la recherche en cours, la lance après une courte pause
/// ou à la validation, et mémorise les mots validés dans l'historique local.
class DiscoSearchField extends ConsumerStatefulWidget {
  const DiscoSearchField({super.key, this.hint = 'Rechercher un produit, un service, un talent…', this.onSubmitted, this.autofocus = false});
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  ConsumerState<DiscoSearchField> createState() => _DiscoSearchFieldState();
}

class _DiscoSearchFieldState extends ConsumerState<DiscoSearchField> {
  late final _c = TextEditingController(text: ref.read(marcheFiltersProvider).q);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _apply(String v) {
    final f = ref.read(marcheFiltersProvider);
    if (f.q.trim() != v.trim()) ref.read(marcheFiltersProvider.notifier).set(f.copy(q: v.trim(), need: ''));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(marcheFiltersProvider.select((f) => f.q), (_, q) {
      if (_c.text.trim() != q.trim()) _c.text = q;
    });
    return TextField(
      controller: _c,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 450), () => _apply(v));
      },
      onSubmitted: (v) {
        _debounce?.cancel();
        _apply(v);
        ref.read(recentSearchesProvider.notifier).add(v);
        widget.onSubmitted?.call(v);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _c.text.isEmpty ? null : IconButton(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), tooltip: 'Effacer la recherche', icon: const Icon(Icons.close_rounded), onPressed: () {
              _debounce?.cancel();
              _c.clear();
              _apply('');
              setState(() {});
            }),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

/// Pastilles de type ; leur état vient de la recherche partagée.
class ExploreChips extends ConsumerWidget {
  const ExploreChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = exploreKindIndex(ref.watch(marcheFiltersProvider), ref.watch(exploreTalentsProvider));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [for (var i = 0; i < kExploreLabels.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: MChip(kExploreLabels[i], selected: i == sel, onTap: () => setExploreKind(ref, i)))]),
    );
  }
}

/// Menu de tri (nouveautés, prix, popularité, notes).
class SortMenu extends ConsumerWidget {
  const SortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(marcheFiltersProvider);
    return PopupMenuButton<String>(
      tooltip: 'Trier',
      initialValue: marcheSorts.containsKey(f.sort) ? f.sort : 'popular',
      onSelected: (v) => ref.read(marcheFiltersProvider.notifier).set(f.copy(sort: v)),
      itemBuilder: (_) => [for (final e in marcheSorts.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Trier : ${marcheSorts[f.sort] ?? marcheSorts['popular']}', style: mst(12.5, w: FontWeight.w600, c: kViolet)), const Icon(Icons.arrow_drop_down_rounded, color: kViolet)]),
      ),
    );
  }
}

/// « 24+ résultats », « 3 résultats » : le serveur livre par pages, le compteur dit ce qui est chargé et s'il en reste.
String resultCountLabel(int loaded, bool more) => more ? '$loaded+ résultats' : '$loaded résultat${loaded > 1 ? 's' : ''}';

/// Ligne de talent (liste des profils étudiants publics) : touche pour ouvrir le profil de la personne.
Widget talentRow(BuildContext context, Map<String, dynamic> x) {
  final t = LiveTalent.fromRow(x);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => gOpenProfile(context, t.id),
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
      child: Row(children: [
        TalentAvatarImage(t, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700))),
              if (t.certified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Color(0xFF2F6BFF))),
            ]),
            if ([t.department, t.skills].any((e) => e.isNotEmpty)) Text([if (t.department.isNotEmpty) t.department, if (t.skills.isNotEmpty) t.skills].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(11.5, c: kGrey)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: kGrey),
      ]),
    ),
  );
}

/// Demande de connexion à la place d'une liste réservée aux comptes (talents, favoris).
Widget loginPrompt(BuildContext context, WidgetRef ref, String pour) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Connexion requise', style: mst(17, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Connectez-vous pour $pour.', textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
          const SizedBox(height: 16),
          mButton('Se connecter', () => requireLogin(context, ref, pour)),
        ]),
      ),
    );

/// Résultats de la recherche partagée : offres du serveur ou talents selon la pastille, avec compteur, tri et « Réinitialiser ».
class ExploreResults extends ConsumerStatefulWidget {
  const ExploreResults({super.key, this.header, this.padding = const EdgeInsets.only(bottom: 24)});

  /// Contenu posé au-dessus des résultats (champ, pastilles) : il défile avec eux.
  final Widget? header;
  final EdgeInsets padding;

  @override
  ConsumerState<ExploreResults> createState() => _ExploreResultsState();
}

class _ExploreResultsState extends ConsumerState<ExploreResults> {
  int _loaded = 0;
  bool _more = false, _known = false;

  void _onLoaded(int n, bool more) {
    if (_loaded == n && _more == more && _known) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _loaded = n;
        _more = more;
        _known = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(marcheFiltersProvider);
    final talents = ref.watch(exploreTalentsProvider);
    final signedIn = ref.watch(authProvider.select((a) => a.current != null));
    final dirty = f.q.trim().isNotEmpty || f.active || talents;
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        Expanded(child: Text(_known ? resultCountLabel(_loaded, _more) : 'Recherche…', style: mst(15, w: FontWeight.w700))),
        if (dirty) TextButton(onPressed: () => resetDiscovery(ref), child: Text('Réinitialiser', style: mst(12.5, w: FontWeight.w600, c: kRed))),
        if (!talents) const SortMenu(),
      ]),
    );
    final head = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [if (widget.header != null) widget.header!, bar]);
    if (talents && Backend.ready && !signedIn) {
      return ListView(padding: widget.padding, children: [head, SizedBox(height: 320, child: loginPrompt(context, ref, 'découvrir les talents'))]);
    }
    if (talents) {
      return PagedCatalog(
        key: const ValueKey('talents'),
        fn: 'talents_list',
        params: {'p_query': f.q.trim()},
        paged: false,
        scrollable: true,
        header: head,
        padding: widget.padding,
        emptyText: 'Aucun talent ne correspond à votre recherche.',
        rowBuilder: (x) => talentRow(context, x),
        onLoaded: _onLoaded,
      );
    }
    return PagedCatalog(
      key: const ValueKey('offers'),
      fn: 'marketplace_search',
      params: f.productParams,
      scrollable: true,
      header: head,
      padding: widget.padding,
      onLoaded: _onLoaded,
    );
  }
}

// ------------------------------------------------------------------ 04 · explorer

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DiscoPage(
        title: 'Explorer',
        child: ExploreResults(
          header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: Align(alignment: Alignment.centerRight, child: SizedBox(width: 150, child: MarcheLink('Marketplace', '/marche')))),
            const ExploreChips(),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ 19 · recherche

class SearchHomeScreen extends ConsumerWidget {
  const SearchHomeScreen({super.key});

  void _go(BuildContext context) => context.push('/s/20');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    return DiscoPage(
      title: 'Rechercher',
      search: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text('Trouvez ce qui vous inspire', style: mst(18, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Produits, services, talents, projets…', style: mst(13, c: kGrey)),
        const SizedBox(height: 12),
        DiscoSearchField(autofocus: true, onSubmitted: (_) => _go(context)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (var i = 1; i < kExploreLabels.length; i++)
            MChip(kExploreLabels[i], selected: false, onTap: () {
              setExploreKind(ref, i);
              _go(context);
            }),
        ]),
        const SizedBox(height: 8),
        mButton('Recherche avancée', () => context.push('/s/21'), dark: false, width: double.infinity),
        if (recents.isNotEmpty) ...[
          mSectionTitle('Recherches récentes', trailing: TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: Text('Effacer', style: mst(12.5, w: FontWeight.w600, c: kRed)))),
          Wrap(spacing: 8, children: [
            for (final r in recents)
              MChip(r, selected: false, onTap: () {
                final f = ref.read(marcheFiltersProvider);
                ref.read(marcheFiltersProvider.notifier).set(f.copy(q: r, need: ''));
                _go(context);
              }),
          ]),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ 20 · résultats de recherche

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(marcheFiltersProvider);
    return DiscoPage(
      title: 'Résultats',
      search: false,
      child: ExploreResults(
        header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              const Expanded(child: DiscoSearchField()),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: f.activeCount > 0 ? 'Filtres : ${f.activeCount} appliqués' : 'Filtres',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => context.push('/s/23'),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: f.active ? kInk : Colors.white, shape: BoxShape.circle),
                    child: Stack(alignment: Alignment.center, children: [
                      Icon(Icons.tune_rounded, color: f.active ? Colors.white : kInk),
                      if (f.activeCount > 0) Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle), child: Text('${f.activeCount}', style: mst(9, w: FontWeight.w800, c: Colors.white)))),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const ExploreChips(),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ 21 · recherche avancée

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  ConsumerState<AdvancedSearchScreen> createState() => _AdvancedSearchState();
}

class _AdvancedSearchState extends ConsumerState<AdvancedSearchScreen> {
  late final _q = TextEditingController(text: ref.read(marcheFiltersProvider).q);
  late final _min = TextEditingController(text: ref.read(marcheFiltersProvider).min?.toString() ?? '');
  late final _max = TextEditingController(text: ref.read(marcheFiltersProvider).max?.toString() ?? '');

  @override
  void dispose() {
    _q.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _set(MarcheFilters f) => ref.read(marcheFiltersProvider.notifier).set(f);

  int? _digits(String s) {
    final d = s.replaceAll(RegExp(r'[^0-9]'), '');
    return d.isEmpty ? null : int.tryParse(d);
  }

  void _search() {
    final f = ref.read(marcheFiltersProvider);
    ref.read(recentSearchesProvider.notifier).add(f.q);
    ref.read(exploreTalentsProvider.notifier).set(false);
    context.push('/s/20');
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none));

  @override
  Widget build(BuildContext context) {
    ref.listen(marcheFiltersProvider, (_, n) {
      if (_q.text.trim() != n.q.trim()) _q.text = n.q;
      if (_digits(_min.text) != n.min) _min.text = n.min?.toString() ?? '';
      if (_digits(_max.text) != n.max) _max.text = n.max?.toString() ?? '';
    });
    final f = ref.watch(marcheFiltersProvider);
    final cats = ref.watch(marcheCategoriesProvider).value ?? const <String>[];
    final recents = ref.watch(recentSearchesProvider);
    return DiscoPage(
      title: 'Recherche avancée',
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(controller: _q, textInputAction: TextInputAction.search, onChanged: (v) => _set(f.copy(q: v.trim(), need: '')), onSubmitted: (_) => _search(), decoration: _deco('Mot-clé', hint: 'Produit, service, nom, compétence…')),
        const SizedBox(height: 12),
        MDropdown(label: 'Type d’offre', value: f.offerType, items: {'': 'Tous les types d’offres', ...offerTypeLabels}, onChanged: (v) => _set(f.copy(offerType: v, category: ''))),
        const SizedBox(height: 12),
        MDropdown(label: 'Filière', value: f.department, items: marcheFilieres, onChanged: (v) => _set(f.copy(department: v))),
        const SizedBox(height: 12),
        MDropdown(label: 'Catégorie', value: f.category, items: {'': 'Toutes catégories', for (final c in cats) c: c}, onChanged: (v) => _set(f.copy(category: v))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, onChanged: (v) => _set(f.copy(min: _digits(v))), decoration: _deco('Budget min (FCFA)'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, onChanged: (v) => _set(f.copy(max: _digits(v))), decoration: _deco('Budget max (FCFA)'))),
        ]),
        const SizedBox(height: 12),
        MDropdown(label: 'Trier par', value: f.sort, items: marcheSorts, onChanged: (v) => _set(f.copy(sort: v))),
        const SizedBox(height: 4),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: f.inStock, onChanged: (v) => _set(f.copy(inStock: v)), title: Text('Disponible uniquement', style: mst(14, w: FontWeight.w600)), subtitle: Text('Masque les produits en rupture de stock.', style: mst(12, c: kGrey))),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: f.verified, onChanged: (v) => _set(f.copy(verified: v)), title: Text('Vendeurs vérifiés', style: mst(14, w: FontWeight.w600)), subtitle: Text('Uniquement les vendeurs dont le profil est certifié.', style: mst(12, c: kGrey))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: mButton('Réinitialiser', () {
            resetDiscovery(ref);
            gToast(context, 'Filtres réinitialisés');
          }, dark: false)),
          const SizedBox(width: 12),
          Expanded(child: mButton('Rechercher', _search)),
        ]),
        if (recents.isNotEmpty) ...[
          mSectionTitle('Recherches récentes', trailing: TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: Text('Effacer', style: mst(12.5, w: FontWeight.w600, c: kRed)))),
          Wrap(spacing: 8, children: [
            for (final r in recents)
              MChip(r, selected: false, onTap: () {
                _set(f.copy(q: r, need: ''));
                _search();
              }),
          ]),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------------ 23 · filtres

class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key});

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<FiltersScreen> {
  static const _priceMax = 500000.0;
  late MarcheFilters _d = ref.read(marcheFiltersProvider);

  void _apply() {
    ref.read(exploreTalentsProvider.notifier).set(false);
    ref.read(marcheFiltersProvider.notifier).set(_d);
    final r = GoRouter.of(context);
    if (r.canPop()) {
      r.pop(true);
    } else {
      r.go('/s/20');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(marcheCategoriesProvider).value ?? const <String>[];
    final lo = (_d.min ?? 0).toDouble().clamp(0.0, _priceMax).toDouble(), hi = (_d.max ?? _priceMax.toInt()).toDouble().clamp(0.0, _priceMax).toDouble();
    String price(double v) => v >= _priceMax ? '500 000 FCFA et plus' : mFcfa(v);
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: mst(15, w: FontWeight.w800)));
    return DiscoPage(
      title: 'Filtres',
      search: false,
      child: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            title('Type d’offre'),
            Wrap(spacing: 8, children: [
              MChip('Tous', selected: _d.offerType.isEmpty, onTap: () => setState(() => _d = _d.copy(offerType: '', category: ''))),
              for (final e in offerTypeLabels.entries) MChip(e.value, selected: _d.offerType == e.key, onTap: () => setState(() => _d = _d.copy(offerType: e.key, category: ''))),
            ]),
            Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.push('/s/87'), child: Text('Voir les innovations', style: mst(13, w: FontWeight.w600, c: kViolet))))),
            title('Filière'),
            MDropdown(label: 'Filière', value: _d.department, items: marcheFilieres, onChanged: (v) => setState(() => _d = _d.copy(department: v))),
            title('Prix'),
            Text('${price(lo)} – ${price(hi)}', style: mst(13, c: kGrey)),
            RangeSlider(
              values: RangeValues(lo <= hi ? lo : hi, hi),
              min: 0,
              max: _priceMax,
              divisions: 100,
              activeColor: kInk,
              onChanged: (v) => setState(() => _d = _d.copy(min: v.start <= 0 ? null : v.start.round(), max: v.end >= _priceMax ? null : v.end.round())),
            ),
            title('Disponibilité'),
            Wrap(spacing: 8, children: [
              MChip('Toutes les offres', selected: !_d.inStock, onTap: () => setState(() => _d = _d.copy(inStock: false))),
              MChip('En stock uniquement', selected: _d.inStock, onTap: () => setState(() => _d = _d.copy(inStock: true))),
            ]),
            title('Vendeur'),
            Wrap(spacing: 8, children: [
              MChip('Tous les vendeurs', selected: !_d.verified, onTap: () => setState(() => _d = _d.copy(verified: false))),
              MChip('Vendeurs vérifiés', selected: _d.verified, onTap: () => setState(() => _d = _d.copy(verified: true))),
            ]),
            if (cats.isNotEmpty) ...[
              title('Catégorie'),
              Wrap(spacing: 8, children: [
                MChip('Toutes', selected: _d.category.isEmpty, onTap: () => setState(() => _d = _d.copy(category: ''))),
                for (final c in cats) MChip(c, selected: _d.category == c, onTap: () => setState(() => _d = _d.copy(category: c))),
              ]),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(children: [
            Expanded(child: mButton('Réinitialiser', () {
              resetDiscovery(ref);
              setState(() => _d = const MarcheFilters());
              gToast(context, 'Filtres réinitialisés');
            }, dark: false)),
            const SizedBox(width: 12),
            Expanded(child: mButton('Appliquer', _apply)),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ 22 · catalogue de produits

class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(marcheFiltersProvider).copy(offerType: 'product', shops: false);
    final cats = [for (final c in ref.watch(marcheCategoriesProvider).value ?? const <String>[]) if (offerTypeOfCategory(c) == 'product') c];
    final base = ref.watch(marcheFiltersProvider);
    return DiscoPage(
      title: 'Catalogue de produits',
      child: ExploreCatalogue(
        params: f.productParams,
        header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8), child: DiscoSearchField(hint: 'Rechercher un produit')),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: MChip('Tous', selected: base.category.isEmpty, onTap: () => ref.read(marcheFiltersProvider.notifier).set(base.copy(category: '', offerType: 'product')))),
              for (final c in cats) Padding(padding: const EdgeInsets.only(right: 8), child: MChip(c, selected: base.category == c, onTap: () => ref.read(marcheFiltersProvider.notifier).set(base.copy(category: c, offerType: 'product')))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Liste paginée avec compteur et tri, pour un écran dont le type est imposé (catalogue de produits).
class ExploreCatalogue extends ConsumerStatefulWidget {
  const ExploreCatalogue({super.key, required this.params, this.header, this.fn = 'marketplace_search', this.sortable = true, this.paged = true, this.emptyText = 'Aucun produit ne correspond à votre recherche.'});
  final Map<String, dynamic> params;
  final Widget? header;
  final String fn, emptyText;
  final bool sortable, paged;

  @override
  ConsumerState<ExploreCatalogue> createState() => _ExploreCatalogueState();
}

class _ExploreCatalogueState extends ConsumerState<ExploreCatalogue> {
  int _loaded = 0;
  bool _more = false, _known = false;

  void _onLoaded(int n, bool more) {
    if (_loaded == n && _more == more && _known) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _loaded = n;
        _more = more;
        _known = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) => PagedCatalog(
        fn: widget.fn,
        params: widget.params,
        paged: widget.paged,
        scrollable: true,
        emptyText: widget.emptyText,
        onLoaded: _onLoaded,
        header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.header != null) widget.header!,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Expanded(child: Text(_known ? resultCountLabel(_loaded, _more) : 'Chargement…', style: mst(15, w: FontWeight.w700))),
              if (widget.sortable) const SortMenu(),
            ]),
          ),
        ]),
      );
}

// ------------------------------------------------------------------ 22c · tendances et nouveautés

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsState();
}

class _TrendsState extends State<TrendsScreen> {
  int _tab = 0;

  static const _tabs = ['Tendances', 'Nouveautés', 'Sélection IUT'];

  @override
  Widget build(BuildContext context) {
    final (fn, params, paged, empty) = switch (_tab) {
      0 => ('trending_products', const <String, dynamic>{}, false, 'Les tendances apparaîtront dès les premières ventes.'),
      1 => ('marketplace_search', const <String, dynamic>{'p_sort': 'recent'}, true, 'Aucune nouveauté pour le moment.'),
      _ => ('marketplace_search', const <String, dynamic>{'p_validated': true, 'p_sort': 'popular'}, true, 'Aucune offre validée par l’IUT pour le moment.'),
    };
    return DiscoPage(
      title: 'Tendances et nouveautés',
      child: ExploreCatalogue(
        key: ValueKey(_tab),
        fn: fn,
        params: params,
        paged: paged,
        sortable: false,
        emptyText: empty,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [for (var i = 0; i < _tabs.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: MChip(_tabs[i], selected: i == _tab, onTap: () => setState(() => _tab = i)))]),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 22d · pour vous

class ForYouScreen extends StatelessWidget {
  const ForYouScreen({super.key});

  @override
  Widget build(BuildContext context) => DiscoPage(
        title: 'Pour vous',
        child: ExploreCatalogue(
          fn: 'recommended_offers',
          params: const {},
          sortable: false,
          emptyText: 'Aucune recommandation pour le moment.',
          header: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Offres choisies selon votre filière, vos favoris et vos achats ; à défaut, les plus populaires de la plateforme.', style: mst(12.5, c: kGrey).copyWith(height: 1.5)),
          ),
        ),
      );
}

// ------------------------------------------------------------------ 25 · mes favoris

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesState();
}

class _FavoritesState extends ConsumerState<FavoritesScreen> {
  int _kind = 0;
  int _bump = 0;

  Future<void> _remove(Map<String, dynamic> x) async {
    final r = await marcheCall('favorite_remove', {'p_listing': x['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(favoritesProvider);
    setState(() => _bump++);
  }

  Widget _gone(Map<String, dynamic> x) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.inventory_2_outlined, color: kGrey),
          const SizedBox(height: 8),
          Text('${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12.5, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Ce produit n’est plus disponible.', style: mst(11.5, c: kGrey)),
          const Spacer(),
          mButton('Retirer des favoris', () => _remove(x), dark: false, width: double.infinity),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider.select((a) => a.current != null));
    final favCount = ref.watch(favoritesProvider.select((l) => l.length));
    final kind = kExploreKinds[_kind];
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [for (var i = 0; i < kExploreLabels.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: MChip(kExploreLabels[i], selected: i == _kind, onTap: () => setState(() => _kind = i)))]),
    );
    Widget body;
    if (Backend.ready && !signedIn) {
      body = loginPrompt(context, ref, 'retrouver vos favoris');
    } else if (kind == 'talent') {
      body = ListView(children: [chips, mNote('Les talents ne peuvent pas encore être enregistrés dans vos favoris. Seuls les produits, services et projets le peuvent.')]);
    } else {
      body = PagedCatalog(
        fn: 'my_favorites',
        params: {if (kind.isNotEmpty) 'p_offer_type': kind},
        reloadKey: '$favCount-$_bump',
        scrollable: true,
        header: Padding(padding: const EdgeInsets.only(bottom: 8), child: chips),
        emptyText: kind.isEmpty ? 'Vous n’avez encore aucun favori.\nTouchez le cœur d’un produit pour le retrouver ici.' : 'Aucun favori de ce type pour le moment.',
        tileBuilder: (x) => x['available'] == false ? _gone(x) : MarcheProductTile(card: x),
      );
    }
    return DiscoPage(title: 'Mes favoris', child: body);
  }
}
