import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart' show allProductsProvider;
import 'store.dart';
import 'talents.dart' show visibleTalentsProvider;

/// Accueil (03), connecté au serveur : produits publiés et talents réels. Aucun produit ni profil de maquette n'est affiché ;
/// sans donnée, un état vide explicite prend la place. Hors connexion au serveur, la maquette reste affichée comme démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class LiveTalent {
  const LiveTalent({required this.id, required this.name, required this.department, required this.skills, required this.avatarUrl, required this.certified});
  final String id, name, department, skills, avatarUrl;
  final bool certified;

  static LiveTalent fromRow(Map x) => LiveTalent(
        id: '${x['id']}',
        name: '${x['name']}',
        department: '${x['department'] ?? ''}',
        skills: '${x['skills'] ?? ''}',
        avatarUrl: '${x['avatar_url'] ?? ''}',
        certified: x['certified'] == true,
      );

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }
}

/// `null` : lecture en cours, visiteur ou serveur absent ; liste vide : aucun talent à présenter.
class TalentsNotifier extends Notifier<List<LiveTalent>?> {
  bool error = false;

  @override
  List<LiveTalent>? build() {
    if (!Backend.ready) return null;
    final signedIn = ref.watch(authProvider.select((a) => a.current != null));
    if (!signedIn) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('talents_list', {'p_query': '', 'p_limit': 12});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) LiveTalent.fromRow(x as Map)];
  }
}

final liveTalentsProvider = NotifierProvider<TalentsNotifier, List<LiveTalent>?>(TalentsNotifier.new);

/// « Talents à découvrir » : cartes défilantes horizontalement, avec chargement, état vide et invitation à se connecter.
class HomeTalents extends ConsumerWidget {
  const HomeTalents({super.key, this.width = 368, this.height = 200});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t, {String? action, VoidCallback? onTap}) => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t, textAlign: TextAlign.center, style: _st(12.5, c: _grey).copyWith(height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(20)), child: Text(action, style: _st(12.5, w: FontWeight.w600, c: Colors.white))),
              ),
            ],
          ]),
        );
    final signedIn = ref.watch(authProvider.select((a) => a.current != null));
    if (!signedIn) return note('Connectez-vous pour découvrir les talents de la communauté.', action: 'Se connecter', onTap: () => gOpen(context, '11'));
    final list = ref.watch(liveTalentsProvider);
    if (list == null) return note('Chargement des talents…');
    if (list.isEmpty) {
      return note(ref.read(liveTalentsProvider.notifier).error ? 'Les talents ne peuvent pas être chargés pour le moment.' : 'Aucun talent à présenter pour le moment.\nLes étudiants qui renseignent leurs compétences apparaissent ici.');
    }
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final t = list[i];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => gOpen(context, '70'),
            child: Container(
              width: 156,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Avatar(t),
                const SizedBox(height: 10),
                Row(children: [
                  Flexible(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13, w: FontWeight.w700))),
                  if (t.certified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Color(0xFF2F6BFF))),
                ]),
                if (t.department.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t.department, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11, c: _grey))),
                const SizedBox(height: 6),
                Expanded(child: Text(t.skills, maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: const Color(0xFF4A4854)).copyWith(height: 1.4))),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.t, {this.size = 44});
  final LiveTalent t;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget initials() => Container(width: size, height: size, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDE9F6)), child: Text(t.initials, style: _st(size * .34, w: FontWeight.w700, c: const Color(0xFF4A4854))));
    if (t.avatarUrl.isEmpty) return initials();
    return ClipOval(child: Image.network(t.avatarUrl, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => initials()));
  }
}

/// Deux produits publiés (les plus récents du catalogue), ou un état vide ; la photo vient de l'annonce, sinon un visuel neutre.
class HomeProducts extends ConsumerWidget {
  const HomeProducts({super.key, this.width = 368, this.height = 229});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(allProductsProvider).where((p) => !p.showcase).take(2).toList();
    if (list.isEmpty) {
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
        child: Text('Aucun produit publié pour le moment.\nLes créations des étudiants apparaîtront ici dès leur publication.', textAlign: TextAlign.center, style: _st(12.5, c: _grey).copyWith(height: 1.5)),
      );
    }
    return Row(children: [
      for (var i = 0; i < list.length; i++) ...[
        if (i > 0) const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref.read(selectedProductProvider.notifier).select(list[i].title);
              gOpen(context, '05');
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 163,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: list[i].image == 'placeholder' || list[i].image.isEmpty ? Image.asset(neutralProductImage, fit: BoxFit.cover) : (list[i].image.startsWith('http') ? Image.network(list[i].image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Image.asset(neutralProductImage, fit: BoxFit.cover)) : Image.asset(list[i].image, fit: BoxFit.cover)),
                ),
              ),
              const SizedBox(height: 8),
              Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, w: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(fcfa(list[i].price), style: _st(10.5, w: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(list[i].seller, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(9.5, c: _grey)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

/// Photo d'un talent de la liste (écran 70) : photo du profil réel, sinon initiales ; la maquette (démonstration) garde ses visuels.
class TalentAvatar extends ConsumerWidget {
  const TalentAvatar({super.key, required this.index});
  final int index;

  static const _demo = ['d902a4aabb7fd7d1d301a3bebd0f8ff54ecefb47', 'ebf23a969ca7b1083d1dcab994c4899c0b4db38b'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(liveTalentsProvider) ?? const <LiveTalent>[];
    if (!Backend.ready) return ClipOval(child: Image.asset('assets/figma/img/${_demo[index % 2]}.png', fit: BoxFit.cover));
    // les lignes suivent la liste filtrée ; on retrouve la personne par son rang parmi les talents visibles
    final shown = ref.watch(visibleTalentsProvider);
    if (index >= shown.length) return const SizedBox.shrink();
    final t = list.where((e) => e.name == shown[index].name).toList();
    return _Avatar(t.isEmpty ? LiveTalent(id: '', name: shown[index].name, department: '', skills: '', avatarUrl: shown[index].avatarUrl, certified: false) : t.first, size: 50);
  }
}
