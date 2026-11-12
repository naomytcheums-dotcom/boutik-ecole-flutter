import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import 'auth.dart';
import 'communities.dart';
import 'marche/marche_data.dart' show kInk, kLine, mst;
import 'marche/marche_widgets.dart' show MarchePage, mNote, mSectionTitle;

/// Explorer les communautés : recherche (nom, centre d'intérêt, promotion, filière), filtre par type, puis trois sections :
/// « Pour toi » (la filière de la personne), « Populaires cette semaine » (celles qui bougent le plus) et « Toutes ».
class CommunityExploreScreen extends ConsumerStatefulWidget {
  const CommunityExploreScreen({super.key});

  @override
  ConsumerState<CommunityExploreScreen> createState() => _CommunityExploreScreenState();
}

class _CommunityExploreScreenState extends ConsumerState<CommunityExploreScreen> {
  final _q = TextEditingController();
  String _kind = '';

  static const kinds = {'': 'Toutes', 'filiere': 'Filières', 'promo': 'Promos', 'interest': 'Centres d’intérêt', 'alumni': 'Alumni', 'project': 'Projets'};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Widget _card(Community c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
        child: CommunityCard(
          c: c,
          onOpen: () {
            ref.read(selectedCommunityProvider.notifier).select(c);
            context.push('/communaute');
          },
          onJoin: () => joinCommunity(context, ref, c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(communitiesProvider);
    final myDept = (ref.watch(authProvider).current?.department ?? '').toLowerCase();
    final list = all == null ? null : [for (final c in all) if (c.status == 'active' && (_kind.isEmpty || c.kind == _kind)) c];
    final forMe = list == null || myDept.isEmpty ? const <Community>[] : [for (final c in list) if (c.department.isNotEmpty && (c.department.toLowerCase().contains(myDept) || myDept.contains(c.department.toLowerCase()))) c];
    final popular = list == null ? const <Community>[] : ([...list]..sort((a, b) => b.postsWeek.compareTo(a.postsWeek))).where((c) => c.postsWeek > 0).take(5).toList();
    return MarchePage(
      title: 'Communautés',
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => ref.read(communitiesProvider.notifier).refresh(v),
            decoration: InputDecoration(hintText: 'Un groupe, une compétence, une filière, une promo', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final e in kinds.entries)
              GestureDetector(
                onTap: () => setState(() => _kind = e.key),
                child: Center(child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: _kind == e.key ? kInk : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _kind == e.key ? kInk : kLine)), child: Text(e.value, style: mst(12.5, w: FontWeight.w600, c: _kind == e.key ? Colors.white : kInk)))),
              ),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: GestureDetector(onTap: () => context.push('/innovations'), child: Container(height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)), child: Text('Innovations : SOS Cours, défis, mur des victoires…', style: mst(12.5, w: FontWeight.w700))))),
        if (list == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          Column(children: [
            mNote('Sois le premier à créer ta communauté !\nFilière, promo, centre d’intérêt, anciens ou projet : en quelques secondes.'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: GestureDetector(onTap: () => createCommunityFlow(context, ref), child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(4)), child: Text('Créer une communauté', style: mst(14, w: FontWeight.w700, c: Colors.white)))),
            ),
          ])
        else ...[
          if (forMe.isNotEmpty) ...[mSectionTitle('Pour toi'), for (final c in forMe) _card(c)],
          if (popular.isNotEmpty) ...[mSectionTitle('Populaires cette semaine'), for (final c in popular) _card(c)],
          mSectionTitle('Toutes les communautés'),
          for (final c in list) _card(c),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(onTap: () => createCommunityFlow(context, ref), child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(4)), child: Text('Créer une communauté', style: mst(14, w: FontWeight.w700, c: Colors.white)))),
          ),
        ],
      ]),
    );
  }
}
