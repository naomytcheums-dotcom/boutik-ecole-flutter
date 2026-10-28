import '../../core/router/screen_entry.dart';
import 's11_connexion/connexion_screen.dart';
import 's12_creer_compte/creer_compte_screen.dart';
import 's13_choix_profil/choix_profil_screen.dart';
import 's14_verification/verification_screen.dart';
import 's15_mot_de_passe_oublie/mot_de_passe_oublie_screen.dart';
import 's16_nouveau_mot_de_passe/nouveau_mot_de_passe_screen.dart';
import 's17_conditions_confidentialite/conditions_confidentialite_screen.dart';
import 's18_etat_validation/etat_validation_screen.dart';
import 's18b_completer_profil/completer_profil_screen.dart';
import 's18c_verification_etudiant/verification_etudiant_screen.dart';
import 's19_decouvrir/decouvrir_screen.dart';
import 's20_resultats_recherche/resultats_recherche_screen.dart';

const _s = 'B';

/// Section B · Authentification (11–20).
final sectionBScreens = <ScreenEntry>[
  ScreenEntry('11', 'Connexion', (_) => const ConnexionScreen(), section: _s, node: '20:2'),
  ScreenEntry('12', 'Créer un compte', (_) => const CreerCompteScreen(), section: _s, node: '20:50'),
  ScreenEntry('13', 'Choix du profil', (_) => const ChoixProfilScreen(), section: _s, node: '22:2'),
  ScreenEntry('14', 'Vérification du compte', (_) => const VerificationScreen(), section: _s, node: '20:173'),
  ScreenEntry('15', 'Mot de passe oublié', (_) => const MotDePasseOublieScreen(), section: _s, node: '20:217'),
  ScreenEntry('16', 'Nouveau mot de passe', (_) => const NouveauMotDePasseScreen(), section: _s, node: '22:61'),
  ScreenEntry('17', 'Conditions et confidentialité', (_) => const ConditionsConfidentialiteScreen(), section: _s, node: '34:3'),
  ScreenEntry('18', 'État de validation', (_) => const EtatValidationScreen(), section: _s, node: '22:276'),
  ScreenEntry('18b', 'Compléter mon profil', (_) => const CompleterProfilScreen(), section: _s, node: '22:123'),
  ScreenEntry('18c', 'Vérification étudiant', (_) => const VerificationEtudiantScreen(), section: _s, node: '22:200'),
  ScreenEntry('19', 'Découvrir', (_) => const DecouvrirScreen(), section: _s, node: '29:2'),
  ScreenEntry('20', 'Résultats de recherche', (_) => const ResultatsRechercheScreen(), section: _s, node: '29:91'),
];
