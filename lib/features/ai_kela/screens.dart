import '../../core/router/screen_entry.dart';
import 's230_assistante_vocale/assistante_vocale_screen.dart';
import 's231_accueil_kela/accueil_kela_screen.dart';
import 's232_voix_en_texte/voix_en_texte_screen.dart';
import 's233_whatsapp_suivi/whatsapp_suivi_screen.dart';
import 's234_whatsapp_jalon/whatsapp_jalon_screen.dart';
import 's235_whatsapp_paiement/whatsapp_paiement_screen.dart';
import 's236_canaux_notifications/canaux_notifications_screen.dart';

const _s = 'AI';

/// Section AI · Kéla et WhatsApp (230–236).
final sectionAIScreens = <ScreenEntry>[
  ScreenEntry('230', 'Assistante vocale Kéla', (_) => const AssistanteVocaleScreen(), section: _s, node: '106:89'),
  ScreenEntry('231', 'Accueil Kéla', (_) => const AccueilKelaScreen(), section: _s, node: '106:134'),
  ScreenEntry('232', 'Voix en texte', (_) => const VoixEnTexteScreen(), section: _s, node: '106:227'),
  ScreenEntry('233', 'WhatsApp · suivi de mission', (_) => const WhatsappSuiviScreen(), section: _s, node: '87:1296'),
  ScreenEntry(
    '234',
    'WhatsApp · validation de jalon',
    (_) => const WhatsappJalonScreen(),
    section: _s,
    node: '87:1341',
  ),
  ScreenEntry(
    '235',
    'WhatsApp · paiement sécurisé',
    (_) => const WhatsappPaiementScreen(),
    section: _s,
    node: '87:1385',
  ),
  ScreenEntry('236', 'Canaux et notifications', (_) => const CanauxNotificationsScreen(), section: _s, node: '87:1432'),
];
