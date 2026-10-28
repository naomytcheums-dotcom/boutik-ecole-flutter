import '../../core/router/screen_entry.dart';
import 's41_adresse_livraison/adresse_livraison_screen.dart';
import 's42_recapitulatif/recapitulatif_screen.dart';
import 's43_instructions_paiement/instructions_paiement_screen.dart';
import 's44_commande_confirmee/commande_confirmee_screen.dart';
import 's45_mes_commandes/mes_commandes_screen.dart';
import 's46_suivi_livraison/suivi_livraison_screen.dart';
import 's47_annuler_commande/annuler_commande_screen.dart';
import 's48_reclamation/reclamation_screen.dart';
import 's49_aide_support/aide_support_screen.dart';

const _s = 'E';

/// Section E · Commandes, livraison, assistance (41–49).
final sectionEScreens = <ScreenEntry>[
  ScreenEntry('41', 'Adresse de livraison', (_) => const AdresseLivraisonScreen(), section: _s, node: '54:719'),
  ScreenEntry('42', 'Récapitulatif', (_) => const RecapitulatifScreen(), section: _s, node: '36:202'),
  ScreenEntry('43', 'Instructions de paiement', (_) => const InstructionsPaiementScreen(), section: _s, node: '54:788'),
  ScreenEntry('44', 'Commande confirmée', (_) => const CommandeConfirmeeScreen(), section: _s, node: '36:285'),
  ScreenEntry('45', 'Mes commandes', (_) => const MesCommandesScreen(), section: _s, node: '54:841'),
  ScreenEntry('46', 'Suivi de livraison', (_) => const SuiviLivraisonScreen(), section: _s, node: '54:929'),
  ScreenEntry('47', 'Annuler la commande', (_) => const AnnulerCommandeScreen(), section: _s, node: '54:1007'),
  ScreenEntry('48', 'Réclamation', (_) => const ReclamationScreen(), section: _s, node: '36:330'),
  ScreenEntry('49', 'Aide et support', (_) => const AideSupportScreen(), section: _s, node: '36:813'),
];
