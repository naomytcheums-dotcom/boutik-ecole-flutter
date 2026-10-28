import '../../core/router/screen_entry.dart';
import 's70_talents_etudiants/talents_etudiants_screen.dart';
import 's72_ajouter_profil/ajouter_profil_screen.dart';
import 's73_mes_documents/mes_documents_screen.dart';
import 's75_opportunites/opportunites_screen.dart';
import 's76_ma_candidature/ma_candidature_screen.dart';
import 's77_profil_mentor/profil_mentor_screen.dart';

const _s = 'H';

/// Section H · Talents et parcours (70–77 ; 74 Talent Passport est dans « nouveaux »).
final sectionHScreens = <ScreenEntry>[
  ScreenEntry('70', 'Talents étudiants', (_) => const TalentsEtudiantsScreen(), section: _s, node: '35:412'),
  ScreenEntry('72', 'Ajouter à mon profil', (_) => const AjouterProfilScreen(), section: _s, node: '38:265'),
  ScreenEntry('73', 'Mes documents', (_) => const MesDocumentsScreen(), section: _s, node: '38:326'),
  ScreenEntry('75', 'Opportunités', (_) => const OpportunitesScreen(), section: _s, node: '38:490'),
  ScreenEntry('76', 'Ma candidature', (_) => const MaCandidatureScreen(), section: _s, node: '38:581'),
  ScreenEntry('77', 'Profil de mentor', (_) => const ProfilMentorScreen(), section: _s, node: '54:284'),
];
