import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'audit.dart';
import 'auth.dart';
import 'store.dart';

/// Talents, projets innovants et opportunités (écrans 70, 75, 78 à 80, 151).

// ------------------------------------------------------------------ boîte de dialogue commune

const _st = TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, color: Color(0xFF111015), textBaseline: TextBaseline.alphabetic);

Future<String?> askText(BuildContext context, {required String title, required String body, required String hint, required String ok, int min = 0}) {
  final c = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(body, style: _st.copyWith(height: 1.55, color: const Color(0xFF66636E))),
            const SizedBox(height: 12),
            TextField(controller: c, style: _st, minLines: 2, maxLines: 4, decoration: InputDecoration(hintText: hint, errorText: error, border: const OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Annuler', style: _st)),
          TextButton(
            onPressed: () {
              if (c.text.trim().length < min) {
                set(() => error = 'Écrivez au moins $min caractères.');
                return;
              }
              Navigator.of(ctx).pop(c.text.trim());
            },
            child: Text(ok, style: _st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}

// ------------------------------------------------------------------ talents (70)

class Talent {
  const Talent(this.name, this.dept, this.skills, this.category, {this.available = true, this.bio = ''});
  final String name, dept, skills, category, bio;
  final bool available;
  String get sub => '$dept · $skills';
}

const talents = <Talent>[
  Talent('Mariam Essono', 'Génie informatique', 'Python, React', 'Développement', bio: 'Étudiante en informatique : applications web et mobiles pour des clients locaux.'),
  Talent('Yannick Mouanga', 'Génie civil', 'Conception, Menuiserie', 'Design', bio: 'Conception d’objets en bois recyclé et d’aménagements d’intérieur.'),
  Talent('Aminata Bello', 'MMI', 'UI/UX, Branding', 'Design', available: false, bio: 'Identités visuelles, interfaces et supports de communication.'),
  Talent('Kouassi Tagne', 'Audiovisuel', 'Montage, Motion', 'Audiovisuel', bio: 'Vidéos de présentation, montage et motion design.'),
  Talent('Brice Ndoumbe', 'Électronique', 'IoT, Drones', 'Électronique', bio: 'Objets connectés, capteurs et drones éducatifs.'),
  Talent('Sandra Tchoua', 'MMI', 'Photo, Retouche', 'Audiovisuel', bio: 'Photographie produit et retouche pour boutiques en ligne.'),
  Talent('Éric Biyick', 'Génie informatique', 'Flutter, API', 'Développement', bio: 'Applications mobiles et services web.'),
  Talent('Carine Mbarga', 'Génie civil', 'BIM, Plans 3D', 'Design', available: false, bio: 'Plans, maquettes numériques et visualisations 3D.'),
];

final talentTabProvider = NotifierProvider<IntV, int>(IntV.new);
final talentQueryProvider = NotifierProvider<StrV, String>(StrV.new);

/// Propositions de mission envoyées (nom du talent → texte).
class TalentRequests extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};
  void send(String name, String msg) => state = {...state, name: msg};
}

final talentRequestsProvider = NotifierProvider<TalentRequests, Map<String, String>>(TalentRequests.new);

const talentCats = ['Tous', 'Développement', 'Design', 'Audiovisuel', 'Électronique'];

final visibleTalentsProvider = Provider<List<Talent>>((ref) {
  final cat = talentCats[ref.watch(talentTabProvider).clamp(0, 4)];
  final q = normText(ref.watch(talentQueryProvider).trim());
  return [
    for (final t in talents)
      if ((cat == 'Tous' || t.category == cat) && (q.isEmpty || normText('${t.name} ${t.dept} ${t.skills}').contains(q))) t,
  ];
});

Color availFill(bool a) => a ? const Color(0xFFDDF5EC) : const Color(0xFFEEE9FF);
Color availInk(bool a) => a ? const Color(0xFF0F7A52) : const Color(0xFF8F5400);

Future<void> talentDialog(BuildContext context, WidgetRef ref, Talent t) async {
  final already = ref.read(talentRequestsProvider).containsKey(t.name);
  final msg = await askText(
    context,
    title: t.name,
    body: '${t.dept} · ${t.skills}\n${t.bio}\n${t.available ? 'Disponible pour de nouvelles missions.' : 'Actuellement occupé(e) : réponse sous quelques jours.'}${already ? '\nUne proposition est déjà envoyée.' : ''}',
    hint: 'Décrivez la mission à proposer',
    ok: 'Proposer une mission',
    min: 10,
  );
  if (msg == null || !context.mounted) return;
  ref.read(talentRequestsProvider.notifier).send(t.name, msg);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Mission proposée', t.name, 'Validations');
  gToast(context, 'Proposition envoyée à ${t.name}');
}

// ------------------------------------------------------------------ projets (78, 79, 80)

class Project {
  const Project(this.title, this.dept, this.progress, this.stage, {this.lead = 'Brice Ndoumbe', this.contributors = 4, this.milestones = 3, this.desc = ''});
  final String title, dept, stage, lead, desc;
  final int progress, contributors, milestones;
  String get sub => '$dept · $progress %';
}

class Projects extends Notifier<List<Project>> {
  @override
  List<Project> build() => const [
        Project('Système de filtration d’eau', 'Génie chimique', 72, 'En cours', desc: 'Un système de filtration low-cost pour les quartiers sans eau potable, testé avec des associations locales.'),
        Project('Serre intelligente', 'Agronomie', 45, 'Financement', lead: 'Aminata Bello', contributors: 5, milestones: 4, desc: 'Une serre pilotée par capteurs pour maraîchers urbains.'),
        Project('Application covoiturage', 'Informatique', 100, 'Terminé', lead: 'Éric Biyick', contributors: 3, milestones: 3, desc: 'Une application de covoiturage entre campus et quartiers de Douala.'),
        Project('Panneaux solaires mobiles', 'Génie électrique', 30, 'Prototype', lead: 'Yannick Mouanga', contributors: 6, milestones: 5, desc: 'Des panneaux solaires démontables pour marchés et événements.'),
      ];
  void add(Project p) => state = [p, ...state];
}

final projectsProvider = NotifierProvider<Projects, List<Project>>(Projects.new);
final projectTabProvider = NotifierProvider<IntV, int>(IntV.new);
final selectedProjectProvider = NotifierProvider<StrV, String>(StrV.new);

final visibleProjectsProvider = Provider<List<Project>>((ref) {
  final tab = ref.watch(projectTabProvider);
  final wanted = const [null, 'Prototype', 'En cours', 'Financement'][tab.clamp(0, 3)];
  return [for (final p in ref.watch(projectsProvider)) if (wanted == null || p.stage == wanted) p];
});

final currentProjectProvider = Provider<Project>((ref) {
  final all = ref.watch(projectsProvider);
  final t = ref.watch(selectedProjectProvider);
  return all.firstWhere((p) => p.title == t, orElse: () => all.first);
});

Color stageFill(String s) => switch (s) {
      'En cours' => const Color(0xFFEFEBFA),
      'Financement' => const Color(0xFFEEE9FF),
      'Terminé' => const Color(0xFFDDF5EC),
      _ => const Color(0xFFF2EFF6),
    };

Color stageInk(String s) => switch (s) {
      'En cours' => const Color(0xFF5A3FE0),
      'Financement' => const Color(0xFF8F5400),
      'Terminé' => const Color(0xFF0F7A52),
      _ => const Color(0xFF66636E),
    };

void submitProject(WidgetRef ref, BuildContext context) {
  final f = ref.read(formProvider);
  final title = (f['pj_title'] ?? '').trim();
  final dept = (f['pj_dept'] ?? 'Génie électrique').trim();
  final stage = (f['pj_stage'] ?? 'Idée / Prototype / Réalisation').toLowerCase();
  final desc = (f['pj_desc'] ?? '').trim();
  final errs = <String, String>{
    if (title.length < 3) 'pj_title': 'Donnez un titre au projet (3 caractères minimum).',
    if (dept.isEmpty) 'pj_dept': 'Indiquez le département.',
    if (!(stage.contains('idée') || stage.contains('idee') || stage.contains('proto') || stage.contains('réal') || stage.contains('real')) ) 'pj_stage': 'Choisissez : Idée, Prototype ou Réalisation.',
    if (desc.length < 20) 'pj_desc': 'Décrivez le problème et la solution (20 caractères minimum).',
  };
  if (errs.isNotEmpty) {
    ref.read(errorsProvider.notifier).setAll(errs);
    return;
  }
  if (ref.read(projectsProvider).any((p) => p.title.toLowerCase() == title.toLowerCase())) {
    ref.read(errorsProvider.notifier).setAll({'pj_title': 'Un projet porte déjà ce titre.'});
    return;
  }
  ref.read(errorsProvider.notifier).clear();
  final real = stage.contains('réal') || stage.contains('real');
  final me = ref.read(profileAccountProvider);
  ref.read(projectsProvider.notifier).add(Project(title, dept, real ? 40 : 10, real ? 'En cours' : 'Prototype', lead: me.name, contributors: 1, milestones: 1, desc: desc));
  ref.read(auditProvider.notifier).log(me.name, 'Projet soumis', title, 'Validations');
  ref.read(projectTabProvider.notifier).set(0);
  gToast(context, 'Projet soumis : il apparaît dans le catalogue');
  gOpen(context, '78');
}

Future<void> supportDialog(BuildContext context, WidgetRef ref) async {
  final p = ref.read(currentProjectProvider);
  final msg = await askText(context, title: 'Soutenir « ${p.title} »', body: 'Indiquez un message d’encouragement ou le montant de votre contribution (FCFA).', hint: 'Ex. 5 000 FCFA, bravo à l’équipe !', ok: 'Soutenir', min: 3);
  if (msg == null || !context.mounted) return;
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Projet soutenu', p.title, 'Finances');
  gToast(context, 'Merci ! Votre soutien est transmis à l’équipe');
}

// ------------------------------------------------------------------ opportunités (75, 151)

class Opportunity {
  const Opportunity(this.title, this.org, this.kind, {this.score = 80});
  final String title, org, kind;
  final int score;
}

const opportunities = <Opportunity>[
  Opportunity('Stage développeur web', 'Orange Cameroun · Douala', 'Stage', score: 92),
  Opportunity('Assistant graphiste', 'Studio Kreatif · Douala', 'Stage', score: 85),
  Opportunity('Technicien électronique', 'Camlight · Douala · 6 mois', 'Emploi', score: 78),
  Opportunity('Chargé de communication', 'Mairie de Douala · 3 mois', 'Stage', score: 74),
  Opportunity('Hackathon Orange Digital', 'Inscriptions jusqu’au 30 oct.', 'Hackathon', score: 88),
  Opportunity('Défi : paiement mobile', 'Prix de 500 000 FCFA', 'Défi', score: 81),
  Opportunity('Stage marketing digital', 'Clôture dans 2 jours', 'Stage', score: 70),
  Opportunity('Concours d’innovation', 'Clôture dans 5 jours', 'Défi', score: 66),
  Opportunity('Développeur mobile junior', 'Camtel · Douala · CDD', 'Emploi', score: 83),
  Opportunity('Refonte du site vitrine', 'Boulangerie Mbella · Mission', 'Mission', score: 77),
];

class Applications extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {'Technicien électronique': 'Candidature envoyée'};
  void apply(String title, String motivation) => state = {...state, title: motivation};
}

final applicationsProvider = NotifierProvider<Applications, Map<String, String>>(Applications.new);
final oppTabProvider = NotifierProvider<IntV, int>(IntV.new); // écran 75 : Stages, Emplois, Défis, Missions
final oppHubTabProvider = NotifierProvider<IntV, int>(IntV.new); // écran 151 : Tout, Stages, Emplois, Projets, Défis, Hackathons

final visibleOpportunities75 = Provider<List<Opportunity>>((ref) {
  final kind = const ['Stage', 'Emploi', 'Défi', 'Mission'][ref.watch(oppTabProvider).clamp(0, 3)];
  return [for (final o in opportunities) if (o.kind == kind) o];
});

final visibleOpportunities151 = Provider<List<Opportunity>>((ref) {
  final tab = ref.watch(oppHubTabProvider).clamp(0, 5);
  final kind = const [null, 'Stage', 'Emploi', 'Projet', 'Défi', 'Hackathon'][tab];
  return [for (final o in opportunities) if (kind == null || o.kind == kind) o];
});

Color oppFill(bool applied) => applied ? const Color(0xFFDDF5EC) : const Color(0xFFEFEBFA);
Color oppInk(bool applied) => applied ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0);

Future<void> applyDialog(BuildContext context, WidgetRef ref, Opportunity o) async {
  if (ref.read(applicationsProvider).containsKey(o.title)) {
    gToast(context, 'Vous avez déjà postulé à « ${o.title} »');
    return;
  }
  final msg = await askText(context, title: 'Postuler : ${o.title}', body: '${o.org}\nCompatibilité avec votre profil : ${o.score} %', hint: 'Votre message de motivation', ok: 'Envoyer ma candidature', min: 20);
  if (msg == null || !context.mounted) return;
  ref.read(applicationsProvider.notifier).apply(o.title, msg);
  ref.read(auditProvider.notifier).log(ref.read(profileAccountProvider).name, 'Candidature envoyée', o.title, 'Validations');
  gToast(context, 'Candidature envoyée : ${o.title}');
}
