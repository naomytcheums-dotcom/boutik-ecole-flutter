import '../../core/router/screen_entry.dart';
import 's240_parrainer/parrainer_screen.dart';
import 's241_contacts/contacts_screen.dart';
import 's242_kit_partage/kit_partage_screen.dart';
import 's243_mes_gains/mes_gains_screen.dart';
import 's244_cercle/cercle_screen.dart';
import 's245_reels/reels_screen.dart';
import 's246_lives/lives_screen.dart';
import 's247_profil_createur/profil_createur_screen.dart';
import 's248_boutique_createur/boutique_createur_screen.dart';
import 's249_creer/creer_screen.dart';
import 's250_nouvelle_publication/nouvelle_publication_am_screen.dart';
import 's251_decouvrir/decouvrir_screen.dart';
import 's252_commentaires/commentaires_screen.dart';
import 's253_defis/defis_screen.dart';
import 's254_activite/activite_screen.dart';

const _s = 'AM';

/// Section AM · Cercle, parrainage, publication (240–254 ; 250b est dans « Nouveaux écrans »).
final sectionAMScreens = <ScreenEntry>[
  ScreenEntry('240', 'Parrainer et gagner', (_) => const ParrainerScreen(), section: _s, node: '125:3'),
  ScreenEntry('241', 'Mes contacts', (_) => const ContactsScreen(), section: _s, node: '125:99'),
  ScreenEntry('242', 'Kit à partager', (_) => const KitPartageScreen(), section: _s, node: '126:2'),
  ScreenEntry('243', 'Mes gains', (_) => const MesGainsScreen(), section: _s, node: '126:72'),
  ScreenEntry('244', 'Cercle', (_) => const CercleScreen(), section: _s, node: '152:17'),
  ScreenEntry(
    '244b',
    'Cercle · publication aimée',
    (_) => const CercleScreen(liked: true),
    section: _s,
    node: '157:16',
  ),
  ScreenEntry('245', 'Reels', (_) => const ReelsScreen(), section: _s, node: '152:125'),
  ScreenEntry('246', 'Lives', (_) => const LivesScreen(), section: _s, node: '152:191'),
  ScreenEntry('247', 'Profil créateur', (_) => const ProfilCreateurScreen(), section: _s, node: '153:16'),
  ScreenEntry('248', 'Boutique du créateur', (_) => const BoutiqueCreateurScreen(), section: _s, node: '153:124'),
  ScreenEntry('249', 'Créer', (_) => const CreerScreen(), section: _s, node: '153:205'),
  ScreenEntry('250', 'Nouvelle publication', (_) => const NouvellePublicationAmScreen(), section: _s, node: '154:16'),
  ScreenEntry('251', 'Découvrir', (_) => const DecouvrirScreen(), section: _s, node: '154:96'),
  ScreenEntry('252', 'Commentaires et avis', (_) => const CommentairesScreen(), section: _s, node: '154:171'),
  ScreenEntry('253', 'Défis et récompenses', (_) => const DefisScreen(), section: _s, node: '156:16'),
  ScreenEntry(
    '253b',
    'Défis · récompense récupérée',
    (_) => const DefisScreen(claimed: true),
    section: _s,
    node: '157:124',
  ),
  ScreenEntry('254', 'Activité', (_) => const ActiviteScreen(), section: _s, node: '156:130'),
];
