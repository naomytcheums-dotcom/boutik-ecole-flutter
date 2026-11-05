import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'profile_data.dart';

/// Mon dossier (écran 154) : la checklist est calculée sur les vraies pièces envoyées (compartiment privé) et sur le profil de la
/// personne. Aucun nom de fichier ni pourcentage de maquette hors démonstration.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

class DossierItem {
  const DossierItem(this.label, this.detail, this.done);
  final String label, detail;
  final bool done;
}

/// Éléments du dossier : CV, carte d'étudiant, certificat de scolarité, diplôme ou certificat, photo de profil et matricule.
List<DossierItem> dossierItems(List<UserDoc> docs, Account a) {
  UserDoc? doc(String kind) => latestDoc(docs, kind);
  final diploma = doc('diploma') ?? doc('certificate');
  return [
    DossierItem('CV', doc('cv')?.name ?? 'Document manquant', doc('cv') != null),
    DossierItem('Carte d’étudiant', doc('student_card')?.name ?? 'Document manquant', doc('student_card') != null),
    DossierItem('Certificat de scolarité', doc('enrollment_certificate')?.name ?? 'Document manquant', doc('enrollment_certificate') != null),
    DossierItem('Diplôme ou certificat', diploma?.name ?? 'Document manquant', diploma != null),
    DossierItem('Photo de profil', a.avatarUrl.isEmpty ? 'Aucune photo' : 'Photo enregistrée', a.avatarUrl.isNotEmpty),
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
    final missing = items.where((i) => !i.done).length;
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
              Text(missing == 0 ? 'Votre dossier est complet.' : 'Encore $missing élément${missing > 1 ? 's' : ''} à fournir.', style: _st(12, c: _grey)),
            ])),
          ]),
          const SizedBox(height: 24),
          Text('Checklist', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Icon(i.done ? Icons.check_circle : Icons.radio_button_unchecked, size: 22, color: i.done ? const Color(0xFF1F9D6B) : const Color(0xFFB9B4C7)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.label, style: _st(13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(i.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                ])),
                Text(i.done ? 'Fait' : 'À fournir', style: _st(11, w: FontWeight.w600, c: i.done ? const Color(0xFF0F7A52) : const Color(0xFF5A3FE0))),
              ]),
            ),
        ]),
      ),
    );
  }
}
