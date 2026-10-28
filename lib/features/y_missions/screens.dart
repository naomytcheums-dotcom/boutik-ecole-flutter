import '../../core/router/screen_entry.dart';
import 's191_votre_besoin/votre_besoin_screen.dart';
import 's192_votre_devis/votre_devis_screen.dart';
import 's193_paiement_securise/paiement_securise_screen.dart';
import 's194_ma_mission/ma_mission_screen.dart';
import 's195_ajouter_preuve/ajouter_preuve_screen.dart';
import 's196_dossier/dossier_screen.dart';
import 's197_valider_jalon/valider_jalon_screen.dart';
import 's198_briefs_recus/briefs_recus_screen.dart';
import 's199_attribuer/attribuer_screen.dart';
import 's200_missions_encaissement/missions_encaissement_screen.dart';
import 's201_mes_missions/mes_missions_screen.dart';
import 's202_pack_lancement/pack_lancement_screen.dart';
import 's203_mes_competences/mes_competences_screen.dart';
import 's204_coup_de_pouce/coup_de_pouce_screen.dart';
import 's205_soumettre_projet/soumettre_projet_screen.dart';

const _s = 'Y';
const _web = ScreenFormat.web;

/// Section Y · Missions sur mesure (191–205).
final sectionYScreens = <ScreenEntry>[
  ScreenEntry('191', 'Votre besoin', (_) => const VotreBesoinScreen(), section: _s, node: '83:2'),
  ScreenEntry('192', 'Votre devis', (_) => const VotreDevisScreen(), section: _s, node: '83:86'),
  ScreenEntry('193', 'Paiement sécurisé', (_) => const PaiementSecuriseScreen(), section: _s, node: '83:154'),
  ScreenEntry('194', 'Ma mission', (_) => const MaMissionScreen(), section: _s, node: '83:220'),
  ScreenEntry('195', 'Ajouter une preuve', (_) => const AjouterPreuveScreen(), section: _s, node: '83:290'),
  ScreenEntry('196', 'Dossier', (_) => const DossierScreen(), section: _s, node: '83:352'),
  ScreenEntry('197', 'Valider le jalon', (_) => const ValiderJalonScreen(), section: _s, node: '83:411'),
  ScreenEntry('198', 'Briefs reçus', (_) => const BriefsRecusScreen(), section: _s, node: '83:1173', format: _web),
  ScreenEntry('199', 'Attribuer', (_) => const AttribuerScreen(), section: _s, node: '83:1295', format: _web),
  ScreenEntry(
    '200',
    'Missions et encaissement',
    (_) => const MissionsEncaissementScreen(),
    section: _s,
    node: '83:1432',
    format: _web,
  ),
  ScreenEntry('201', 'Mes missions', (_) => const MesMissionsScreen(), section: _s, node: '83:461'),
  ScreenEntry('202', 'Pack Lancement de marque', (_) => const PackLancementScreen(), section: _s, node: '83:533'),
  ScreenEntry('203', 'Mes compétences', (_) => const MesCompetencesScreen(), section: _s, node: '83:609'),
  ScreenEntry('204', 'Coup de pouce startup', (_) => const CoupDePouceScreen(), section: _s, node: '83:703'),
  ScreenEntry('205', 'Soumettre mon projet', (_) => const SoumettreProjetScreen(), section: _s, node: '83:779'),
];
