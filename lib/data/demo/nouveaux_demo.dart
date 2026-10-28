import '../models/models.dart';
import 'catalog_demo.dart';

/// Données de démonstration de la section « Nouveaux écrans » (255–288, 74, 250b).
/// Tous les chiffres sont fictifs et repris des maquettes.
class NouveauxData {
  const NouveauxData();

  // 255 · Suivi de publication
  final publicationProduct = const (
    title: 'Lampe en bois recyclé',
    detail: 'Génie civil · soumis le 22 oct.',
    stepLabel: 'Étape 5 sur 10',
    image: Photos.builder,
  );
  final publicationSteps = const <WorkflowStep>[
    WorkflowStep('Dépôt', 'Terminé · 22 oct.', Progress.done),
    WorkflowStep('Contrôles automatiques', 'Terminé · 22 oct. · 12/12 contrôles', Progress.done),
    WorkflowStep('Validation départementale', 'Terminé · Dr Mbarga · 23 oct.', Progress.done),
    WorkflowStep('Validation éditoriale', 'Terminé · modératrice · 24 oct.', Progress.done),
    WorkflowStep('Contrôles réglementaires', 'En cours · checklist 3/5', Progress.current),
    WorkflowStep('Certification', 'À venir · certificat et ancrage', Progress.upcoming),
    WorkflowStep('Publication', 'À venir', Progress.upcoming),
    WorkflowStep('Transaction', 'À venir · commande, devis ou financement', Progress.upcoming),
    WorkflowStep('Préparation / réalisation', 'À venir', Progress.upcoming),
    WorkflowStep('Clôture', 'À venir · livraison, facture, revenus, archivage', Progress.upcoming),
  ];

  // 256 · Contrôles de la fiche
  final autoChecks = const <CheckItem>[
    CheckItem('Champs obligatoires', CheckState.passed),
    CheckItem('Photos : formats et dimensions', CheckState.passed),
    CheckItem('Prix en FCFA', CheckState.passed),
    CheckItem('Quantité et disponibilité', CheckState.passed),
    CheckItem('Liens externes valides', CheckState.passed),
    CheckItem('Fichiers sans contenu actif', CheckState.passed),
    CheckItem('Titre et description (longueur)', CheckState.passed),
    CheckItem('Auteurs et contributeurs déclarés', CheckState.passed),
  ];
  final autoChecksTotal = 12;
  final regulatoryChecks = const <CheckItem>[
    CheckItem('Propriété intellectuelle : droits d’utilisation', CheckState.passed),
    CheckItem('Sécurité du produit (mécanique, électrique)', CheckState.passed),
    CheckItem('Alimentaire ou santé : non concerné', CheckState.passed),
    CheckItem('Données personnelles : non concerné', CheckState.pending),
    CheckItem('Visa du référent réglementaire', CheckState.pending),
  ];

  // 257–260 · Paiement
  final pendingPayment = const Payment(
    orderId: '#BE-2026-0142',
    method: 'Orange Money',
    amount: 330000,
    reference: 'OM-7F3A-2210',
    remaining: '01:48',
  );
  final failedPayment = const Payment(
    orderId: '#BE-2026-0142',
    method: 'Orange Money',
    amount: 330000,
    reference: 'OM-7F3A-2210',
    failureReason: 'Solde insuffisant',
    attempt: '1 sur 3',
  );
  final receipt = const Payment(
    orderId: '#BE-2026-0142',
    method: 'Orange Money',
    amount: 330000,
    reference: 'OM-7F3A-2210',
    receiptNo: 'RC-2026-00842',
    date: '22 oct. 2026 · 14:32',
    seller: 'Yannick Mouanga · GC',
    pickup: 'Kiosque IUT · Bloc A',
  );
  final paymentMethods = const <PaymentMethod>[
    PaymentMethod('om', 'Orange Money', 'OM'),
    PaymentMethod('momo', 'MTN MoMo', 'MM'),
    PaymentMethod('cash', 'Espèces au kiosque', '€'),
  ];
  final invoice = const Invoice(
    number: 'FA-2026-00391',
    date: '22 oct. 2026',
    lines: [
      InvoiceLine('Lampe en bois recyclé', 2, 50000),
      InvoiceLine('Kit solaire portable', 1, 18000),
      InvoiceLine('Support de tablette', 5, 30000),
    ],
    fees: 1470,
    taxes: 0,
  );

  // 261 · Espace client
  final clientName = 'Mariam';
  final clientOrdersInProgress = 2;
  final clientSummary = '1 devis en attente de réponse · 1 mission à valider';
  final clientCounters = const <LabeledValue>[
    LabeledValue('Commandes', '12'),
    LabeledValue('Devis', '3'),
    LabeledValue('Favoris', '8'),
  ];
  final clientOrders = const <StatusItem>[
    StatusItem('Lampe en bois recyclé', '#BE-2026-0142', 'En route', Tone.accent, extra: Photos.builder),
    StatusItem('Jus de bissap', '#BE-2026-0139', 'Livrée', Tone.success, extra: Photos.bissap),
  ];
  final clientCollab = const StatusItem(
    'Identité visuelle · Mbella',
    'Étape 3 sur 5 · livraison le 28 nov.',
    'À valider',
    Tone.warning,
    extra: Photos.studentHijab,
  );

  // 270 · Showroom national
  final showroomFilters = const ['Tous', 'Douala', 'Bandjoun', 'Ngaoundéré'];
  final showroom = const <Product>[
    Product(id: 's1', title: 'Lampe en bois recyclé', price: 25000, seller: '', department: 'GC', image: Photos.lamp),
    Product(id: 's2', title: 'Kit solaire portable', price: 18000, seller: '', department: 'ENR', institution: 'IUT de Bandjoun', image: Photos.solar),
    Product(id: 's3', title: 'Suivi clients', price: 0, seller: '', department: 'GI', image: Photos.coder),
    Product(id: 's4', title: 'Jus de bissap', price: 0, seller: '', department: 'BTA', institution: 'IUT de Ngaoundéré', image: Photos.bissap),
    Product(id: 's5', title: 'Identité Mbella', price: 0, seller: '', department: 'MMI', image: Photos.phone),
    Product(id: 's6', title: 'Pont miniature', price: 0, seller: '', department: 'GC', institution: 'IUT de Bandjoun', image: Photos.maquette),
  ];

  // 271 · Liens et réseaux
  final socialLinks = const <SocialLink>[
    SocialLink('LinkedIn', 'linkedin.com/in/mariam-essono', true, 'in'),
    SocialLink('X', '@mariam_dev', true, 'X'),
    SocialLink('Instagram', '@mariam.codes', true, 'IG'),
    SocialLink('GitHub', 'github.com/mariam-essono', true, 'GH'),
    SocialLink('Facebook', '', false, 'f'),
    SocialLink('YouTube', '', false, 'YT'),
    SocialLink('TikTok', '', false, 'TT'),
    SocialLink('WhatsApp', '+237 6 •• •• •• 42', true, 'WA'),
  ];

  // 272 · Double authentification
  final twoFactorTarget = '+237 6 •• •• •• 42';
  final twoFactorPrefill = '4817';
  final twoFactorResend = '00:42';
  final backupCodes = 10;

  // 273 · Mes données
  final lastExport = 'Dernier export : 12 mars 2026 · 4,2 Mo';

  // 274 · CGU
  final termsVersion = 'Version 2.1 · mise à jour le 02/09/2026';

  // 276 · Borne hors ligne
  final offlineKiosk = 'Hall principal · Borne n°2';
  final offlineFeatures = const [
    '120 produits et services en vitrine',
    'Cartes de visite et QR codes',
    'Plan de l’IUT et horaires',
  ];
  final helpDesk = 'Adressez-vous à l’accueil · poste 214';

  // 277 · Supervision des bornes
  final kiosks = const <StatusItem>[
    StatusItem('Borne 1 · Hall principal', 'Dernier signal il y a 12 s', 'En ligne', Tone.success),
    StatusItem('Borne 2 · Bibliothèque', 'Mode secours actif depuis 6 min', 'Hors ligne', Tone.error),
    StatusItem('Borne 3 · Département MMI', 'Dernier signal il y a 8 s', 'En ligne', Tone.success),
    StatusItem('Borne 4 · Salle des profs', 'Version 1.8.2 → 1.8.3 (72 %)', 'Mise à jour', Tone.warning),
  ];

  // 278 · Fiche projet
  final projectLinks = const <LabeledValue>[
    LabeledValue('GitHub', 'github.com/mariam-essono/lampe-iot'),
    LabeledValue('Démo en ligne', 'lampe-demo.boutik-ecole.cm'),
    LabeledValue('Documentation', 'docs.boutik-ecole.cm/lampe'),
    LabeledValue('Vidéo de présentation', 'youtube.com/watch?v=…'),
  ];
  final projectIp = const <LabeledValue>[
    LabeledValue('Auteurs', 'Mariam E. · Yannick M.'),
    LabeledValue('Encadrant', 'Dr Ngono · Génie civil'),
    LabeledValue('Licence', 'CC BY-NC 4.0'),
    LabeledValue('Droits', 'Étudiants + IUT (50 / 50)'),
    LabeledValue('Restrictions', 'Usage commercial sur accord'),
  ];

  // 279 · Fichiers
  final uploadRules = const <LabeledValue>[
    LabeledValue('Types autorisés', 'JPG · PNG · WebP · PDF · MP4 · ZIP'),
    LabeledValue('Taille maximale', '5 Mo image · 200 Mo vidéo'),
    LabeledValue('Analyse', 'Antivirus à chaque dépôt'),
  ];
  final uploads = const <StatusItem>[
    StatusItem('plan-lampe.pdf', 'Analyse terminée : sain', '2,1 Mo', Tone.success),
    StatusItem('maquette.zip', 'Analyse en cours… 64 %', '48 Mo', Tone.warning),
    StatusItem('script.exe', 'Refusé : type non autorisé', '1,2 Mo', Tone.error),
    StatusItem('video-demo.mp4', 'Refusé : dépasse 200 Mo', '312 Mo', Tone.error),
  ];

  // 280 · Intégrations
  final api = const <LabeledValue>[
    LabeledValue('Version active', 'v2 (v1 retirée le 31/12/2026)'),
    LabeledValue('Limite', '600 requêtes / minute'),
    LabeledValue('Documentation', 'api.boutik-ecole.cm/docs', tone: Tone.accent),
  ];
  final apiKeys = const <StatusItem>[
    StatusItem('Portail entreprises', 'be_live_••••8F2A · Créée le 04/06', 'Révoquer', Tone.error),
    StatusItem('Kiosque', 'be_live_••••19C0 · Créée le 12/07', 'Révoquer', Tone.error),
  ];
  final webhooks = const <StatusItem>[
    StatusItem('commande.payee', 'https://erp.iut-douala.cm/hook', 'Actif', Tone.success),
    StatusItem('certificat.emis', 'https://partenaire.cm/events', 'Actif', Tone.success),
  ];

  // 281 · Rôles et périmètres (lire, écrire, valider)
  final roleMatrix = const <(String, bool, bool, bool)>[
    ('Visiteur', true, false, false),
    ('Client', true, true, false),
    ('Étudiant', true, true, false),
    ('Responsable département', true, true, true),
    ('Référent de validation', true, false, true),
    ('Modérateur éditorial', true, true, true),
    ('Logisticien', true, true, false),
    ('Responsable finance', true, false, true),
    ('Administrateur institution', true, true, true),
  ];

  // 282 · QR de transfert
  final qrKiosk = 'Borne n°2 · Hall principal';
  final qrExpiry = '04:32';
  final qrSecurity = const <LabeledValue>[
    LabeledValue('Signature', 'HMAC-SHA256 vérifiée'),
    LabeledValue('Réutilisation', 'Refusée après le 1er scan', tone: Tone.error),
    LabeledValue('Contenu', 'Panier + identifiant de borne'),
  ];
  final qrEvent = const <LabeledValue>[
    LabeledValue('Événement', 'Journée de l’innovation'),
    LabeledValue('Début', '12/11/2026 · 08:00'),
    LabeledValue('Fin', '12/11/2026 · 18:00'),
    LabeledValue('Contenu mis en avant', 'Drops et projets MMI'),
  ];

  // 283 · Registre des certificats
  final certificates = const <StatusItem>[
    StatusItem('BE-C-0412 · Lampe en bois recyclé', 'Par Dr Ngono · 02/09/2026', 'Émis', Tone.success),
    StatusItem('BE-C-0398 · Chaise ergonomique', 'Scan public · 29/08/2026', 'Vérifié', Tone.accent),
    StatusItem('BE-C-0377 · Panneau solaire V1', 'Remplacé par BE-C-0419', 'Remplacé', Tone.warning),
    StatusItem('BE-C-0351 · Prototype drone', 'Motif : non-conformité · 14/08/2026', 'Révoqué', Tone.error),
  ];

  // 284 · Registre financier
  final ledgerOrder = '#BE-2026-0142';
  final ledgerGross = 330000;
  final ledgerFees = 4950;
  final ledgerTaxes = 53280;
  final ledgerRefunds = 0;

  // 285 · Espace projet
  final missionTitle = 'Mission : Identité visuelle · Mbella SARL';
  final missionContract = const <LabeledValue>[
    LabeledValue('Montant', '1 200 000 FCFA'),
    LabeledValue('Statut', 'Signé le 08/09/2026', tone: Tone.success),
    LabeledValue('Livraison', '30/11/2026'),
    LabeledValue('Équipe', '4 étudiants MMI'),
  ];
  final milestones = const <StatusItem>[
    StatusItem('1 · Brief validé', '', 'Terminé', Tone.success),
    StatusItem('2 · Maquettes', '', 'Terminé', Tone.success),
    StatusItem('3 · Version finale', '', 'En cours', Tone.warning),
    StatusItem('4 · Livraison', '', 'À venir', Tone.neutral),
  ];
  final missionMessages = 3;

  // 286 · Soumissions et équipe
  final submissions = const <StatusItem>[
    StatusItem('Lampe en bois recyclé', 'Mariam E. · Il y a 2 h', '', Tone.neutral),
    StatusItem('Tote bag sérigraphié', 'Yannick M. · Il y a 5 h', '', Tone.neutral),
    StatusItem('Site vitrine boulangerie', 'Carine M. · Hier', '', Tone.neutral),
  ];
  final team = const <Member>[
    Member('Dr Ngono', 'Responsable', 'Valider · Publier · Équipe'),
    Member('Pr Fotso', 'Référent de validation', 'Valider'),
    Member('Sandra T.', 'Modératrice éditoriale', 'Éditer · Publier'),
    Member('Éric B.', 'Logisticien', 'Commandes · Stock'),
    Member('Mariam E.', 'Étudiante', 'Déposer'),
  ];

  // 74 · Talent Passport
  final passportOwner = 'Mariam Essono · Génie informatique';
  final passportLevel = 'Niveau Confirmé';
  final passportNumber = 'Passeport n° TP-2026-0187 · vérifié par l’IUT';
  final passportSkills = const <Skill>[
    Skill('Python', 'Avancé', .9),
    Skill('React', 'Confirmé', .75),
    Skill('Mobile (Flutter)', 'Intermédiaire', .6),
  ];
  final passportBadges = const <LabeledValue>[
    LabeledValue('Hackathon IUT 2026', '1re place'),
    LabeledValue('Mentor étudiant', '12 h'),
    LabeledValue('Vendeuse fiable', '4,9 / 5'),
  ];
  final passportCertificates = const [
    'BE-C-0412 · Lampe en bois recyclé · Émis',
    'BE-C-0377 · Application de stock · Vérifié',
  ];
  final passportRecommendations = '2 recommandations d’entreprises · Orange Cameroun';

  // 287 / 288 · Catalogue du département
  final departmentName = 'MMI';
  final catalogSummary = '18 fiches · 12 publiées · 4 en validation · 2 brouillons';
  final catalogTotal = 18;

  // 262 · Accueil B2B
  final b2bKpis = const <Kpi>[
    Kpi('Entreprises inscrites', '184', delta: '+ 12 ce mois'),
    Kpi('Briefs reçus', '63', delta: '+ 8 cette semaine'),
    Kpi('Stages et recrutements', '27', delta: '+ 4 ce mois'),
    Kpi('Délai moyen de réponse', '2,4 j', delta: '- 0,6 j'),
  ];
  final openChallenges = const <(String, String, String, String)>[
    ('Application de suivi clients', '7 équipes', '30 nov.', 'Ouvert'),
    ('Borne solaire mobile', '4 équipes', '15 nov.', 'Ouvert'),
  ];

  // 263 · Médiathèque
  final media = const <MediaItem>[
    MediaItem('Lampe en bois recyclé.jpg', 'Image', Photos.builder),
    MediaItem('Jus de bissap.mp4', 'Vidéo', Photos.bissap),
    MediaItem('Kit solaire.jpg', 'Image', Photos.solar),
    MediaItem('Application de suivi.jpg', 'Image', Photos.coder, public: false),
    MediaItem('Affiche concours.mp4', 'Vidéo', Photos.phone),
    MediaItem('Maquette de pont.jpg', 'Image', Photos.maquette),
    MediaItem('Tableau de bord.jpg', 'Image', Photos.technician),
    MediaItem('Atelier RH.mp4', 'Vidéo', Photos.office),
  ];
  final storage = 'Stockage utilisé : 14,2 Go sur 50 Go · URLs signées pour les fichiers privés';

  // 264 · Pages éditoriales
  final editorialPages = const <(String, String, String)>[
    ('Accueil', '22 oct. · Admin', 'Publiée'),
    ('À propos de Boutik-École', '20 oct. · Admin', 'Publiée'),
    ('FAQ', '18 oct. · Support', 'Publiée'),
    ('Conditions générales', '15 oct. · Juridique', 'Brouillon'),
    ('Mentions légales', '15 oct. · Juridique', 'Brouillon'),
    ('Page impact', '12 oct. · Admin', 'Publiée'),
  ];

  // 265 · Modèles de notifications
  final notificationTemplates = const <(String, String, String, String)>[
    ('Commande confirmée', 'Email · SMS', 'FR · EN', 'Actif'),
    ('Paiement échoué', 'SMS · WhatsApp', 'FR · EN', 'Actif'),
    ('Étape de mission validée', 'WhatsApp', 'FR', 'Actif'),
    ('Certificat émis', 'Email', 'FR · EN', 'Actif'),
    ('Alerte fraude Mobile Money', 'SMS', 'FR', 'Actif'),
    ('Rappel de live', 'Push', 'FR', 'Brouillon'),
  ];
  final templatePreview =
      'Bonjour {prénom}, votre paiement de {montant} FCFA pour la commande {numéro} a échoué. Vous pouvez réessayer : {lien}';

  // 266 · État technique
  final uptime = const <Kpi>[
    Kpi('API', '99,98 %', status: 'En ligne'),
    Kpi('Base de données', '99,99 %', status: 'En ligne'),
    Kpi('Stockage et CDN', '99,95 %', status: 'En ligne'),
    Kpi('Passerelle de paiement', '99,2 %', status: 'Dégradé', tone: Tone.warning),
  ];
  final backups = const <(String, String, String, String)>[
    ('Complète', '27 oct. · 02:00', '12,4 Go', 'Réussi'),
    ('Complète', '26 oct. · 02:00', '12,3 Go', 'Réussi'),
    ('Incrémentale', '26 oct. · 14:00', '0,6 Go', '—'),
    ('Complète', '25 oct. · 02:00', '12,3 Go', 'Réussi'),
  ];
  final platformVersion = 'Version v1.8.2 · dernière migration le 24 oct.';

  // 267 · Réseau
  final institutions = const <StatusItem>[
    StatusItem('IUT de Douala', 'Catalogue partagé · étudiants actifs', 'Actif', Tone.success),
    StatusItem('IUT de Bandjoun', 'Catalogue partagé · étudiants actifs', 'Actif', Tone.success),
    StatusItem('IUT de Ngaoundéré', 'Catalogue partagé · étudiants actifs', 'Actif', Tone.success),
    StatusItem('Université partenaire A', 'Catalogue partagé · étudiants actifs', 'Intégration', Tone.warning),
  ];
  final networkKpis = const <Kpi>[
    Kpi('Établissements', '5', delta: '+ 2'),
    Kpi('Projets partagés', '312', delta: '+ 2'),
    Kpi('Compétences', '128', delta: '+ 2'),
    Kpi('Défis intercampus', '6', delta: '+ 2'),
  ];

  // 268 · Analytics de la borne
  final kioskKpis = const <Kpi>[
    Kpi('Sessions', '1 820', delta: '+ 14 %'),
    Kpi('Scans QR', '642', delta: '+ 9 %'),
    Kpi('Paniers transférés', '318', delta: '+ 11 %'),
    Kpi('Conversions', '96', delta: '+ 6 %'),
  ];
  final sessionsPerDay = const <double>[
    .2, .6, .7, .4, .4, .7, .6, .2, .6, .7, .4, .4, .7, .6, .2, .6, .7, .4, .45, .7, .6,
    .3, .82, .9, .58, .64, .92, .78, .4, .82,
  ];
  final topKioskProducts = const <(String, String)>[
    ('Lampe en bois recyclé', '312'),
    ('Jus de bissap', '268'),
    ('Kit solaire', '201'),
  ];
  final kioskFleet = const <(String, String, String, String, String)>[
    ('BORNE-001', 'IUT Douala · Hall A', 'il y a 2 min', '1.8.2', 'En ligne'),
    ('BORNE-002', 'IUT Douala · Bibliothèque', 'il y a 6 min', '1.8.2', 'En ligne'),
  ];

  // 269 · Innovation Radar
  final skillDemand = const <Skill>[
    Skill('Développement web', '92 %', .92),
    Skill('Énergies renouvelables', '84 %', .84),
    Skill('Design et identité visuelle', '76 %', .76),
    Skill('IoT et électronique', '71 %', .71),
    Skill('Logistique', '58 %', .58),
    Skill('Agro-transformation', '49 %', .49),
  ];
  final marketNeeds = const <(String, String)>[
    ('Application de suivi', '23'),
    ('Borne solaire', '11'),
    ('Charte graphique', '9'),
  ];
  final quarterTrend =
      'Les demandes en énergies renouvelables progressent de 22 % : renforcer l’offre du département ENR.';
}
