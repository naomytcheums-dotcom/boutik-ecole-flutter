import '../../core/router/screen_entry.dart';
import 's100_evenements/evenements_screen.dart';
import 's101_evenement/evenement_screen.dart';
import 's102_vitrine/vitrine_screen.dart';
import 's103_communaute/communaute_screen.dart';
import 's104_carte_innovation/carte_innovation_screen.dart';
import 's105_inter_etablissements/inter_etablissements_screen.dart';
import 's106_economie_circulaire/economie_circulaire_screen.dart';
import 's107_mon_impact/mon_impact_screen.dart';
import 's237_impact_territoire/impact_territoire_screen.dart';
import 's238_impact_global/impact_global_screen.dart';
import 's239_rapport_sponsors/rapport_sponsors_screen.dart';

const _s = 'K';

/// Section K · Événements, communautés, impact (100–107, 237–239).
final sectionKScreens = <ScreenEntry>[
  ScreenEntry('100', 'Événements', (_) => const EvenementsScreen(), section: _s, node: '40:2'),
  ScreenEntry('101', 'Événement', (_) => const EvenementScreen(), section: _s, node: '40:111'),
  ScreenEntry('102', 'Vitrine', (_) => const VitrineScreen(), section: _s, node: '40:172'),
  ScreenEntry('103', 'Communauté', (_) => const CommunauteScreen(), section: _s, node: '40:242'),
  ScreenEntry('104', 'Carte de l’innovation', (_) => const CarteInnovationScreen(), section: _s, node: '40:335'),
  ScreenEntry('105', 'Inter-établissements', (_) => const InterEtablissementsScreen(), section: _s, node: '40:433'),
  ScreenEntry('106', 'Économie circulaire', (_) => const EconomieCirculaireScreen(), section: _s, node: '40:523'),
  ScreenEntry('107', 'Mon impact', (_) => const MonImpactScreen(), section: _s, node: '40:611'),
  ScreenEntry(
    '237',
    'Impact par territoire',
    (_) => const ImpactTerritoireScreen(),
    section: _s,
    node: '87:1566',
    format: ScreenFormat.web,
  ),
  ScreenEntry('238', 'Impact de Boutik-École', (_) => const ImpactGlobalScreen(), section: _s, node: '87:1498'),
  ScreenEntry(
    '239',
    'Rapport sponsors',
    (_) => const RapportSponsorsScreen(),
    section: _s,
    node: '87:1669',
    format: ScreenFormat.web,
  ),
];
