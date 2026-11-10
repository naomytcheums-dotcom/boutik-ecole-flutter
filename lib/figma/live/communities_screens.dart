import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'backend.dart';
import 'communities.dart';
import 'talents.dart' show askText;

/// Écrans des communautés façon « groupes » : création (validation par l'administrateur, description de 500 mots au plus,
/// département lu dans le référentiel universitaire en base), page d'une communauté (publications, membres, mentors) et file
/// de validation de l'équipe. Tout vient du serveur ; aucune donnée d'exemple.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _violet = Color(0xFF5A3FE0);
const _line = Color(0xFFECE8F2);
const _bg = Color(0xFFF7F6F4);

/// Limite de la description d'une communauté.
const kCommunityMaxWords = 500;

/// Nombre de mots d'un texte (séparés par des espaces ou retours à la ligne).
int wordCount(String text) {
  final t = text.trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}

TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leading: IconButton(tooltip: 'Retour', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(17, w: FontWeight.w700)),
    );

Widget _button(String label, VoidCallback? onTap, {bool dark = true, bool busy = false}) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onTap == null ? const Color(0xFFB9B4C7) : (dark ? _ink : Colors.white), borderRadius: BorderRadius.circular(24), border: dark ? null : Border.all(color: _line)),
        child: Text(busy ? 'Un instant…' : label, textAlign: TextAlign.center, style: _st(14, w: FontWeight.w700, c: dark ? Colors.white : _ink)),
      ),
    );

// ------------------------------------------------------------------ référentiel : départements

class DepartmentOption {
  const DepartmentOption(this.id, this.name, this.institution);
  final String id, name, institution;
  String get label => institution.isEmpty ? name : '$name · $institution';
}

/// Départements vérifiés du référentiel universitaire (table `departments`), jamais saisis en dur.
final communityDepartmentsProvider = FutureProvider<List<DepartmentOption>>((ref) async {
  if (!Backend.ready) return const [];
  final r = await Backend.rows('departments', 'id,name,institutions(name)', eq: {'status': 'verified'}, order: 'name', ascending: true, limit: 500);
  if (r.error != null) throw Exception(r.error);
  return [for (final x in r.rows) DepartmentOption('${x['id']}', '${x['name']}', '${(x['institutions'] as Map?)?['name'] ?? ''}')];
});

// ------------------------------------------------------------------ création

class CommunityCreateScreen extends ConsumerStatefulWidget {
  const CommunityCreateScreen({super.key});
  @override
  ConsumerState<CommunityCreateScreen> createState() => _CommunityCreateState();
}

class _CommunityCreateState extends ConsumerState<CommunityCreateScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _privacy = 'public';
  String? _department;
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.length < 3 || name.length > 60) return setState(() => _error = 'Le nom doit contenir entre 3 et 60 caractères.');
    final words = wordCount(_desc.text);
    if (words > kCommunityMaxWords) return setState(() => _error = 'La description ne doit pas dépasser $kCommunityMaxWords mots ($words saisis).');
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await Backend.rpc('create_community', {'p_name': name, 'p_description': _desc.text.trim(), 'p_category': '', 'p_privacy': _privacy, 'p_rules': '', 'p_department': _department});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _error = Backend.userMessage(r.error!);
      });
      return;
    }
    await ref.read(communitiesProvider.notifier).refresh();
    if (!mounted) return;
    Navigator.of(context).pop();
    gToast(context, 'Communauté envoyée : elle sera publiée après validation par l’administrateur.');
  }

  @override
  Widget build(BuildContext context) {
    final deps = ref.watch(communityDepartmentsProvider);
    final words = wordCount(_desc.text);
    final over = words > kCommunityMaxWords;
    InputDecoration deco(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14));
    Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: _st(13.5, w: FontWeight.w700)));
    Widget privacy(String v, String title, String sub) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _privacy = v),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _privacy == v ? _ink : _line, width: _privacy == v ? 2 : 1)),
            child: Row(children: [
              Icon(_privacy == v ? Icons.radio_button_checked : Icons.radio_button_off, color: _privacy == v ? _ink : _grey),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _st(13.5, w: FontWeight.w700)), Text(sub, style: _st(12, c: _grey))])),
            ]),
          ),
        );
    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar(context, 'Nouvelle communauté'),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(14)),
            child: Text('Votre communauté sera examinée par l’administrateur avant d’être publiée. Vous serez prévenu de sa décision.', style: _st(12.5, c: _ink).copyWith(height: 1.4)),
          ),
          label('Nom de la communauté'),
          TextField(controller: _name, maxLength: 60, decoration: deco('Développeurs du Cameroun').copyWith(counterText: '')),
          label('Département (facultatif)'),
          deps.when(
            loading: () => Text('Chargement des départements…', style: _st(12.5, c: _grey)),
            error: (_, _) => Text('Les départements ne peuvent pas être chargés pour le moment.', style: _st(12.5, c: const Color(0xFFB42318))),
            data: (list) => list.isEmpty
                ? Text('Aucun département n’est encore renseigné dans le référentiel.', style: _st(12.5, c: _grey))
                : DropdownButtonFormField<String?>(
                    initialValue: _department,
                    isExpanded: true,
                    decoration: deco('Choisir un département'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Aucun département')),
                      for (final d in list) DropdownMenuItem<String?>(value: d.id, child: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _department = v),
                  ),
          ),
          label('Description'),
          TextField(controller: _desc, minLines: 5, maxLines: 12, onChanged: (_) => setState(() {}), decoration: deco('À quoi sert cette communauté ? À qui s’adresse-t-elle ?')),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('$words / $kCommunityMaxWords mots', textAlign: TextAlign.right, style: _st(12, w: FontWeight.w600, c: over ? const Color(0xFFB42318) : _grey))),
          label('Confidentialité'),
          privacy('public', 'Publique', 'Tout le monde peut rejoindre et lire.'),
          privacy('approval', 'Privée · sur approbation', 'Les demandes sont examinées par les responsables.'),
          privacy('invite', 'Privée · sur invitation', 'Seules les personnes invitées peuvent entrer.'),
          if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error, style: _st(13, w: FontWeight.w600, c: const Color(0xFFB42318)))),
          const SizedBox(height: 16),
          _button('Envoyer pour validation', over ? null : _submit, busy: _busy),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ page d'une communauté

final selectedCommunityProvider = NotifierProvider<SelectedCommunity, Community?>(SelectedCommunity.new);

class SelectedCommunity extends Notifier<Community?> {
  @override
  Community? build() => null;
  void select(Community? c) => state = c;
}

final communityFeedProvider = NotifierProvider<CommunityFeed, List<Map<String, dynamic>>?>(CommunityFeed.new);

class CommunityFeed extends Notifier<List<Map<String, dynamic>>?> {
  bool error = false;
  @override
  List<Map<String, dynamic>>? build() {
    final c = ref.watch(selectedCommunityProvider);
    if (!Backend.ready || c == null) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final c = ref.read(selectedCommunityProvider);
    if (c == null) return;
    final r = await Backend.rpc('community_feed', {'p_community': c.id, 'p_limit': 50});
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
  }
}

/// Membres actifs d'une communauté (propriétaire, administrateurs, modérateurs, mentors, membres).
final communityMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final r = await Backend.rpc('community_members_list', {'p_community': id, 'p_limit': 300});
  if (r.error != null || r.data is! List) throw Exception(r.error ?? 'Lecture impossible');
  return [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
});

String roleLabel(String role) => switch (role) {
      'owner' => 'Propriétaire',
      'admin' => 'Administrateur',
      'moderator' => 'Modérateur',
      'mentor' => 'Mentor',
      _ => 'Membre',
    };

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _text = TextEditingController();
  bool _busy = false;
  int _tab = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = ref.read(selectedCommunityProvider);
    if (c == null) return;
    setState(() => _busy = true);
    final r = await Backend.rpc('create_community_post', {'p_community': c.id, 'p_body': _text.text});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return;
    }
    _text.clear();
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  /// Recharge l'annuaire puis la communauté ouverte (son état d'adhésion a pu changer).
  Future<void> _reload(String id) async {
    await ref.read(communitiesProvider.notifier).refresh();
    if (!mounted) return;
    final list = ref.read(communitiesProvider) ?? const <Community>[];
    final fresh = list.where((x) => x.id == id).firstOrNull;
    if (fresh != null) ref.read(selectedCommunityProvider.notifier).select(fresh);
    ref.invalidate(communityMembersProvider(id));
  }

  Future<void> _hide(Map<String, dynamic> p) async {
    final r = await Backend.rpc('moderate_community_post', {'p_post': p['id'], 'p_hide': true});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  Future<void> _changeRole(Community c, Map<String, dynamic> m) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Rôle de ${m['name']}', style: _st(15, w: FontWeight.w700))),
          for (final (v, t) in const [('mentor', 'Mentor'), ('moderator', 'Modérateur'), ('admin', 'Administrateur'), ('member', 'Membre simple')])
            ListTile(title: Text(t, style: _st(14, w: FontWeight.w600)), trailing: m['role'] == v ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(ctx, v)),
        ]),
      ),
    );
    if (role == null || role == m['role'] || !mounted) return;
    final r = await Backend.rpc('set_member_role', {'p_community': c.id, 'p_user': m['user_id'], 'p_role': role});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    ref.invalidate(communityMembersProvider(c.id));
    gToast(context, '${m['name']} : ${roleLabel(role).toLowerCase()}');
  }

  Widget _card(Widget child) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)), child: child);

  Widget _tabs() {
    const names = ['Publications', 'Membres', 'Mentors'];
    return SizedBox(
      height: 48,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        for (var i = 0; i < names.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _tab = i),
            child: Center(child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(color: _tab == i ? _ink : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _tab == i ? _ink : _line)), child: Text(names[i], style: _st(12.5, w: FontWeight.w600, c: _tab == i ? Colors.white : _ink)))),
          ),
      ]),
    );
  }

  Widget _header(Community c) {
    final canJoin = c.status == 'active' && !c.isMember && c.myStatus != 'pending' && c.myStatus != 'banned';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name, style: _st(19, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([c.membersLabel, c.privacyLabel, if (c.department.isNotEmpty) c.department].join(' · '), style: _st(12, c: _grey)),
        if (c.description.isNotEmpty) ...[const SizedBox(height: 10), Text(c.description, style: _st(13.5, c: _ink).copyWith(height: 1.5))],
        if (c.isPending) Padding(padding: const EdgeInsets.only(top: 10), child: Text('En attente de validation par l’administrateur.', style: _st(12.5, w: FontWeight.w700, c: const Color(0xFFB45309)))),
        if (c.isRejected) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Refusée${c.decisionNote.isEmpty ? '' : ' : ${c.decisionNote}'}', style: _st(12.5, w: FontWeight.w700, c: const Color(0xFFB42318)))),
        const SizedBox(height: 12),
        if (canJoin) _button(c.actionLabel, () async { await joinCommunity(context, ref, c); if (mounted) await _reload(c.id); }),
        if (c.isMember && c.myRole != 'owner') _button('Quitter la communauté', () async { await leaveCommunity(context, ref, c); if (mounted) await _reload(c.id); }, dark: false),
        if (!canJoin && !c.isMember && c.status == 'active') Text(c.actionLabel, style: _st(13, w: FontWeight.w600, c: _violet)),
      ])),
    );
  }

  Widget _posts(Community c, List<Map<String, dynamic>>? feed) {
    if (feed == null) return const Center(child: CircularProgressIndicator());
    if (ref.read(communityFeedProvider.notifier).error) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('Ce fil est réservé aux membres, ou indisponible pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
    if (feed.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('Aucune publication pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: feed.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = feed[i];
        return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${p['author']}', style: _st(13.5, w: FontWeight.w700))),
            if (c.canManage) GestureDetector(onTap: () => _hide(p), child: Padding(padding: const EdgeInsets.all(4), child: Text('Masquer', style: _st(12, w: FontWeight.w600, c: _grey)))),
          ]),
          const SizedBox(height: 6),
          Text('${p['body']}', style: _st(14).copyWith(height: 1.5)),
        ]));
      },
    );
  }

  Widget _members(Community c, {required bool mentorsOnly}) {
    final async = ref.watch(communityMembersProvider(c.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('La liste des membres est indisponible pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey)))),
      data: (all) {
        final list = mentorsOnly ? [for (final m in all) if (m['role'] == 'mentor') m] : all;
        if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(mentorsOnly ? 'Aucun mentor pour le moment.' : 'Aucun membre.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
        final canRole = c.myRole == 'owner' || c.myRole == 'admin';
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = list[i];
            final manageable = canRole && m['mine'] != true && m['role'] != 'owner';
            return _card(Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF1EEFB), borderRadius: BorderRadius.circular(13)), child: Text('${m['name']}'.characters.first.toUpperCase(), style: _st(15, w: FontWeight.w700, c: _violet))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['name']}', style: _st(13.5, w: FontWeight.w700)), Text(roleLabel('${m['role']}'), style: _st(11.5, c: m['role'] == 'member' ? _grey : _violet))])),
              if (manageable) GestureDetector(onTap: () => _changeRole(c, m), child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.more_horiz))),
            ]));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(selectedCommunityProvider);
    final feed = ref.watch(communityFeedProvider);
    if (c == null) {
      return Scaffold(backgroundColor: _bg, appBar: _bar(context, 'Communauté'), body: const Center(child: Text('Aucune communauté ouverte.')));
    }
    final Widget body = switch (_tab) {
      1 => _members(c, mentorsOnly: false),
      2 => _members(c, mentorsOnly: true),
      _ => _posts(c, feed),
    };
    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar(context, c.name),
      body: SafeArea(
        child: Column(children: [
          _header(c),
          _tabs(),
          Expanded(child: body),
          if (_tab == 0 && c.status == 'active')
            c.isMember
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: Row(children: [
                      Expanded(child: TextField(controller: _text, maxLength: 2000, decoration: InputDecoration(hintText: 'Écrire dans ${c.name}…', counterText: '', filled: true, fillColor: const Color(0xFFF2EFF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
                      const SizedBox(width: 8),
                      IconButton(tooltip: 'Publier', onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded)),
                    ]),
                  )
                : Container(width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(16), child: Text('Rejoignez la communauté pour publier.', textAlign: TextAlign.center, style: _st(13, c: _grey))),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ validation par l'équipe

class CommunityPendingScreen extends ConsumerWidget {
  const CommunityPendingScreen({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> c, bool approve) async {
    String note = '';
    if (!approve) {
      final n = await askText(context, title: 'Motif du refus', body: 'Expliquez brièvement pourquoi « ${c['name']} » n’est pas validée.', hint: 'Motif', ok: 'Refuser', min: 3);
      if (n == null || !context.mounted) return;
      note = n.trim();
    }
    final r = await Backend.rpc('community_decide', {'p_community': c['id'], 'p_approve': approve, 'p_note': note});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Décision impossible', Backend.userMessage(r.error!));
    ref.invalidate(communitiesPendingProvider);
    await ref.read(communitiesProvider.notifier).refresh();
    if (context.mounted) gToast(context, approve ? 'Communauté publiée' : 'Communauté refusée');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(communitiesPendingProvider);
    return Scaffold(
      backgroundColor: _bg,
      appBar: _bar(context, 'Communautés à valider'),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text('Liste indisponible.', style: _st(13.5, c: _grey))),
          data: (list) => list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('Aucune communauté en attente.', style: _st(13.5, c: _grey))))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final dept = '${c['department'] ?? ''}';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c['name']}', style: _st(15, w: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('Proposée par ${c['owner']}${dept.isEmpty ? '' : ' · $dept'}', style: _st(12, c: _grey)),
                        if ('${c['description']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${c['description']}', maxLines: 8, overflow: TextOverflow.ellipsis, style: _st(13).copyWith(height: 1.45))),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _button('Refuser', () => _decide(context, ref, c, false), dark: false)),
                          const SizedBox(width: 10),
                          Expanded(child: _button('Valider', () => _decide(context, ref, c, true))),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
