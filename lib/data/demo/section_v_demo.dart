import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';

/// Contenu d'un écran d'accueil par rôle (175–178).
typedef VOnboardingData = ({
  String welcome,
  String image,
  String bannerTitle,
  String bannerSubtitle,
  int dot,
  int dots,
  String heading,
  String description,
  List<(String, String, String)> features,
  String primary,
  String primaryTarget,
});

/// Données de démonstration — section V « Onboarding, guide, rôles » (175–181).
class SectionVData {
  const SectionVData();

  final VOnboardingData student = const (
    welcome: 'Bienvenue, étudiant',
    image: 'assets/images/v_diplomes.jpg',
    bannerTitle: 'Vendez vos créations',
    bannerSubtitle: 'Produits, services et projets de l’IUT',
    dot: 0,
    dots: 1,
    heading: 'Exposez vos talents',
    description: 'Publiez vos annonces, montez un portfolio et recevez des propositions d’entreprises.',
    features: [
      (AppIcons.tag, 'Vendre produits et services', '58'),
      (AppIcons.layers, 'Construire un portfolio', '74'),
      (AppIcons.trophy, 'Participer aux hackathons', '160'),
    ],
    primary: 'Continuer',
    primaryTarget: '57',
  );

  final VOnboardingData buyer = const (
    welcome: 'Bienvenue',
    image: 'assets/images/v_etudiante.jpg',
    bannerTitle: 'Achetez local et étudiant',
    bannerSubtitle: 'Des créations uniques de l’IUT de Douala',
    dot: 1,
    dots: 3,
    heading: 'Trouvez ce qui vous inspire',
    description: 'Parcourez les produits, commandez en toute confiance et retirez au kiosque près de vous.',
    features: [
      (AppIcons.shoppingCart, 'Commander facilement', '22'),
      (AppIcons.shieldCheck, 'Payer en sécurité', '171'),
      (AppIcons.package, 'Retirer au kiosque', '206'),
    ],
    primary: 'Continuer',
    primaryTarget: '03',
  );

  final VOnboardingData company = const (
    welcome: 'Bienvenue, entreprise',
    image: 'assets/images/t_salle.jpg',
    bannerTitle: 'Recrutez les talents de demain',
    bannerSubtitle: 'Stages, défis et collaborations',
    dot: 2,
    dots: 3,
    heading: 'Trouvez vos futurs talents',
    description: 'Publiez un besoin, recevez des propositions et laissez l’IA classer les meilleurs dossiers.',
    features: [
      (AppIcons.fileText, 'Publier un besoin', '90'),
      (AppIcons.sparkles, 'Propositions classées par IA', '93'),
      (AppIcons.users, 'Collaborer avec des équipes', '98'),
    ],
    primary: 'Continuer',
    primaryTarget: '88',
  );

  final VOnboardingData jury = const (
    welcome: 'Bienvenue, jury',
    image: 'assets/images/v_jury_fond.jpg',
    bannerTitle: 'Évaluez les projets',
    bannerSubtitle: 'Notation claire et transparente',
    dot: 0,
    dots: 1,
    heading: 'Un espace de notation simple',
    description: 'Consultez les projets, notez selon les critères et laissez des commentaires constructifs.',
    features: [
      (AppIcons.layers, 'Projets à examiner', '166'),
      (AppIcons.starFilled, 'Critères de notation', '167'),
      (AppIcons.messageCircle, 'Commentaires au jury', '52'),
    ],
    primary: 'Commencer',
    primaryTarget: '167',
  );

  // 179 · Guide d'utilisation
  final guideTabs = const ['Débuter', 'Acheter', 'Vendre', 'Opportunités'];

  /// (icône, titre, détail, onglet, vidéo, écran cible).
  final guides = const [
    (AppIcons.play, 'Prendre en main Boutik-École', 'Vidéo · 2 min', 'Débuter', true, ''),
    (AppIcons.fileText, 'Créer et publier une annonce', 'Guide pas à pas', 'Vendre', false, '58'),
    (AppIcons.trophy, 'S’inscrire à un hackathon', 'Guide pas à pas', 'Opportunités', false, '162'),
    (AppIcons.circleHelp, 'Compléter mon dossier', 'Checklist guidée', 'Débuter', false, '18b'),
  ];
  final guideImage = 'assets/images/v_guide.jpg';

  // 180 · Rôles et permissions (web)
  /// (icône, rôle, description, nombre de comptes).
  final roles = const [
    (AppIcons.award, 'Jury', 'Note les projets, commente, voit les résultats', 4),
    (AppIcons.trophy, 'Organisateur partenaire', 'Publie des concours, gère les inscriptions', 3),
    (AppIcons.briefcase, 'Entreprise', 'Publie des besoins et des offres', 28),
  ];

  /// Règles par rôle : (création, validation, expiration).
  final roleRules = const {
    'Jury': ('Par un administrateur', 'Par l’institution', 'Fin du concours'),
    'Organisateur partenaire': ('Par un administrateur', 'Par l’institution', 'Fin du partenariat'),
    'Entreprise': ('Inscription en ligne', 'Par l’administration', 'Aucune'),
  };

  // 181 · Matrice des permissions (web)
  final matrixRoles = const ['Étudiant', 'Entreprise', 'Jury', 'Organisateur', 'Resp. dép.', 'Admin'];
  final matrix = const [
    ('Publier une annonce', ['Oui', '—', '—', '—', 'Valide', 'Oui']),
    ('Publier un besoin', ['—', 'Oui', '—', '—', '—', 'Oui']),
    ('Publier un concours', ['—', '—', '—', 'Oui', 'Valide', 'Oui']),
    ('Noter un projet', ['—', '—', 'Oui', '—', '—', 'Oui']),
    ('Valider une annonce', ['—', '—', '—', '—', 'Oui', 'Oui']),
    ('Voir les finances', ['—', '—', '—', '—', '—', 'Oui']),
  ];
}

final sectionVDataProvider = Provider<SectionVData>((_) => const SectionVData());
