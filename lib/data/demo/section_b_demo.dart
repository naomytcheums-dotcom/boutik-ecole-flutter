import 'catalog_demo.dart';

/// Résultat de recherche (écran 20).
class SearchResult {
  const SearchResult(this.title, this.price, this.category, this.image, {this.favorite = false});

  final String title;
  final int price;
  final String category;
  final String image;
  final bool favorite;
}

/// Données de démonstration de la section B (authentification, 11–20).
class SectionBData {
  const SectionBData();

  final otpTarget = '+237 6•• •• •• 42';
  final otpResend = '00:45';

  final roles = const [
    ('Client', 'Achetez des produits et services proposés par les étudiants.', 'assets/icons/shopping-bag.svg'),
    ('Étudiant vendeur', 'Publiez vos produits, services et projets sur la marketplace.', 'assets/icons/graduation-cap.svg'),
    ('Entreprise', 'Découvrez des talents et lancez des collaborations.', 'assets/icons/briefcase.svg'),
    ('Autre rôle autorisé', 'Enseignant, partenaire ou administration de l’IUT.', 'assets/icons/users.svg'),
  ];

  final termsTabs = const ['Conditions', 'Confidentialité', 'Consentements'];
  final terms = const [
    (
      '1. Utilisation de la plateforme',
      'Boutik-École est la marketplace de l’expertise et des productions de l’IUT de Douala. En créant un compte, vous vous engagez à publier des informations exactes et à respecter les règles de la communauté étudiante.',
    ),
    (
      '2. Données personnelles',
      'Vos données servent uniquement au fonctionnement du service : commandes, livraison, validation du compte et communication avec les vendeurs.',
    ),
  ];
  final consents = const [
    ('Notifications de commande', 'Suivi, livraison et réception', true),
    ('Actualités et offres', 'Nouveautés et événements de l’IUT', false),
    ('Statistiques anonymes', 'Aider à améliorer l’application', true),
  ];

  final validationOutcomes = const [
    ('Approuvé', 'Votre compte vendeur est activé.', 'success'),
    ('Refusé', 'Votre demande n’a pas pu être acceptée.', 'error'),
    ('À corriger', 'Des informations sont à compléter.', 'accent'),
  ];

  final institutions = const ['IUT de Douala', 'IUT de Bandjoun', 'IUT de Ngaoundéré'];
  final departments = const [
    'Génie informatique',
    'Génie civil',
    'Génie électrique',
    'MMI',
    'Génie chimique',
    'Agronomie',
    'Audiovisuel',
  ];
  final levels = const ['Licence 1', 'Licence 2', 'Licence 3', 'Master 1', 'Master 2'];
  final studentId = 'IUT-2023-0412';
  final studentCardFile = 'carte_etudiant.jpg • 1,2 Mo';

  final discoverCategories = const [
    ('Produits', 'assets/icons/layout-grid.svg'),
    ('Services', 'assets/icons/briefcase.svg'),
    ('Talents', 'assets/icons/user.svg'),
    ('Projets', 'assets/icons/lightbulb.svg'),
  ];

  final searchQuery = 'design';
  final searchCount = 128;
  final searchResults = const [
    SearchResult('Sac à dos design', 25000, 'Design – MMI', Photos.bagDesign),
    SearchResult('Logo & identité visuelle', 15000, 'Graphisme – TCO', Photos.droneLogo, favorite: true),
    SearchResult('Application mobile', 50000, 'Développement – Info', Photos.drone, favorite: true),
    SearchResult('Tableau décoratif', 18000, 'Arts – Génie civil', Photos.backpacks),
  ];
}
