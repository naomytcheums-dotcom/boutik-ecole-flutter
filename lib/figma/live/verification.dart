import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'profile_data.dart';

/// Compléter le profil (18b) et vérification étudiant (18c) : sélection dans les référentiels, matricule saisi par la
/// personne, pièces justificatives envoyées dans le compartiment privé. Hors connexion au serveur, la maquette reste une démonstration.

const _grey = Color(0xFF57545F);
const levels = ['Licence 1', 'Licence 2', 'Licence 3', 'Master 1', 'Master 2', 'Doctorat', 'BTS', 'DUT', 'Cycle ingénieur', 'Autre'];

Future<void> chooseInstitution(BuildContext context, WidgetRef ref) async {
  final it = await pickInstitution(context);
  if (it == null) return;
  final f = ref.read(formProvider.notifier);
  final changed = ref.read(formProvider)['pf_inst_id'] != it.id;
  f.put('pf_inst_id', it.id);
  f.put('pf_inst_name', it.name);
  if (changed) {
    f.put('pf_dept_id', '');
    f.put('pf_dept_name', '');
  }
}

Future<void> chooseDepartment(BuildContext context, WidgetRef ref) async {
  final f = ref.read(formProvider);
  final instId = (f['pf_inst_id'] ?? '').isNotEmpty ? f['pf_inst_id']! : ref.read(profileAccountProvider).institutionId;
  final it = await pickDepartment(context, instId);
  if (it == null) return;
  ref.read(formProvider.notifier).put('pf_dept_id', it.id);
  ref.read(formProvider.notifier).put('pf_dept_name', it.name);
}

Future<void> chooseStudyLevel(BuildContext context, WidgetRef ref) async {
  final v = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Votre niveau d’étude', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18, fontWeight: FontWeight.w700))),
        for (final l in levels) ListTile(title: Text(l, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600)), onTap: () => Navigator.of(ctx).pop(l)),
      ]),
    ),
  );
  if (v != null) ref.read(formProvider.notifier).put('vs_level', v);
}

/// Sous-texte d'un emplacement de pièce : nom et taille du document envoyé, « Envoi en cours… », ou invite.
class DocLine extends ConsumerWidget {
  const DocLine({super.key, required this.kind, required this.demo, required this.empty, this.center = false});
  final String kind, demo, empty;
  final bool center;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: center ? 11.5 : 12, fontWeight: FontWeight.w500, color: _grey);
    String text;
    Color? color;
    if (demoContent) {
      text = demo;
    } else if (ref.watch(uploadingProvider).contains('doc:$kind')) {
      text = 'Envoi en cours…';
    } else {
      final d = latestDoc(ref.watch(myDocsProvider), kind);
      if (d == null) {
        text = empty;
      } else {
        text = '${d.name} • ${sizeLabel(d.size)} • ${d.statusLabel}';
        color = d.status == 'rejected' ? const Color(0xFFC0261B) : (d.status == 'verified' ? const Color(0xFF0F7A52) : null);
      }
    }
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: center ? TextAlign.center : TextAlign.left, style: color == null ? st : st.copyWith(color: color));
  }
}

/// Pastille « envoyé » : visible seulement lorsqu'un document de ce type est réellement enregistré (toujours visible en démonstration).
class DocBadge extends ConsumerWidget {
  const DocBadge({super.key, required this.kind, required this.child});
  final String kind;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (demoContent) return child;
    return latestDoc(ref.watch(myDocsProvider), kind) == null ? const SizedBox.shrink() : child;
  }
}


/// « Passer pour l'instant » : la vérification n'est jamais obligatoire pour entrer dans l'application. Un client rejoint son accueil, un étudiant la présentation.
void skipVerification(WidgetRef ref, BuildContext context) {
  final a = ref.read(authProvider).current;
  if (a != null && a.role == 1 && a.staff.isEmpty) {
    gToast(context, 'Vous pourrez envoyer vos pièces plus tard, depuis « Devenir vendeur » (conditions pour vendre).');
    gOpen(context, '175');
  } else {
    finishAuthFlow(ref, context, fallback: homeScreenFor(a));
  }
}

/// « Envoyer pour validation » : le matricule est obligatoire pour un étudiant (jamais prérempli), au moins une pièce doit être envoyée.
Future<void> submitVerification(WidgetRef ref, BuildContext context) async {
  if (!Backend.ready) {
    gToast(context, 'Démonstration : la vérification nécessite la connexion au serveur.');
    return;
  }
  final f = ref.read(formProvider);
  final a = ref.read(profileAccountProvider);
  final matricule = (f['vs_mat'] ?? a.matricule).trim();
  if (matricule.length < 3) {
    gToast(context, 'Saisissez votre matricule (3 caractères au moins).');
    return;
  }
  if (ref.read(uploadingProvider).isNotEmpty) {
    gToast(context, 'Un envoi est en cours, patientez un instant.');
    return;
  }
  final docs = ref.read(myDocsProvider);
  if (!(docs ?? const []).any((d) => d.status != 'rejected' && (d.kind == 'student_card' || d.kind == 'enrollment_certificate'))) {
    gToast(context, 'Ajoutez au moins une pièce justificative valable : carte d’étudiant ou certificat de scolarité (une pièce refusée ne compte pas).');
    return;
  }
  final instId = (f['pf_inst_id'] ?? '').isNotEmpty ? f['pf_inst_id']! : a.institutionId;
  final deptId = (f['pf_dept_id'] ?? '').isNotEmpty ? f['pf_dept_id']! : a.departmentId;
  final level = (f['vs_level'] ?? a.studyLevel).trim();
  final err = await saveAcademic(ref, institutionId: instId, departmentId: deptId, matricule: matricule, level: level);
  if (!context.mounted) return;
  if (err != null) {
    await gAlert(context, 'Profil non enregistré', err);
    return;
  }
  ref.read(authProvider.notifier).update(a.copyWith(matricule: matricule, studyLevel: level, institutionId: instId, departmentId: deptId));
  // l'équipe concernée (département de l'étudiant, administration, support) est prévenue : c'est ce qui rend la phrase ci-dessous vraie
  final sub = await Backend.rpc('verification_submit', const {});
  if (!context.mounted) return;
  if (sub.error != null) {
    await gAlert(context, 'Envoi à l’équipe impossible', sub.error!);
    return;
  }
  gToast(context, 'Pièces envoyées : l’équipe de votre département a été prévenue. Vous serez notifié de sa décision.');
  gOpen(context, '175');
}

const _docKinds = {
  'cv': 'CV',
  'diploma': 'Diplôme',
  'certificate': 'Certificat ou attestation',
  'student_card': 'Carte d’étudiant',
  'enrollment_certificate': 'Certificat de scolarité',
  'other': 'Autre document',
};

/// « Téléverser un document » (écran 73) : choix du type, puis sélection et envoi dans le compartiment privé.
Future<void> uploadAnyDocument(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'L’envoi de documents nécessite la connexion au serveur.');
  final kind = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Type de document', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18, fontWeight: FontWeight.w700))),
        for (final e in _docKinds.entries) ListTile(title: Text(e.value, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 15, fontWeight: FontWeight.w600)), onTap: () => Navigator.of(ctx).pop(e.key)),
      ]),
    ),
  );
  if (kind == null || !context.mounted) return;
  await importDocument(context, ref, kind: kind, replacePrevious: false);
}

/// Documents de la personne connectée : état vide, chargement, ligne par document (type, date, état de vérification), consultation et suppression.
class DocumentsList extends ConsumerWidget {
  const DocumentsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (demoContent) return const SizedBox.shrink();
    final docs = ref.watch(myDocsProvider);
    final busy = ref.watch(uploadingProvider).any((k) => k.startsWith('doc:'));
    Widget note(String t) => Center(child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: _grey, height: 1.5)));
    if (docs == null) return note('Chargement de vos documents…');
    if (docs.isEmpty) return note(busy ? 'Envoi en cours…' : 'Aucun document pour le moment.\nAjoutez un CV, un diplôme ou un certificat.');
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: docs.length + (busy ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 14, thickness: 1, color: Color(0xFFF2EFF6)),
      itemBuilder: (_, i) {
        if (i >= docs.length) return const Text('Envoi en cours…', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: _grey));
        final d = docs[i];
        final color = switch (d.status) { 'verified' => const Color(0xFF0F7A52), 'rejected' => const Color(0xFFC0261B), _ => const Color(0xFF8F5400) };
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => openDocument(context, d),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF111015))),
                const SizedBox(height: 2),
                Text('${_docKinds[d.kind] ?? 'Document'} • ${sizeLabel(d.size)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: _grey)),
                if (d.status == 'rejected' && d.note.isNotEmpty) Text(d.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: color)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(d.statusLabel, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            if (d.status != 'verified')
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline, size: 20, color: _grey),
                onPressed: () async {
                  final err = await removeDocument(ref, d);
                  if (context.mounted) gToast(context, err ?? 'Document supprimé');
                },
              ),
          ]),
        );
      },
    );
  }
}

/// État de vérification réel de la personne connectée (fonction serveur my_student_status).
final myStudentStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (!Backend.ready) return null;
  final r = await Backend.rpc('my_student_status', const {});
  return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
});

/// Carte « Étudiant vérifié » des écrans 18 et 69 : statut réel, état de la certification, et les deux démarches (pièces, certification).
/// « Vérifié » = une carte d'étudiant ou un certificat de scolarité validé par l'équipe, ou une certification approuvée : le serveur n'ouvre
/// l'annuaire des talents, les invitations d'organisations et le vivier qu'aux étudiants vérifiés.
class StudentVerificationCard extends ConsumerWidget {
  const StudentVerificationCard({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(myStudentStatusProvider);
    return st.when(
      loading: () => SizedBox(width: width, height: 60, child: Center(child: Text('Chargement…', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: _grey)))),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) return const SizedBox.shrink();
        final verified = s['verified'] == true;
        final hasDoc = s['has_identity_document'] == true;
        final cert = '${s['certification']}';
        // l'état décidé par le département revient à l'étudiant : le compte affiché (badge, publication) suit le serveur
        final me = ref.read(authProvider).current;
        if (me != null && me.staff.isEmpty && me.certification != cert && const {'none', 'pending', 'review', 'approved', 'rejected', 'revoked'}.contains(cert)) {
          WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(authProvider.notifier).update(me.copyWith(certification: cert)));
        }
        final canAsk = s['can_request_certification'] == true;
        const certLabel = {
          'none': 'Certification : non demandée',
          'pending': 'Certification : demande en attente',
          'review': 'Certification : en cours d’examen',
          'approved': 'Certification : badge accordé',
          'rejected': 'Certification : refusée (vous pouvez refaire une demande)',
          'revoked': 'Certification : badge retiré',
        };
        final title = verified ? 'Étudiant vérifié' : (hasDoc ? 'Vérification en cours' : 'Vérification à compléter');
        final body = verified
            ? 'Votre carte d’étudiant a été validée par l’équipe : vous apparaissez dans l’annuaire des talents et pouvez recevoir des invitations d’organisations.'
            : (hasDoc
                ? 'Votre pièce est en attente de décision de l’équipe de votre département. Vous serez notifié du résultat.'
                : 'Déposez votre carte d’étudiant ou votre certificat de scolarité : l’annuaire des talents et les invitations d’organisations ne s’ouvrent qu’après leur validation.');
        final phoneOk = s['phone_verified'] == true;
        final hasPhone = s['has_phone'] == true;
        final hasDept = s['has_department'] != false;
        final rejected = [for (final d in (s['rejected_documents'] as List? ?? const [])) if (d is Map) d];
        final todo = <String>[
          if (!verified && !hasDept) 'Choisissez votre établissement et votre département dans votre profil : c’est le département qui reçoit et décide de votre dossier.',
          for (final d in rejected.take(1))
            if (!verified && !hasDoc) 'Votre dernière pièce a été refusée${'${d['note'] ?? ''}'.isEmpty ? '' : ' (motif : ${d['note']})'} : déposez-en une nouvelle.',
          if (!phoneOk) hasPhone ? 'Vérifiez votre numéro de téléphone (code reçu par SMS) : tant qu’il ne l’est pas, il ne sert ni à la connexion ni aux notifications SMS et WhatsApp.' : 'Ajoutez puis vérifiez votre numéro de téléphone.',
        ];
        const ink = Color(0xFF111015);
        Widget btn(String t, VoidCallback f, {bool dark = true}) => GestureDetector(
              onTap: f,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: dark ? ink : Colors.white, borderRadius: BorderRadius.circular(22), border: dark ? null : Border.all(color: const Color(0xFFD9D3E6))),
                child: Text(t, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: dark ? Colors.white : ink)),
              ),
            );
        return Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: verified ? const Color(0xFF1F9D6B) : const Color(0xFFECE8F2), width: verified ? 1.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 17, fontWeight: FontWeight.w800, color: verified ? const Color(0xFF0F7A52) : ink)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, height: 1.5, color: Color(0xFF4A4854))),
            const SizedBox(height: 10),
            Text(certLabel[cert] ?? 'Certification', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12.5, fontWeight: FontWeight.w600, color: _grey)),
            if (!verified) ...[
              const SizedBox(height: 8),
              const Text('Tant que vous n’êtes pas vérifié : vous pouvez parcourir, acheter et préparer vos annonces, mais l’annuaire des talents, les invitations d’organisations et les offres réservées aux étudiants vérifiés restent fermés. Publier une annonce demande en plus la certification du compte.', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, height: 1.5, color: _grey)),
            ],
            for (final t in todo) Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2, right: 6), child: Icon(Icons.chevron_right, size: 16, color: Color(0xFF8F5400))),
                Expanded(child: Text(t, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, height: 1.45, color: Color(0xFF8F5400), fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (!verified) btn('Déposer une pièce', () => gOpen(context, '18c'), dark: !hasDoc),
              if (!phoneOk) btn(hasPhone ? 'Vérifier mon numéro' : 'Ajouter mon numéro', () => GoRouter.of(context).push('/parametres/informations'), dark: false),
              if (canAsk) btn('Demander la certification', () async {
                await requestCertificationFlow(ref, context);
                ref.invalidate(myStudentStatusProvider);
              }),
              btn('Actualiser', () {
                ref.invalidate(myStudentStatusProvider);
                ref.read(myDocsProvider.notifier).refresh();
              }, dark: false),
            ]),
          ]),
        );
      },
    );
  }
}
