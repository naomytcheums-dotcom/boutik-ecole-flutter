import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../product_card.dart';
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Liste paginée des offres (ou des boutiques) servie par une fonction du serveur : première page, « Charger plus », chargement à
/// l'approche de la fin quand la liste défile seule, états de chargement, d'échec (avec « Réessayer») et de liste vide.

/// Taille d'une page demandée au serveur.
const kCatalogPage = 24;

typedef MarcheFetcher = Future<List<Map<String, dynamic>>> Function(String fn, Map<String, dynamic> params);

/// Lecture d'une fonction du serveur ; remplaçable dans les tests.
final marcheFetcherProvider = Provider<MarcheFetcher>((ref) => (fn, params) async {
      final r = await marcheCall(fn, params);
      if (r.error != null) throw MarcheException(r.error);
      return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    });

class PagedCatalog extends ConsumerStatefulWidget {
  const PagedCatalog({
    super.key,
    required this.fn,
    this.params = const {},
    this.paged = true,
    this.scrollable = false,
    this.header,
    this.emptyText = 'Aucun produit ne correspond à votre recherche.',
    this.rowBuilder,
    this.tileBuilder,
    this.reloadKey,
    this.onLoaded,
    this.padding = const EdgeInsets.only(bottom: 90),
  });

  final String fn;
  final Map<String, dynamic> params;

  /// Faux : une seule page (fonctions sans décalage, comme `trending_products`).
  final bool paged;

  /// Vrai : la liste défile seule (écran dédié) et charge la page suivante près de la fin ; faux : à placer dans un défilement parent.
  final bool scrollable;
  final Widget? header;
  final String emptyText;

  /// Affiche chaque ligne autrement que par une tuile produit (boutiques).
  final Widget Function(Map<String, dynamic> row)? rowBuilder;

  /// Remplace la tuile produit dans la grille (favoris dont l'annonce n'est plus en ligne).
  final Widget Function(Map<String, dynamic> row)? tileBuilder;

  /// Un changement de cette valeur relit la liste depuis la première page.
  final Object? reloadKey;

  /// Appelé après chaque lecture réussie avec les lignes déjà chargées et l'indication « il en reste ».
  final void Function(int loaded, bool more)? onLoaded;
  final EdgeInsets padding;

  @override
  ConsumerState<PagedCatalog> createState() => _PagedCatalogState();
}

class _PagedCatalogState extends ConsumerState<PagedCatalog> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  bool _loading = true, _more = false, _loadingMore = false;
  Object? _error;
  int _token = 0;

  String get _key => '${widget.fn}|${widget.params}|${widget.paged}|${widget.reloadKey}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    Future.microtask(_reset);
  }

  @override
  void didUpdateWidget(PagedCatalog old) {
    super.didUpdateWidget(old);
    if ('${old.fn}|${old.params}|${old.paged}|${old.reloadKey}' != _key) _reset();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollable && _scroll.hasClients && _scroll.position.extentAfter < 600) _loadMore();
  }

  Future<List<Map<String, dynamic>>> _fetch(int offset) => ref.read(marcheFetcherProvider)(widget.fn, {...widget.params, 'p_limit': widget.paged ? kCatalogPage : 50, if (widget.paged) 'p_offset': offset});

  Future<void> _reset() async {
    if (!mounted) return;
    final token = ++_token;
    setState(() {
      _items.clear();
      _loading = true;
      _error = null;
      _more = false;
      _loadingMore = false;
    });
    try {
      final page = await _fetch(0);
      if (!mounted || token != _token) return;
      setState(() {
        _items.addAll(page);
        _more = widget.paged && page.length >= kCatalogPage;
        _loading = false;
      });
      widget.onLoaded?.call(_items.length, _more);
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _error = e is MarcheException ? e.code : e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_more) return;
    final token = _token;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_items.length);
      if (!mounted || token != _token) return;
      setState(() {
        _items.addAll(page);
        _more = page.length >= kCatalogPage;
        _loadingMore = false;
      });
      widget.onLoaded?.call(_items.length, _more);
    } catch (e) {
      if (!mounted || token != _token) return;
      setState(() {
        _loadingMore = false;
        _more = false;
        _error = e is MarcheException ? e.code : e;
      });
    }
  }

  Widget _status() {
    if (_loading) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
    if (_error != null && _items.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        mNote(marcheErrorText(_error)),
        if (_error != 'offline' && _error != 'missing') mButton('Réessayer', _reset, dark: false),
      ]);
    }
    if (_items.isEmpty) return mNote(widget.emptyText);
    return const SizedBox.shrink();
  }

  Widget _footer() {
    if (_loadingMore) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    if (_error != null && _items.isNotEmpty) {
      return Padding(padding: const EdgeInsets.all(12), child: Center(child: mButton('Réessayer de charger la suite', () {
            setState(() {
              _error = null;
              _more = true;
            });
            _loadMore();
          }, dark: false)));
    }
    if (!_more) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: mButton('Charger plus', _loadMore, dark: false, width: double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    if (widget.scrollable) {
      return LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 5 : (c.maxWidth >= 600 ? 3 : 2);
        return CustomScrollView(controller: _scroll, slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          if (_items.isEmpty) SliverToBoxAdapter(child: status),
          if (_items.isNotEmpty && widget.rowBuilder != null) SliverList.builder(itemCount: _items.length, itemBuilder: (_, i) => widget.rowBuilder!(_items[i])),
          if (_items.isNotEmpty && widget.rowBuilder == null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.builder(
                itemCount: _items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 20, childAspectRatio: productCardAspect((c.maxWidth - 24 - 10 * (cols - 1)) / cols)),
                itemBuilder: (_, i) => widget.tileBuilder?.call(_items[i]) ?? MarcheProductTile(card: _items[i]),
              ),
            ),
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: widget.padding.bottom), child: _footer())),
        ]);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.header != null) widget.header!,
      if (_items.isEmpty) status,
      if (_items.isNotEmpty) widget.rowBuilder == null ? MarcheGrid(cards: _items, tileBuilder: widget.tileBuilder) : Column(children: [for (final r in _items) widget.rowBuilder!(r)]),
      _footer(),
    ]);
  }
}
