import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration — section U « Confiance, sécurité, partage » (170–174, 211–213).
class SectionUData {
  const SectionUData();

  /// Annonce concernée par le signalement, le partage et le passeport.
  final listing = const (
    title: 'Lampe en bois recyclé',
    price: 25000,
    seller: 'Y. Mouanga',
    image: Photos.lamp,
    darkImage: 'assets/images/u_lampe_sombre.jpg',
    link: 'boutik-ecole.cm/p/lampe-0142',
  );

  // 170 · Signaler une annonce
  final reportReasons = const [
    'Annonce frauduleuse ou trompeuse',
    'Photos ou description non conformes',
    'Prix anormal ou demande de paiement hors plateforme',
    'Contenu inapproprié',
  ];

  // 171 · Paiement sécurisé
  final officialNumber = '6 9X XX XX XX';
  final requestedNumber = '6 7X XX XX XX';

  // 172 · Confiance du vendeur
  final seller = const (name: 'Yannick Mouanga', detail: 'Génie civil · IUT de Douala', image: Photos.studentHijab);

  /// (icône, titre, détail, valeur, tonalité).
  final trustBadges = const [
    (AppIcons.circleCheck, 'Identité vérifiée', 'Matricule et pièce confirmés', 'Oui', Tone.success),
    (AppIcons.graduationCap, 'Étudiant de l’IUT', 'Certificat de scolarité validé', 'Oui', Tone.success),
    (AppIcons.truck, 'Livraison fiable', '98 % de commandes livrées à temps', '98 %', Tone.success),
    (AppIcons.starFilled, 'Avis positifs', '4,9 / 5 · 38 avis', '4,9', Tone.warning),
  ];

  // 174 · Centre de confiance
  final trustTips = const [
    'Payez uniquement dans l’application',
    'Vérifiez le badge du vendeur',
    'Signalez toute demande suspecte',
  ];

  /// (icône, titre, écran cible).
  final guides = const [
    (AppIcons.wallet, 'Payer en sécurité par Mobile Money', '171'),
    (AppIcons.shieldCheck, 'Reconnaître une annonce suspecte', '172'),
    (AppIcons.lock, 'Protéger mon compte', '148-1'),
    (AppIcons.flag, 'Signaler un problème', '170'),
  ];

  // 211 · Passeport du produit
  final passportImage = 'assets/images/u_betonniere.jpg';
  final origin = const [
    ('Département', 'Génie civil · GC'),
    ('Créateur', 'Mouanga Yannick'),
    ('Date', '12 oct. 2026'),
    ('Identifiant', 'BE-CERT-0021'),
  ];

  /// (étape, détail).
  final fabrication = const [
    ('Récupération des chutes', 'Ateliers GC'),
    ('Découpe et assemblage', 'Équipe de 2 étudiants'),
    ('Contrôle qualité', 'Validé par Dr Tchoupo'),
  ];

  // 212 · Vérifier un certificat
  final certificateId = 'BE-CERT-0021';
  final verification = const [
    ('Statut', 'Émis · vérifié'),
    ('Émis le', '12 oct. 2026'),
    ('Empreinte', 'a3f9…7c21'),
    ('Révoqué', 'Non'),
  ];

  // 213 · Registre des certificats (web)
  /// (libellé, valeur, tonalité de la barre).
  final registryKpis = const [
    ('Émis', '412', Tone.success),
    ('Vérifiés (30 j)', '1 286', Tone.accent),
    ('Remplacés', '9', Tone.warning),
    ('Révoqués', '2', Tone.error),
  ];

  /// (identifiant, élément, département, émis le, empreinte, statut, tonalité).
  final certificates = const [
    ('BE-CERT-0021', 'Lampe en bois recyclé', 'GC', '12 oct. 2026', 'a3f9…7c21', 'Émis', Tone.success),
    ('BE-CERT-0020', 'Application Boutik', 'GI', '10 oct. 2026', '91bc…02de', 'Émis', Tone.success),
    ('BE-CERT-0019', 'Jus de bissap', 'BTA', '08 oct. 2026', '77aa…fe10', 'Émis', Tone.success),
    ('BE-CERT-0018', 'Drone éducatif', 'GEII', '05 oct. 2026', 'c04d…b9a2', 'Remplacé', Tone.accent),
    ('BE-CERT-0015', 'Kit solaire', 'ENR', '28 sept. 2026', '5e11…3340', 'Révoqué', Tone.error),
  ];
  final adminName = 'Administration';
  final adminSubtitle = 'Boutik-École';
}

final sectionUDataProvider = Provider<SectionUData>((_) => const SectionUData());
