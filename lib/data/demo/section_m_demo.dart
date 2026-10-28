import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration de la section M (administration institutionnelle, 117–126).
class SectionMData {
  const SectionMData();

  final account = 'Direction';
  final accountSubtitle = 'IUT de Douala';

  // 117 · Tableau de bord institutionnel
  final activityTitle = 'Activité et ventes (M FCFA)';
  final activityTotal = 48700000;
  final activityDelta = '+ 11 %';
  final activityGain = 4800000;
  final activityTooltip = ('48,7 M', 'Octobre 2026');
  final months = const ['Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.'];
  final activityBars = const [
    0.32, 0.30, 0.35, 0.31, 0.36, 0.34, 0.31, 0.37, 0.32, 0.36, 0.34, 0.33, 0.37, 0.39, 0.33, 0.34, 0.37, 0.39, 0.35, 0.34, //
    0.38, 0.31, 0.35, 0.32, 0.30, 0.29, 0.30, 0.32, 0.28, 0.30, 0.30, 0.27, 0.28, 0.25, 0.24, 0.25, 0.27, 0.26, 0.74, 0.58, //
    0.80, 0.64, 0.82, 0.78, 0.64, 0.84, 0.60, 0.92, 0.58, 0.82, 0.64, 0.74, 0.62, 0.84, 0.64, 0.72, 0.68, 0.68, 0.86, 0.58, //
    0.90, 0.50, 0.86, 0.60, 0.82, 0.64, 0.80, 0.48, 0.42, 0.44, 0.40, 0.46, 0.46, 0.48, 0.47, 0.42, 0.44, 0.47, 0.40, 0.44,
  ];
  final activityHighlight = (38, 66);
  final activityCurve = const [0.57, 0.72, 0.54, 0.40, 0.54, 0.78, 0.62, 0.48];

  /// (vignette, département, sigle, étudiants actifs, statut, tonalité, ventes en k FCFA).
  final activeDepartments = const [
    (Photos.coder, 'Génie informatique', 'GI', 312, 'Actif', Tone.success, 4820),
    (Photos.lamp, 'Génie civil', 'GC', 286, 'Actif', Tone.neutral, 3950),
    (Photos.solar, 'Génie électrique', 'GEII', 241, 'Actif', Tone.success, 3310),
    (Photos.technician, 'Gestion logistique', 'GLT', 198, 'Actif', Tone.neutral, 2740),
    (Photos.studentHijab, 'Techniques de commercialisation', 'TCO', 176, 'À relancer', Tone.success, 2120),
  ];
  final yearGoal = 71;
  final yearProgress = const [(71, 'des ventes'), (80, 'des certificats')];
  final kelaAvatar = Photos.portraitWoman;
  final kelaQuestion = 'Quels enseignements cherches-tu ?';
  final kelaAnswer =
      'L’activité de l’établissement progresse de 11 %. TCO est en retrait ce mois-ci : veux-tu relancer le département ?';

  // 118 · Établissement et identité visuelle
  final institutionInfo = const [
    ('Nom', 'IUT de Douala'),
    ('Sigle', 'IUT-D'),
    ('Adresse', 'Bonabéri, Douala'),
    ('E-mail', 'contact@iut-douala.cm'),
    ('Téléphone', '+237 233 XX XX XX'),
  ];
  final visualIdentity = const [
    ('Couleur principale', '#12253F · Bleu marine'),
    ('Couleur d’accent', '#FBB52B · Doré'),
    ('Police', 'Sans-serif professionnelle'),
    ('Mode sombre', 'Non disponible'),
  ];
  final brandFiles = const [('Logo de l’établissement', 'PNG ou SVG · 2 Mo max'), ('Bannière d’accueil', '1600 × 600 px')];

  // 119 · Départements et filières
  /// (département, filières, responsable, étudiants, statut, tonalité).
  final departments = const [
    ('Génie informatique', 'Informatique, Réseaux', 'Dr Mbarga', 248, 'Actif', Tone.success),
    ('Génie civil', 'Bâtiment, Travaux publics', 'Dr Tchoupo', 212, 'Actif', Tone.success),
    ('MMI', 'Design, Audiovisuel', 'Mme Etoga', 180, 'Actif', Tone.success),
    ('Génie électrique', 'Électronique, IoT', 'Pr Ngassa', 165, 'Actif', Tone.success),
    ('Agronomie', 'Production végétale', 'Dr Fotso', 98, 'En création', Tone.accent),
  ];

  // 120 · Utilisateurs et affectations
  final userTabs = const ['Tous (1 240)', 'Étudiants', 'Vendeurs', 'Responsables', 'Suspendus'];

  /// (nom, rôle, département, dernière connexion, statut, tonalité).
  final users = const [
    ('Mariam Essono', 'Vendeur', 'Génie informatique', 'Aujourd’hui 09:12', 'Actif', Tone.success),
    ('Dr Mbarga', 'Responsable', 'Génie informatique', 'Aujourd’hui 08:30', 'Actif', Tone.success),
    ('Kouassi Tagne', 'Étudiant', 'MMI', 'Hier 18:44', 'Actif', Tone.success),
    ('Carine Mbarga', 'Étudiant', 'Génie informatique', '12 oct.', 'Suspendu', Tone.error),
    ('Brice Ndoumbe', 'Vendeur', 'Génie électrique', 'Aujourd’hui 07:55', 'Actif', Tone.success),
  ];

  // 121 · Responsables et encadreurs
  final staffKpis = const [
    ('Responsables', '8', AppIcons.award),
    ('Enseignants', '64', AppIcons.users),
    ('Encadreurs', '27', AppIcons.graduationCap),
    ('Mentors externes', '12', AppIcons.briefcase),
  ];

  /// (nom, fonction, département, affectations, statut).
  final staff = const [
    ('Dr Mbarga', 'Responsable', 'Génie informatique', '248 étudiants', 'Actif'),
    ('Dr Tchoupo', 'Responsable', 'Génie civil', '212 étudiants', 'Actif'),
    ('Pr Ngassa', 'Encadreur', 'Génie électrique', '18 projets', 'Actif'),
    ('Mme Etoga', 'Responsable', 'MMI', '180 étudiants', 'Actif'),
  ];

  // 122 · Circuits de validation
  final circuitTabs = const ['Annonces produits', 'Services', 'Projets', 'Vendeurs'];
  final circuitSteps = const [
    ('1. Soumission par l’étudiant', 'Brouillon → À valider', 0),
    ('2. Contrôle du département', 'Responsable de département · 48 h max', 1),
    ('3. Validation institutionnelle', 'Si montant > 100 000 FCFA', 2),
  ];
  final circuitRules = const [
    ('Validation automatique sous 5 000 FCFA', 'Sans intervention humaine', false),
    ('Double validation au-delà de 100 000 FCFA', 'Département + institution', true),
    ('Notification de l’étudiant', 'À chaque décision', true),
  ];

  // 123 · Ventes et activité
  final salesKpis = const [
    ('Chiffre d’affaires', '28 400 000 FCFA', AppIcons.wallet, '+11 %'),
    ('Commandes', '1 482', AppIcons.receipt, '+9 %'),
    ('Vendeurs actifs', '312', AppIcons.users, '+24'),
    ('Panier moyen', '19 160 FCFA', AppIcons.shoppingCart, '+2 %'),
  ];
  final salesByDepartment = const [('Info', 9.8), ('Civil', 7.9), ('MMI', 6.2), ('Élec.', 4.5), ('Agro', 2.0)];
  final monthlyOrders = const [180, 210, 238, 262, 290, 318];

  // 124 · Événements et campagnes
  /// (événement, date, lieu, inscrits, statut, tonalité).
  final campaigns = const [
    ('Exposition des innovations', '24 oct. 2026', 'Hall principal', '186 / 250', 'Confirmé', Tone.success),
    ('Salon des créations étudiantes', '14 nov. 2026', 'Campus', '94 / 300', 'Inscriptions ouvertes', Tone.accent),
    ('Campagne « Achetez local »', 'Nov. 2026', 'En ligne', '—', 'Brouillon', Tone.neutral),
  ];

  // 125 · Rapports consolidés
  final reports = const [
    ('Rapport mensuel global', 'PDF · Octobre 2026'),
    ('Ventes par département', 'Excel · 12 mois'),
    ('Validations et décisions', 'CSV · 12 mois'),
  ];

  /// (rapport, fréquence, destinataires, prochain envoi).
  final scheduled = const [
    ('Synthèse mensuelle', 'Mensuelle', 'Direction, départements', '1er nov. 2026'),
    ('Ventes hebdomadaires', 'Hebdomadaire', 'Responsables', '26 oct. 2026'),
    ('Audit de sécurité', 'Trimestrielle', 'Direction', '1er janv. 2027'),
  ];

  // 126 · Journal d'audit
  final auditTabs = const ['Toutes', 'Connexions', 'Validations', 'Paramètres', 'Suppressions'];

  /// (date, utilisateur, action, cible, IP, niveau, catégorie d'onglet).
  final audit = const [
    ('22 oct. 10:24', 'Dr Mbarga', 'Annonce validée', 'Lampe en bois recyclé', '41.202.x.x', 'Normal', 'Validations'),
    ('22 oct. 09:58', 'Direction', 'Circuit modifié', 'Annonces produits', '41.202.x.x', 'Sensible', 'Paramètres'),
    ('21 oct. 17:12', 'Admin', 'Compte suspendu', 'Carine Mbarga', '197.15.x.x', 'Sensible', 'Paramètres'),
    ('21 oct. 11:03', 'Direction', 'Export des données', 'Ventes 12 mois', '41.202.x.x', 'Sensible', 'Paramètres'),
  ];
}

final sectionMDataProvider = Provider<SectionMData>((_) => const SectionMData());
