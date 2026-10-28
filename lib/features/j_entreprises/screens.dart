import '../../core/router/screen_entry.dart';
import 's88_espace_entreprise/espace_entreprise_screen.dart';
import 's89_profil_entreprise/profil_entreprise_screen.dart';
import 's90_publier_besoin/publier_besoin_screen.dart';
import 's91_rechercher_talents/rechercher_talents_screen.dart';
import 's93_propositions_recues/propositions_recues_screen.dart';
import 's93b_proposition/proposition_screen.dart';
import 's94_comparer_propositions/comparer_propositions_screen.dart';
import 's95_devis_negociations/devis_negociations_screen.dart';
import 's95b_demande_devis/demande_devis_screen.dart';
import 's96_defis_innovation/defis_innovation_screen.dart';
import 's97_recrutement/recrutement_screen.dart';
import 's98_collaborations/collaborations_screen.dart';
import 's99_historique/historique_screen.dart';

const _s = 'J';

/// Section J · Entreprises et B2B (88–99).
final sectionJScreens = <ScreenEntry>[
  ScreenEntry('88', 'Espace entreprise', (_) => const EspaceEntrepriseScreen(), section: _s, node: '39:332'),
  ScreenEntry('89', 'Profil de l’entreprise', (_) => const ProfilEntrepriseScreen(), section: _s, node: '54:366'),
  ScreenEntry('90', 'Publier un besoin', (_) => const PublierBesoinScreen(), section: _s, node: '39:524'),
  ScreenEntry('91', 'Rechercher des talents', (_) => const RechercherTalentsScreen(), section: _s, node: '39:601'),
  ScreenEntry('93', 'Propositions reçues', (_) => const PropositionsRecuesScreen(), section: _s, node: '39:756'),
  ScreenEntry('93b', 'Proposition', (_) => const PropositionScreen(), section: _s, node: '39:816'),
  ScreenEntry('94', 'Comparer les propositions', (_) => const ComparerPropositionsScreen(), section: _s, node: '54:1288'),
  ScreenEntry('95', 'Devis et négociations', (_) => const DevisNegociationsScreen(), section: _s, node: '39:926'),
  ScreenEntry('95b', 'Demande de devis', (_) => const DemandeDevisScreen(), section: _s, node: '39:872'),
  ScreenEntry('96', 'Défis d’innovation', (_) => const DefisInnovationScreen(), section: _s, node: '39:1005'),
  ScreenEntry('97', 'Recrutement', (_) => const RecrutementScreen(), section: _s, node: '39:1085'),
  ScreenEntry('98', 'Collaborations', (_) => const CollaborationsScreen(), section: _s, node: '39:1172'),
  ScreenEntry('99', 'Historique', (_) => const HistoriqueScreen(), section: _s, node: '54:1352'),
];
