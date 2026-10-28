import '../models/models.dart';
import 'catalog_demo.dart';

/// Article du panier.
class CartLine {
  const CartLine(this.title, this.department, this.price, this.image, {this.qty = 1});

  final String title;
  final String department;
  final int price;
  final String image;
  final int qty;

  CartLine withQty(int q) => CartLine(title, department, price, image, qty: q);
}

/// Carte du catalogue « Explorer » (04) : la pastille de type est sous la photo.
class ExploreItem {
  const ExploreItem(this.title, this.kind, this.price, this.department, this.image, {this.favorite = false});

  final String title;
  final String kind;
  final String? price;
  final String department;
  final String image;
  final bool favorite;
}

/// Données de démonstration de la section A (01–10). Chiffres fictifs repris des maquettes.
class SectionAData {
  const SectionAData();

  // 01 / 02 · Accueil de bienvenue
  final onboardingTitle = 'Des talents étudiants,\ndes créations uniques,\nun même espace.';
  final onboardingText =
      'Découvrez, achetez et soutenez les produits, services, compétences, projets et innovations des étudiants de l’IUT de Douala.';

  // 03 · Accueil
  final homeCategories = const [
    ('Tous', 'assets/icons/layout-grid.svg'),
    ('Produits', 'assets/icons/shopping-bag.svg'),
    ('Services', 'assets/icons/briefcase.svg'),
    ('Talents', 'assets/icons/user.svg'),
    ('Projets', 'assets/icons/lightbulb.svg'),
  ];
  final heroBadge = 'À la une';
  final heroTitle = 'L’innovation\nétudiante en action';
  final heroText = 'Des projets qui transforment demain.';
  final featured = const [
    Product(id: 'f1', title: 'Lampe en bois recyclé', price: 25000, seller: 'Ngoné M.', department: 'Génie civil', image: Photos.lamp),
    Product(id: 'f2', title: 'Drone éducatif', price: 150000, seller: 'Team Innov’', department: 'Génie électrique', image: Photos.bulb),
  ];
  final talents = const [
    ('Mariam Essono', 'Développement web', Photos.coder),
    ('Brice Ndoumbe', 'IoT et énergie', Photos.solar),
    ('Aminata Bello', 'Identité visuelle', Photos.studentHijab),
  ];

  // 04 · Explorer
  final exploreFilters = const ['Tous', 'Produits', 'Services', 'Talents', 'Projets'];
  final explore = const [
    ExploreItem('Pots connectés pour l’agriculture urbaine', 'Produit', '15 000 FCFA', 'Agronomie', Photos.laptopMeeting, favorite: true),
    ExploreItem('Développement web sur mesure', 'Service', 'À partir de 30 000 FCFA', 'Informatique', Photos.plants),
    ExploreItem('Système de filtration d’eau innovant', 'Projet', null, 'Génie chimique', Photos.plantPot, favorite: true),
    ExploreItem('Montage vidéo & création de contenu', 'Talent', 'À partir de 10 000 FCFA', 'Audiovisuel', Photos.phoneStand),
  ];

  // 05 · Fiche produit
  final product = const (
    title: 'Lampe en bois recyclé',
    price: 25000,
    rating: '4.8',
    reviews: 24,
    description:
        'Lampe décorative fabriquée à partir de bois recyclé. Écologique, design et idéale pour un intérieur moderne.',
    creator: 'Mouanga Yannick',
    department: 'Génie civil',
  );
  final productFeatures = const [
    ('Matériaux recyclés', 'assets/icons/leaf.svg'),
    ('Fait main', 'assets/icons/hammer.svg'),
    ('Éclairage LED', 'assets/icons/lightbulb.svg'),
  ];

  // 06 · Panier
  final cart = const [
    CartLine('Ordinateur portable prototype', 'Informatique', 250000, Photos.paint),
    CartLine('Lampe en bois recyclé', 'Génie civil', 25000, Photos.paintRed),
    CartLine('Logo et identité visuelle', 'MMI', 50000, Photos.branding),
  ];
  final deliveryFee = 5000;

  // 07 · Livraison
  final deliveryAddress = 'Douala, Cameroun';
  final deliveryDelay = '2 à 5 jours ouvrés';

  // 08 · Paiement
  final orangeAccount = 'Compte IUT DFI';

  // 09 · Ma commande
  final orderId = '#BE-2025-0018';
  final orderDate = '12 avril 2025 • 14h32';
  final orderSteps = const ['Confirmée', 'En préparation', 'Expédiée', 'Livrée'];
  final orderCurrentStep = 1;
  final pickupAddress = 'IUT de Douala – Bâtiment principal\nService de la vie étudiante';

  // 10 · Profil étudiant
  final student = const (
    name: 'Mariam Essono',
    school: 'Génie informatique · IUT de Douala',
    tags: '#Python  #React  #Mobile',
    bio: 'Étudiante en informatique, je crée des applications web et mobiles pour des clients locaux.',
    counters: ['12 Produits', '3 Services', '5 Projets'],
    passport: 'Talent Passport · Confirmé · 3 badges',
  );
  final studentGallery = const [Photos.coder, Photos.solar, Photos.builder];
}

extension Totals on List<CartLine> {
  int get subtotal => fold(0, (s, l) => s + l.price * l.qty);
  int get count => fold(0, (s, l) => s + l.qty);
}
