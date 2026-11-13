import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gImg, gToast;
import '../i18n.dart' show Text;
import '../nav.dart' show gTab;
import 'tp_ui.dart' show GlassBack;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Trouver des coéquipiers : étudiants qui ont renseigné leurs compétences, recherche sur la page, filtres (catégories gérées par l'administrateur
/// + filière), invitation d'équipe avec réponse. Tout vient du serveur (migration 20261114001500) ; aucun talent n'est inventé.

class MateCategory {
  const MateCategory({required this.id, required this.label, this.keywords = const [], this.active = true});
  final String id, label;
  final List<String> keywords;
  final bool active;
  factory MateCategory.fromJson(Map<String, dynamic> j) =>
      MateCategory(id: '${j['id']}', label: '${j['label']}', keywords: [for (final k in (j['keywords'] as List? ?? const [])) '$k'], active: j['active'] != false);
}

class MateQuery {
  const MateQuery({this.q = '', this.category = '', this.department = ''});
  final String q, category, department;
  MateQuery copy({String? q, String? category, String? department}) => MateQuery(q: q ?? this.q, category: category ?? this.category, department: department ?? this.department);
  bool get filtered => category.isNotEmpty || department.trim().isNotEmpty;
  Map<String, dynamic> get params => {
        'p_query': q.trim(),
        if (category.isNotEmpty) 'p_category': category,
        if (department.trim().isNotEmpty) 'p_department': department.trim(),
        'p_limit': 40,
      };
  @override
  bool operator ==(Object other) => other is MateQuery && other.q == q && other.category == category && other.department == department;
  @override
  int get hashCode => Object.hash(q, category, department);
}

final mateCategoriesProvider = FutureProvider.autoDispose<List<MateCategory>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('mate_categories_list', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) MateCategory.fromJson(Map<String, dynamic>.from(x as Map))];
});

final matesSearchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, MateQuery>((ref, q) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('mates_search', q.params);
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

final myMateInvitesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, role) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('my_teammate_invites', {'p_role': role});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

/// Texte du bouton d'invitation selon l'état renvoyé par le serveur (aucune invitation, en attente, acceptée, déclinée).
String mateInviteLabel(Object? status) => switch ('$status') {
      'pending' => 'En attente',
      'accepted' => 'Écrire',
      'declined' => 'Réinviter',
      _ => 'Inviter',
    };

/// « 3 talents disponibles », « 1 talent disponible » ou « Aucun talent trouvé ».
String mateCountLabel(int n) => n == 0 ? 'Aucun talent trouvé' : n == 1 ? '1 talent disponible' : '$n talents disponibles';

Future<bool> _call(BuildContext context, String fn, Map<String, dynamic> params, {String? ok}) async {
  final r = await marcheCall(fn, params);
  if (!context.mounted) return false;
  if (r.error != null) {
    gToast(context, Backend.userMessage('${r.error}'));
    return false;
  }
  if (ok != null) gToast(context, ok);
  return true;
}

/// Menu du bas de l'application en ligne : Kéla, messages, accueil, réseau social, profil. La pastille sombre suit l'onglet de la page.
class MateNavPill extends StatelessWidget {
  const MateNavPill({super.key, this.active});

  /// Onglet allumé (0 Kéla, 1 messages, 2 accueil, 3 réseau social, 4 profil) ; -1 = aucun.
  final int? active;

  static const _targets = ['231', '52', '03', '244', '10'];
  static const _labels = ['Kéla', 'Messages', 'Accueil', 'Réseau social', 'Profil'];

  @override
  Widget build(BuildContext context) {
    final on = active ?? -1;
    Widget glyph(int k, Color c) => switch (k) {
          0 => Image.asset('assets/figma/img/2b51b5d6469cca917952ac344a2ddf9cc1440830.png', width: 30, height: 30, fit: BoxFit.contain),
          1 => Icon(Icons.chat_bubble_outline, size: 23, color: c),
          2 => Icon(Icons.home_rounded, size: 25, color: c),
          3 => Icon(Icons.groups_outlined, size: 25, color: c),
          _ => Icon(Icons.person_outline, size: 25, color: c),
        };
    return Container(
      width: 346,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x29403366), offset: Offset(0, 10), blurRadius: 24)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var k = 0; k < 5; k++)
          Semantics(
            button: true,
            selected: k == on,
            label: _labels[k],
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => gTab(context, _targets[k]),
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: k == on
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xF22A2D36), Color(0xF20E0F14)]),
                        border: Border.all(color: const Color(0xB3E3E6EE), width: 1.6),
                      )
                    : const BoxDecoration(shape: BoxShape.circle),
                child: glyph(k, k == on ? Colors.white : const Color(0xFF111015)),
              ),
            ),
          ),
      ]),
    );
  }
}

class TeammatesScreen extends ConsumerStatefulWidget {
  const TeammatesScreen({super.key});

  @override
  ConsumerState<TeammatesScreen> createState() => _MatesState();
}

class _MatesState extends ConsumerState<TeammatesScreen> {
  final _q = TextEditingController();
  MateQuery _query = const MateQuery();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _set(MateQuery q) => setState(() => _query = q);

  /// La recherche se fait sur cette page, en tapant ou en touchant la loupe : jamais de saut vers une autre page.
  void _search(String v) {
    _debounce?.cancel();
    _set(_query.copy(q: v));
  }

  void _typing(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _set(_query.copy(q: v));
    });
  }

  Future<void> _invite(Map<String, dynamic> m) async {
    if (!await requireLogin(context, ref, 'inviter un coéquipier') || !mounted) return;
    if ('${m['invite']}' == 'pending') {
      gToast(context, 'Invitation déjà envoyée : ${m['name']} doit répondre.');
      return;
    }
    if ('${m['invite']}' == 'accepted' && '${m['invite_id'] ?? ''}'.isNotEmpty) {
      await openTeammateChat(context, '${m['invite_id']}', '${m['name']}');
      return;
    }
    final msg = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Inviter ${m['name']}', style: mst(18, w: FontWeight.w800)),
          Text('${m['name']} reçoit une notification et répond dans l’application.', style: mst(12.5, c: kGrey)),
          const SizedBox(height: 12),
          TextField(controller: msg, maxLength: 500, maxLines: 3, decoration: InputDecoration(labelText: 'Message (facultatif)', hintText: 'Pourquoi vous l’invitez, pour quel projet…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: mButton('Annuler', () => Navigator.pop(c, false), dark: false)),
            const SizedBox(width: 10),
            Expanded(child: mButton('Envoyer', () => Navigator.pop(c, true))),
          ]),
        ]),
      ),
    );
    if (ok != true || !mounted) return;
    if (await _call(context, 'teammate_invite', {'p_user': m['id'], 'p_message': msg.text}, ok: 'Invitation envoyée à ${m['name']}')) ref.invalidate(matesSearchProvider);
  }

  Future<void> _filters(List<MateCategory> cats) async {
    var cat = _query.category;
    final dept = TextEditingController(text: _query.department);
    final res = await showModalBottomSheet<MateQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Filtrer les talents', style: mst(18, w: FontWeight.w800)),
            const SizedBox(height: 12),
            MDropdown(label: 'Catégorie', value: cat, items: {'': 'Toutes les catégories', for (final k in cats) k.id: k.label}, onChanged: (v) => setS(() => cat = v)),
            const SizedBox(height: 10),
            TextField(controller: dept, decoration: InputDecoration(labelText: 'Filière', hintText: 'Génie informatique, Gestion…', border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: mButton('Réinitialiser', () => Navigator.pop(c, _query.copy(category: '', department: '')), dark: false)),
              const SizedBox(width: 10),
              Expanded(child: mButton('Appliquer', () => Navigator.pop(c, _query.copy(category: cat, department: dept.text)))),
            ]),
          ]),
        ),
      ),
    );
    if (res != null && mounted) _set(res);
  }

  Future<void> _invitations() async {
    if (!await requireLogin(context, ref, 'voir vos invitations') || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => const MateInvitesSheet(),
    );
    if (mounted) ref.invalidate(matesSearchProvider);
  }

  Future<void> _manage() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (c) => const MateCategoriesAdminSheet(),
    );
    if (mounted && _query.category.isNotEmpty) {
      final still = ref.read(mateCategoriesProvider).asData?.value.any((k) => k.id == _query.category) ?? true;
      if (!still) _set(_query.copy(category: ''));
    }
  }

  Widget _avatar(Map<String, dynamic> m) {
    final url = '${m['avatar_url'] ?? ''}';
    final name = '${m['name']}'.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return SizedBox(
      width: 50,
      height: 50,
      child: ClipOval(
        child: url.startsWith('http')
            ? MImage(url, icon: Icons.person_outline)
            : Container(color: const Color(0xFFEFEBFA), alignment: Alignment.center, child: Text(initial, style: mst(18, w: FontWeight.w800, c: kViolet))),
      ),
    );
  }

  Widget _row(Map<String, dynamic> m) {
    final st = '${m['invite'] ?? ''}';
    final done = st == 'pending' || st == 'accepted';
    final dept = '${m['department'] ?? ''}'.trim();
    final skills = '${m['skills'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        _avatar(m),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700)),
            Text([if (dept.isNotEmpty) dept, if (skills.isNotEmpty) skills].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _invite(m),
          child: Container(
            constraints: const BoxConstraints(minHeight: 36, minWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? const Color(0xFFDDF5EC) : const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(18)),
            child: Text(mateInviteLabel(st), style: mst(12, w: FontWeight.w700, c: done ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0))),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(mateCategoriesProvider);
    final list = ref.watch(matesSearchProvider(_query));
    final admin = ref.watch(authProvider.select((a) => a.current?.staff == 'admin'));
    final catList = cats.asData?.value ?? const <MateCategory>[];
    final count = list.asData?.value.length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: Row(children: [
                Semantics(button: true, label: 'Retour', excludeSemantics: true, child: GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03'))),
                Expanded(child: Text('Trouver des coéquipiers', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(20, w: FontWeight.w800))),
                IconButton(tooltip: 'Mes invitations', onPressed: _invitations, icon: const Icon(Icons.mail_outline)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onChanged: _typing,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      hintText: 'Compétence, filière, nom…',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: IconButton(tooltip: 'Rechercher', onPressed: () => _search(_q.text), icon: const Icon(Icons.search)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Filtres',
                  child: GestureDetector(
                    onTap: () => _filters(catList),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: _query.filtered ? kViolet : Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.tune, color: _query.filtered ? Colors.white : kInk),
                    ),
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 42,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                _chip('Tous', _query.category.isEmpty, () => _set(_query.copy(category: ''))),
                for (final k in catList) _chip(k.label, _query.category == k.id, () => _set(_query.copy(category: k.id))),
                if (admin) _chip('Gérer les catégories', false, _manage, icon: Icons.edit_outlined),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text(count == null ? ' ' : mateCountLabel(count), style: mst(15, w: FontWeight.w800))),
            ),
            Expanded(
              child: list.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _error(e),
                data: (rows) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
                  if (rows.isEmpty) mNote('Aucun étudiant ne correspond. Essayez une autre compétence, filière ou catégorie.'),
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 62, color: Color(0xFFF2EFF6)),
                    _row(rows[i]),
                  ],
                  if (rows.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text('Les invitations sont envoyées par notification dans l’application.', style: mst(12, c: kGrey))),
                ]),
              ),
            ),
          ]),
          const Positioned(left: 0, right: 0, bottom: 14, child: Center(child: MateNavPill())),
        ]),
      ),
    );
  }

  Widget _error(Object e) {
    final msg = e is MarcheException ? e.toString() : marcheErrorText('$e');
    final needLogin = ref.read(authProvider).current == null;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      mNote(needLogin ? 'Connectez-vous pour trouver des coéquipiers.' : msg),
      if (needLogin) mButton('Se connecter', () async {
        if (await requireLogin(context, ref, 'trouver des coéquipiers') && mounted) ref.invalidate(matesSearchProvider);
      }, width: 200),
    ]);
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? kInk : const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(17)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(icon, size: 16, color: kGrey)),
              Text(label, style: mst(12.5, w: on ? FontWeight.w700 : FontWeight.w500, c: on ? Colors.white : kGrey)),
            ]),
          ),
        ),
      );
}

/// Invitations reçues (accepter / refuser) et envoyées (état).
class MateInvitesSheet extends ConsumerWidget {
  const MateInvitesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final received = ref.watch(myMateInvitesProvider('received'));
    final sent = ref.watch(myMateInvitesProvider('sent'));
    String state(String s) => switch (s) { 'accepted' => 'Acceptée', 'declined' => 'Déclinée', 'cancelled' => 'Annulée', _ => 'En attente' };
    Future<void> decide(String id, bool yes) async {
      if (await _call(context, 'teammate_invite_decide', {'p_id': id, 'p_accept': yes}, ok: yes ? 'Invitation acceptée' : 'Invitation déclinée')) {
        ref.invalidate(myMateInvitesProvider);
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Text('Mes invitations', style: mst(18, w: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Reçues', style: mst(14, w: FontWeight.w700)),
        mAsync<List<Map<String, dynamic>>>(received, (rows) => rows.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Aucune invitation reçue.', style: mst(13, c: kGrey)))
            : Column(children: [
                for (final i in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i['other']} vous invite', style: mst(13.5, w: FontWeight.w700)),
                      if ('${i['message']}'.isNotEmpty) Text('${i['message']}', style: mst(12.5, c: kGrey)),
                      if ('${i['status']}' == 'accepted') Padding(padding: const EdgeInsets.only(top: 6), child: mButton('Écrire à ${i['other']}', () => openTeammateChat(context, '${i['id']}', '${i['other']}'), icon: Icons.chat_bubble_outline)),
                      if ('${i['status']}' == 'pending')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(children: [
                            Expanded(child: mButton('Refuser', () => decide('${i['id']}', false), dark: false)),
                            const SizedBox(width: 10),
                            Expanded(child: mButton('Accepter', () => decide('${i['id']}', true))),
                          ]),
                        )
                      else
                        Text(state('${i['status']}'), style: mst(12, w: FontWeight.w700, c: kGrey)),
                    ]),
                  ),
              ])),
        const SizedBox(height: 14),
        Text('Envoyées', style: mst(14, w: FontWeight.w700)),
        mAsync<List<Map<String, dynamic>>>(sent, (rows) => rows.isEmpty
            ? Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Aucune invitation envoyée.', style: mst(13, c: kGrey)))
            : Column(children: [
                for (final i in rows)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text('${i['other']}', style: mst(13.5))), if ('${i['status']}' == 'accepted') TextButton(onPressed: () => openTeammateChat(context, '${i['id']}', '${i['other']}'), child: Text('Écrire')) else Text(state('${i['status']}'), style: mst(12, w: FontWeight.w700, c: kGrey))])),
              ])),
      ]),
    );
  }
}

/// Catégories de filtre : l'administrateur ajoute, renomme, désactive ou supprime ; les étudiants voient le changement aussitôt.
class MateCategoriesAdminSheet extends ConsumerWidget {
  const MateCategoriesAdminSheet();

  Future<void> _edit(BuildContext context, WidgetRef ref, MateCategory? k) async {
    final label = TextEditingController(text: k?.label ?? ''), words = TextEditingController(text: (k?.keywords ?? const []).join(', '));
    var active = k?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(k == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: label, decoration: const InputDecoration(labelText: 'Nom affiché', hintText: 'Juristes')),
              const SizedBox(height: 8),
              TextField(controller: words, maxLines: 3, decoration: const InputDecoration(labelText: 'Mots-clés de compétence', hintText: 'droit, juridique, contrat', helperText: 'Séparés par des virgules ; un étudiant dont les compétences ou la filière en contiennent un apparaît dans cette catégorie.')),
              Row(children: [Expanded(child: Text('Visible des étudiants', style: mst(13))), Switch(value: active, onChanged: (v) => setS(() => active = v))]),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Enregistrer'))],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final kw = [for (final w in words.text.split(RegExp(r'[,;\n]'))) if (w.trim().isNotEmpty) w.trim()];
    if (await _call(context, 'mate_category_save', {'p_id': k?.id, 'p_label': label.text, 'p_keywords': kw, 'p_position': 0, 'p_active': active}, ok: 'Catégorie enregistrée')) ref.invalidate(mateCategoriesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, MateCategory k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Supprimer « ${k.label} » ?'),
        content: Text('Les étudiants ne verront plus cette catégorie. Leurs profils ne sont pas touchés.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Supprimer'))],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await _call(context, 'mate_category_delete', {'p_id': k.id}, ok: 'Catégorie supprimée')) ref.invalidate(mateCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(mateCategoriesProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
        Text('Catégories de coéquipiers', style: mst(18, w: FontWeight.w800)),
        Text('Réservé à l’administrateur. Les changements sont visibles tout de suite par les étudiants.', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 10),
        mAsync<List<MateCategory>>(cats, (rows) => Column(children: [
              for (final k in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(k.label, style: mst(14, w: FontWeight.w700)),
                  subtitle: Text('${k.active ? '' : 'Masquée · '}${k.keywords.join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, k)),
                    IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, k)),
                  ]),
                ),
            ])),
        const SizedBox(height: 8),
        mButton('Ajouter une catégorie', () => _edit(context, ref, null), icon: Icons.add),
      ]),
    );
  }
}

// ------------------------------------------------------------------ messagerie entre coéquipiers

Future<void> openTeammateChat(BuildContext context, String inviteId, String otherName) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TeammateChatScreen(inviteId: inviteId, otherName: otherName)));

/// Messages échangés entre deux coéquipiers (invitation acceptée). Rafraîchi toutes les 4 secondes tant que l'écran est ouvert.
class TeammateChatScreen extends ConsumerStatefulWidget {
  const TeammateChatScreen({super.key, required this.inviteId, required this.otherName});
  final String inviteId, otherName;

  @override
  ConsumerState<TeammateChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<TeammateChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = const [];
  String? _error;
  bool _loading = true, _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await marcheCall('teammate_messages_list', {'p_invite': widget.inviteId});
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.error != null) {
        _error = Backend.userMessage('${r.error}');
      } else {
        _error = null;
        final next = [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        final grew = next.length != _msgs.length;
        _msgs = next;
        if (grew) WidgetsBinding.instance.addPostFrameCallback((_) => _scroll.hasClients ? _scroll.jumpTo(_scroll.position.maxScrollExtent) : null);
      }
    });
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await marcheCall('teammate_message_send', {'p_invite': widget.inviteId, 'p_body': t});
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    _text.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: kInk, title: Text(widget.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(17, w: FontWeight.w800))),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? mNote(_error!)
                      : _msgs.isEmpty
                          ? mNote('Aucun message pour le moment.\nPrésentez-vous et organisez votre équipe.')
                          : ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                              for (final m in _msgs)
                                Align(
                                  alignment: m['mine'] == true ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                    decoration: BoxDecoration(color: m['mine'] == true ? kInk : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
                                    child: Text('${m['body']}', style: mst(13.5, c: m['mine'] == true ? Colors.white : kInk).copyWith(height: 1.4)),
                                  ),
                                ),
                            ]),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(child: TextField(controller: _text, maxLength: 1000, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: 'Votre message…', counterText: '', filled: true, fillColor: const Color(0xFFF2EFF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
                const SizedBox(width: 8),
                IconButton(tooltip: 'Envoyer', onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ]),
        ),
      );
}
