import 'community_exchanges.dart';
import 'community_media.dart';
import 'study_rooms.dart' show StudyRoomsTab;
import 'innovations_screens.dart' show LevelBadge, communityLevelsProvider;
import 'community_styles.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'tp_ui.dart' show tpBackground, GlassBack, TpFrame;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'auth.dart' show authProvider, requireLogin;
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

/// Limite de la description d'une communauté.
const kCommunityMaxWords = 500;

/// Nombre de mots d'un texte (séparés par des espaces ou retours à la ligne).
int wordCount(String text) {
  final t = text.trim();
  return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
}

TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: _ink,
      leadingWidth: 64, leading: Padding(padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4), child: const GlassBack()),
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
  String _kind = 'interest';
  String _promo = '';
  final _interest = TextEditingController();
  final _promoText = TextEditingController();
  String? _department;
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _interest.dispose();
    _promoText.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (_kind == 'filiere' && _department == null) return setState(() => _error = 'Choisissez la filière.');
    if (_kind == 'promo' && _promo.isEmpty && _promoText.text.trim().isEmpty) return setState(() => _error = 'Indiquez la promotion.');
    if (_kind == 'interest' && _interest.text.trim().isEmpty) return setState(() => _error = 'Indiquez le centre d’intérêt.');
    if (name.length < 3 || name.length > 60) return setState(() => _error = 'Le nom doit contenir entre 3 et 60 caractères.');
    final words = wordCount(_desc.text);
    if (words > kCommunityMaxWords) return setState(() => _error = 'La description ne doit pas dépasser $kCommunityMaxWords mots ($words saisis).');
    setState(() {
      _busy = true;
      _error = '';
    });
    final promo = _promo.isNotEmpty ? _promo : _promoText.text.trim();
    final r = await Backend.rpc('create_community', {'p_name': name, 'p_description': _desc.text.trim(), 'p_category': '', 'p_privacy': _privacy, 'p_rules': '', 'p_department': _department, 'p_kind': _kind, 'p_promo': _kind == 'promo' ? promo : null, 'p_interest': _kind == 'interest' ? _interest.text.trim() : null});
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
    return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, 
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
          label('Type de communauté'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (k, t) in const [('filiere', 'Par filière'), ('promo', 'Par promo'), ('interest', 'Par centre d’intérêt'), ('alumni', 'Alumni (anciens)'), ('project', 'Par projet')])
              GestureDetector(
                onTap: () => setState(() => _kind = k),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _kind == k ? _ink : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kind == k ? _ink : _line)), child: Text(t, style: _st(12.5, w: FontWeight.w600, c: _kind == k ? Colors.white : _ink))),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(switch (_kind) {
              'filiere' => 'Génie Info, Génie Électrique, Génie Civil, Agroalimentaire…',
              'promo' => 'Retrouvez votre classe : Promo 2024, Promo 2025, Promo 2026…',
              'alumni' => 'Les anciens qui travaillent déjà et peuvent aider.',
              'project' => 'Ceux qui travaillent sur le même projet.',
              _ => 'Dev Flutter, Design, Entrepreneuriat, Musique, Sport, IA…',
            }, style: _st(12, c: _grey)),
          ),
          if (_kind == 'promo') ...[
            label('Promotion'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final y in [for (var i = 0; i < 4; i++) 'Promo ${DateTime.now().year - 1 + i}'])
                GestureDetector(
                  onTap: () => setState(() {
                    _promo = y;
                    _promoText.clear();
                  }),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _promo == y ? _ink : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _promo == y ? _ink : _line)), child: Text(y, style: _st(12.5, w: FontWeight.w600, c: _promo == y ? Colors.white : _ink))),
                ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _promoText, onChanged: (_) => setState(() => _promo = ''), decoration: deco('Ou une autre promotion')),
          ],
          if (_kind == 'interest') ...[
            label('Centre d’intérêt'),
            TextField(controller: _interest, maxLength: 60, decoration: deco('Ex. Dev Flutter, Design, Sport').copyWith(counterText: '')),
          ],
          label(_kind == 'filiere' ? 'Filière' : 'Département (facultatif)'),
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
    )));
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
  String? _style;
  bool _compose = false;
  PostAttachment? _attach;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final c = ref.read(selectedCommunityProvider);
    if (c == null) return;
    setState(() => _busy = true);
    final a = _attach;
    final r = await Backend.rpc('create_community_post', {'p_community': c.id, 'p_body': _text.text, 'p_style': _style, if (a != null && a.kind != 'link') 'p_media_path': a.path, if (a != null && a.kind != 'link') 'p_media_kind': a.kind, if (a != null && a.kind == 'link') 'p_link': a.link});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return;
    }
    _text.clear();
    setState(() {
      _style = null;
      _compose = false;
      _attach = null;
    });
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  Future<void> _newPoll(Community c) async {
    final q = TextEditingController();
    final opts = [TextEditingController(), TextEditingController()];
    String? style;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nouveau sondage', style: _st(18, w: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(controller: q, maxLength: 280, decoration: InputDecoration(labelText: 'Question', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 8),
              for (var i = 0; i < opts.length; i++) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: opts[i], maxLength: 80, decoration: InputDecoration(labelText: 'Réponse ${i + 1}', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              if (opts.length < 6) TextButton.icon(onPressed: () => set(() => opts.add(TextEditingController())), icon: const Icon(Icons.add), label: const Text('Ajouter une réponse')),
              Text('Fond (facultatif)', style: _st(12.5, w: FontWeight.w700)),
              StylePicker(value: style, onChanged: (v) => set(() => style = v)),
              const SizedBox(height: 8),
              if (q.text.trim().isNotEmpty || style != null) PollView(question: q.text.trim().isEmpty ? 'Votre question' : q.text.trim(), poll: {'options': [for (final o in opts) {'label': o.text.trim().isEmpty ? '…' : o.text.trim(), 'votes': 0}], 'total': 0, 'mine': null}, onVote: (_) {}, style: postStyleOf(style)),
              const SizedBox(height: 12),
              _button('Publier le sondage', () => Navigator.pop(sheet, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await Backend.rpc('create_community_poll', {'p_community': c.id, 'p_question': q.text, 'p_options': [for (final o in opts) if (o.text.trim().isNotEmpty) o.text.trim()], 'p_style': style});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  Future<void> _vote(Map<String, dynamic> p, int option) async {
    if (!await requireLogin(context, ref, 'voter à ce sondage') || !mounted) return;
    final r = await Backend.rpc('vote_community_poll', {'p_post': p['id'], 'p_option': option});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  Future<void> _pin(Map<String, dynamic> p) async {
    final r = await Backend.rpc('pin_community_post', {'p_post': p['id'], 'p_pin': p['pinned'] != true});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage(r.error!));
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

  Future<void> _decline(Community c) async {
    if (!await requireLogin(context, ref, 'répondre à cette invitation') || !mounted) return;
    final r = await Backend.rpc('leave_community', {'p_community': c.id});
    if (!mounted) return;
    if (r.error != null) return gAlert(context, 'Action impossible', Backend.userMessage(r.error!));
    await ref.read(communitiesProvider.notifier).refresh();
    if (!mounted) return;
    gToast(context, 'Invitation refusée : « ${c.name} »');
    final still = (ref.read(communitiesProvider) ?? const <Community>[]).any((x) => x.id == c.id);
    if (still) {
      await _reload(c.id);
    } else {
      await Navigator.of(context).maybePop();
    }
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
    const names = ['Publications', 'Chat', 'Questions', 'Événements', 'Fichiers', 'Membres', 'Mentors', 'Salons vocaux'];
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
    return Column(mainAxisSize: MainAxisSize.min, children: [CommunityBanner(community: c), Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name, style: _st(19, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([c.kindLabel, c.membersLabel, c.privacyLabel, if (c.department.isNotEmpty) c.department].join(' · '), style: _st(12, c: _grey)),
        if (c.badges(DateTime.now()).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, children: [for (final b in c.badges(DateTime.now())) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: b == 'Officiel IUT' ? const Color(0xFF0F2E4E) : const Color(0xFFFFF0D6), borderRadius: BorderRadius.circular(4)), child: Text(b, style: _st(10.5, w: FontWeight.w700, c: b == 'Officiel IUT' ? Colors.white : const Color(0xFF8F5400))))])),
        if (c.description.isNotEmpty) ...[const SizedBox(height: 10), Text(c.description, style: _st(13.5, c: _ink).copyWith(height: 1.5))],
        if (c.isPending) Padding(padding: const EdgeInsets.only(top: 10), child: Text('En attente de validation par l’administrateur.', style: _st(12.5, w: FontWeight.w700, c: const Color(0xFFB45309)))),
        if (c.isRejected) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Refusée${c.decisionNote.isEmpty ? '' : ' : ${c.decisionNote}'}', style: _st(12.5, w: FontWeight.w700, c: const Color(0xFFB42318)))),
        const SizedBox(height: 12),
        if (canJoin) _button(c.actionLabel, () async { await joinCommunity(context, ref, c); if (mounted) await _reload(c.id); }),
        if (c.myStatus == 'invited') _button('Refuser l’invitation', () => _decline(c), dark: false),
        if (c.isMember && c.myRole != 'owner') _button('Quitter la communauté', () async { await leaveCommunity(context, ref, c); if (mounted) await _reload(c.id); }, dark: false),
        if (!canJoin && !c.isMember && c.status == 'active') Text(c.actionLabel, style: _st(13, w: FontWeight.w600, c: _violet)),
      ])),
    )]);
  }

  /// Visiteur sans compte (avec le serveur) : les messages « réservé aux membres » proposent de se connecter.
  bool get _visitor => Backend.ready && ref.watch(authProvider.select((a) => a.current == null));

  Widget _loginButton() => TextButton(onPressed: () => requireLogin(context, ref, 'voir cette communauté'), child: Text('Se connecter', style: _st(13.5, w: FontWeight.w700, c: _violet)));

  Widget _posts(Community c, List<Map<String, dynamic>>? feed) {
    if (feed == null) return const Center(child: CircularProgressIndicator());
    if (ref.read(communityFeedProvider.notifier).error) {
      final visitor = _visitor;
      return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(visitor ? 'Ce fil est réservé aux membres : connectez-vous pour le consulter.' : 'Ce fil est réservé aux membres, ou indisponible pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey)),
        if (visitor) _loginButton(),
      ])));
    }
    if (feed.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text('Aucune publication pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: feed.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = feed[i];
        final pinned = p['pinned'] == true;
        return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (pinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin, size: 15, color: Color(0xFF8F5400))),
            Expanded(child: Text('${p['author']}${pinned ? ' · annonce épinglée' : ''}', style: _st(13.5, w: FontWeight.w700))),
            if (c.canManage) GestureDetector(onTap: () => _pin(p), child: Padding(padding: const EdgeInsets.all(4), child: Text(pinned ? 'Retirer' : 'Épingler', style: _st(12, w: FontWeight.w600, c: _grey)))),
            if (c.canManage) GestureDetector(onTap: () => _hide(p), child: Padding(padding: const EdgeInsets.all(4), child: Text('Masquer', style: _st(12, w: FontWeight.w600, c: _grey)))),
          ]),
          const SizedBox(height: 6),
          if ('${p['kind']}' == 'poll' && p['poll'] is Map)
            PollView(question: '${p['body']}', poll: Map<String, dynamic>.from(p['poll'] as Map), onVote: (o) => _vote(p, o), style: postStyleOf(p['style']))
          else
            StyledPostText('${p['body']}', style: postStyleOf(p['style'])),
          PostAttachmentView(post: p),
        ]));
      },
    );
  }

  Widget _members(Community c, {required bool mentorsOnly}) {
    final async = ref.watch(communityMembersProvider(c.id));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) {
        final visitor = _visitor;
        return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(visitor ? 'La liste des membres est réservée aux membres : connectez-vous pour la consulter.' : 'La liste des membres est indisponible pour le moment.', textAlign: TextAlign.center, style: _st(13.5, c: _grey)),
          if (visitor) _loginButton(),
        ])));
      },
      data: (all) {
        final list = mentorsOnly ? [for (final m in all) if (m['role'] == 'mentor') m] : all;
        if (list.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Text(mentorsOnly ? 'Aucun mentor pour le moment.' : 'Aucun membre.', textAlign: TextAlign.center, style: _st(13.5, c: _grey))));
        final canRole = c.myRole == 'owner' || c.myRole == 'admin';
        final levels = ref.watch(communityLevelsProvider(c.id)).asData?.value ?? const <String, Map<String, dynamic>>{};
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['name']}', style: _st(13.5, w: FontWeight.w700)), Text(roleLabel('${m['role']}'), style: _st(11.5, c: m['role'] == 'member' ? _grey : _violet)), if (levels['${m['user_id']}'] != null) Padding(padding: const EdgeInsets.only(top: 3), child: LevelBadge(level: '${levels['${m['user_id']}']!['level']}', compact: true))])),
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
      return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, appBar: _bar(context, 'Communauté'), body: const Center(child: Text('Aucune communauté ouverte.')))));
    }
    final Widget body = switch (_tab) {
      1 => CommunityChatTab(key: ValueKey('chat-${c.id}-${c.isMember}'), communityId: c.id, isMember: c.isMember),
      2 => CommunityQaTab(key: ValueKey('qa-${c.id}'), communityId: c.id, isMember: c.isMember),
      3 => CommunityEventsTab(key: ValueKey('ev-${c.id}'), communityId: c.id, isMember: c.isMember),
      4 => CommunityFilesTab(key: ValueKey('files-${c.id}-${c.isMember}'), communityId: c.id, isMember: c.isMember),
      5 => _members(c, mentorsOnly: false),
      6 => _members(c, mentorsOnly: true),
      7 => StudyRoomsTab(key: ValueKey('rooms-${c.id}-${c.isMember}'), communityId: c.id, isMember: c.isMember),
      _ => _posts(c, feed),
    };
    return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, 
      appBar: _bar(context, c.name),
      body: SafeArea(
        child: Column(children: [
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4), child: SingleChildScrollView(child: _header(c))),
          _tabs(),
          Expanded(child: body),
          if (_tab == 0 && c.status == 'active')
            c.isMember
                ? Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_compose) ...[
                        Align(alignment: Alignment.centerLeft, child: Text('Fond de la publication', style: _st(12, w: FontWeight.w700, c: _grey))),
                        StylePicker(value: _style, onChanged: (v) => setState(() { _style = v; if (v != null) _attach = null; })),
                        if (_style != null && _text.text.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: StyledPostText(_text.text.trim(), style: postStyleOf(_style), minHeight: 110)),
                      ],
                      if (_attach != null) AttachmentChip(attachment: _attach!, onRemove: () => setState(() => _attach = null)),
                      Row(children: [
                      IconButton(tooltip: 'Joindre une photo, une vidéo ou un lien', onPressed: () async { final a = await chooseAttachment(context, ref); if (a != null && mounted) setState(() { _attach = a; _style = null; }); }, icon: Icon(Icons.attach_file, color: _attach != null ? _violet : _ink)),
                      IconButton(tooltip: 'Fond design', onPressed: () => setState(() => _compose = !_compose), icon: Icon(Icons.palette_outlined, color: _compose ? _violet : _ink)),
                      IconButton(tooltip: 'Sondage', onPressed: () => _newPoll(c), icon: const Icon(Icons.poll_outlined)),
                      Expanded(child: TextField(controller: _text, maxLength: 2000, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Écrire dans ${c.name}…', counterText: '', filled: true, fillColor: const Color(0xFFF2EFF6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
                      const SizedBox(width: 8),
                      IconButton(tooltip: 'Publier', onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded)),
                    ]),
                    ]),
                  )
                : Container(width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Rejoignez la communauté pour publier.', textAlign: TextAlign.center, style: _st(13, c: _grey)),
                    if (_visitor) _loginButton(),
                  ])),
        ]),
      ),
    )));
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
    return DecoratedBox(decoration: tpBackground, child: TpFrame(child: Scaffold(backgroundColor: Colors.transparent, 
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
    )));
  }
}
