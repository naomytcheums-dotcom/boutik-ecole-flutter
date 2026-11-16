import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FactorStatus;

import '../gen.dart';
import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'docs_prestataire.dart' show downloadMissionInvoice;
import 'l10_voeux.dart' show openWish, openWishEditor;
import 'lot20.dart' show kioskLiveStatus, kioskStatus;
import 'missions.dart' show missionProvider;
import 'project_pages.dart' show projectProgress;
import 'profile_links.dart' show profileLinkError, savedProfileLinksProvider;
import 'seller.dart';
import 'share.dart';
import 'store.dart' show ordersProvider, viewedOrderProvider;
import 'verification_equipe.dart' show certificationQueueDialog;

/// Lots « missions, vœux, campagnes, certificats, bornes, projets » (migration 20261031a).
/// Chaque action lit les champs réellement saisis, appelle une fonction serveur qui vérifie le rôle, l'état et les données,
/// puis affiche le résultat du serveur. Rien n'est simulé : sans serveur, l'action l'explique.

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: Color(0xFF111015));
const _muted = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF57545F));

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
Future<List<String>?> formDialog(BuildContext context, String title, List<(String label, String initial)> fields, {String submit = 'Enregistrer', String? intro, bool numeric = false}) {
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
              child: TextField(controller: ctrls[i], keyboardType: numeric ? TextInputType.number : null, decoration: InputDecoration(labelText: fields[i].$1, border: const OutlineInputBorder(), isDense: true), style: _st),
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

/// Lecture par fonction serveur (réservée à l'auteur ou au département) : la table n'est pas lue en direct.
Future<List<Map<String, dynamic>>?> _loadRpc(BuildContext context, String fn) async {
  final r = await Backend.rpc(fn, const {});
  if (r.error != null) {
    if (context.mounted) await gAlert(context, 'Lecture impossible', r.error!);
    return null;
  }
  return [for (final x in (r.data is List ? r.data as List : const [])) if (x is Map) Map<String, dynamic>.from(x)];
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

/// Écran 191 (mission sur mesure) : le besoin décrit est publié côté serveur ; le département est prévenu et qualifie les équipes.
/// Retourne vrai uniquement si le serveur a enregistré la demande.
Future<bool> publishMissionBrief(BuildContext context, WidgetRef ref, String kind, String desc, {int? budgetMin, int? budgetMax, String deadline = ''}) async {
  if (!await _ready(context, ref, 'envoyer votre besoin')) return false;
  if (!context.mounted) return false;
  final r = await _run(context, 'save_mission', {
    'p_id': null, 'p_title': 'Mission sur mesure · $kind', 'p_description': desc,
    'p_budget_min': budgetMin, 'p_budget_max': budgetMax, 'p_deadline': deadline, 'p_publish': true, 'p_kind': 'mission',
  }, title: 'Besoin non envoyé');
  return r.ok;
}

Future<bool> _confirm(BuildContext context, String title, String text, String yes) async {
  final v = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text(text, style: _muted),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes))],
    ),
  );
  return v == true;
}

/// Écran 202 : « Commander le pack » crée une demande de mission sur mesure, après confirmation et une seule fois tant qu'elle est ouverte.
Future<void> orderPack(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'commander le pack')) return;
  if (!context.mounted) return;
  const title = 'Pack Lancement de marque';
  final mine = await Backend.rows('missions', 'id,title,status', eq: {'client_id': Backend.currentUserId ?? ''}, order: 'updated_at', limit: 100);
  if (!context.mounted) return;
  if (mine.error == null && mine.rows.any((m) => m['title'] == title && const {'published', 'assigned', 'in_progress'}.contains(m['status']))) {
    return gAlert(context, 'Demande déjà envoyée', 'Votre demande de pack est déjà ouverte : retrouvez-la, avec les propositions reçues, dans « Mes besoins ».');
  }
  if (!await _confirm(context, 'Commander le pack ?', 'Une demande « Pack Lancement de marque » est envoyée au département, qui qualifie les équipes. Le prix n’est pas fixé d’avance : il découle des propositions que vous recevrez, et vous choisissez ou refusez.', 'Envoyer la demande') || !context.mounted) return;
  final r = await _run(context, 'save_mission', {
    'p_id': null, 'p_title': title,
    'p_description': 'Identité visuelle (MMI), fabrication du produit (BTA), photo et vidéo (TCO), emballage (GMP) : un seul interlocuteur.',
    'p_budget_min': null, 'p_budget_max': null, 'p_deadline': '', 'p_publish': true, 'p_kind': 'mission',
  }, title: 'Demande non envoyée');
  if (r.ok && context.mounted) {
    ref.read(missionProvider.notifier).refresh();
    gToast(context, 'Demande envoyée : le département est prévenu et qualifie les équipes.');
  }
}

/// Mes besoins : propositions reçues (auteur, accepter, refuser), jalons livrés (valider, demander une correction) et retrait d'un besoin non attribué.
Future<void> myNeedsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter vos besoins')) return;
  if (!context.mounted) return;
  final res = await Backend.rpc('my_needs', const {});
  if (res.error != null) {
    if (context.mounted) await gAlert(context, 'Lecture impossible', res.error!);
    return;
  }
  final mine = [for (final x in (res.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)].where((m) => m['status'] != 'cancelled').toList();
  if (!context.mounted) return;
  if (mine.isEmpty) return gAlert(context, 'Mes besoins', 'Vous n’avez encore publié aucun besoin.');
  final rows = <Map<String, dynamic>>[];
  for (final m in mine) {
    rows.add({...m, '_t': 'n'});
    for (final p in (m['proposals'] as List? ?? const [])) {
      rows.add({...Map<String, dynamic>.from(p as Map), '_t': 'p', 'mission_id': m['id'], '_m': m});
    }
    for (final j in (m['milestones'] as List? ?? const [])) {
      rows.add({...Map<String, dynamic>.from(j as Map), '_t': 'j', 'mission_id': m['id'], '_m': m});
    }
  }
  await _listDialog(
    context,
    'Mes besoins',
    rows,
    (r) => switch (r['_t']) {
      'n' => '${r['title']}',
      'p' => 'Proposition de ${r['author_name']} · ${_money(r['amount'])} en ${r['delay_days']} j',
      _ => 'Jalon ${r['position']} · ${r['title']} (${_money(r['amount'])})',
    },
    sub: (r) => switch (r['_t']) {
      'n' => [_status('${r['status']}'), if (r['budget_max'] != null) 'budget ${_money(r['budget_min'])} – ${_money(r['budget_max'])}', if ('${r['deadline'] ?? ''}'.isNotEmpty) 'pour le ${r['deadline']}'].join(' · '),
      'j' => [
          '${(r['_m'] as Map)['title']} · ${_status('${r['status']}')}',
          if ('${r['proof_note'] ?? ''}'.isNotEmpty) 'Preuve : ${r['proof_note']}',
          if ((r['proof_files'] as List? ?? const []).isNotEmpty) '${(r['proof_files'] as List).length} pièce(s) jointe(s)',
          if (r['status'] == 'validated') payStatusLabel('${r['pay_status']}', '${r['pay_method'] ?? ''}'),
        ].join('\n'),
      _ => '${(r['_m'] as Map)['title']} · ${_status('${r['status']}')}${'${r['message'] ?? ''}'.isEmpty || r['_t'] != 'p' ? '' : ' · ${r['message']}'}',
    },
    actions: (r) => switch (r['_t']) {
      'n' => [
          if (r['status'] == 'published' || r['status'] == 'draft') ('Annuler ce besoin', (x) => _cancelNeed(context, ref, x)),
          if (r['status'] == 'delivered') ('Clôturer la mission', (x) => _closeMission(context, ref, x)),
          if (const {'assigned', 'in_progress', 'delivered', 'closed'}.contains(r['status'])) ('Facture de mission', (x) async {
            await downloadMissionInvoice(context, ref, '${x['id']}');
            return false;
          }),
        ],
      'p' => [
          ('Voir le profil', (x) async {
            GoRouter.of(context).push('/etudiant/${x['author_id']}');
            return true;
          }),
          ('Poser une question', (x) => _askAuthor(context, x)),
          if (r['status'] == 'submitted') ('Accepter', (x) => _decideProposal(context, ref, x, true)),
          if (r['status'] == 'submitted') ('Refuser', (x) => _decideProposal(context, ref, x, false)),
        ],
      _ => [
          for (final f in (r['proof_files'] as List? ?? const []))
            ('Voir ${(f as Map)['name']}', (x) async {
              final u = await Backend.projectFileUrl('${f['path']}');
              if (u != null && context.mounted) await openUrl(context, u);
              return false;
            }),
          if (r['status'] == 'submitted') ('Valider', (x) => _decideMilestone(context, x, true)),
          if (r['status'] == 'submitted') ('Demander une correction', (x) => _decideMilestone(context, x, false)),
          if (r['status'] == 'validated' && r['pay_status'] != 'confirmed') ('Déclarer le paiement', (x) => _declarePayment(context, x)),
        ],
    },
  );
}

/// Libellé du règlement d'un jalon validé entre le client et le prestataire (aucun séquestre).
String payStatusLabel(String payStatus, String method) => switch (payStatus) {
      'confirmed' => 'Réglé : réception confirmée par le prestataire${method.isEmpty ? '' : ' ($method)'}',
      'declared' => 'Paiement déclaré${method.isEmpty ? '' : ' ($method)'} : en attente de confirmation du prestataire',
      _ => 'À régler directement avec le prestataire',
    };

Future<bool> _declarePayment(BuildContext context, Map<String, dynamic> j) async {
  final v = await formDialog(context, 'Déclarer le paiement', [('Moyen utilisé (Orange Money, MTN MoMo, espèces…)', ''), ('Référence de la transaction (facultatif)', '')],
      intro: 'Boutik-École ne reçoit ni ne bloque cet argent : vous réglez le prestataire directement. Cette déclaration est tracée et le prestataire doit confirmer la réception.', submit: 'Déclarer');
  if (v == null || !context.mounted) return false;
  final r = await _run(context, 'milestone_pay_declare', {'p_mission': j['mission_id'], 'p_position': j['position'], 'p_method': v[0], 'p_reference': v[1]});
  if (r.ok && context.mounted) gToast(context, 'Paiement déclaré : le prestataire est prévenu et doit confirmer.');
  return r.ok;
}

Future<bool> _closeMission(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
  if (!await _confirm(context, 'Clôturer la mission ?', 'Tous les jalons sont validés. Le prestataire est prévenu.', 'Clôturer') || !context.mounted) return false;
  final r = await _run(context, 'mission_close', {'p_mission': m['id']});
  if (r.ok && context.mounted) {
    ref.read(missionProvider.notifier).refresh();
    gToast(context, 'Mission clôturée.');
  }
  return r.ok;
}

/// Question à l'auteur d'une proposition, avant de l'accepter : message direct (la réponse arrive dans la messagerie).
Future<bool> _askAuthor(BuildContext context, Map<String, dynamic> p) async {
  final v = await formDialog(context, 'Question à ${p['author_name']}', [('Votre question', '')], submit: 'Envoyer');
  if (v == null || v.first.isEmpty || !context.mounted) return false;
  final r = await Backend.startDirectConversation('${p['author_id']}', 'À propos de ma proposition de mission :\n\n${v.first}');
  if (!context.mounted) return false;
  if (r.error != null) {
    await gAlert(context, 'Message non envoyé', r.error!);
    return false;
  }
  gToast(context, 'Question envoyée : la réponse arrive dans vos messages.');
  return false;
}

Future<bool> _cancelNeed(BuildContext context, WidgetRef ref, Map<String, dynamic> m) async {
  if (!await _confirm(context, 'Annuler ce besoin ?', 'Il n’est plus visible des talents et les propositions en attente sont déclinées : leurs auteurs sont prévenus.', 'Annuler le besoin') || !context.mounted) return false;
  final r = await _run(context, 'mission_cancel', {'p_id': m['id']});
  if (r.ok && context.mounted) {
    ref.read(missionProvider.notifier).refresh();
    gToast(context, 'Besoin annulé.');
  }
  return r.ok;
}

Future<bool> _decideProposal(BuildContext context, WidgetRef ref, Map<String, dynamic> p, bool accept) async {
  final r = await _run(context, 'decide_proposal', {'p_id': p['id'], 'p_accept': accept});
  if (r.ok && context.mounted) {
    ref.read(missionProvider.notifier).refresh();
    gToast(context, accept ? 'Proposition acceptée : la mission est attribuée.' : 'Proposition refusée.');
  }
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
    gToast(context, validate ? 'Jalon validé : la livraison est acceptée. Le paiement se règle directement avec le prestataire.' : 'Correction demandée au prestataire.');
  }
  return r.ok;
}

/// Talents : besoins publiés (description complète, budget, échéance), avec proposition d'un montant et d'un délai.
Future<void> openNeedsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'répondre à un besoin')) return;
  if (!context.mounted) return;
  final open = await _loadRpc(context, 'open_needs');
  if (open == null || !context.mounted) return;
  if (open.isEmpty) return gAlert(context, 'Besoins à pourvoir', 'Aucun besoin publié pour le moment.');
  await _listDialog(
    context,
    'Besoins à pourvoir',
    open,
    (m) => '${m['title'] ?? m['number']}',
    sub: (m) => [
      if ('${m['description'] ?? ''}'.isNotEmpty) '${m['description']}',
      [
        if (m['budget_max'] != null) 'Budget ${_money(m['budget_min'])} – ${_money(m['budget_max'])}',
        if ('${m['deadline'] ?? ''}'.isNotEmpty) 'avant le ${m['deadline']}',
        '${m['proposals'] ?? 0} proposition(s) reçue(s)',
        if (m['my_status'] != null) 'ma proposition : ${_status('${m['my_status']}')}',
      ].join(' · '),
    ].join('\n'),
    actions: (m) => [
      if (m['my_status'] != 'submitted' && m['my_status'] != 'accepted')
        ('Proposer', (x) async {
          final ok = await _confirm(context, 'Avant de proposer', 'Boutik-École ne bloque ni ne verse l’argent d’une mission : le paiement de chaque jalon se règle directement avec le client. L’application trace la livraison, la validation et le règlement déclaré de chaque jalon (facture de mission). Continuer ?', 'Continuer');
          if (!ok || !context.mounted) return false;
          final v = await formDialog(context, 'Ma proposition', [('Montant (FCFA)', ''), ('Délai (jours)', ''), ('Message', '')], submit: 'Envoyer');
          if (v == null || !context.mounted) return false;
          final r = await _run(context, 'propose_on_mission', {'p_mission': x['id'], 'p_amount': firstInt(v[0]), 'p_delay_days': firstInt(v[1]), 'p_message': v[2]});
          if (r.ok && context.mounted) gToast(context, 'Proposition envoyée. Suivez-la dans « Mes missions et jalons ».');
          return r.ok;
        }),
    ],
  );
}

/// Talents : « Mes missions et jalons » = écran 201 (missions retenues, livraisons avec preuve, règlements, propositions envoyées).
Future<void> myMissionsDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'suivre vos missions')) return;
  if (!context.mounted) return;
  gOpen(context, '201');
}

/// Écran 199 (département) : choisit un besoin publié puis la proposition à retenir ; le talent retenu et le client sont prévenus.
Future<void> assignNeedDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'attribuer un besoin')) return;
  if (!context.mounted) return;
  final rows = await _load(context, 'missions', 'id,number,title,status', eq: {'status': 'published'});
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Attribuer', 'Aucun besoin publié en attente d’attribution.');
  await _listDialog(context, 'Attribuer un besoin', rows, (m) => '${m['title'] ?? m['number']}', sub: (m) => '${m['number']}', actions: (m) => [
        ('Voir les propositions', (x) async {
          final props = await Backend.rpc('staff_mission_proposals', {'p_mission': x['id']});
          if (!context.mounted) return false;
          if (props.error != null) {
            await gAlert(context, 'Lecture impossible', props.error!);
            return false;
          }
          final list = [for (final p in (props.data as List? ?? const [])) Map<String, dynamic>.from(p as Map)].where((p) => p['status'] == 'submitted').toList();
          if (list.isEmpty) {
            await gAlert(context, 'Aucune proposition', 'Ce besoin n’a pas de proposition en attente : un talent doit d’abord proposer.');
            return false;
          }
          await _listDialog(context, 'Propositions', list, (p) => '${p['author']} · ${_money(p['amount'])} en ${p['delay_days']} j', sub: (p) => '${p['department'] ?? ''}', actions: (p) => [
                ('Attribuer', (y) async {
                  final r = await _run(context, 'assign_mission', {'p_mission': x['id'], 'p_proposal': y['id']});
                  if (r.ok && context.mounted) gToast(context, 'Besoin attribué à ${y['author']}.');
                  return r.ok;
                }),
              ]);
          return false;
        }),
      ]);
}

// ---------------------------------------------------------------- vœux (218, validation par le département)
// saveWish (publication et brouillon) : voir l10_voeux.dart.

/// Mes vœux : état de validation, modification d'un brouillon ou d'un vœu refusé, suppression.
Future<void> myWishesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'consulter vos vœux')) return;
  if (!context.mounted) return;
  final rows = await _loadRpc(context, 'my_wishes');
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Mes vœux', 'Vous n’avez encore proposé aucun vœu.');
  await _listDialog(context, 'Mes vœux', rows, (w) => '${w['title']}', sub: (w) => '${_status('${w['status']}')}${w['review_note'] == null ? '' : ' · ${w['review_note']}'}', actions: (w) => [
        if (w['status'] == 'draft' || w['status'] == 'rejected')
          ('Modifier', (x) async {
            openWishEditor(context, '${x['id']}');
            return true;
          }),
        if (w['status'] == 'submitted')
          ('Retirer la demande', (x) async {
            final r = await _run(context, 'withdraw_wish', {'p_id': x['id']});
            if (r.ok && context.mounted) gToast(context, 'Demande retirée : le vœu est redevenu un brouillon.');
            return r.ok;
          }),
        if (w['status'] == 'approved' || w['status'] == 'scheduled')
          ('Voir la fiche', (x) async {
            openWish(context, '${x['id']}');
            return true;
          }),
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
  final rows = await _loadRpc(context, 'wishes_to_review');
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Vœux à valider', 'Aucun vœu en attente.');
  Future<bool> decide(Map<String, dynamic> w, String d) async {
    var note = '', when = '';
    if (d != 'approved') {
      final v = await formDialog(context, d == 'rejected' ? 'Motif du refus' : 'Planifier la mise en ligne', [(d == 'rejected' ? 'Motif' : 'Date de mise en ligne (AAAA-MM-JJ HH:MM)', '')], submit: 'Confirmer');
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
    _reviewQueue(context, ref, 'projects', 'id,title,summary,department,status,kind,details,media', 'review_project', 'Projets à examiner', (p) => '${p['title']}', _projectBrief);

/// Département : jalons de campagne déclarés atteints par le porteur, à valider sur preuve (affichés « atteints » au public seulement après validation).
Future<void> reviewMilestonesDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'valider les jalons de campagne')) return;
  if (!context.mounted) return;
  final rows = await _loadRpc(context, 'campaign_milestones_to_review');
  if (rows == null || !context.mounted) return;
  if (rows.isEmpty) return gAlert(context, 'Jalons à valider', 'Aucun jalon en attente.');
  Future<bool> decide(Map<String, dynamic> m, bool approve) async {
    var note = '';
    if (!approve) {
      final v = await formDialog(context, 'Motif du refus', [('Motif', '')], submit: 'Confirmer');
      if (v == null) return false;
      note = v.first;
    }
    if (!context.mounted) return false;
    final r = await _run(context, 'campaign_milestone_review', {'p_id': m['id'], 'p_approve': approve, 'p_note': note});
    if (r.ok && context.mounted) gToast(context, 'Décision enregistrée ; le porteur est notifié.');
    return r.ok;
  }

  await _listDialog(context, 'Jalons à valider', rows, (m) => '${m['campaign']} · ${m['title']}',
      sub: (m) => 'Par ${m['owner']} · preuve : ${m['proof']}${'${m['proof_url'] ?? ''}'.isEmpty ? '' : ' (${m['proof_url']})'}',
      actions: (m) => [('Valider', (x) => decide(x, true)), ('Refuser', (x) => decide(x, false))]);
}

/// Fiche de décision d'un projet soumis : tout ce que le relecteur doit lire avant de valider ou refuser (les contacts n'y figurent pas).
String _projectBrief(Map<String, dynamic> p) {
  final d = p['details'] is Map ? Map<String, dynamic>.from(p['details'] as Map) : <String, dynamic>{};
  String g(String k) => '${d[k] ?? ''}'.trim();
  final team = [for (final m in (d['team'] as List? ?? const [])) if (m is Map && '${m['name']}'.trim().isNotEmpty) '${m['name']}${'${m['role'] ?? ''}'.isEmpty ? '' : ' (${m['role']})'}'];
  final links = [
    for (final (label, key) in const [('Prototype', 'prototype_url'), ('Démonstration', 'demo_url'), ('Documentation', 'doc_url'), ('Vidéo', 'video_url')])
      if (g(key).isNotEmpty) '$label : ${g(key)}',
  ];
  final medias = p['media'] is List ? (p['media'] as List).length : 0;
  return [
    [if ('${p['kind']}' == 'innovation') 'Innovation' else 'Projet', if ('${p['department'] ?? ''}'.isNotEmpty) '${p['department']}'].join(' · '),
    if ('${p['summary'] ?? ''}'.trim().isNotEmpty) '${p['summary']}'.trim(),
    if (g('problem').isNotEmpty) 'Problème : ${g('problem')}',
    if (g('solution').isNotEmpty) 'Solution : ${g('solution')}',
    if (projectProgress[g('progress')] != null) 'Avancement : ${projectProgress[g('progress')]}',
    if (team.isNotEmpty) 'Équipe : ${team.join(', ')}',
    ...links,
    if (medias > 0) '$medias visuel${medias > 1 ? 's' : ''} joint${medias > 1 ? 's' : ''}',
  ].join('\n');
}

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
      if (note.length < 5) {
        if (context.mounted) await gAlert(context, 'Motif obligatoire', 'Expliquez le refus en 5 caractères minimum : le porteur le lira.');
        return false;
      }
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

/// 224 « Programmer un live » : voir saveLive dans l10_ateliers.dart (create_live avec une vraie date).

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
  final url = v[1].trim(), label = v[0].trim();
  final err = profileLinkError(label, url);
  if (err != null) return gAlert(context, 'Lien invalide', err);
  ref.read(pendingLinksProvider.notifier).add(label.isEmpty ? 'Lien' : label, url);
  gToast(context, 'Lien ajouté : pensez à enregistrer.');
}

/// Enregistre les liens ajoutés EN PLUS de ceux du profil : la fonction serveur remplace toute la liste, les liens déjà enregistrés sont donc relus d'abord.
Future<void> saveProfileLinks(BuildContext context, WidgetRef ref) async {
  final links = ref.read(pendingLinksProvider);
  if (links.isEmpty) return gAlert(context, 'Aucun lien', 'Ajoutez d’abord un lien avec « Ajouter un autre lien ».');
  if (!await _ready(context, ref, 'enregistrer vos liens')) return;
  if (!context.mounted) return;
  final uid = Backend.userId;
  final current = uid == null ? null : await Backend.rows('profiles', 'links', eq: {'id': uid}, limit: 1);
  if (!context.mounted) return;
  if (current == null || current.error != null) return gAlert(context, 'Liens non enregistrés', 'Vos liens actuels n’ont pas pu être lus : rien n’a été modifié pour ne pas les écraser. Réessayez.');
  final saved = current.rows.isEmpty ? const [] : (current.rows.first['links'] as List? ?? const []);
  final merged = <Map<String, String>>[];
  for (final l in [...saved, ...links]) {
    if (l is! Map) continue;
    final url = '${l['url'] ?? ''}';
    if (url.isEmpty || merged.any((m) => m['url'] == url)) continue;
    merged.add({'label': '${l['label'] ?? ''}', 'url': url});
  }
  if (merged.length > 12) return gAlert(context, 'Trop de liens', 'Un profil peut afficher 12 liens au maximum (${saved.length} déjà enregistrés).');
  final r = await _run(context, 'save_profile_links', {'p_links': merged});
  if (r.ok && context.mounted) {
    ref.read(pendingLinksProvider.notifier).clear();
    ref.invalidate(savedProfileLinksProvider);
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

/// Révocation d'un certificat (département, administration) : code et motif obligatoires, vérifiés par le serveur (revoke_certificate).
Future<void> revokeCertificateDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'révoquer un certificat')) return;
  if (!context.mounted) return;
  final v = await formDialog(context, 'Révoquer un certificat', [('Code du certificat', ''), ('Motif (5 caractères minimum)', '')],
      submit: 'Révoquer', intro: 'La révocation est définitive : la vérification publique indiquera que le certificat n’est plus valide, avec le motif.');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'revoke_certificate', {'p_code': v[0], 'p_reason': v[1]}, title: 'Certificat non révoqué');
  if (r.ok && context.mounted) gToast(context, 'Certificat révoqué : la vérification publique le signale désormais.');
}

/// Demandes de badge « certifié » : file lue sur le serveur dans le périmètre du responsable (administration : toutes ; département : les siennes),
/// voir certificationQueueDialog (verification_equipe.dart) ; les décisions passent par decide_certification.
Future<void> certificationRequestsDialog(BuildContext context, WidgetRef ref) => certificationQueueDialog(context, ref);

/// Vérification publique d'un certificat par son code (aucune donnée personnelle au-delà du certificat).
Future<void> verifyCertificateDialog(BuildContext context, WidgetRef ref, {String code = ''}) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La vérification nécessite la connexion au serveur.');
  final v = await formDialog(context, 'Vérifier un certificat', [('Code du certificat', code)], submit: 'Vérifier');
  if (v == null || !context.mounted) return;
  final r = await _run(context, 'verify_certificate', {'p_code': v.first}, title: 'Vérification impossible');
  if (!r.ok || !context.mounted) return;
  final d = Map<String, dynamic>.from((r.data as Map?) ?? const {});
  if (d['introuvable'] == true) return gAlert(context, 'Certificat introuvable', 'Aucun certificat ne porte le code ${d['code']}.');
  if (d['limite'] == true) return gAlert(context, 'Trop de tentatives', 'Trop de codes inconnus ont été essayés. Réessayez dans quelques minutes.');
  final fp = '${d['empreinte'] ?? ''}';
  await gAlert(
      context,
      d['valide'] == true ? 'Certificat authentique' : 'Certificat révoqué',
      '${d['code']}\n${d['objet']}\nTitulaire : ${d['titulaire']}${d['departement'] == null ? '' : ' · ${d['departement']}'}\nDélivré le ${d['delivre_le']}'
          '${d['valide'] == true ? '' : '\nMotif : ${d['motif_revocation']}'}${fp.isEmpty ? '' : '\nEmpreinte : ${fp.length > 16 ? '${fp.substring(0, 16)}…' : fp}'}');
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

/// Écran 206 : état réel des bornes (statut et dernière mise à jour lus sur le serveur).
Future<void> kioskNetworkCheck(BuildContext context) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Sans connexion au serveur, l’état de la borne est inconnu : seul le catalogue de démonstration est affiché.');
  final r = await Backend.rows('kiosks', 'id,name,location,status,updated_at,last_seen_at', order: 'id', ascending: true);
  if (!context.mounted) return;
  if (r.error != null && !r.error!.contains('pas encore activée')) return gAlert(context, 'État de la borne inconnu', 'Le serveur ne répond pas. Réessayez dans un instant.');
  if (r.rows.isEmpty) return gAlert(context, 'Aucune borne enregistrée', 'Aucune borne n’est enregistrée sur le serveur pour le moment.');
  await gAlert(context, 'État des bornes', [for (final k in r.rows) '${k['name']} (${k['location']}) : ${kioskStatus(kioskLiveStatus(k))} · ${k['last_seen_at'] == null ? 'aucun signal reçu' : 'dernier signal ${_dateTime(k['last_seen_at'])}'}'].join('\n'));
}

String _dateTime(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? 'inconnue' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
  // La médiathèque est réservée au département et à l'administration : le refus est annoncé avant tout dépôt.
  if (scope == 'media' && !const {'dept', 'admin'}.contains(roleKey(ref.read(authProvider).current))) {
    if (context.mounted) await gAlert(context, 'Fichier refusé', 'Médiathèque réservée au département.');
    return null;
  }
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

Future<Map<String, dynamic>?> _pickMission(BuildContext context, [String preferId = '']) async {
  final rows = await _load(context, 'missions', 'id,number,title,status,client_id', order: 'updated_at');
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
    await gAlert(context, 'Aucun dossier', 'Le dossier s’ouvre lorsqu’une proposition est acceptée. Avant cela, posez vos questions aux auteurs des propositions depuis « Mes besoins ».');
    return null;
  }
  if (mine.length == 1) return mine.first;
  // La mission affichée par les écrans de suivi (192 à 197) est celle dont le dossier s'ouvre.
  for (final m in mine) {
    if (preferId.isNotEmpty && '${m['id']}' == preferId) return m;
  }
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
  final m = await _pickMission(context, ref.read(missionProvider).uuid);
  if (m == null || !context.mounted) return;
  final msgs = await _load(context, 'mission_messages', 'body,sender_id,created_at', eq: {'mission_id': m['id']}, order: 'created_at') ?? const [];
  final files = await _load(context, 'files', 'name,path,created_at', eq: {'ref': m['id']}) ?? const [];
  if (!context.mounted) return;
  final me = Backend.currentUserId;
  var other = 'Le client';
  if (m['client_id'] == me) {
    final needs = await Backend.rpc('my_needs', const {});
    for (final n in (needs.data as List? ?? const [])) {
      if ((n as Map)['id'] != m['id']) continue;
      for (final p in (n['proposals'] as List? ?? const [])) {
        if ((p as Map)['status'] == 'accepted') other = '${p['author_name']}';
      }
    }
  }
  if (!context.mounted) return;
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
                child: Text('${x['sender_id'] == me ? 'Moi' : other} · ${x['body']}', style: _st),
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
  final m = await _pickMission(context, ref.read(missionProvider).uuid);
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
  await gAlert(context, 'Code de retrait', '${c.substring(0, 3)} ${c.substring(3)}\n\nCommande $orderNumber — à présenter au kiosque, ou au vendeur lors d’une remise en main propre : un code saisi par le vendeur prouve la remise. Ne le donnez qu’à la personne qui vous remet l’article, et seulement quand vous l’avez en main.');
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
