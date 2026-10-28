import '../../core/router/screen_entry.dart';
import 's50_notifications/notifications_screen.dart';
import 's51_detail_notification/detail_notification_screen.dart';
import 's52_messages/messages_screen.dart';
import 's53_conversation/conversation_screen.dart';
import 's54_conversation_commande/conversation_commande_screen.dart';
import 's55_conversation_entreprise/conversation_entreprise_screen.dart';
import 's56_notifications_confidentialite/notifications_confidentialite_screen.dart';

const _s = 'F';

/// Section F · Communication et notifications (50–56).
final sectionFScreens = <ScreenEntry>[
  ScreenEntry('50', 'Notifications', (_) => const NotificationsScreen(), section: _s, node: '36:464'),
  ScreenEntry('51', 'Détail d’une notification', (_) => const DetailNotificationScreen(), section: _s, node: '36:574'),
  ScreenEntry('52', 'Messages', (_) => const MessagesScreen(), section: _s, node: '36:635'),
  ScreenEntry('53', 'Conversation', (_) => const ConversationScreen(), section: _s, node: '36:709'),
  ScreenEntry('54', 'Conversation commande', (_) => const ConversationCommandeScreen(), section: _s, node: '54:1062'),
  ScreenEntry(
    '55',
    'Conversation entreprise',
    (_) => const ConversationEntrepriseScreen(),
    section: _s,
    node: '54:1099',
  ),
  ScreenEntry(
    '56',
    'Notifications et confidentialité',
    (_) => const NotificationsConfidentialiteScreen(),
    section: _s,
    node: '40:802',
  ),
];
