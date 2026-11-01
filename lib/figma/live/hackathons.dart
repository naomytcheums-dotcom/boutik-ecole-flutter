import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'drafts.dart';
import 'engage.dart' show engageAction, unavailableAction;
import 'lots.dart' show copyText;
import 'store.dart';

/// Hackathons et concours : agenda, inscription d'équipe, coéquipiers, dépôt, jury, classement (écrans 160 à 167).
/// Avec le serveur : l'inscription est un engagement réel (event_registration) ; le dépôt, la notation du jury et les invitations
/// de coéquipiers n'ont pas encore de fonction serveur et l'expliquent au lieu de simuler un envoi ; le classement n'affiche
/// aucune équipe fictive.

/// Explique qu'une étape du concours n'est pas encore reliée au serveur (jamais de faux succès en production).
bool _notYetOnServer(BuildContext context, String title, String why) {
  if (!Backend.ready) return false;
  unavailableAction(context, title, why);
  return true;
}

class Hackathon {
  const Hackathon(this.id, this.title, this.dates, this.city, this.prize, this.places, this.status, {this.free = false, this.hours = 48, this.desc = ''});
  final String id, title, dates, city, status, desc;
  final int prize, places, hours;
  final bool free;

  String get listSub => '$dates · $city${city == 'En ligne' ? ' · Prix de ${fcfa(prize)}' : ' · ${prizeShort(prize)}'}';
}

String prizeShort(int p) => p >= 1000000 ? '${(p / 1000000).toString().replaceAll('.0', '')} M FCFA' : fcfa(p);

const hackathons = <Hackathon>[
  Hackathon('orange', 'Orange Digital Challenge', '14–16 nov.', 'Douala', 5000000, 120, 'Ouvert',
      desc: 'Concevez en équipe une solution numérique pour l’inclusion financière, de l’idée au pitch devant le jury.'),
  Hackathon('iot', 'Hackathon IoT et énergie', '28–29 nov.', 'Yaoundé', 2000000, 80, 'J-12', hours: 36,
      desc: 'Objets connectés et énergie propre : prototypez en 36 heures avec des mentors de l’industrie.'),
  Hackathon('innov', 'Concours d’innovation', 'Dès aujourd’hui', 'En ligne', 1000000, 300, 'Ouvert', free: true, hours: 72,
      desc: 'Concours ouvert à toutes les filières : présentez votre innovation en ligne.'),
  Hackathon('vert', 'Défi start-up verte', '5–6 déc.', 'Douala', 750000, 60, 'Ouvert', free: true, hours: 24,
      desc: 'Des solutions durables pour les marchés, l’eau et les déchets.'),
];

class Registration {
  const Registration(this.eventId, this.teamName, this.theme);
  final String eventId, teamName, theme;
}

class Registrations extends Notifier<Map<String, Registration>> {
  @override
  Map<String, Registration> build() => const {};
  void add(Registration r) => state = {...state, r.eventId: r};
}

final registrationsProvider = NotifierProvider<Registrations, Map<String, Registration>>(Registrations.new);
final selectedEventProvider = NotifierProvider<StrV, String>(StrV.new);
final hackTabProvider = NotifierProvider<IntV, int>(IntV.new);
final rulesProvider = NotifierProvider<Flag, bool>(Flag.new);

final currentEventProvider = Provider<Hackathon>((ref) {
  final id = ref.watch(selectedEventProvider);
  return hackathons.firstWhere((h) => h.id == id, orElse: () => hackathons.first);
});

final visibleHackathonsProvider = Provider<List<Hackathon>>((ref) {
  final tab = ref.watch(hackTabProvider).clamp(0, 4);
  return [
    for (final h in hackathons)
      if (tab == 0 || (tab == 1 && h.city == 'En ligne') || (tab == 2 && h.city == 'Douala') || (tab == 3 && h.city == 'Yaoundé') || (tab == 4 && h.free)) h,
  ];
});

int placesLeft(Hackathon h, Map<String, Registration> regs) => h.places - (regs.containsKey(h.id) ? 1 : 0);

// ------------------------------------------------------------------ coéquipiers (163) et équipe (162, 164)

class Mate {
  const Mate(this.name, this.skills, this.cat);
  final String name, skills, cat;
}

const mates = <Mate>[
  Mate('Kouassi Tagne', 'Audiovisuel · Montage, Motion', 'Designers'),
  Mate('Carine Mbarga', 'Informatique · Python, Data', 'IA et data'),
  Mate('Landry Essomba', 'Gestion · Business plan', 'Business'),
  Mate('Yannick Mouanga', 'Génie civil · Prototypage', 'Développeurs'),
  Mate('Éric Biyick', 'Informatique · Flutter, API', 'Développeurs'),
  Mate('Sandra Tchoua', 'MMI · Photo, Identité visuelle', 'Designers'),
  Mate('Nadège Fotso', 'Gestion · Marketing digital', 'Business'),
  Mate('Paul Nkoa', 'Informatique · Machine learning', 'IA et data'),
];

class Member {
  const Member(this.name, this.skills, {this.confirmed = false});
  final String name, skills;
  final bool confirmed;
}

/// Équipe de l'utilisateur : membres invités (le capitaine, c'est le compte connecté).
class TeamMembers extends Notifier<List<Member>> {
  @override
  List<Member> build() => const [Member('Brice Ndoumbe', 'IoT · Invitation acceptée', confirmed: true)];
  bool has(String n) => state.any((m) => m.name == n);
  void invite(Mate m) => state = [...state, Member(m.name, '${m.cat} · Invitation envoyée')];
  void remove(String n) => state = [for (final m in state) if (m.name != n) m];
  void confirm(String n) => state = [for (final m in state) m.name == n ? Member(m.name, m.skills.replaceAll('Invitation envoyée', 'Invitation acceptée'), confirmed: true) : m];
}

final teamMembersProvider = NotifierProvider<TeamMembers, List<Member>>(TeamMembers.new);
final mateTabProvider = NotifierProvider<IntV, int>(IntV.new);
final mateQueryProvider = NotifierProvider<StrV, String>(StrV.new);

final visibleMatesProvider = Provider<List<Mate>>((ref) {
  final cat = const ['Développeurs', 'Designers', 'Business', 'IA et data'][ref.watch(mateTabProvider).clamp(0, 3)];
  final q = normText(ref.watch(mateQueryProvider).trim());
  return [for (final m in mates) if ((m.cat == cat) && (q.isEmpty || normText('${m.name} ${m.skills}').contains(q))) m];
});

Color inviteFill(bool invited) => invited ? const Color(0xFFDDF5EC) : const Color(0xFFEFEBFA);
Color inviteInk(bool invited) => invited ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0);

void toggleInvite(WidgetRef ref, BuildContext context, Mate m) {
  if (_notYetOnServer(context, 'Invitations indisponibles',
      'L’invitation de coéquipiers n’est pas encore reliée au serveur : aucune invitation n’est envoyée. Contactez vos coéquipiers par la messagerie.')) {
    return;
  }
  final n = ref.read(teamMembersProvider.notifier);
  if (n.has(m.name)) {
    n.remove(m.name);
    gToast(context, 'Invitation retirée : ${m.name}');
    return;
  }
  if (ref.read(teamMembersProvider).length >= 4) {
    gToast(context, 'Une équipe compte 5 personnes au maximum.');
    return;
  }
  n.invite(m);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Invitation d’équipe envoyée', m.name, 'Validations');
  gToast(context, 'Invitation envoyée à ${m.name}');
}

// ------------------------------------------------------------------ inscription (162)

void submitRegistration(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final ev = ref.read(currentEventProvider);
  final name = (f['hk_team'] ?? 'Team Innov’').trim();
  final theme = (f['hk_theme'] ?? 'Inclusion financière').trim();
  final errs = <String, String>{
    if (name.length < 3) 'hk_team': 'Donnez un nom d’équipe (3 caractères minimum).',
    if (theme.isEmpty) 'hk_theme': 'Choisissez une thématique.',
  };
  if (errs.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errs);
    return;
  }
  if (!ref.read(rulesProvider)) {
    gToast(context, 'Acceptez le règlement pour valider l’inscription.');
    return;
  }
  if (ref.read(registrationsProvider).containsKey(ev.id)) {
    gToast(context, 'Votre équipe est déjà inscrite à ce concours.');
    gOpen(context, '164');
    return;
  }
  if (placesLeft(ev, ref.read(registrationsProvider)) <= 0) {
    gToast(context, 'Plus de places disponibles.');
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  if (Backend.ready) {
    _serverRegistration(ref, context, ev, name, theme);
    return;
  }
  ref.read(registrationsProvider.notifier).add(Registration(ev.id, name, theme));
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Équipe inscrite', '$name · ${ev.title}', 'Validations');
  gToast(context, 'Inscription validée : ${ev.title}');
  gOpen(context, '164');
}

// ------------------------------------------------------------------ dépôt (165), jury (167), classement (166)

/// 161 « Partager » : copie réellement le lien du concours ; le message dépend du résultat de la copie.
Future<void> shareEventLink(WidgetRef ref, BuildContext context) async {
  final ev = ref.read(currentEventProvider);
  final ok = await copyText('${ev.title} · Boutik-École : ${Uri.base.origin}/#/s/161');
  if (context.mounted) gToast(context, ok ? 'Lien du concours copié' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Inscription enregistrée côté serveur (engagement « event_registration ») ; l'état local ne suit qu'après confirmation.
Future<void> _serverRegistration(WidgetRef ref, BuildContext context, Hackathon ev, String name, String theme) async {
  final ok = await engageAction(context, ref, 'event_registration', 'hackathon:${ev.id}',
      data: {'team': name, 'theme': theme, 'event': ev.title}, success: 'Inscription enregistrée : ${ev.title}', need: 'inscrire votre équipe',
      already: 'Votre équipe est déjà inscrite à ce concours.');
  if (!ok || !context.mounted) return;
  ref.read(registrationsProvider.notifier).add(Registration(ev.id, name, theme));
  gOpen(context, '164');
}

class Submission {
  const Submission(this.team, this.title, this.link, this.desc, {this.points});
  final String team, title, link, desc;
  final int? points;
}

class Submissions extends Notifier<Submission?> {
  @override
  Submission? build() => null;
  void submit(Submission s) => state = s;
  void score(int pts) {
    final s = state;
    if (s != null) state = Submission(s.team, s.title, s.link, s.desc, points: pts);
  }
}

final submissionProvider = NotifierProvider<Submissions, Submission?>(Submissions.new);

void submitDeposit(WidgetRef ref, BuildContext context) {
  if (_notYetOnServer(context, 'Dépôt non disponible',
      'Le dépôt des projets de concours n’est pas encore relié au serveur : rien n’est transmis au jury. Gardez votre brouillon (« Enregistrer ») et remettez le projet aux organisateurs.')) {
    return;
  }
  final f = ref.read(formProvider);
  final title = (f['dp_title'] ?? 'Paiement mobile hors connexion').trim();
  final link = (f['dp_link'] ?? '').trim();
  final desc = (f['dp_desc'] ?? '').trim();
  final errs = <String, String>{
    if (title.length < 3) 'dp_title': 'Le titre est obligatoire.',
    if (!RegExp(r'^https?://[^\s]+\.[^\s]+').hasMatch(link)) 'dp_link': 'Entrez un lien valide (https://…).',
    if (desc.length < 30) 'dp_desc': 'Décrivez problème, solution et impact (30 caractères minimum).',
  };
  if (errs.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errs);
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final reg = ref.read(registrationsProvider).values.isEmpty ? null : ref.read(registrationsProvider).values.first;
  ref.read(submissionProvider.notifier).submit(Submission(reg?.teamName ?? 'Team Innov’', title, link, desc));
  Drafts.clear('165', const ['dp_title', 'dp_link', 'dp_desc']);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Projet déposé', title, 'Validations');
  gToast(context, 'Projet déposé : le jury le recevra après clôture');
  gOpen(context, '164');
}

class Scores extends Notifier<List<int>> {
  @override
  List<int> build() => const [8, 7, 9, 6];
  void bump(int i) => state = [for (var k = 0; k < state.length; k++) k == i ? (state[k] + 1) % 11 : state[k]];
}

final scoresProvider = NotifierProvider<Scores, List<int>>(Scores.new);

class Ranked {
  const Ranked(this.team, this.project, this.pts);
  final String team, project;
  final int pts;
}

const _seedRanking = [
  Ranked('Team Innov’', 'Paiement mobile hors connexion', 94),
  Ranked('Équipe Kreatif', 'Marketplace artisans', 89),
  Ranked('Équipe Solaire+', 'Énergie hors réseau', 86),
];

/// Classement : avec le serveur, seulement le projet réellement noté (aucune équipe fictive) ; hors connexion (tests, aperçu),
/// équipes d'exemple de la maquette + projet déposé et noté par le jury.
final rankingProvider = Provider<List<Ranked>>((ref) {
  final s = ref.watch(submissionProvider);
  final seeds = Backend.ready ? const <Ranked>[] : _seedRanking;
  final base = [for (final r in seeds) if (s == null || s.points == null || r.team != s.team) r];
  final all = [...base, if (s != null && s.points != null) Ranked(s.team, s.title, s.points!)];
  all.sort((a, b) => b.pts.compareTo(a.pts));
  return all;
});

int provisionalRank(List<int> scores) {
  final mine = (scores.fold(0, (a, b) => a + b) * 100 / 40).round();
  return 1 + _seedRanking.where((r) => r.pts > mine).length;
}

String ordinal(int n) => n == 1 ? '1er' : '${n}e';

void validateJury(WidgetRef ref, BuildContext context) {
  if (_notYetOnServer(context, 'Notation non disponible',
      'La notation du jury n’est pas encore reliée au serveur : aucune note n’est enregistrée ni publiée. Les notes saisies restent affichées sur cet écran.')) {
    return;
  }
  final pts = (ref.read(scoresProvider).fold(0, (a, b) => a + b) * 100 / 40).round();
  final s = ref.read(submissionProvider);
  ref.read(auditProvider.notifier).log('Jury', 'Note validée', '${s?.title ?? 'Serre intelligente'} · $pts pts', 'Validations');
  if (s == null) {
    gToast(context, 'Note enregistrée ($pts pts). Aucun projet déposé par votre équipe à classer.');
    return;
  }
  ref.read(submissionProvider.notifier).score(pts);
  gToast(context, 'Note validée : $pts pts — classement mis à jour');
  gOpen(context, '166');
}
