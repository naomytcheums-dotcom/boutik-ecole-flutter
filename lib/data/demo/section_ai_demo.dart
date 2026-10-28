import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';

/// Type de message des conversations Kéla et WhatsApp.
enum AiMsgKind {
  /// Message reçu (Kéla ou compte Boutik-École).
  incoming,

  /// Message envoyé par l'utilisateur.
  outgoing,

  /// Note vocale envoyée (durée dans `text`).
  voice,

  /// Image envoyée (aperçu).
  image,

  /// Photo de preuve reçue (chemin d'image dans `text`).
  proof,

  /// Séparateur de date (« Aujourd'hui »).
  day,

  /// Boutons de réponse rapide (libellés séparés par « | »).
  actions,

  /// Carte de jalon à valider (écran 234).
  milestone,

  /// Carte de paiement sécurisé (écran 235).
  payment,
}

/// Message de démonstration : type, texte (ou durée / image), heure.
typedef AiMessage = ({AiMsgKind kind, String text, String time});

/// Canal de suivi des missions (écran 236).
typedef AiChannel = ({String title, String detail, String icon, bool enabled, bool locked, bool whatsapp});

/// Données fictives de la section AI · Kéla et WhatsApp (230–236).
class SectionAIData {
  const SectionAIData();

  // 230 · Assistante vocale
  final assistantName = 'Kéla';
  final spokenAlready = 'Peux-tu m’aider à créer un logo et une affiche';
  final spokenNow = 'pour mon parfum, avant fin novembre ?';

  // 231 · Accueil Kéla
  final firstName = 'Mariam';
  final themes = const ['Missions', 'Design', 'Vidéo', 'Commerce'];
  final matchingTalents = 2;
  final matchingDepartment = 'MMI';
  final briefSubject = 'parfum';

  // 232 · Voix en texte
  final voiceBudget = 200000;
  List<AiMessage> get voiceChat => [
    (kind: AiMsgKind.voice, text: '1:33', time: '16:43'),
    (
      kind: AiMsgKind.incoming,
      text: 'Décris-moi ton parfum : cible, style et budget. Je prépare le brief et je contacte les étudiants de MMI et de TCO.',
      time: '16:43',
    ),
    (kind: AiMsgKind.image, text: '', time: '16:44'),
    (kind: AiMsgKind.outgoing, text: 'Crée la mission pour moi', time: '16:44'),
    (
      kind: AiMsgKind.incoming,
      text:
          'Compris ! Je lance ton brief : logo + affiche, budget d’environ ${fcfa(voiceBudget)}. Veux-tu aussi une vidéo teaser ?',
      time: '16:44',
    ),
  ];

  // 233 · WhatsApp, suivi de mission
  final clientName = 'Mme Mbella';
  final missionName = 'Identité visuelle';
  final missionProgress = 60;
  final missionStep = 3;
  final missionSteps = 5;
  final proofPhoto = 'assets/images/maquette.jpg';
  List<AiMessage> get followUpChat => [
    (kind: AiMsgKind.day, text: 'Aujourd’hui', time: ''),
    (
      kind: AiMsgKind.incoming,
      text:
          'Bonjour $clientName👋 Votre mission « $missionName » avance bien : $missionProgress\u00A0% (étape $missionStep sur $missionSteps).',
      time: '10:12',
    ),
    (kind: AiMsgKind.incoming, text: 'L’équipe vient de déposer des propositions de logo.', time: '10:12'),
    (kind: AiMsgKind.proof, text: proofPhoto, time: '10:12'),
    (kind: AiMsgKind.incoming, text: 'Que souhaitez-vous faire ?', time: '10:13'),
    (kind: AiMsgKind.actions, text: 'Voir les propositions|Écrire à l’équipe', time: ''),
  ];

  // 234 · WhatsApp, validation de jalon
  final milestoneNumber = 2;
  final milestoneName = 'Propositions de logo';
  final milestoneAmount = 72000;
  final milestonePhoto = 'assets/images/phone.jpg';
  final nextMilestone = 'livraison finale';
  List<AiMessage> get milestoneChat => [
    (
      kind: AiMsgKind.incoming,
      text: 'Le jalon $milestoneNumber « $milestoneName » est terminé. Montant à libérer : ${fcfa(milestoneAmount)}.',
      time: '10:20',
    ),
    (kind: AiMsgKind.milestone, text: milestonePhoto, time: ''),
    (kind: AiMsgKind.actions, text: '✓ Valider et libérer|Demander une correction', time: ''),
    (kind: AiMsgKind.outgoing, text: '✓Valider et libérer', time: '10:21'),
    (
      kind: AiMsgKind.incoming,
      text: 'Merci ! ${fcfa(milestoneAmount)} libérés. Le jalon ${milestoneNumber + 1} ($nextMilestone) démarre.',
      time: '10:21',
    ),
  ];

  // 235 · WhatsApp, paiement sécurisé
  final firstMilestoneAmount = 54000;
  final milestonesCount = 3;
  final receiptUrl = 'boutik-ecole.cm/r/8841';
  List<AiMessage> get paymentChat => [
    (
      kind: AiMsgKind.incoming,
      text: 'Pour démarrer la mission, payez le jalon 1 : ${fcfa(firstMilestoneAmount)} par Orange Money.',
      time: '09:40',
    ),
    (kind: AiMsgKind.payment, text: '', time: ''),
    (kind: AiMsgKind.outgoing, text: 'Paiement effectué ✓', time: '09:42'),
    (
      kind: AiMsgKind.incoming,
      text: 'Merci ! ${fcfa(firstMilestoneAmount)} reçus et bloqués en séquestre. Reçu : $receiptUrl',
      time: '09:42',
    ),
  ];

  // 236 · Canaux et notifications
  final whatsappNumber = '+237 6 XX XX XX XX';
  List<AiChannel> get channels => const [
    (
      title: 'WhatsApp',
      detail: 'Suivi, validation de jalon, paiement',
      icon: 'assets/icons/message-circle.svg',
      enabled: true,
      locked: false,
      whatsapp: true,
    ),
    (
      title: 'SMS',
      detail: 'Alertes importantes',
      icon: 'assets/icons/send.svg',
      enabled: true,
      locked: false,
      whatsapp: false,
    ),
    (
      title: 'Notifications dans l’application',
      detail: 'Toujours actives',
      icon: 'assets/icons/bell.svg',
      enabled: true,
      locked: true,
      whatsapp: false,
    ),
    (
      title: 'E-mail',
      detail: 'Reçus et résumés',
      icon: 'assets/icons/file.svg',
      enabled: false,
      locked: false,
      whatsapp: false,
    ),
  ];
}

final sectionAIDataProvider = Provider<SectionAIData>((_) => const SectionAIData());
