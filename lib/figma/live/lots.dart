import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FactorStatus;

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'seller.dart';
import 'share.dart';
import 'store.dart' show ordersProvider, viewedOrderProvider;

/// Lots « missions, vœux, campagnes, certificats, bornes, projets » (migration 20261031a).
/// Chaque action lit les champs réellement saisis, appelle une fonction serveur qui vérifie le rôle, l'état et les données,
/// puis affiche le résultat du serveur. Rien n'est simulé : sans serveur, l'action l'explique.

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: Color(0xFF111015));
const _muted = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF66636E));

/// Valeur d'un champ du formulaire : la saisie, sinon la valeur affichée par la maquette (champ prérempli).
String field(WidgetRef ref, String key, [String shown = '']) {
  final v = ref.read(formProvider.notifier).get(key).trim();
  return v.isEmpty ? shown : v;
}

/// Premier nombre entier d'un texte (« 300 000 – 500 000 FCFA » → 300000) ; null s'il n'y en a pas.
int? firstInt(String s) => _ints(s).firstOrNull;

/// Deuxième nombre d'une fourchette (« 300 000 – 500 000 » → 500000), sinon le premier.
int? lastInt(String s) => _ints(s).lastOrNull;

List<int> _ints(String s) => [
      for (final m in RegExp(r'\d[\d\s\u202f\u00a0.]*').allMatches(s))
        if (int.tryParse(m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '')) case final n?) n,
    ];

Future<bool> _ready(BuildContext context, WidgetRef ref, String need) async {
  if (!Backend.ready) {
    await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return false;
  }
  return requireLogin(context, ref, need);
}

/// Appelle une fonction serveur et affiche son refus éventuel ; renvoie la valeur en cas de succès.
Future<({bool ok, Object? data})> _run(BuildContext context, String fn, Map<String, dynamic> params,
    {String title = 'Action impossible', Duration? timeout, String? timeoutMessage}) async {
  final r = await Backend.rpc(fn, params, timeout: timeout, timeoutMessage: timeoutMessage);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, title, r.error!);
    return (ok: false, data: null);
  }
  return (ok: true, data: r.data);
}


/// Copie dans le presse-papiers sans jamais interrompre l'action : le navigateur peut la refuser
/// (permission, ou copie demandée après un appel réseau, hors du geste de l'utilisateur). Renvoie vrai si la copie a eu lieu.
Future<bool> copyText(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------- dialogues génériques

/// Formulaire en fenêtre : renvoie les valeurs saisies (dans l'ordre des champs) ou null si annulé.
Future<List<String>?> formDialog(BuildContext context, String title, List<(String label, String initial)> fields, {String submit = 'Enregistrer', String? intro}) {
  final ctrls = [for (final f in fields) TextEditingController(text: f.$2)];
  return gDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (intro != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(intro, style: _muted)),
          for (var i = 0; i < fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: ctrls[i], decoration: InputDecoration(labelText: fields[i].$1, border: const OutlineInputBorder(), isDense: true), style: _st),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, [for (final c in ctrls) c.text.trim()]), child: Text(submit)),
      ],
    ),
  );
}

/// Liste de lignes serveur, avec des actions par ligne. Chaque action renvoie true pour fermer la fenêtre (liste à recharger).
Future<void> _listDialog(BuildContext context, String title, List<Map<String, dynamic>> rows, String Function(Map<String, dynamic>) line,
    {String Function(Map<String, dynamic>)? sub,
    List<(String, Future<bool> Function(Map<String, dynamic>))> Function(Map<String, dynamic>)? actions,
    (String, Future<bool> Function())? footer,
    String empty = 'Aucun élément.'}) {
  return gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        // Colonne défilante (et non ListView) : chaque ligne reste exposée aux lecteurs d'écran.
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (rows.isEmpty) Text(empty, style: _muted),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(line(r), style: _st.copyWith(fontWeight: FontWeight.w600)),
                if (sub != null) Text(sub(r), style: _muted),
                if (actions != null)
                  Wrap(spacing: 8, children: [
                    for (final a in actions(r))
                      TextButton(
                        onPressed: () async {
                          if (await a.$2(r) && ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(a.$1),
                      ),
                  ]),
              ]),
            ),
        ])),
      ),
      actions: [
        if (footer != null)
          TextButton(
            onPressed: () async {
              if (await footer.$2() && ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(footer.$1),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
      ],
    ),
  );
}

Future<List<Map<String, dynamic>>?> _load(BuildContext context, String table, String select, {Map<String, Object> eq = const {}, String order = 'created_at'}) async {
  final r = await Backend.rows(table, select, eq: eq, order: order);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, 'Lecture impossible', r.error!);
    return null;
  }
  return r.rows;
}

String _status(String s) => const {
      'draft': 'Brouillon', 'published': 'Publié', 'submitted': 'En attente de validation', 'approved': 'Validé', 'rejected': 'Refusé',
      'scheduled': 'Planifié', 'assigned': 'Attribué', 'in_progress': 'En cours', 'delivered': 'Livré', 'closed': 'Clôturé', 'cancelled': 'Annulé',
      'accepted': 'Acceptée', 'declined': 'Déclinée', 'withdrawn': 'Retirée', 'pending': 'À livrer', 'validated': 'Validé', 'correction': 'Correction demandée',
    }[s] ??
    s;

String _money(Object? v) {
  final n = v is num ? v.round() : int.tryParse('$v') ?? 0;
  final s = '$n';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b FCFA';
}

// ---------------------------------------------------------------- besoins et missions (90, 93b, 199, 202, 234, 285)

/// Écran 90 : enregistre le besoin (brouillon) ou le publie pour recevoir des propositions.
Future<void> saveNeed(BuildContext context, WidgetRef ref, {required bool publish}) async {
  if (!await _ready(context, ref, 'publier un besoin')) return;
  final title = field(ref, 'b_title');
  if (title.length < 3) return gAlert(context, 'Titre manquant', 'Donnez un titre à votre besoin (3 caractères minimum).');
  final desc = [field(ref, 'b_desc'), 'Catégorie : ${field(ref, 'b_cat', 'Développement')}'].where((x) => x.isNotEmpty).join('\n');
  final budget = field(ref, 'b_budget', '300 000 – 500 000 FCFA');
  if (!context.mounted) return;
  final r = await _run(context, 'save_mission', {
    'p_id': null, 'p_title': title, 'p_description': desc, 'p_budget_min': firstInt(budget), 'p_budget_max': lastInt(budget),
    'p_deadline': field(ref, 'b_deadline', '30 nov. 2026'), 'p_publish': publish, 'p_kind': 'besoin',
  }, title: publish ? 'Besoin non publié' : 'Brouillon non enregistré');
  if (!r.ok || !context.mounted) return;
  ref.read(formProvider.notifier).clear(const ['b_title', 'b_cat', 'b_desc', 'b_budget', 'b_deadline']);
  gToast(context, publish ? 'Besoin publié : les talents peuvent vous faire des propositions.' : 'Brouillon enregistré.');
  if (publish) gBack(context);
}

/// Écran 202 : « Commander le pack » crée une demande de mission sur mesure ; « Personnaliser » ouvre le formulaire de besoin.
Future<void> orderPack(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'commander le pack')) return;
  if (!context.mounted) return;
  final r = await _run(context, 'save_mission', {
    'p_id': null, 'p_title': 'Pack Lancement de marque',
    'p_description': 'Identité visuelle (MMI), fabrication du produit (BTA), photo et vidéo (TCO), emballage (GMP) : un seul interlocuteur.',
    'p_budget_min': null, 'p_budget_max': null, 'p_deadline': '', 'p_publish': true, 'p_kind': 'mission',
  });
  if (r.ok && context.mounted) gToast(context, 'Demande envoyée : le département qualifie les équipes et vous répond.');
}

/// Mes besoins : propositions reçues (accepter, refuser) et jalons livrés (valider, demander une correction).
Future<void> myNeedsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter vos besoins')) return;
  final me = Backend.currentUserId;
  if (!context.mounted) return;
  final missions = await _load(context, 'missions', 'id,number,title,status,budget_min,budget_max,client_id', order: 'updated_at');
  if (missions == null || !context.mounted) return;
  final mine = missions.where((m) => m['client_id'] == me).toList();
  if (mine.isEmpty) return gAlert(context, 'Mes besoins', 'Vous n’avez encore publié aucun besoin.');
  final ids = {for (final m in mine) m['id']};
  final props = (await _load(context, 'mission_proposals', 'id,mission_id,amount,delay_days,message,status')) ?? const [];
  final miles = (await _load(context, 'mission_milestones', 'mission_id,position,title,amount,status', order: 'position')) ?? const [];
  if (!context.mounted) return;
  final rows = <Map<String, dynamic>>[
    for (final p in props)
      if (ids.contains(p['mission_id'])) {...p, '_t': 'p', '_m': mine.firstWhere((m) => m['id'] == p['mission_id'])},
    for (final j in miles)
      if (ids.contains(j['mission_id'])) {...j, '_t': 'j', '_m': mine.firstWhere((m) => m['id'] == j['mission_id'])},
  ];
  if (rows.isEmpty) {
    return gAlert(context, 'Mes besoins', [for (final m in mine) '${m['title'] ?? m['number']} · ${_status('${m['status']}')}'].join('\n'));
  }
  await _listDialog(
    context,
    'Mes besoins',
    rows,
    (r) => r['_t'] == 'p' ? 'Proposition · ${_money(r['amount'])} en ${r['delay_days']} j' : 'Jalon ${r['position']} · ${r['title']} (${_money(r['amount'])})',
    sub: (r) => '${(r['_m'] as Map)['title'] ?? (r['_m'] as Map)['number']} · ${_status('${r['status']}')}${r['message'] == null ? '' : ' · ${r['message']}'}',
    actions: (r) => r['_t'] == 'p'
        ? [
            if (r['status'] == 'submitted') ('Accepter', (x) => _decideProposal(context, x, true)),
            if (r['status'] == 'submitted') ('Refuser', (x) => _decideProposal(context, x, false)),
          ]
        : [
            if (r['status'] == 'submitted') ('Valider', (x) => _decideMilestone(context, x, true)),
            if (r['status'] == 'submitted') ('Demander une correction', (x) => _decideMilestone(context, x, false)),
          ],
  );
}

Future<bool> _decideProposal(BuildContext context, Map<String, dynamic> p, bool accept) async {
  final r = await _run(context, 'decide_proposal', {'p_id': p['id'], 'p_accept': accept});
  if (r.ok && context.mounted) gToast(context, accept ? 'Proposition acceptée : la mission est attribuée.' : 'Proposition refusée.');
  return r.ok;
}

Future<bool> _decideMilestone(BuildContext context, Map<String, dynamic> j, bool validate) async {
  var note = '';
  if (!validate) {
    final v = await formDialog(context, 'Demander une correction', [('Correction attendue', '')], submit: 'Envoyer');
    if (v == null) return false;
    note = v.first;
  }
  if (!context.mounted) return false;
  final r = await _run(context, 'decide_milestone', {'p_mission': j['mission_id'], 'p_position': j['position'], 'p_validate': validate, 'p_note': note});
  if (r.ok && context.mounted) {
    gToast(context, validate ? 'Jalon validé. Le versement suivra l’activation des paiements Mobile Money.' : 'Correction demandée au prestataire.');
  }
  return r.ok;
}

/// Talents : besoins publiés, avec proposition d'un montant et d'un délai.
Future<void> openNeedsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'répondre à un besoin')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'missions', 'id,number,title,description,budget_min,budget_max,deadline,status,client_id', eq: {'status': 'published'});
  if (rows == null || !context.mounted) return;
  final me = Backend.currentUserId;
  final open = rows.where((m) => m['client_id'] != me).toList();
  if (open.isEmpty) return gAlert(context, 'Besoins à pourvoir', 'Aucun besoin publié pour le moment.');
  await _listDialog(
    context,
    'Besoins à pourvoir',
    open,
    (m) => '${m['title'] ?? m['number']}',
    sub: (m) => [if (m['budget_max'] != null) 'Budget ${_money(m['budget_min'])} – ${_money(m['budget_max'])}', if (m['deadline'] != null) 'avant le ${m['deadline']}'].join(' · '),
    actions: (m) => [
      ('Proposer', (x) async {
        final v = await formDialog(context, 'Ma proposition', [('Montant (FCFA)', ''), ('Délai (jours)', ''), ('Message', '')], submit: 'Envoyer');
        if (v == null || !context.mounted) return false;
        final r = await _run(context, 'propose_on_mission', {'p_mission': x['id'], 'p_amount': firstInt(v[0]), 'p_delay_days': firstInt(v[1]), 'p_message': v[2]});
        if (r.ok && context.mounted) gToast(context, 'Proposition envoyée.');
        return r.ok;
      }),
    ],
  );
}

/// Talents : missions obtenues, jalons à livrer.
Future<void> myMissionsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'suivre vos missions')) return;
  if (!context.mounted) return;
  final props = await _load(context, 'mission_proposals', 'mission_id,status,amount');
  if (props == null || !context.mounted) return;
  final won = {for (final p in props) if (p['status'] == 'accepted') p['mission_id']};
  final miles = ((await _load(context, 'mission_milestones', 'mission_id,position,title,amount,status,note', order: 'position')) ?? const [])
      .where((j) => won.contains(j['mission_id']))
      .toList();
  if (!context.mounted) return;
  if (miles.isEmpty) {
    return gAlert(context, 'Mes missions', props.isEmpty ? 'Vous n’avez encore fait aucune proposition.' : [for (final p in props) 'Proposition ${_money(p['amount'])} · ${_status('${p['status']}')}'].join('\n'));
  }
  await _listDialog(
    context,
    'Mes missions',
    miles,
    (j) => 'Jalon ${j['position']} · ${j['title']}',
    sub: (j) => '${_status('${j['status']}')} · ${_money(j['amount'])}${j['note'] == null ? '' : ' · ${j['note']}'}',
    actions: (j) => [
      if (j['status'] == 'pending' || j['status'] == 'correction')
        ('Déclarer livré', (x) async {
          final r = await _run(context, 'submit_milestone', {'p_mission': x['mission_id'], 'p_position': x['position']});
          if (r.ok && context.mounted) gToast(context, 'Jalon déclaré livré : le client va le valider.');
          return r.ok;
        }),
    ],
  );
}

/// Écran 199 (département) : attribue un besoin publié à l'équipe affichée.
Future<void> assignNeedDialog(BuildContext context, WidgetRef ref, {String team = 'Aminata Bello · MMI'}) async {
  if (!await _ready(context, ref, 'attribuer un besoin')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'missions', 'id,number,title,status', eq: {'status': 'published'});
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Attribuer', 'Aucun besoin publié en attente d’attribution.');
  await _listDialog(context, 'Attribuer à : $team', rows, (m) => '${m['title'] ?? m['number']}', sub: (m) => '${m['number']}', actions: (m) => [
        ('Attribuer', (x) async {
          final r = await _run(context, 'assign_mission', {'p_mission': x['id'], 'p_team': team});
          if (r.ok && context.mounted) gToast(context, 'Besoin attribué à $team.');
          return r.ok;
        }),
      ]);
}

// ---------------------------------------------------------------- vœux (218, validation par le département)

Future<void> saveWish(BuildContext context, WidgetRef ref, {required bool submit}) async {
  if (!await _ready(context, ref, 'publier un vœu')) return;
  final title = field(ref, 'w_title', 'Lampe en bois recyclé');
  if (!context.mounted) return;
  final r = await _run(context, 'save_wish', {
    'p_id': null, 'p_title': title, 'p_description': field(ref, 'w_desc'), 'p_price': firstInt(field(ref, 'w_price', '25 000 FCFA')),
    'p_threshold': firstInt(field(ref, 'w_threshold', '200')), 'p_duration_days': firstInt(field(ref, 'w_duration', '30 jours')), 'p_submit': submit,
  }, title: submit ? 'Vœu non envoyé' : 'Brouillon non enregistré');
  if (!r.ok || !context.mounted) return;
  ref.read(formProvider.notifier).clear(const ['w_title', 'w_desc', 'w_price', 'w_threshold', 'w_duration']);
  gToast(context, submit ? 'Vœu envoyé : votre département le valide avant sa mise en ligne.' : 'Brouillon enregistré.');
  if (submit) gBack(context);
}

/// Mes vœux : état de validation, suppression d'un brouillon ou d'un vœu refusé.
Future<void> myWishesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter vos vœux')) return;
  final me = Backend.currentUserId;
  if (!context.mounted) return;
  final rows = (await _load(context, 'wishes', 'id,title,status,price,threshold,review_note,author_id'))?.where((w) => w['author_id'] == me).toList();
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Mes vœux', 'Vous n’avez encore proposé aucun vœu.');
  await _listDialog(context, 'Mes vœux', rows, (w) => '${w['title']}', sub: (w) => '${_status('${w['status']}')}${w['review_note'] == null ? '' : ' · ${w['review_note']}'}', actions: (w) => [
        if (w['status'] == 'draft' || w['status'] == 'rejected')
          ('Supprimer', (x) async {
            final r = await _run(context, 'delete_wish', {'p_id': x['id']});
            if (r.ok && context.mounted) gToast(context, 'Vœu supprimé.');
            return r.ok;
          }),
      ]);
}

/// Département : vœux à valider (valider, refuser avec motif, planifier la mise en ligne).
Future<void> reviewWishesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'valider les vœux')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'wishes', 'id,title,description,price,threshold,duration_days,status', eq: {'status': 'submitted'});
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Vœux à valider', 'Aucun vœu en attente.');
  Future<bool> decide(Map<String, dynamic> w, String d) async {
    var note = '', when = '';
    if (d != 'approved') {
      final v = await formDialog(context, d == 'rejected' ? 'Motif du refus' : 'Planifier la mise en ligne', [(d == 'rejected' ? 'Motif' : 'Date de mise en ligne', '')], submit: 'Confirmer');
      if (v == null) return false;
      d == 'rejected' ? note = v.first : when = v.first;
    }
    if (!context.mounted) return false;
    final r = await _run(context, 'review_wish', {'p_id': w['id'], 'p_decision': d, 'p_note': note, 'p_scheduled_for': when});
    if (r.ok && context.mounted) gToast(context, 'Décision enregistrée ; l’auteur est notifié.');
    return r.ok;
  }

  await _listDialog(context, 'Vœux à valider', rows, (w) => '${w['title']}',
      sub: (w) => '${_money(w['price'])} · seuil ${w['threshold'] ?? '?'} · ${w['duration_days'] ?? '?'} j',
      actions: (w) => [('Valider', (x) => decide(x, 'approved')), ('Planifier', (x) => decide(x, 'scheduled')), ('Refuser', (x) => decide(x, 'rejected'))]);
}

// ---------------------------------------------------------------- campagnes (84)

Future<void> saveCampaign(BuildContext context, WidgetRef ref, {required bool submit}) async {
  if (!await _ready(context, ref, 'créer une campagne')) return;
  final kindLabel = field(ref, 'c_kind', 'Financement participatif').toLowerCase();
  final kind = kindLabel.contains('précommande') ? 'preorder' : (kindLabel.contains('sponsor') ? 'sponsoring' : 'project');
  if (!context.mounted) return;
  final r = await _run(context, 'save_campaign', {
    'p_id': null, 'p_kind': kind, 'p_project': field(ref, 'c_project', 'Serre intelligente'), 'p_goal': firstInt(field(ref, 'c_goal', '2 000 000')),
    'p_duration_days': firstInt(field(ref, 'c_duration', '30 jours')), 'p_presentation': field(ref, 'c_pres'), 'p_rewards': null, 'p_submit': submit,
  }, title: submit ? 'Campagne non envoyée' : 'Brouillon non enregistré');
  if (!r.ok || !context.mounted) return;
  ref.read(formProvider.notifier).clear(const ['c_kind', 'c_project', 'c_goal', 'c_duration', 'c_pres']);
  gToast(context, submit ? 'Campagne envoyée au département pour validation.' : 'Brouillon enregistré.');
  if (submit) gBack(context);
}

/// Département : campagnes, projets à examiner.
Future<void> reviewCampaignsDialog(BuildContext context, WidgetRef ref) =>
    _reviewQueue(context, ref, 'campaigns', 'id,project,goal,duration_days,presentation,status', 'review_campaign', 'Campagnes à valider', (c) => '${c['project']}', (c) => 'Objectif ${_money(c['goal'])} · ${c['duration_days']} j');

Future<void> reviewProjectsDialog(BuildContext context, WidgetRef ref) =>
    _reviewQueue(context, ref, 'projects', 'id,title,summary,department,status', 'review_project', 'Projets à examiner', (p) => '${p['title']}', (p) => '${p['summary'] ?? ''}');

Future<void> _reviewQueue(BuildContext context, WidgetRef ref, String table, String select, String fn, String title, String Function(Map<String, dynamic>) line, String Function(Map<String, dynamic>) sub) async {
  if (!await _ready(context, ref, 'valider')) return;
  if (!context.mounted) return;
  final rows = await _load(context, table, select, eq: {'status': 'submitted'});
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, title, 'Rien en attente de validation.');
  Future<bool> decide(Map<String, dynamic> x, bool ok) async {
    var note = '';
    if (!ok) {
      final v = await formDialog(context, 'Motif du refus', [('Motif', '')], submit: 'Refuser');
      if (v == null) return false;
      note = v.first;
    }
    if (!context.mounted) return false;
    final r = await _run(context, fn, {'p_id': x['id'], 'p_approve': ok, 'p_note': note});
    if (r.ok && context.mounted) gToast(context, 'Décision enregistrée ; le porteur est notifié.');
    return r.ok;
  }

  await _listDialog(context, title, rows, line, sub: sub, actions: (x) => [('Valider', (y) => decide(y, true)), ('Refuser', (y) => decide(y, false))]);
}

// ---------------------------------------------------------------- projets (205, 82, 278)

Future<void> saveProject(BuildContext context, WidgetRef ref, {required bool submit}) async {
  if (!await _ready(context, ref, 'soumettre votre projet')) return;
  final budget = field(ref, 'p_budget', '1 500 000 FCFA');
  final summary = [field(ref, 'p_summary', 'Les maraîchers perdent des récoltes à cause de la chaleur…'), 'Besoin estimé : $budget'].join('\n');
  if (!context.mounted) return;
  final r = await _run(context, 'save_project', {
    'p_id': null, 'p_title': field(ref, 'p_title', 'Serre intelligente pour maraîchers'), 'p_summary': summary, 'p_department': null, 'p_links': <String, dynamic>{}, 'p_submit': submit,
  }, title: submit ? 'Projet non envoyé' : 'Brouillon non enregistré');
  if (!r.ok || !context.mounted) return;
  gToast(context, submit ? 'Projet envoyé à l’IUT : le département l’examine.' : 'Brouillon enregistré.');
  if (submit) gBack(context);
}

Future<Map<String, dynamic>?> _myLatestProject(BuildContext context) async {
  final me = Backend.currentUserId;
  final rows = await _load(context, 'projects', 'id,title,links,owner_id', order: 'updated_at');
  final mine = rows?.where((p) => p['owner_id'] == me).toList() ?? const [];
  if (rows != null && mine.isEmpty && context.mounted) {
    await gAlert(context, 'Aucun projet', 'Créez d’abord votre projet depuis « Soumettre mon projet ».');
  }
  return mine.isEmpty ? null : mine.first;
}

/// Écran 82 : ajoute une étape datée au journal du projet le plus récent.
Future<void> addProjectStep(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'compléter le journal du projet')) return;
  if (!context.mounted) return;
  final p = await _myLatestProject(context);
  if (p == null || !context.mounted) return;
  final v = await formDialog(context, 'Nouvelle étape', [('Étape réalisée', '')], intro: 'Projet : ${p['title']}', submit: 'Ajouter');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'add_project_step', {'p_project': p['id'], 'p_title': v.first});
  if (r.ok && context.mounted) gToast(context, 'Étape ajoutée au journal du projet.');
}

/// Écran 278 : liens du projet (GitHub, démo, documentation, vidéo), enregistrés sur le projet le plus récent.
Future<void> saveProjectLinks(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'enregistrer les liens du projet')) return;
  if (!context.mounted) return;
  final p = await _myLatestProject(context);
  if (p == null || !context.mounted) return;
  final cur = Map<String, dynamic>.from((p['links'] as Map?) ?? const {});
  final v = await formDialog(context, 'Liens du projet', [
    ('GitHub', '${cur['github'] ?? ''}'), ('Démo en ligne', '${cur['demo'] ?? ''}'), ('Documentation', '${cur['docs'] ?? ''}'), ('Vidéo de présentation', '${cur['video'] ?? ''}'),
  ], intro: 'Projet : ${p['title']} · adresses https:// uniquement');
  if (v == null || !context.mounted) return;
  final links = <String, dynamic>{};
  for (final (k, x) in [('github', v[0]), ('demo', v[1]), ('docs', v[2]), ('video', v[3])]) {
    if (x.isEmpty) continue;
    if (!RegExp(r'^https://\S{3,300}$').hasMatch(x)) return gAlert(context, 'Lien invalide', '« $x » : une adresse commençant par https:// est attendue.');
    links[k] = x;
  }
  final r = await _run(context, 'save_project', {'p_id': p['id'], 'p_title': p['title'], 'p_summary': null, 'p_department': null, 'p_links': links, 'p_submit': false});
  if (r.ok && context.mounted) gToast(context, 'Liens du projet enregistrés.');
}

// ---------------------------------------------------------------- services (59), lives (224), liens du profil (271, P5)

/// Écran 59 : un service est une annonce de catégorie « Services », validée par le département comme un produit.
Future<void> saveService(BuildContext context, WidgetRef ref, {required bool submit}) async {
  if (!await _ready(context, ref, 'publier un service')) return;
  final title = field(ref, 's_title');
  final price = firstInt(field(ref, 's_price', '30 000'));
  if (title.length < 3) return gAlert(context, 'Titre manquant', 'Donnez un titre à votre service (3 à 80 caractères).');
  if (price == null || price < 500) return gAlert(context, 'Tarif invalide', 'Indiquez un tarif d’au moins 500 FCFA.');
  final desc = [field(ref, 's_desc'), 'Délai moyen : ${field(ref, 's_delay', '3 à 7 jours')}', 'Prestation : ${field(ref, 's_mode', 'À distance ou sur campus')}',
    'Domaine : ${field(ref, 's_cat', 'Développement')}'].where((x) => x.isNotEmpty).join('\n');
  final r = await Backend.createListing(Listing(title: title, category: 'Services', price: price, stock: 999, description: desc), submit: submit);
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, submit ? 'Service non soumis' : 'Brouillon non enregistré', r.error!);
  ref.read(formProvider.notifier).clear(const ['s_title', 's_cat', 's_price', 's_delay', 's_mode', 's_desc']);
  gToast(context, submit ? 'Service soumis : il sera visible après validation du département.' : 'Brouillon enregistré.');
  if (submit) gBack(context);
}

Future<void> saveLive(BuildContext context, WidgetRef ref, {required bool schedule}) async {
  if (!await _ready(context, ref, 'programmer un live')) return;
  if (!context.mounted) return;
  final r = await _run(context, 'save_live', {
    'p_title': field(ref, 'l_title', 'Fabrication de la lampe en bois recyclé'), 'p_starts_at': field(ref, 'l_date', 'Jeudi 29 oct. · 16 h'),
    'p_product': 'Lampe en bois recyclé', 'p_schedule': schedule,
  });
  if (r.ok && context.mounted) gToast(context, schedule ? 'Live programmé : il apparaît dans « Prochains lives ».' : 'Brouillon enregistré.');
}

/// Liens ajoutés pendant la session (271, P5), enregistrés ensemble.
class PendingLinks extends Notifier<List<Map<String, String>>> {
  @override
  List<Map<String, String>> build() => const [];
  void add(String label, String url) => state = [...state, {'label': label, 'url': url}];
  void clear() => state = const [];
}

final pendingLinksProvider = NotifierProvider<PendingLinks, List<Map<String, String>>>(PendingLinks.new);

Future<void> addProfileLink(BuildContext context, WidgetRef ref) async {
  final v = await formDialog(context, 'Ajouter un lien', [('Nom (portfolio, site, Drive…)', ''), ('Adresse https://', 'https://')], submit: 'Ajouter');
  if (v == null || !context.mounted) return;
  if (!RegExp(r'^https://\S{3,300}$').hasMatch(v[1])) return gAlert(context, 'Lien invalide', 'Une adresse commençant par https:// est attendue.');
  ref.read(pendingLinksProvider.notifier).add(v[0].isEmpty ? 'Lien' : v[0], v[1]);
  gToast(context, 'Lien ajouté : pensez à enregistrer.');
}

Future<void> saveProfileLinks(BuildContext context, WidgetRef ref) async {
  final links = ref.read(pendingLinksProvider);
  if (links.isEmpty) return gAlert(context, 'Aucun lien', 'Ajoutez d’abord un lien avec « Ajouter un autre lien ».');
  if (!await _ready(context, ref, 'enregistrer vos liens')) return;
  if (!context.mounted) return;
  final r = await _run(context, 'save_profile_links', {'p_links': links});
  if (r.ok && context.mounted) {
    ref.read(pendingLinksProvider.notifier).clear();
    gToast(context, 'Liens enregistrés sur votre profil.');
  }
}

// ---------------------------------------------------------------- certificats (166, 211, 213, 283)

/// Émission (département, administration) : objet, titulaire et département ; le serveur vérifie l'éligibilité.
Future<void> issueCertificateDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'émettre un certificat')) return;
  if (!context.mounted) return;
  final v = await formDialog(context, 'Émettre un certificat', [
    ('Type (produit, projet ou talent)', 'produit'), ('Objet (titre exact du produit ou du projet)', ''), ('E-mail du titulaire (s’il a un compte)', ''), ('Nom du titulaire', ''), ('Département', ''),
  ], submit: 'Émettre', intro: 'Un produit doit être une annonce validée. Le certificat reçoit un code unique et une empreinte SHA-256.');
  if (v == null || !context.mounted) return;
  final t = v[0].toLowerCase();
  final kind = t.startsWith('proj') ? 'project' : (t.startsWith('tal') ? 'talent' : 'product');
  final r = await _run(context, 'issue_certificate', {'p_kind': kind, 'p_subject': v[1], 'p_holder_email': v[2], 'p_holder_name': v[3], 'p_department': v[4]}, title: 'Certificat non émis');
  if (r.ok && context.mounted) await gAlert(context, 'Certificat émis', 'Code : ${r.data}\nLe titulaire est notifié ; le code se vérifie publiquement.');
}

/// Vérification publique d'un certificat par son code (aucune donnée personnelle au-delà du certificat).
Future<void> verifyCertificateDialog(BuildContext context, WidgetRef ref, {String code = ''}) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La vérification nécessite la connexion au serveur.');
  final v = await formDialog(context, 'Vérifier un certificat', [('Code du certificat', code)], submit: 'Vérifier');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'verify_certificate', {'p_code': v.first}, title: 'Vérification impossible');
  if (!r.ok || !context.mounted) return;
  final d = Map<String, dynamic>.from((r.data as Map?) ?? const {});
  if (d['introuvable'] == true) return gAlert(context, 'Certificat introuvable', 'Aucun certificat ne porte le code ${d['code']}.');
  await gAlert(
      context,
      d['valide'] == true ? 'Certificat authentique' : 'Certificat révoqué',
      '${d['code']}\n${d['objet']}\nTitulaire : ${d['titulaire']}${d['departement'] == null ? '' : ' · ${d['departement']}'}\nDélivré le ${d['delivre_le']}'
          '${d['valide'] == true ? '' : '\nMotif : ${d['motif_revocation']}'}\nEmpreinte : ${'${d['empreinte']}'.substring(0, 16)}…');
}

/// Mes certificats (titulaire) ; sans certificat, propose la vérification d'un code.
Future<void> myCertificatesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter vos certificats')) return;
  final me = Backend.currentUserId;
  if (!context.mounted) return;
  final rows = (await _load(context, 'certificates', 'code,subject_title,issued_at,revoked,holder_id', order: 'issued_at'))?.where((c) => c['holder_id'] == me).toList();
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return verifyCertificateDialog(context, ref);
  await _listDialog(context, 'Mes certificats', rows, (c) => '${c['subject_title']}', sub: (c) => '${c['code']}${c['revoked'] == true ? ' · révoqué' : ''}', actions: (c) => [
        ('Copier le code', (x) async {
          final ok = await copyText('${x['code']}');
          if (context.mounted) gToast(context, ok ? 'Code copié' : 'Copie refusée par le navigateur : ${x['code']}');
          return false;
        }),
        ('Partager', (x) async {
          await shareText(context, 'Certificat Boutik-École ${x['code']} — vérifiable sur $siteUrl');
          return false;
        }),
      ]);
}

// ---------------------------------------------------------------- exports CSV (284 registre financier, 288 catalogue)

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return RegExp(r'[;"\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// CSV (séparateur « ; », lisible par un tableur en français) à partir des lignes que le serveur autorise au rôle.
String toCsv(List<String> columns, List<Map<String, dynamic>> rows) =>
    [columns.join(';'), for (final r in rows) [for (final c in columns) _csvCell(r[c])].join(';')].join('\r\n');

Future<void> _export(BuildContext context, WidgetRef ref, String table, List<String> columns, String file, String need) async {
  if (!await _ready(context, ref, need)) return;
  final r = await Backend.rows(table, columns.join(','), order: 'created_at', limit: 5000);
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Export impossible', r.error!);
  if (r.rows.isEmpty) return gAlert(context, 'Rien à exporter', 'Aucune ligne visible pour votre rôle.');
  final downloaded = await saveTextFile(file, toCsv(columns, r.rows), 'text/csv');
  if (context.mounted) gToast(context, downloaded ? '${r.rows.length} lignes exportées ($file).' : '${r.rows.length} lignes copiées dans le presse-papiers.');
}

/// Écran 284 (finance, direction, administration) : commandes visibles par le rôle, avec montants et état de paiement.
Future<void> exportFinancialRegister(BuildContext context, WidgetRef ref) =>
    _export(context, ref, 'orders', const ['number', 'created_at', 'subtotal', 'fee', 'method', 'reference', 'paid', 'cancelled', 'status'], 'registre-financier.csv', 'exporter le registre financier');

/// Écran 288 (département, administration) : fiches du catalogue visibles par le rôle.
Future<void> exportCatalog(BuildContext context, WidgetRef ref) =>
    _export(context, ref, 'listings', const ['title', 'department', 'category', 'price', 'stock', 'status', 'created_at'], 'catalogue.csv', 'exporter le catalogue');

// ---------------------------------------------------------------- bornes (206, 276, 277, 282)

/// Écran 206 : état réel de la connexion au serveur.
Future<void> kioskNetworkCheck(BuildContext context) async {
  if (!Backend.ready) return gAlert(context, 'Borne hors ligne', 'Le catalogue reste consultable hors ligne ; les commandes reprendront au retour du réseau.');
  final r = await Backend.rows('kiosks', 'id', limit: 1);
  if (!context.mounted) return;
  r.error == null || r.error!.contains('pas encore activée')
      ? gToast(context, 'Borne prête · réseau OK')
      : await gAlert(context, 'Réseau indisponible', 'Le serveur ne répond pas. Le catalogue reste consultable hors ligne.');
}

/// Écran 277 (support, administration) : journal des incidents et signalement d'un nouvel incident.
Future<void> kioskIncidentsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter les incidents des bornes')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'kiosk_incidents', 'id,kiosk_id,kind,message,created_at,resolved_at');
  if (rows == null || !context.mounted) return;
  await _listDialog(context, 'Journal des incidents', rows, (i) => '${i['kiosk_id']} · ${i['kind']}',
      sub: (i) => '${i['message']} · ${'${i['created_at']}'.substring(0, 16).replaceAll('T', ' ')}',
      empty: 'Aucun incident enregistré.',
      footer: ('Signaler un incident', () async {
        final v = await formDialog(context, 'Signaler un incident', [
          ('Borne (borne-1 à borne-4)', 'borne-2'), ('Type (offline, restart, fallback, hardware, payment, other)', 'offline'), ('Description', ''),
          ('Nouvel état (online, offline, fallback, maintenance) — facultatif', ''),
        ], submit: 'Signaler');
        if (v == null || !context.mounted) return false;
        final r = await _run(context, 'report_kiosk_incident', {'p_kiosk': v[0], 'p_kind': v[1], 'p_message': v[2], 'p_status': v[3].isEmpty ? null : v[3]});
        if (r.ok && context.mounted) gToast(context, 'Incident enregistré au journal.');
        return r.ok;
      }));
}

/// Écran 282 (support, administration) : programme le mode événement d'une borne sur un créneau libre.
Future<void> scheduleKioskEvent(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'programmer un événement de borne')) return;
  if (!context.mounted) return;
  final v = await formDialog(context, 'Programmer l’événement', [('Borne', 'borne-2'), ('Événement', 'Journée de l’innovation'), ('Début (AAAA-MM-JJ HH:MM)', '2026-11-12 08:00'), ('Fin (AAAA-MM-JJ HH:MM)', '2026-11-12 18:00')], submit: 'Programmer');
  if (v == null || !context.mounted) return;
  final s = DateTime.tryParse(v[2].replaceFirst(' ', 'T')), e = DateTime.tryParse(v[3].replaceFirst(' ', 'T'));
  if (s == null || e == null) return gAlert(context, 'Dates invalides', 'Format attendu : AAAA-MM-JJ HH:MM.');
  final r = await _run(context, 'schedule_kiosk_event', {'p_kiosk': v[0], 'p_title': v[1], 'p_starts': s.toUtc().toIso8601String(), 'p_ends': e.toUtc().toIso8601String()});
  if (r.ok && context.mounted) gToast(context, 'Événement programmé sur ${v[0]}.');
}

// ---------------------------------------------------------------- 20261031b : établissement (118), modèles (265), pages (264), clés (280), équipe (286)

/// Écran 118 (direction, administration) : identité de l'établissement, préremplie depuis le serveur.
Future<void> editInstitutionDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'modifier l’établissement')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'institution_settings', 'name,acronym,address,email,phone,primary_color,accent_color,font', order: 'updated_at');
  if (rows == null || !context.mounted) return;
  final c = rows.isEmpty ? const <String, dynamic>{} : rows.first;
  String v(String k, String d) => '${c[k] ?? d}';
  final f = await formDialog(context, 'Établissement et identité visuelle', [
    ('Nom', v('name', 'IUT de Douala')), ('Sigle', v('acronym', 'IUT-D')), ('Adresse', v('address', '')), ('E-mail', v('email', '')), ('Téléphone', v('phone', '')),
    ('Couleur principale (#RRVVBB)', v('primary_color', '#12253F')), ('Couleur d’accent (#RRVVBB)', v('accent_color', '#FBB52B')), ('Police', v('font', '')),
  ], submit: 'Enregistrer les modifications');
  if (f == null || !context.mounted) return;
  final r = await _run(context, 'save_institution', {
    'p_name': f[0], 'p_acronym': f[1], 'p_address': f[2], 'p_email': f[3], 'p_phone': f[4], 'p_primary': f[5], 'p_accent': f[6], 'p_font': f[7],
  }, title: 'Modifications refusées');
  if (r.ok && context.mounted) gToast(context, 'Identité de l’établissement enregistrée.');
}

/// Écran 265 (administration) : modification d'un modèle de notification (objet, message, canaux, actif).
Future<void> editTemplatesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'modifier les modèles')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'notification_templates', 'key,label,channels,subject,body,active', order: 'key');
  if (rows == null || !context.mounted) return;
  await _listDialog(context, 'Modèles de notifications', rows, (t) => '${t['label']}',
      sub: (t) => '${(t['channels'] as List?)?.join(' · ') ?? ''} · ${t['active'] == true ? 'Actif' : 'Inactif'}',
      empty: 'Aucun modèle visible pour votre rôle.',
      actions: (t) => [
            ('Modifier le modèle', (x) async {
              final f = await formDialog(context, '${x['label']}', [
                ('Objet (e-mail)', '${x['subject'] ?? ''}'), ('Message ({{nom}}, {{numero}}…)', '${x['body']}'),
                ('Canaux (email, sms, whatsapp, app)', ((x['channels'] as List?) ?? const []).join(', ')), ('Actif (oui / non)', x['active'] == true ? 'oui' : 'non'),
              ]);
              if (f == null || !context.mounted) return false;
              final r = await _run(context, 'save_notification_template', {
                'p_key': x['key'], 'p_subject': f[0], 'p_body': f[1],
                'p_channels': [for (final c in f[2].split(',')) if (c.trim().isNotEmpty) c.trim().toLowerCase()], 'p_active': !f[3].toLowerCase().startsWith('n'),
              }, title: 'Modèle non enregistré');
              if (r.ok && context.mounted) gToast(context, 'Modèle enregistré.');
              return r.ok;
            }),
          ]);
}

/// Écran 264 : aperçu d'une page éditoriale, telle que les visiteurs la voient.
Future<void> previewPagesDialog(BuildContext context) => _listDialog(
      context,
      'Aperçu des pages',
      const [
        {'t': 'Accueil', 's': '03'}, {'t': 'À propos de Boutik-École', 's': '17'}, {'t': 'FAQ', 's': '49'}, {'t': 'Conditions générales', 's': '274'},
      ],
      (p) => '${p['t']}',
      actions: (p) => [
        ('Aperçu', (x) async {
          gOpen(context, '${x['s']}');
          return true;
        }),
      ],
    );

/// Écran 280 (administration) : création d'une clé d'intégration (affichée une seule fois), liste et révocation.
Future<void> apiKeysDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'gérer les clés d’intégration')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'api_keys', 'id,label,prefix,created_at,revoked_at');
  if (rows == null || !context.mounted) return;
  await _listDialog(context, 'Clés d’intégration', rows, (k) => '${k['label']}',
      sub: (k) => '${k['prefix']}•••• · ${k['revoked_at'] == null ? 'active' : 'révoquée'}',
      empty: 'Aucune clé.',
      actions: (k) => [
            if (k['revoked_at'] == null)
              ('Révoquer', (x) async {
                final r = await _run(context, 'revoke_api_key', {'p_id': x['id']});
                if (r.ok && context.mounted) gToast(context, 'Clé révoquée : elle ne fonctionne plus.');
                return r.ok;
              }),
          ],
      footer: ('Créer une clé', () async {
        final f = await formDialog(context, 'Nouvelle clé d’intégration', [('Usage (ex. Portail entreprises)', '')], submit: 'Créer');
        if (f == null || !context.mounted) return false;
        final r = await _run(context, 'create_api_key', {'p_label': f.first});
        if (!r.ok || !context.mounted) return false;
        final copied = await copyText('${r.data}');
        if (context.mounted) {
          await gAlert(context, 'Clé créée', '${r.data}\n\n${copied ? 'Elle vient d’être copiée. ' : ''}Notez-la maintenant : elle ne sera plus jamais affichée, seule son empreinte est conservée.');
        }
        return true;
      }));
}

/// Écran 286 (département) : invitation d'un membre (e-mail et rôle) ; le compte existant est notifié.
Future<void> inviteMemberDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'inviter un membre')) return;
  if (!context.mounted) return;
  final f = await formDialog(context, 'Inviter un membre', [('E-mail', ''), ('Rôle (validator, moderator, member)', 'member')], submit: 'Inviter');
  if (f == null || !context.mounted) return;
  final r = await _run(context, 'invite_department_member', {'p_email': f[0], 'p_role': f[1].trim().toLowerCase()}, title: 'Invitation non envoyée');
  if (r.ok && context.mounted) gToast(context, r.data == 'notified' ? 'Invitation envoyée : la personne est notifiée.' : 'Invitation enregistrée : elle s’affichera à son inscription.');
}

// ---------------------------------------------------------------- fichiers (263, 83, 279, 196)

const _fileMimes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'pdf': 'application/pdf', 'mp4': 'video/mp4', 'zip': 'application/zip'};

/// Type accepté d'après l'extension (les autres sont refusés avant tout envoi) ; null si refusé.
String? acceptedMime(String name) => _fileMimes[name.split('.').last.toLowerCase()];

/// Choix, contrôle (type, taille), dépôt dans le dossier de la personne puis enregistrement serveur.
Future<String?> pickAndUpload(BuildContext context, WidgetRef ref, String scope, String? refId) async {
  if (!await _ready(context, ref, 'déposer un fichier')) return null;
  final picked = await FilePicker.pickFiles();
  if (picked.isEmpty || !context.mounted) return null;
  final f = picked.first;
  final mime = acceptedMime(f.name);
  if (mime == null) {
    await gAlert(context, 'Type refusé', '« ${f.name} » : seuls JPG, PNG, WebP, PDF, MP4 et ZIP sont acceptés.');
    return null;
  }
  final bytes = await f.readAsBytes();
  if (bytes.isEmpty || !context.mounted) return null;
  final max = mime.startsWith('image/') ? 5 * 1024 * 1024 : 50 * 1024 * 1024;
  if (bytes.length > max) {
    if (context.mounted) await gAlert(context, 'Fichier trop lourd', mime.startsWith('image/') ? '5 Mo au maximum pour une image.' : '50 Mo au maximum.');
    return null;
  }
  final up = await Backend.uploadProjectFile(scope, f.name, bytes, mime);
  if (!context.mounted) return null;
  if (up.error != null) {
    await gAlert(context, 'Dépôt impossible', up.error!);
    return null;
  }
  final r = await _run(context, 'register_file', {'p_scope': scope, 'p_ref': refId, 'p_path': up.path, 'p_name': f.name, 'p_mime': mime, 'p_size': bytes.length}, title: 'Fichier refusé');
  if (!r.ok || !context.mounted) return null;
  gToast(context, '« ${f.name} » déposé.');
  return '${r.data}';
}

/// 263 (département) : médiathèque.
Future<void> uploadMedia(BuildContext context, WidgetRef ref) => pickAndUpload(context, ref, 'media', null);

/// 83 et 279 : fichiers du projet le plus récent.
Future<void> uploadProjectFileFor(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'ajouter des fichiers au projet')) return;
  if (!context.mounted) return;
  final p = await _myLatestProject(context);
  if (p == null || !context.mounted) return;
  await pickAndUpload(context, ref, 'project', '${p['id']}');
}

// ---------------------------------------------------------------- dossier de mission (196)

Future<Map<String, dynamic>?> _pickMission(BuildContext context) async {
  final rows = await _load(context, 'missions', 'id,number,title,status', order: 'updated_at');
  final open = rows?.where((m) => const ['assigned', 'in_progress', 'delivered'].contains(m['status'])).toList() ?? const [];
  if (rows == null || !context.mounted) return null;
  final me = Backend.currentUserId;
  final props = await _load(context, 'mission_proposals', 'mission_id,status,author_id');
  final mineIds = {for (final p in props ?? const []) if (p['status'] == 'accepted' && p['author_id'] == me) p['mission_id']};
  final all = await _load(context, 'missions', 'id,client_id', order: 'updated_at');
  final asClient = {for (final m in all ?? const []) if (m['client_id'] == me) m['id']};
  final mine = open.where((m) => mineIds.contains(m['id']) || asClient.contains(m['id'])).toList();
  if (!context.mounted) return null;
  if (mine.isEmpty) {
    await gAlert(context, 'Aucun dossier', 'Le dossier s’ouvre lorsqu’une mission vous est attribuée (ou lorsque vous attribuez votre besoin).');
    return null;
  }
  if (mine.length == 1) return mine.first;
  Map<String, dynamic>? chosen;
  await _listDialog(context, 'Choisir le dossier', mine, (m) => '${m['title'] ?? m['number']}', sub: (m) => '${m['number']}', actions: (m) => [
        ('Ouvrir', (x) async {
          chosen = x;
          return true;
        }),
      ]);
  return chosen;
}

/// 196 « Envoyer » : fil du dossier (messages et fichiers), réponse et pièce jointe, entre le client et le prestataire retenu.
Future<void> missionDossierDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'ouvrir le dossier de mission')) return;
  if (!context.mounted) return;
  final m = await _pickMission(context);
  if (m == null || !context.mounted) return;
  final msgs = await _load(context, 'mission_messages', 'body,sender_id,created_at', eq: {'mission_id': m['id']}, order: 'created_at') ?? const [];
  final files = await _load(context, 'files', 'name,path,created_at', eq: {'ref': m['id']}) ?? const [];
  if (!context.mounted) return;
  final me = Backend.currentUserId;
  final ctrl = TextEditingController();
  await gDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Dossier ${m['number']}', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (msgs.isEmpty) Text('Aucun message pour le moment.', style: _muted),
            for (final x in msgs.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${x['sender_id'] == me ? 'Moi' : 'Autre partie'} · ${x['body']}', style: _st),
              ),
            for (final f in files)
              TextButton(
                onPressed: () async {
                  final u = await Backend.projectFileUrl('${f['path']}');
                  if (u != null && ctx.mounted) await openUrl(ctx, u);
                },
                child: Text('📎 ${f['name']}'),
              ),
            TextField(controller: ctrl, maxLength: 2000, decoration: const InputDecoration(labelText: 'Votre message', border: OutlineInputBorder(), isDense: true), style: _st),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final fid = await pickAndUpload(ctx, ref, 'mission', '${m['id']}');
            if (fid != null && ctx.mounted) {
              await _run(ctx, 'send_mission_message', {'p_mission': m['id'], 'p_body': 'Fichier ajouté au dossier', 'p_file': fid});
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          child: const Text('Ajouter un fichier'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        FilledButton(
          onPressed: () async {
            if (ctrl.text.trim().isEmpty) return;
            final r = await _run(ctx, 'send_mission_message', {'p_mission': m['id'], 'p_body': ctrl.text.trim(), 'p_file': null}, title: 'Message non envoyé');
            if (r.ok && ctx.mounted) {
              gToast(ctx, 'Message envoyé.');
              Navigator.pop(ctx);
            }
          },
          child: const Text('Envoyer'),
        ),
      ],
    ),
  );
}

/// 196 « Ajouter un fichier » : dépôt direct dans le dossier choisi.
Future<void> missionFileUpload(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'ajouter un fichier au dossier')) return;
  if (!context.mounted) return;
  final m = await _pickMission(context);
  if (m == null || !context.mounted) return;
  final fid = await pickAndUpload(context, ref, 'mission', '${m['id']}');
  if (fid != null && context.mounted) await _run(context, 'send_mission_message', {'p_mission': m['id'], 'p_body': 'Fichier ajouté au dossier', 'p_file': fid});
}

// ---------------------------------------------------------------- CV partagé (228), code de retrait (46, 146-2), double authentification (272)

/// 228 : nouveau lien de CV (l'ancien cesse de fonctionner), copié et prêt à partager.
Future<void> regenerateCvLink(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'partager votre CV')) return;
  if (!context.mounted) return;
  final r = await _run(context, 'regenerate_cv_link', {});
  if (!r.ok || !context.mounted) return;
  final url = '$siteUrl/#/cv/${r.data}';
  final copied = await copyText(url);
  if (context.mounted) await gAlert(context, 'Nouveau lien de CV', '$url\n\n${copied ? 'Lien copié. ' : ''}L’ancien lien ne fonctionne plus ; vos coordonnées n’y figurent pas.');
}

/// 46 : code de retrait de la commande consultée (délivré une fois la commande payée).
/// La liste des commandes du compte est relue d'abord : sans elle, l'écran montrerait la commande d'exemple de la maquette.
Future<void> showPickupCode(BuildContext context, WidgetRef ref, [String? number]) async {
  if (!await _ready(context, ref, 'voir le code de retrait')) return;
  await ref.read(ordersProvider.notifier).refresh();
  if (!context.mounted) return;
  final orderNumber = number ?? ref.read(viewedOrderProvider).id;
  if (!ref.read(ordersProvider).any((o) => o.id == orderNumber)) {
    return gAlert(context, 'Aucune commande', 'Le code de retrait apparaît ici dès qu’une de vos commandes est payée.');
  }
  final r = await _run(context, 'my_pickup_code', {'p_number': orderNumber}, title: 'Code indisponible');
  if (!r.ok || !context.mounted) return;
  final c = '${r.data}';
  await gAlert(context, 'Code de retrait', '${c.substring(0, 3)} ${c.substring(3)}\n\nCommande $orderNumber — à présenter au kiosque. Ne le communiquez à personne d’autre.');
}

/// 146-2 (kiosque) : la remise n'est confirmée qu'avec le code présenté par l'acheteur.
/// Le succès n'est annoncé que sur la réponse « delivered » du serveur ; toute autre issue (code erroné, blocage, erreur HTTP,
/// réseau, délai dépassé, réponse inattendue) affiche un refus. Une seule confirmation à la fois depuis ce poste ; le serveur
/// garantit de son côté qu'une commande n'est remise qu'une fois (verrou de ligne, date de retrait).
bool _pickupInFlight = false;

Future<void> confirmPickupDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'confirmer une remise')) return;
  if (!context.mounted) return;
  if (_pickupInFlight) {
    gToast(context, 'Une confirmation de remise est déjà en cours.');
    return;
  }
  final f = await formDialog(context, 'Confirmer la remise', [('Numéro de commande', '#BE-'), ('Code de retrait (6 chiffres)', '')], submit: 'Confirmer');
  if (f == null || !context.mounted) return;
  _pickupInFlight = true;
  try {
    final r = await _run(context, 'confirm_pickup', {'p_number': f[0], 'p_code': f[1].replaceAll(' ', '')},
        title: 'Remise refusée',
        timeout: const Duration(seconds: 20),
        timeoutMessage: 'Le serveur n’a pas répondu à temps : la remise n’est PAS confirmée. Vérifiez l’état de la commande avant de remettre l’article.');
    if (!r.ok || !context.mounted) return;
    // un code erroné est compté et journalisé par le serveur (5 essais au plus), sans interrompre la transaction
    if (r.data == 'incorrect') {
      await gAlert(context, 'Remise refusée', 'Code de retrait incorrect. L’essai est journalisé ; après 5 essais, l’acheteur devra afficher un nouveau code.');
      return;
    }
    if (r.data != 'delivered') {
      await gAlert(context, 'Remise non confirmée', 'Réponse inattendue du serveur : la remise n’est pas confirmée. Vérifiez l’état de la commande avant de remettre l’article.');
      return;
    }
    gToast(context, 'Remise confirmée : la commande est livrée.');
  } finally {
    _pickupInFlight = false;
  }
}

/// 272 : double authentification par application (TOTP) — inscription du facteur puis vérification d'un code réel.
Future<void> twoFactorDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'activer la vérification en 2 étapes')) return;
  if (!context.mounted) return;
  final existing = (await Backend.totpFactors()).where((f) => f.status == FactorStatus.verified).toList();
  if (!context.mounted) return;
  String factorId;
  String intro;
  if (existing.isNotEmpty) {
    factorId = existing.first.id;
    intro = 'Saisissez le code à 6 chiffres affiché par votre application d’authentification.';
  } else {
    final e = await Backend.enrollTotp();
    if (!context.mounted) return;
    if (e.error != null) return gAlert(context, 'Activation impossible', e.error!);
    final t = e.enrolled!.totp!;
    factorId = e.enrolled!.id;
    final copied = await copyText(t.secret);
    if (!context.mounted) return;
    await gDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Scannez ce code', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 180, height: 180, child: SvgPicture.string(t.qrCode)),
          const SizedBox(height: 8),
          Text('Clé : ${t.secret}', style: _muted, textAlign: TextAlign.center),
          Text(copied ? '(copiée — à saisir dans l’application si le scan est impossible)' : '(à saisir dans l’application si le scan est impossible)', style: _muted, textAlign: TextAlign.center),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('J’ai ajouté le compte'))],
      ),
    );
    intro = 'Saisissez le premier code affiché par l’application pour activer la protection.';
  }
  if (!context.mounted) return;
  for (var essai = 0; essai < 3; essai++) {
    final f = await formDialog(context, 'Vérification en 2 étapes', [('Code à 6 chiffres', '')], intro: intro, submit: 'Vérifier');
    if (f == null || !context.mounted) return;
    final err = await Backend.verifyTotp(factorId, f.first.replaceAll(' ', ''));
    if (!context.mounted) return;
    if (err == null) return gToast(context, 'Vérification en 2 étapes active sur ce compte.');
    await gAlert(context, 'Vérification échouée', err);
    if (!context.mounted) return;
  }
}

/// 158 : comparaison des propositions réellement reçues sur vos besoins (montant, délai, message), de la moins chère à la plus chère.
Future<void> compareProposalsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'comparer les candidatures')) return;
  final me = Backend.currentUserId;
  if (!context.mounted) return;
  final missions = await _load(context, 'missions', 'id,title,number,client_id', order: 'updated_at');
  final ids = {for (final m in missions ?? const []) if (m['client_id'] == me) m['id']};
  final props = (await _load(context, 'mission_proposals', 'mission_id,amount,delay_days,message,status') ?? const []).where((p) => ids.contains(p['mission_id'])).toList()
    ..sort((a, b) => ((a['amount'] as num?) ?? 0).compareTo((b['amount'] as num?) ?? 0));
  if (!context.mounted) return;
  if (props.isEmpty) return gAlert(context, 'Comparer la sélection', 'Aucune proposition reçue sur vos besoins pour le moment.');
  final title = {for (final m in missions ?? const []) m['id']: m['title'] ?? m['number']};
  await _listDialog(context, 'Comparaison des propositions', props, (p) => '${_money(p['amount'])} · ${p['delay_days']} jours',
      sub: (p) => '${title[p['mission_id']]} · ${_status('${p['status']}')}${p['message'] == null ? '' : ' · ${p['message']}'}');
}
