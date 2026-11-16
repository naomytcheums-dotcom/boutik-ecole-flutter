import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart';
import '../i18n.dart' show Text;
import 'auth.dart' show requireLogin;
import 'backend.dart';
import 'lots.dart' show formDialog;

/// Écrans d'équipe de la vérification étudiante : pièces justificatives (administration, support, département dans son périmètre),
/// propositions d'établissements et de départements (administration, support), demandes de certification (administration, département
/// dans son périmètre), suppressions de compte échues et récupération 2FA (administration, support). Chaque décision passe par une fonction
/// serveur qui vérifie le rôle et le périmètre, motive les refus et notifie la personne concernée ; rien n'est simulé.

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, color: Color(0xFF111015));
const _muted = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Color(0xFF57545F));

typedef _Row = Map<String, dynamic>;
typedef _Action = (String, Future<bool> Function(_Row));

const docKindLabels = {
  'student_card': 'carte d’étudiant',
  'enrollment_certificate': 'certificat de scolarité',
  'diploma': 'diplôme',
  'certificate': 'certificat',
  'cv': 'CV',
  'other': 'autre document',
};

Future<bool> _ready(BuildContext context, WidgetRef ref, String need) async {
  if (!Backend.ready) {
    await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return false;
  }
  return requireLogin(context, ref, need);
}

Future<List<_Row>?> _load(BuildContext context, String fn, [Map<String, dynamic> params = const {}]) async {
  final r = await Backend.rpc(fn, params);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, 'Lecture impossible', r.error!);
    return null;
  }
  final d = r.data;
  return d is List ? [for (final x in d) Map<String, dynamic>.from(x as Map)] : const <_Row>[];
}

/// Appelle une fonction serveur ; en cas de refus, l'explique. Renvoie vrai si elle a réussi.
Future<bool> _call(BuildContext context, String fn, Map<String, dynamic> params, String title) async {
  final r = await Backend.rpc(fn, params);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, title, r.error!);
    return false;
  }
  return true;
}

/// Liste rechargée après chaque action (contrairement à une fenêtre figée) : une ligne traitée disparaît.
Future<void> _teamDialog(
  BuildContext context, {
  required String title,
  required Future<List<_Row>?> Function() load,
  required String Function(_Row) line,
  required String Function(_Row) sub,
  required List<_Action> Function(_Row) actions,
  String empty = 'Rien à traiter.',
  List<(String, Future<void> Function())> footer = const [],
}) async {
  var rows = await load();
  if (rows == null || !context.mounted) return;
  await gDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (rows!.isEmpty) Text(empty, style: _muted),
              for (final r in rows!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(line(r), style: _st.copyWith(fontWeight: FontWeight.w600)),
                    Text(sub(r), style: _muted),
                    Wrap(spacing: 8, children: [
                      for (final a in actions(r))
                        TextButton(
                          onPressed: () async {
                            if (!await a.$2(r)) return;
                            final fresh = await load();
                            if (fresh != null && ctx.mounted) setState(() => rows = fresh);
                          },
                          child: Text(a.$1),
                        ),
                    ]),
                  ]),
                ),
            ]),
          ),
        ),
        actions: [
          for (final f in footer)
            TextButton(
              onPressed: () async {
                await f.$2();
                final fresh = await load();
                if (fresh != null && ctx.mounted) setState(() => rows = fresh);
              },
              child: Text(f.$1),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    ),
  );
}

String _date(Object? v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ---------------------------------------------------------------- pièces justificatives (S1-24)

/// Pièces en attente (administration, support : toutes ; département : celles de ses étudiants) : ouverture par lien signé, validation, refus motivé.
Future<void> documentReviewDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'examiner les pièces justificatives') || !context.mounted) return;
  await _teamDialog(
    context,
    title: 'Pièces justificatives à examiner',
    load: () => _load(context, 'documents_to_review', {'p_status': 'pending'}),
    line: (d) => '${d['owner_name']} · ${docKindLabels[d['kind']] ?? d['kind']}',
    sub: (d) => [
      if ('${d['matricule']}'.isNotEmpty) 'matricule ${d['matricule']}',
      '${d['institution']}',
      '${d['department']}',
      '${d['name']}',
      _date(d['created_at']),
    ].where((x) => x.isNotEmpty).join(' · '),
    empty: 'Aucune pièce en attente dans votre périmètre.',
    actions: (d) => [
      ('Ouvrir', (x) async {
        final url = await Backend.signedFileUrl('profile-documents', '${x['path']}');
        if (!context.mounted) return false;
        if (url == null) {
          gToast(context, 'Document inaccessible pour le moment.');
        } else if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) && context.mounted) {
          gToast(context, 'Impossible d’ouvrir le document.');
        }
        return false;
      }),
      ('Valider', (x) async {
        final ok = await _call(context, 'document_decide', {'p_id': x['id'], 'p_status': 'verified', 'p_note': null}, 'Décision non enregistrée');
        if (ok && context.mounted) gToast(context, 'Pièce validée ; l’étudiant est notifié.');
        return ok;
      }),
      ('Refuser', (x) async {
        final v = await formDialog(context, 'Motif du refus', [('Motif (visible par l’étudiant)', '')], submit: 'Refuser la pièce');
        if (v == null || !context.mounted) return false;
        final ok = await _call(context, 'document_decide', {'p_id': x['id'], 'p_status': 'rejected', 'p_note': v.first}, 'Décision non enregistrée');
        if (ok && context.mounted) gToast(context, 'Pièce refusée ; l’étudiant est notifié avec le motif.');
        return ok;
      }),
    ],
  );
}

// ---------------------------------------------------------------- établissements et départements proposés (S1-19)

Future<void> referenceReviewDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'relire les propositions') || !context.mounted) return;
  await _teamDialog(
    context,
    title: 'Établissements et départements proposés',
    load: () => _load(context, 'references_to_review'),
    line: (r) => '${r['kind'] == 'department' ? 'Département' : 'Établissement'} : ${r['name']}',
    sub: (r) => [
      if ('${r['parent']}'.isNotEmpty) '${r['parent']}',
      if ('${r['city']}'.isNotEmpty) '${r['city']}',
      'proposé par ${r['proposed_by']}',
      _date(r['created_at']),
    ].join(' · '),
    empty: 'Aucune proposition à relire.',
    actions: (r) => [
      for (final (label, approve) in const [('Publier', true), ('Refuser', false)])
        (label, (x) async {
          final ok = await _call(context, 'reference_review', {'p_kind': x['kind'], 'p_id': x['id'], 'p_approve': approve}, 'Décision non enregistrée');
          if (ok && context.mounted) gToast(context, approve ? 'Publié ; le proposant est notifié.' : 'Refusé ; le proposant est notifié.');
          return ok;
        }),
    ],
  );
}

// ---------------------------------------------------------------- certification (S1-84)

/// Demandes de badge (administration : toutes ; département : celles de son périmètre). Le serveur vérifie le périmètre à chaque décision.
Future<void> certificationQueueDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'traiter les demandes de certification') || !context.mounted) return;
  const labels = {'pending': 'Demande reçue', 'review': 'En examen', 'approved': 'Certifié'};
  await _teamDialog(
    context,
    title: 'Demandes de certification',
    load: () => _load(context, 'certification_queue'),
    line: (p) => '${p['name']}',
    sub: (p) {
      final docs = [
        for (final d in (p['documents'] as List? ?? const [])) '${docKindLabels[(d as Map)['kind']] ?? d['kind']} (${const {'verified': 'vérifiée', 'rejected': 'refusée'}[d['status']] ?? 'en attente'})',
      ];
      final motive = '${p['motive'] ?? ''}';
      return [
        [p['department'], p['institution'], labels[p['certification']]].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '),
        if (motive.isNotEmpty) '« $motive »',
        if ('${p['links'] ?? ''}'.isNotEmpty) '${p['links']}',
        'justificatifs : ${docs.isEmpty ? 'aucun' : docs.join(', ')}',
      ].join('\n');
    },
    empty: 'Aucune demande dans votre périmètre.',
    actions: (p) => [
      for (final (label, status) in switch (p['certification']) {
        'pending' => const [('Examiner', 'review'), ('Valider', 'approved'), ('Refuser', 'rejected')],
        'review' => const [('Valider', 'approved'), ('Refuser', 'rejected')],
        _ => const [('Retirer le badge', 'revoked')],
      })
        (label, (x) async {
          String? note;
          if (status == 'rejected' || status == 'revoked') {
            final v = await formDialog(context, status == 'rejected' ? 'Motif du refus' : 'Motif du retrait', [('Motif (visible par la personne)', '')], submit: 'Confirmer');
            if (v == null || !context.mounted) return false;
            note = v.first;
          }
          final ok = await _call(context, 'decide_certification', {'p_user': x['id'], 'p_status': status, 'p_note': note}, 'Décision non enregistrée');
          if (ok && context.mounted) gToast(context, 'Décision enregistrée ; la personne est notifiée.');
          return ok;
        }),
    ],
  );
}

// ---------------------------------------------------------------- suppressions de compte (S1-55)

/// Demandes de suppression en attente. Après 30 jours et sans commande en cours, l'administrateur exécute l'anonymisation
/// (les commandes, paiements et écritures comptables sont conservés).
Future<void> accountDeletionsDialog(BuildContext context, WidgetRef ref, {required bool canExecute}) async {
  if (!await _ready(context, ref, 'traiter les suppressions de compte') || !context.mounted) return;
  await _teamDialog(
    context,
    title: 'Suppressions de compte',
    load: () => _load(context, 'account_deletions_pending'),
    line: (d) => '${d['name']} · ${d['role']}',
    sub: (d) {
      final open = (d['open_orders'] as num?)?.toInt() ?? 0;
      return [
        'demandée le ${_date(d['requested_at'])}',
        d['due'] == true ? 'échue' : 'exécutable à partir du ${_date(d['scheduled_for'])}',
        if (open > 0) '$open commande(s) en cours : suppression bloquée',
      ].join(' · ');
    },
    empty: 'Aucune demande de suppression en attente.',
    actions: (_) => const [],
    footer: [
      if (canExecute)
        ('Exécuter les suppressions échues', () async {
          final r = await Backend.rpc('admin_process_account_deletions', const {});
          if (!context.mounted) return;
          if (r.error != null) {
            await gAlert(context, 'Exécution impossible', r.error!);
            return;
          }
          final m = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
          final blocked = (m['blocked'] as List?)?.length ?? 0;
          gToast(context, '${m['processed'] ?? 0} compte(s) anonymisé(s)${blocked > 0 ? ' · $blocked en attente (commandes en cours)' : ''}');
        }),
    ],
  );
}

// ---------------------------------------------------------------- récupération 2FA (S1-51)

/// Procédure d'équipe : l'identité de la personne est vérifiée hors de l'application (voir docs/transformation/PROCEDURE_2FA_SECOURS.md),
/// puis la double authentification du compte est retirée ; la décision est journalisée et la personne notifiée.
Future<void> mfaResetDialog(BuildContext context, WidgetRef ref) async {
  if (!await _ready(context, ref, 'réinitialiser une double authentification') || !context.mounted) return;
  final v = await formDialog(
    context,
    'Réinitialiser la double authentification',
    [('E-mail du compte', ''), ('Comment l’identité a été vérifiée', '')],
    submit: 'Réinitialiser',
    intro: 'À utiliser seulement quand la personne a perdu son téléphone ET ses codes de secours, après avoir vérifié son identité (pièce d’identité, appel vidéo…). L’action est journalisée.',
  );
  if (v == null || !context.mounted) return;
  if (await _call(context, 'admin_mfa_reset_by_email', {'p_email': v[0], 'p_note': v[1]}, 'Réinitialisation impossible') && context.mounted) {
    gToast(context, 'Double authentification retirée ; la personne est notifiée.');
  }
}
