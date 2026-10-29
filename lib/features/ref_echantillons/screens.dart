import '../../core/router/screen_entry.dart';
import 'sa1_kela_ecoute/kela_ecoute_screen.dart';
import 'sa2_accueil_kela/accueil_kela_screen.dart';
import 'sa3_voix_texte/voix_texte_screen.dart';
import 'sp1_profil_talent/profil_talent_screen.dart';
import 'sp2_profil_abonnement/profil_abonnement_screen.dart';
import 'sp3_avis_outils/avis_outils_screen.dart';
import 'sp4_nouvelle_publication/nouvelle_publication_screen.dart';
import 'sv1_vitrine/vitrine_screen.dart';
import 'sp5_connecter_outils/connecter_outils_screen.dart';
import 'sl1_aller_direct/aller_direct_screen.dart';
import 'ss1_splash/splash_screen.dart';
import 'sd1_tableau_studio/tableau_studio_screen.dart';

const _s = 'REF';

/// Section REF · Échantillons de référence (Kéla, profils, vitrine, splash, tableau de bord).
final sectionREFScreens = <ScreenEntry>[
  ScreenEntry('A1', 'Assistante vocale Kéla', (_) => const KelaEcouteScreen(), section: _s, node: '94:2'),
  ScreenEntry('A2', 'Accueil Kéla', (_) => const AccueilKelaScreen(), section: _s, node: '94:50'),
  ScreenEntry('A3', 'Voix en texte', (_) => const VoixTexteScreen(), section: _s, node: '94:145'),
  ScreenEntry('P1', 'Profil talent', (_) => const ProfilTalentScreen(), section: _s, node: '94:210'),
  ScreenEntry('P2', 'Profil talent · abonnement', (_) => const ProfilAbonnementScreen(), section: _s, node: '94:272'),
  ScreenEntry('P3', 'Avis et outils connectés', (_) => const AvisOutilsScreen(), section: _s, node: '94:365'),
  ScreenEntry('P4', 'Nouvelle publication', (_) => const NouvellePublicationScreen(), section: _s, node: '94:506'),
  ScreenEntry('V1', 'Vitrine', (_) => const VitrineScreen(), section: _s, node: '94:583'),
  ScreenEntry('P5', 'Connecter mes outils', (_) => const ConnecterOutilsScreen(), section: _s, node: '101:25'),
  ScreenEntry('L1', 'Aller en direct', (_) => const AllerDirectScreen(), section: _s, node: '101:223'),
  ScreenEntry('S1', 'Démarrage animé', (_) => const SplashScreen(), section: _s, node: '161:16'),
  ScreenEntry(
    'D1',
    'Tableau de bord du studio',
    (_) => const TableauStudioScreen(),
    section: _s,
    node: '94:745',
    format: ScreenFormat.web,
  ),
];
