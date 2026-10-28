import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_icons.dart';
import '../../core/utils/money.dart';
import 'catalog_demo.dart';

/// Catégorie d'une notification (pastilles de filtre de l'écran 50).
enum FNotifKind { orders, messages, promotions, account }

/// Notification de la liste (50).
class FNotification {
  const FNotification({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.isNew = false,
    this.today = true,
    this.target,
    this.iconColor,
  });

  final String id;
  final String icon;
  final String title;
  final String subtitle;
  final FNotifKind kind;
  final bool isNew;

  /// Groupe « Aujourd’hui » (sinon « Plus tôt »).
  final bool today;

  /// Écran du manifeste ouvert au toucher.
  final String? target;
  final Color? iconColor;
}

/// Étape du suivi de commande (51).
class FStep {
  const FStep(this.title, this.detail);

  final String title;
  final String detail;
}

/// Message d'une conversation (53–55).
class FMessage {
  const FMessage(this.text, this.time, {this.mine = false});

  final String text;
  final String time;

  /// Message envoyé par l'utilisateur (bulle encre à droite).
  final bool mine;
}

/// Carte de contexte épinglée en haut d'une conversation (article, commande, besoin).
class FContextCard {
  const FContextCard({
    required this.title,
    this.subtitle,
    this.amount,
    this.amountMax,
    this.image,
    this.icon,
    this.badge,
    this.badgeTone = FBadgeTone.accent,
    this.action,
    this.target,
  });

  final String title;
  final String? subtitle;

  /// Montant (ou fourchette avec [amountMax]) affiché après le sous-titre.
  final int? amount;
  final int? amountMax;
  final String? image;
  final String? icon;

  /// Ligne secondaire : « Prête au retrait · 25 000 FCFA », « Budget 300 000 – 500 000 FCFA ».
  String get detail {
    if (amount == null) return subtitle ?? '';
    if (amountMax != null) {
      final range = '${fcfa(amount!, withUnit: false)} – ${fcfa(amountMax!)}';
      return subtitle == null ? range : '$subtitle $range';
    }
    return subtitle == null ? fcfa(amount!) : '$subtitle · ${fcfa(amount!)}';
  }

  /// Pastille à droite (« Voir », « Ouvert »).
  final String? badge;
  final FBadgeTone badgeTone;

  /// Lien texte à droite (« Voir » en gras).
  final String? action;
  final String? target;
}

enum FBadgeTone { accent, success }

/// Conversation (liste 52 et fils 53–55).
class FConversation {
  const FConversation({
    required this.id,
    required this.name,
    required this.preview,
    this.avatar,
    this.avatarAlignment = Alignment.center,
    this.status = 'En ligne',
    this.unread = 0,
    this.messages = const [],
    this.card,
    this.composerHint = 'Écrire un message…',
    this.title,
    this.screen,
  });

  final String id;
  final String name;
  final String preview;
  final String? avatar;
  final Alignment avatarAlignment;

  /// Sous-titre de l'en-tête du fil.
  final String status;
  final int unread;
  final List<FMessage> messages;
  final FContextCard? card;
  final String composerHint;

  /// Titre de l'en-tête (par défaut : nom du contact).
  final String? title;

  /// Écran du manifeste dédié à ce fil, s'il existe.
  final String? screen;
}

/// Préférence activable (56).
class FPref {
  const FPref(this.title, this.subtitle, this.enabled);

  final String title;
  final String subtitle;
  final bool enabled;
}

/// Données de démonstration de la section F (50–56). Chiffres et noms fictifs repris des maquettes.
class SectionFData {
  const SectionFData();

  // 50 · Notifications
  final notifFilters = const ['Toutes', 'Commandes', 'Messages', 'Promotions'];
  final notifications = const [
    FNotification(
      id: 'n1',
      icon: AppIcons.truck,
      title: 'Commande expédiée',
      subtitle: '#BE-2026-0142 est en route · 10:24',
      kind: FNotifKind.orders,
      isNew: true,
      target: '51',
    ),
    FNotification(
      id: 'n2',
      icon: AppIcons.messageCircle,
      title: 'Nouveau message de Yannick',
      subtitle: 'La lampe est prête pour le retrait',
      kind: FNotifKind.messages,
      isNew: true,
      target: '53',
    ),
    FNotification(
      id: 'n3',
      icon: AppIcons.tag,
      title: 'Nouveauté dans vos favoris',
      subtitle: 'Support téléphone en bois · 08:40',
      kind: FNotifKind.promotions,
      target: '32',
    ),
    FNotification(
      id: 'n4',
      icon: AppIcons.starFilled,
      title: 'Laissez un avis',
      subtitle: 'Comment s’est passée votre commande ?',
      kind: FNotifKind.orders,
      today: false,
      target: '45',
      iconColor: Color(0xFF2F5D8A),
    ),
    FNotification(
      id: 'n5',
      icon: AppIcons.info,
      title: 'Événement : exposition',
      subtitle: 'Samedi 24 oct. · Hall principal',
      kind: FNotifKind.promotions,
      today: false,
      target: '100',
    ),
    FNotification(
      id: 'n6',
      icon: AppIcons.shieldCheck,
      title: 'Compte vérifié',
      subtitle: 'Votre compte est désormais actif',
      kind: FNotifKind.account,
      today: false,
      target: '57',
    ),
  ];

  // 51 · Détail d'une notification (commande expédiée)
  final shippedTitle = 'Commande expédiée';
  final shippedWhen = 'Aujourd’hui · 10:24';
  final shippedText =
      'Votre commande #BE-2026-0142 a quitté l’atelier du vendeur. Elle sera disponible au point de retrait du '
      'Bloc A d’ici demain, 14 h.';
  final shippedSteps = const [
    FStep('Confirmée', '22 oct. · 08:10'),
    FStep('Préparée', '22 oct. · 09:40'),
    FStep('Expédiée', '23 oct. · 10:24'),
    FStep('Prête au retrait', '24 oct. · 14:00'),
  ];
  final shippedCurrentStep = 2;
  final orderRef = '#BE-2026-0142';
  final pickupPoint = 'Kiosque IUT – Bloc A';
  final orderAmount = 330000;

  // 52 · Messages
  final conversations = const [
    FConversation(
      id: 'yannick',
      name: 'Mouanga Yannick',
      preview: 'La lampe est prête pour le retrait',
      avatar: 'assets/images/f_avatar_yannick.jpg',
      unread: 2,
      screen: '53',
    ),
    FConversation(
      id: 'mariam',
      name: 'Mariam Essono',
      preview: 'Je vous envoie la maquette ce soir',
      avatar: 'assets/images/f_avatar_mariam.jpg',
      unread: 1,
      messages: [FMessage('Je vous envoie la maquette ce soir', '09:58')],
    ),
    FConversation(
      id: 'support',
      name: 'Support Boutik-École',
      preview: 'Votre demande a bien été reçue',
      avatar: 'assets/images/f_avatar_support.jpg',
      status: 'Répond sous 24 h',
      messages: [FMessage('Votre demande a bien été reçue', 'Hier')],
    ),
    FConversation(
      id: 'aminata',
      name: 'Aminata Bello',
      preview: 'Merci pour votre commande !',
      avatar: Photos.studentHijab,
      avatarAlignment: Alignment(0, -0.55),
      messages: [FMessage('Merci pour votre commande !', 'Lun.')],
    ),
    FConversation(
      id: 'brice',
      name: 'Brice Ndoumbe',
      preview: 'Le drone est disponible en 3 jours',
      avatar: 'assets/images/f_avatar_brice.jpg',
      messages: [FMessage('Le drone est disponible en 3 jours', '20 oct.')],
    ),
  ];

  // 53 · Conversation avec un vendeur (à propos d'un article)
  final productChat = const FConversation(
    id: 'yannick',
    name: 'Mouanga Yannick',
    preview: 'La lampe est prête pour le retrait',
    avatar: 'assets/images/f_avatar_yannick.jpg',
    card: FContextCard(
      title: 'Lampe en bois recyclé',
      amount: 25000,
      image: Photos.drone,
      action: 'Voir',
      target: '32',
    ),
    messages: [
      FMessage('Bonjour ! Votre lampe est prête, vous pouvez venir la retirer demain.', '10:12'),
      FMessage('Parfait, merci. Je passe à 14 h au Bloc A.', '10:14', mine: true),
      FMessage('Très bien, je l’emballe avec soin. À demain !', '10:15'),
    ],
  );

  // 54 · Conversation liée à une commande
  final orderChat = const FConversation(
    id: 'order-0142',
    name: 'Mouanga Yannick',
    title: 'Commande #BE-2026-0142',
    status: 'Mouanga Yannick · En ligne',
    preview: 'Merci ! Je passe cet après-midi.',
    card: FContextCard(
      title: 'Lampe en bois recyclé',
      subtitle: 'Prête au retrait',
      amount: 25000,
      image: Photos.bulb,
      badge: 'Voir',
      target: '46',
    ),
    messages: [
      FMessage('Votre commande est prête, vous pouvez la retirer au Bloc A.', '10:12'),
      FMessage('Merci ! Je passe cet après-midi.', '10:14', mine: true),
    ],
  );

  // 55 · Conversation avec une entreprise (besoin B2B)
  final companyChat = const FConversation(
    id: 'orange',
    name: 'Orange Cameroun',
    status: 'Partenaire vérifié · Répond sous 24 h',
    preview: 'Parfait, nous planifions un entretien jeudi.',
    composerHint: 'Répondre à l’entreprise…',
    card: FContextCard(
      title: 'Besoin : application de suivi des livraisons',
      subtitle: 'Budget',
      amount: 300000,
      amountMax: 500000,
      icon: AppIcons.briefcase,
      badge: 'Ouvert',
      badgeTone: FBadgeTone.success,
    ),
    messages: [
      FMessage('Bonjour Mariam, votre proposition nous intéresse. Pouvez-vous présenter votre portfolio ?', '09:30'),
      FMessage('Bonjour, voici mon portfolio et deux références.', '09:42', mine: true),
      FMessage('Parfait, nous planifions un entretien jeudi.', '10:05'),
    ],
  );

  // 56 · Notifications et confidentialité
  final notificationPrefs = const [
    FPref('Suivi des commandes', 'Expédition, retrait, livraison', true),
    FPref('Messages', 'Nouveaux messages reçus', true),
    FPref('Promotions et événements', 'Offres et actualités de l’IUT', false),
    FPref('Avis et évaluations', 'Rappels après réception', true),
  ];
  final privacyPrefs = const [
    FPref('Profil public', 'Visible par les entreprises', true),
    FPref('Afficher mon établissement', 'Sur mon profil', true),
    FPref('Statistiques anonymes', 'Améliorer l’application', false),
  ];
  final dataExportDelay = 'Vous recevrez l’archive de vos données par e-mail sous 48 h.';
}

final sectionFDataProvider = Provider<SectionFData>((_) => const SectionFData());
