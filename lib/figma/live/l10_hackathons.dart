import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart';
import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'contests.dart';
import 'hackathons.dart';
import 'l10_ui.dart';
import 'lots.dart' show myCertificatesDialog;
import 'store.dart' show normText;
import 'talents.dart' show askText;

/// Écrans réels des hackathons (161 à 166) : règlement lu sur le serveur, inscription individuelle ou en équipe,
/// espace d'équipe (membres, tâches, dépôt) et résultats publiés. La maquette reste servie hors connexion (demoContent).

/// Concours de l'espace d'équipe : le concours choisi s'il compte une équipe de l'utilisateur, sinon son unique équipe.
String teamContestId(WidgetRef ref) {
  final selected = ref.read(currentEventProvider).id;
  final mine = ref.read(myContestTeamsProvider);
  if (mine.containsKey(selected) || mine.isEmpty) return selected;
  return mine.keys.first;
}

final teamSpaceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, contest) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final r = await Backend.rpc('contest_team_space', {'p_contest': contest});
  if (r.error != null) throw r.error!;
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

String _closeText(DateTime? d, String label) => d == null ? '' : '$label ${l10When(d.toIso8601String())}';

// ------------------------------------------------------------------ 161 : à propos, programme, prix, règlement

class ContestInfoPanel extends ConsumerStatefulWidget {
  const ContestInfoPanel({super.key, this.width = 342});
  final double width;

  @override
  ConsumerState<ContestInfoPanel> createState() => _ContestInfoPanelState();
}

class _ContestInfoPanelState extends ConsumerState<ContestInfoPanel> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final ev = ref.watch(currentEventProvider);
    if (ev.id.isEmpty) return l10Note(widget.width, ev.desc.isEmpty ? ev.title : '${ev.title}\n${ev.desc}');
    const labels = ['À propos', 'Programme', 'Prix', 'Règlement'];
    final body = switch (tab) {
      0 => _about(ev),
      1 => _program(ev),
      2 => _prizes(ev),
      _ => _rules(ev),
    };
    return SizedBox(
      width: widget.width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == i,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == i ? const Color(0xFF6A4DFF) : const Color(0xFFECE8F2), width: tab == i ? 3 : 1))),
                    child: Text(labels[i], textAlign: TextAlign.center, style: l10St(12, w: tab == i ? FontWeight.w700 : FontWeight.w500, c: tab == i ? l10Ink : l10Grey)),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 90), child: body)),
      ]),
    );
  }

  Widget _p(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: l10St(13, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.55)));

  Widget _about(Hackathon ev) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _p(ev.desc.isEmpty ? 'L’organisateur n’a pas encore ajouté de description.' : ev.desc),
        if (ev.theme.isNotEmpty) _p('Thématique : ${ev.theme}'),
        _p('Lieu : ${ev.city}'),
        if (ev.dates.isNotEmpty) _p('Dates : ${ev.dates}'),
      ]);

  Widget _program(Hackathon ev) {
    Widget step(String t, String d, bool done) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: done ? const Color(0xFF1F9D6B) : l10Grey),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: l10St(13.5, w: FontWeight.w600)), Text(d, style: l10St(11.5, c: l10Grey))])),
          ]),
        );
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      step('Clôture des inscriptions', ev.regClose == null ? 'Date non communiquée' : l10When(ev.regClose!.toIso8601String()), ev.regClose != null && ev.regClose!.isBefore(now)),
      step('Clôture des dépôts de projets', ev.submitClose == null ? 'Date non communiquée' : l10When(ev.submitClose!.toIso8601String()), ev.submitClose != null && ev.submitClose!.isBefore(now)),
      step('Délibération du jury', ev.serverStatus == 'judging' || ev.serverStatus == 'results' ? 'En cours ou terminée' : 'Après la clôture des dépôts', ev.serverStatus == 'judging' || ev.serverStatus == 'results'),
      step('Résultats', ev.serverStatus == 'results' ? 'Publiés : voir l’onglet Résultats du concours' : 'Publiés par le département après le jury', ev.serverStatus == 'results'),
    ]);
  }

  Widget _prizes(Hackathon ev) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _p(ev.prize > 0 ? 'Dotation annoncée : ${prizeShort(ev.prize)}. Elle est versée par l’organisateur ; Boutik-École ne la bloque pas.' : 'Aucune dotation en argent n’est annoncée pour ce concours.'),
        _p(ev.fee > 0 ? 'Frais de participation : ${prizeShort(ev.fee)}.' : 'Participation gratuite.'),
        _p('Les trois premières équipes reçoivent un certificat vérifiable à la publication des résultats.'),
        _p(placesKnown() ? 'Places restantes : ${placesLeft(ev, const {})} sur ${ev.places}.' : 'Places limitées : ${ev.places} équipes au plus.'),
      ]);

  Widget _rules(Hackathon ev) => ev.rules.trim().isEmpty
      ? _p('L’organisateur n’a pas encore publié de règlement détaillé. Vous pourrez l’accepter au moment de l’inscription une fois publié.')
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_p(ev.rules.trim())]);
}

// ------------------------------------------------------------------ 160 : liste des concours

/// Ordre de l'écran 160 : concours ouverts d'abord (clôture la plus proche en tête), puis jury, résultats et clos (les plus récents d'abord).
List<Hackathon> sortContestsForList(Iterable<Hackathon> all) {
  int rank(Hackathon h) => switch (h.status) { 'Ouvert' => 0, 'Jury' => 1, 'Résultats' => 2, 'Clos' => 3, _ => 4 };
  final l = [...all];
  l.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final x = a.regClose, y = b.regClose;
    if (x == null || y == null) return x == null && y == null ? a.title.compareTo(b.title) : (x == null ? 1 : -1);
    return rank(a) == 0 ? x.compareTo(y) : y.compareTo(x);
  });
  return l;
}

/// Filtres de l'écran 160 dérivés des concours réellement publiés : « Tous », chaque ville (sans tenir compte des accents ni de la casse), « Gratuits ».
List<(String, String)> contestFilters(Iterable<Hackathon> all) {
  final seen = <String>{};
  final out = <(String, String)>[('all', 'Tous')];
  for (final h in all) {
    final city = h.city.trim();
    if (city.isEmpty) continue;
    final k = normText(city);
    if (seen.add(k)) out.add(('city:$k', city));
  }
  if (all.any((h) => h.free)) out.add(('free', 'Gratuits'));
  return out;
}

bool contestMatchesFilter(Hackathon h, String filter) =>
    filter == 'all' || (filter == 'free' && h.free) || (filter.startsWith('city:') && normText(h.city.trim()) == filter.substring(5));

const contestsPageSize = 10;

/// Écran 160 en production : tous les concours publiés (ouverts d'abord), filtres par ville réelle et par gratuité, pagination, états de chargement, d'erreur et vide.
class ContestsListScreen extends ConsumerStatefulWidget {
  const ContestsListScreen({super.key});

  @override
  ConsumerState<ContestsListScreen> createState() => _ContestsListState();
}

class _ContestsListState extends ConsumerState<ContestsListScreen> {
  String _filter = 'all';
  int _shown = contestsPageSize;

  (Color, Color) _pill(String status) => switch (status) {
        'Ouvert' => (const Color(0xFFDDF5EC), const Color(0xFF0F7A52)),
        'Jury' => (const Color(0xFFFFF1D6), const Color(0xFF8F5400)),
        'Résultats' => (const Color(0xFFEEE9FF), const Color(0xFF5A3FE0)),
        'Annulé' => (const Color(0xFFFDE4E4), const Color(0xFFB02A2A)),
        _ => (const Color(0xFFF2EFF6), const Color(0xFF57545F)),
      };

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(serverContestsProvider);
    final error = ref.watch(contestsErrorProvider);
    final all = sortContestsForList(ref.watch(contestsProvider));
    final filters = contestFilters(all);
    final filter = filters.any((f) => f.$1 == _filter) ? _filter : 'all';
    final list = [for (final h in all) if (contestMatchesFilter(h, filter)) h];

    Widget body;
    if (loaded == null && error.isEmpty) {
      body = l10Note(342, 'Chargement…');
    } else if (all.isEmpty) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        l10Note(342, error.isNotEmpty ? error : 'Aucun concours publié pour le moment.', height: 90),
        if (error.isNotEmpty) l10Btn('Réessayer', () => ref.read(serverContestsProvider.notifier).refresh(), width: 200, compact: true),
      ]);
    } else if (list.isEmpty) {
      body = l10Note(342, 'Aucun concours ne correspond à ce filtre.');
    } else {
      final shown = list.take(_shown).toList();
      body = ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        for (final h in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              label: 'Ouvrir le concours ${h.title}',
              child: l10Card(
                onTap: () {
                  ref.read(selectedEventProvider.notifier).set(h.id);
                  gOpen(context, '161');
                },
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: l10St(13.5, w: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(h.listSub, maxLines: 2, overflow: TextOverflow.ellipsis, style: l10St(11.5, c: l10Grey)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  l10Chip(h.status, fill: _pill(h.status).$1, ink: _pill(h.status).$2),
                ]),
              ),
            ),
          ),
        if (list.length > shown.length) l10Btn('Afficher plus (${list.length - shown.length})', () => setState(() => _shown += contestsPageSize), dark: false, width: 342, compact: true),
        const SizedBox(height: 14),
        l10Card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pas encore d’équipe ?', style: l10St(14, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Trouvez des coéquipiers dans l’annuaire des talents.', style: l10St(12, c: l10Grey)),
            const SizedBox(height: 10),
            l10Btn('Trouver une équipe', () => gOpen(context, '163'), compact: true),
          ]),
        ),
        const SizedBox(height: 10),
        l10Btn('Concours, bourses et appels à projets', () => GoRouter.of(context).push('/concours'), dark: false, width: 342, compact: true),
      ]);
    }

    return L10Screen(
      title: 'Hackathons et concours',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: f.$1 == filter,
                  child: l10Btn(f.$2, () => setState(() {
                        _filter = f.$1;
                        _shown = contestsPageSize;
                      }), dark: f.$1 == filter, compact: true),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(child: body),
      ]),
    );
  }
}

// ------------------------------------------------------------------ 162 : inscription

class ContestRegisterScreen extends ConsumerWidget {
  const ContestRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = ref.watch(currentEventProvider);
    final solo = ref.watch(contestSoloProvider);
    final rulesOk = ref.watch(contestRulesOkProvider);
    final errors = ref.watch(errorsProvider);
    final role = roleKey(ref.watch(authProvider).current);
    final registered = ref.watch(myContestTeamsProvider).containsKey(ev.id);
    final closed = ev.id.isNotEmpty && (ev.serverStatus != 'published' || (ev.regClose != null && ev.regClose!.isBefore(DateTime.now())));

    Widget field(String key, String label, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: l10St(12.5, w: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              onChanged: (v) => ref.read(formProvider.notifier).put(key, v),
              style: l10St(13.5),
              decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE8F2)))),
            ),
            if (errors[key] != null) Padding(padding: const EdgeInsets.only(top: 4, left: 6), child: Text(errors[key]!, style: l10St(11.5, c: const Color(0xFFD33A3A)))),
          ]),
        );

    Widget mode(String t, bool on, bool value) => Expanded(child: l10Btn(t, () => ref.read(contestSoloProvider.notifier).set(value), dark: on, compact: true));

    return L10Screen(
      title: 'Inscription',
      child: ev.id.isEmpty
          ? l10Note(342, 'Aucun concours publié pour le moment.')
          : ListView(padding: const EdgeInsets.only(bottom: 40), children: [
              Text(ev.title, style: l10St(16, w: FontWeight.w800)),
              const SizedBox(height: 4),
              Text([if (ev.regClose != null) 'Inscriptions jusqu’au ${l10Day(ev.regClose!.toIso8601String())}', ev.city].join(' · '), style: l10St(11.5, c: l10Grey)),
              const SizedBox(height: 16),
              if (role != 'visitor' && role != 'student')
                l10Card(child: Text('Les inscriptions aux concours sont réservées aux comptes étudiants. Vous pouvez consulter le concours et son règlement, mais pas vous inscrire.', style: l10St(12.5, c: l10Grey, h: 1.5)))
              else if (registered)
                l10Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vous êtes déjà inscrit à ce concours.', style: l10St(13, w: FontWeight.w700)),
                  const SizedBox(height: 10),
                  l10Btn('Ouvrir mon espace d’équipe', () => gOpen(context, '164'), width: 342, compact: true),
                ]))
              else if (closed)
                l10Card(child: Text('Les inscriptions à ce concours sont closes.', style: l10St(13, w: FontWeight.w700)))
              else ...[
                Row(children: [mode('Individuelle', solo, true), const SizedBox(width: 10), mode('En équipe', !solo, false)]),
                const SizedBox(height: 16),
                if (ev.fee > 0) ...[
                  l10Card(child: Text('Frais de participation : ${prizeShort(ev.fee)}. Ils sont réglés directement auprès de l’organisateur : Boutik-École n’encaisse rien et cette inscription ne vaut pas paiement.', style: l10St(12, c: l10Grey, h: 1.5))),
                  const SizedBox(height: 12),
                ],
                if (!solo) field('hk_team', 'Nom de l’équipe', 'Au moins 3 caractères'),
                field('hk_theme', 'Thématique (facultatif)', 'Ex. inclusion financière'),
                l10Card(child: Text(
                  solo
                      ? 'Vous participez seul : vous êtes votre propre équipe et déposez le projet vous-même.'
                      : 'Vous êtes capitaine. Les étudiants qui ont accepté votre invitation (écran « Trouver des coéquipiers ») rejoignent l’équipe, 5 membres au plus.',
                  style: l10St(12, c: l10Grey, h: 1.5))),
                const SizedBox(height: 12),
                l10Card(
                  onTap: () => gDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Règlement du concours'),
                      content: SingleChildScrollView(child: Text(ev.rules.trim().isEmpty ? 'L’organisateur n’a pas publié de règlement détaillé. En vous inscrivant, vous acceptez les conditions générales de la plateforme.' : ev.rules.trim())),
                      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.menu_book_outlined, size: 20, color: l10Violet),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Lire le règlement', style: l10St(13, w: FontWeight.w700, c: l10Violet))),
                    const Icon(Icons.chevron_right, color: l10Grey),
                  ]),
                ),
                const SizedBox(height: 10),
                Semantics(
                  checked: rulesOk,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(contestRulesOkProvider.notifier).toggle(),
                    child: Row(children: [
                      Icon(rulesOk ? Icons.check_box : Icons.check_box_outline_blank, color: rulesOk ? l10Ink : l10Grey),
                      const SizedBox(width: 10),
                      Expanded(child: Text('J’ai lu et j’accepte le règlement du concours.', style: l10St(12.5, c: const Color(0xFF4A4854)))),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                l10Btn('Valider l’inscription', () => submitRegistration(ref, context), width: 342),
                const SizedBox(height: 10),
                if (!solo) l10Btn('Trouver des coéquipiers', () => gOpen(context, '163'), dark: false, width: 342, compact: true),
              ],
            ]),
    );
  }
}

// ------------------------------------------------------------------ 164 : espace d'équipe

class TeamSpaceScreen extends ConsumerWidget {
  const TeamSpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(myContestTeamsProvider);
    final id = teamContestId(ref);
    final signedOut = ref.watch(authProvider.select((a) => a.current == null));
    return L10Screen(
      title: 'Espace d’équipe',
      child: signedOut
          ? l10Note(342, 'Connectez-vous pour retrouver votre équipe de concours.')
          : id.isEmpty
              ? l10Note(342, 'Aucun concours sélectionné.\nOuvrez un concours puis inscrivez-vous.')
              : ref.watch(teamSpaceProvider(id)).when(
                    loading: () => l10Note(342, 'Chargement…'),
                    error: (_, _) => l10Note(342, 'Votre espace d’équipe ne peut pas être chargé pour le moment.'),
                    data: (s) => s == null ? _NoTeam(contest: id) : _TeamSpace(contest: id, space: s),
                  ),
    );
  }
}

class _NoTeam extends ConsumerWidget {
  const _NoTeam({required this.contest});
  final String contest;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        l10Note(342, 'Vous n’avez pas d’équipe pour ce concours.', height: 90),
        l10Btn('S’inscrire au concours', () {
          ref.read(selectedEventProvider.notifier).set(contest);
          gOpen(context, '162');
        }, width: 342),
      ]);
}

class _TeamSpace extends ConsumerWidget {
  const _TeamSpace({required this.contest, required this.space});
  final String contest;
  final Map<String, dynamic> space;

  Future<void> _save(BuildContext context, WidgetRef ref, String teamId, {String? id, required String title, bool done = false, String? assignee}) async {
    final r = await Backend.rpc('contest_task_save', {'p_team': teamId, 'p_id': id, 'p_title': title, 'p_done': done, 'p_assignee': assignee});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Tâche non enregistrée', r.error!);
    ref.invalidate(teamSpaceProvider(contest));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = Map<String, dynamic>.from(space['team'] as Map);
    final c = Map<String, dynamic>.from(space['contest'] as Map);
    final members = l10Rows(space['members']);
    final tasks = l10Rows(space['tasks']);
    final sub = space['submission'] is Map ? Map<String, dynamic>.from(space['submission'] as Map) : null;
    final teamId = '${team['id']}';
    final submitClose = DateTime.tryParse('${c['submit_close_at'] ?? ''}')?.toLocal();
    final submitted = sub != null && sub['submitted'] == true;
    final hidden = team['hidden'] == true;
    final doneCount = tasks.where((t) => t['done'] == true).length;
    final steps = [
      ('Équipe', true),
      ('Tâches', tasks.isNotEmpty && doneCount == tasks.length),
      ('Projet', sub != null),
      ('Dépôt', submitted),
    ];

    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      Text('${team['name']}', style: l10St(20, w: FontWeight.w800)),
      Text('${c['title']}${team['solo'] == true ? ' · participation individuelle' : ''}', style: l10St(12, c: l10Grey)),
      const SizedBox(height: 14),
      if (hidden) ...[
        l10Card(child: Text('Votre équipe a été écartée par la modération${'${team['hidden_reason'] ?? ''}'.isEmpty ? '' : ' : ${team['hidden_reason']}'}.', style: l10St(12.5, c: const Color(0xFFD33A3A), h: 1.5))),
        const SizedBox(height: 14),
      ],
      Row(children: [
        for (final s in steps)
          Expanded(child: Column(children: [
            Icon(s.$2 ? Icons.check_circle : Icons.radio_button_unchecked, color: s.$2 ? const Color(0xFF1F9D6B) : l10Grey, size: 22),
            const SizedBox(height: 4),
            Text(s.$1, style: l10St(11, w: s.$2 ? FontWeight.w700 : FontWeight.w500, c: s.$2 ? l10Ink : l10Grey)),
          ])),
      ]),
      const SizedBox(height: 18),
      Text('Membres', style: l10St(15, w: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final m in members)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: l10Card(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Text('${m['name'] ?? 'Membre'}${m['me'] == true ? ' (vous)' : ''}', style: l10St(13, w: FontWeight.w600))),
              l10Chip(m['status'] == 'captain' ? 'Capitaine' : 'Membre'),
            ]),
          ),
        ),
      if (team['solo'] != true && members.length < 5 && team['captain'] == true) ...[
        const SizedBox(height: 4),
        l10Btn('Inviter ou écrire à un coéquipier', () {
          ref.read(selectedEventProvider.notifier).set(contest);
          gOpen(context, '163');
        }, dark: false, width: 342, compact: true),
      ],
      if (team['captain'] != true && !submitted && !hidden) ...[
        const SizedBox(height: 4),
        l10Btn('Quitter cette équipe', () async {
          final ok = await gDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Quitter l’équipe ?'),
              content: Text('Vous ne ferez plus partie de « ${team['name']} » ; le capitaine sera prévenu. Vous pourrez vous inscrire seul ou rejoindre une autre équipe tant que les inscriptions sont ouvertes.'),
              actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Rester')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitter'))],
            ),
          );
          if (ok != true || !context.mounted) return;
          final r = await Backend.rpc('contest_team_leave', {'p_team': teamId});
          if (!context.mounted) return;
          if (r.error != null) return gAlert(context, 'Sortie impossible', r.error!);
          await ref.read(myContestTeamsProvider.notifier).refresh();
          ref.invalidate(teamSpaceProvider(contest));
          if (context.mounted) gToast(context, 'Vous avez quitté l’équipe.');
        }, dark: false, width: 342, compact: true),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Text('Tâches de l’équipe ($doneCount / ${tasks.length})', style: l10St(15, w: FontWeight.w700))),
        if (!hidden)
          l10Btn('Ajouter', () async {
            final t = await askText(context, title: 'Nouvelle tâche', body: 'Décrivez la tâche en quelques mots (2 à 120 caractères).', hint: 'Ex. maquettes de l’écran d’accueil', ok: 'Ajouter', min: 2);
            if (t == null || !context.mounted) return;
            await _save(context, ref, teamId, title: t);
          }, compact: true),
      ]),
      const SizedBox(height: 8),
      if (tasks.isEmpty) Text('Aucune tâche pour le moment. Ajoutez celles que vous vous répartissez.', style: l10St(12, c: l10Grey)),
      for (final t in tasks)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Semantics(
              button: true,
              label: t['done'] == true ? 'Marquer la tâche comme à faire' : 'Marquer la tâche comme faite',
              child: IconButton(
                onPressed: hidden ? null : () => _save(context, ref, teamId, id: '${t['id']}', title: '${t['title']}', done: t['done'] != true, assignee: t['assignee_id'] as String?),
                icon: Icon(t['done'] == true ? Icons.check_box : Icons.check_box_outline_blank, color: t['done'] == true ? const Color(0xFF1F9D6B) : l10Grey),
              ),
            ),
            Expanded(child: Text('${t['title']}', style: l10St(13, w: FontWeight.w600, c: t['done'] == true ? l10Grey : l10Ink))),
            if (!hidden)
              IconButton(
                tooltip: 'Supprimer la tâche',
                onPressed: () async {
                  final r = await Backend.rpc('contest_task_delete', {'p_id': t['id']});
                  if (!context.mounted) return;
                  if (r.error != null) return gAlert(context, 'Suppression impossible', r.error!);
                  ref.invalidate(teamSpaceProvider(contest));
                },
                icon: const Icon(Icons.delete_outline, color: l10Grey),
              ),
          ]),
        ),
      const SizedBox(height: 18),
      Text('Dépôt du projet', style: l10St(15, w: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        submitted ? 'Projet déposé : « ${sub['title']} ». Il est transmis au jury après la clôture.' : (submitClose == null ? 'Date limite non communiquée.' : _closeText(submitClose, 'Dépôt possible jusqu’au')),
        style: l10St(12.5, c: l10Grey, h: 1.5),
      ),
      const SizedBox(height: 14),
      if (!submitted && !hidden && team['captain'] == true) l10Btn('Déposer le projet', () {
        ref.read(selectedEventProvider.notifier).set(contest);
        gOpen(context, '165');
      }, width: 342),
      if (!submitted && team['captain'] != true) Text('Seul le capitaine dépose le projet.', style: l10St(12, c: l10Grey)),
      const SizedBox(height: 10),
      l10Btn('Voir les résultats du concours', () {
        ref.read(selectedEventProvider.notifier).set(contest);
        gOpen(context, '166');
      }, dark: false, width: 342, compact: true),
    ]);
  }
}

// ------------------------------------------------------------------ 166 : résultats

class ContestResultsScreen extends ConsumerWidget {
  const ContestResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = ref.watch(currentEventProvider);
    final ranking = ref.watch(rankingProvider);
    final withResults = [for (final h in ref.watch(contestsProvider)) if (h.id.isNotEmpty) h];
    final published = ev.serverStatus == 'results';
    final waiting = switch (ev.serverStatus) {
      'judging' => 'Le jury délibère : les résultats seront publiés par le département.',
      'cancelled' => 'Ce concours a été annulé.',
      _ => 'Le concours est en cours : les résultats seront publiés après le jury.',
    };
    return L10Screen(
      title: 'Résultats',
      child: ev.id.isEmpty
          ? l10Note(342, ev.title)
          : ListView(padding: const EdgeInsets.only(bottom: 40), children: [
              if (withResults.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final h in withResults)
                      Padding(padding: const EdgeInsets.only(right: 8), child: l10Btn(h.title, () => ref.read(selectedEventProvider.notifier).set(h.id), dark: h.id == ev.id, compact: true)),
                  ]),
                ),
              Text(ev.title, style: l10St(18, w: FontWeight.w800)),
              const SizedBox(height: 14),
              if (!published) l10Card(child: Text(waiting, style: l10St(12.5, c: l10Grey, h: 1.5))),
              if (published && ranking.isEmpty) l10Card(child: Text('Aucun classement n’est disponible pour ce concours : aucun projet noté par le jury.', style: l10St(12.5, c: l10Grey, h: 1.5))),
              if (ranking.isNotEmpty) ...[
                if (!published) ...[const SizedBox(height: 10), Text('Classement provisoire visible par le jury et le département.', style: l10St(11.5, c: l10Grey))],
                const SizedBox(height: 10),
                for (var i = 0; i < ranking.length && i < 10; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: l10Card(child: Row(children: [
                      Text('${i + 1}.', style: l10St(16, w: FontWeight.w800)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ranking[i].team, style: l10St(13.5, w: FontWeight.w700)),
                        Text(ranking[i].project, style: l10St(11.5, c: l10Grey)),
                      ])),
                      Text('${ranking[i].pts} pts', style: l10St(12, w: FontWeight.w700, c: const Color(0xFF0F7A52))),
                    ])),
                  ),
              ],
              if (published) ...[
                const SizedBox(height: 8),
                Text(ev.prize > 0 ? 'Dotation annoncée par l’organisateur : ${prizeShort(ev.prize)}.' : 'Aucune dotation en argent annoncée.', style: l10St(12, c: l10Grey)),
                const SizedBox(height: 4),
                Text('Les membres des trois premières équipes reçoivent un certificat du concours.', style: l10St(12, c: l10Grey)),
                const SizedBox(height: 14),
                l10Btn('Voir mes certificats', () => myCertificatesDialog(context, ref), width: 342),
              ],
            ]),
    );
  }
}
