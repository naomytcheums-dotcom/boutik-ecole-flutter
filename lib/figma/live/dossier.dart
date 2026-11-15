import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'access.dart' show roleKey;
import 'backend.dart';
import 'profile_data.dart';

/// Mon dossier (écran 154) : la checklist est calculée sur les vraies pièces envoyées (compartiment privé) et sur le profil de la
/// personne. Aucun nom de fichier ni pourcentage de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class DossierItem {
  const DossierItem(this.label, this.detail, this.done, {this.waiting = false, this.rejected = false});
  final String label, detail;

  /// Fait : pièce vérifiée par l'équipe, ou information renseignée. Une pièce en attente ou refusée n'est jamais « Faite ».
  final bool done;
  final bool waiting, rejected;

  String get stateLabel => done ? 'Fait' : (waiting ? 'En attente' : (rejected ? 'Refusé' : 'À fournir'));
}

/// Un étudiant a une carte d'étudiant, un certificat de scolarité et un matricule ; les autres rôles (client, entreprise…) n'en ont pas.
bool isStudentDossier(Account a) => roleKey(a) == 'student';

/// Meilleure pièce parmi les types donnés : vérifiée, sinon en attente, sinon refusée (la plus récente à égalité).
UserDoc? bestDoc(List<UserDoc>? docs, List<String> kinds) {
  if (docs == null) return null;
  int rank(UserDoc d) => switch (d.status) { 'verified' => 3, 'pending' => 2, _ => 1 };
  final l = docs.where((d) => kinds.contains(d.kind)).toList()
    ..sort((a, b) {
      final c = rank(b).compareTo(rank(a));
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  return l.isEmpty ? null : l.first;
}

DossierItem _docItem(String label, List<UserDoc>? docs, List<String> kinds) {
  final d = bestDoc(docs, kinds);
  if (d == null) return DossierItem(label, 'Document manquant', false);
  return switch (d.status) {
    'verified' => DossierItem(label, d.name, true),
    'rejected' => DossierItem(label, d.note.isEmpty ? '${d.name} · refusé, à renvoyer' : '${d.name} · refusé : ${d.note}', false, rejected: true),
    _ => DossierItem(label, '${d.name} · en attente de vérification', false, waiting: true),
  };
}

/// Éléments du dossier selon le rôle : l'étudiant fournit CV, carte d'étudiant, certificat de scolarité, diplôme ou certificat, photo et matricule ;
/// les autres rôles, CV, diplôme ou certificat et photo de profil.
List<DossierItem> dossierItems(List<UserDoc> docs, Account a) {
  final photo = DossierItem('Photo de profil', a.avatarUrl.isEmpty ? 'Aucune photo' : 'Photo enregistrée', a.avatarUrl.isNotEmpty);
  if (!isStudentDossier(a)) {
    return [_docItem('CV', docs, const ['cv']), _docItem('Diplôme ou certificat', docs, const ['diploma', 'certificate']), photo];
  }
  return [
    _docItem('CV', docs, const ['cv']),
    _docItem('Carte d’étudiant', docs, const ['student_card']),
    _docItem('Certificat de scolarité', docs, const ['enrollment_certificate']),
    _docItem('Diplôme ou certificat', docs, const ['diploma', 'certificate']),
    photo,
    DossierItem('Matricule', a.matricule.isEmpty ? 'Non renseigné' : 'Renseigné', a.matricule.isNotEmpty),
  ];
}

int dossierPercent(List<DossierItem> items) => items.isEmpty ? 0 : (items.where((i) => i.done).length * 100 / items.length).round();

class DossierPanel extends ConsumerWidget {
  const DossierPanel({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(profileAccountProvider);
    final docs = ref.watch(myDocsProvider);
    Widget note(String t) => Container(width: width, height: 150, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey)));
    if (ref.watch(authProvider.select((s) => s.current == null))) return note('Connectez-vous pour voir votre dossier.');
    if (!Backend.ready || docs == null) return note('Chargement de votre dossier…');
    final items = dossierItems(docs, a);
    final pct = dossierPercent(items);
    final missing = items.where((i) => !i.done && !i.waiting).length;
    final waiting = items.where((i) => i.waiting).length;
    final status = [
      if (missing > 0) 'Encore $missing élément${missing > 1 ? 's' : ''} à fournir.',
      if (waiting > 0) '$waiting pièce${waiting > 1 ? 's' : ''} en attente de vérification.',
      if (missing == 0 && waiting == 0) 'Votre dossier est complet.',
    ].join(' ');
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 70, height: 70, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: _ink), child: Text('$pct %', style: _st(18, w: FontWeight.w800, c: Colors.white))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dossier complet à $pct %', style: _st(15.5, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(status, style: _st(12, c: _grey)),
            ])),
          ]),
          const SizedBox(height: 24),
          Text('Checklist', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Icon(i.done ? Icons.check_circle : (i.waiting ? Icons.schedule : (i.rejected ? Icons.cancel_outlined : Icons.radio_button_unchecked)), size: 22, color: i.done ? const Color(0xFF1F9D6B) : (i.waiting ? const Color(0xFF8F5400) : (i.rejected ? const Color(0xFFE5484D) : const Color(0xFFB9B4C7)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.label, style: _st(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(i.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                ])),
                Text(i.stateLabel, style: _st(11, w: FontWeight.w600, c: i.done ? const Color(0xFF0F7A52) : (i.rejected ? const Color(0xFFE5484D) : (i.waiting ? const Color(0xFF8F5400) : const Color(0xFF5A3FE0))))),
              ]),
            ),
        ]),
      ),
    );
  }
}
