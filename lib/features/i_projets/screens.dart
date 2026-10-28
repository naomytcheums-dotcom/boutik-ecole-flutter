import '../../core/router/screen_entry.dart';
import 's78_projets_innovants/projets_innovants_screen.dart';
import 's79_projet/projet_screen.dart';
import 's80_soumettre_projet/soumettre_projet_screen.dart';
import 's81_equipe_projet/equipe_projet_screen.dart';
import 's82_journal_projet/journal_projet_screen.dart';
import 's83_medias_preuves/medias_preuves_screen.dart';
import 's84_nouvelle_campagne/nouvelle_campagne_screen.dart';
import 's84b_financement/financement_screen.dart';
import 's85_objectifs_jalons/objectifs_jalons_screen.dart';
import 's86_resultats_campagne/resultats_campagne_screen.dart';
import 's87_registre_innovations/registre_innovations_screen.dart';

const _s = 'I';

/// Section I · Projets, innovations, financement (78–87).
final sectionIScreens = <ScreenEntry>[
  ScreenEntry('78', 'Projets innovants', (_) => const ProjetsInnovantsScreen(), section: _s, node: '38:738'),
  ScreenEntry('79', 'Projet', (_) => const ProjetScreen(), section: _s, node: '38:819'),
  ScreenEntry('80', 'Soumettre un projet', (_) => const SoumettreProjetScreen(), section: _s, node: '38:883'),
  ScreenEntry('81', 'Équipe du projet', (_) => const EquipeProjetScreen(), section: _s, node: '38:952'),
  ScreenEntry('82', 'Journal du projet', (_) => const JournalProjetScreen(), section: _s, node: '38:1016'),
  ScreenEntry('83', 'Médias et preuves', (_) => const MediasPreuvesScreen(), section: _s, node: '39:2'),
  ScreenEntry('84', 'Nouvelle campagne', (_) => const NouvelleCampagneScreen(), section: _s, node: '54:1206'),
  ScreenEntry('84b', 'Financement', (_) => const FinancementScreen(), section: _s, node: '39:63'),
  ScreenEntry('85', 'Objectifs et jalons', (_) => const ObjectifsJalonsScreen(), section: _s, node: '39:129'),
  ScreenEntry('86', 'Résultats de campagne', (_) => const ResultatsCampagneScreen(), section: _s, node: '39:186'),
  ScreenEntry('87', 'Registre des innovations', (_) => const RegistreInnovationsScreen(), section: _s, node: '39:255'),
];
