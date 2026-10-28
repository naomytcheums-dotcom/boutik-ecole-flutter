import '../../core/router/screen_entry.dart';
import 's216_marche_voeux/marche_voeux_screen.dart';
import 's217_fiche_voeu/fiche_voeu_screen.dart';
import 's218_publier_voeu/publier_voeu_screen.dart';
import 's219_nouveau_duel/nouveau_duel_screen.dart';
import 's220_duel_talents/duel_talents_screen.dart';
import 's221_resultat_duel/resultat_duel_screen.dart';
import 's222_atelier_direct/atelier_direct_screen.dart';
import 's223_ateliers_direct/ateliers_direct_screen.dart';
import 's224_validation_voeux/validation_voeux_screen.dart';
import 's225_jumeau_3d/jumeau_3d_screen.dart';
import 's226_moderation_duels/moderation_duels_screen.dart';
import 's227_regie_ateliers/regie_ateliers_screen.dart';
import 's228_partager_cv/partager_cv_screen.dart';
import 's229_cv_vivant/cv_vivant_screen.dart';

const _s = 'AD';
const _web = ScreenFormat.web;

/// Section AD · Innovations (216–229).
final sectionADScreens = <ScreenEntry>[
  ScreenEntry('216', 'Marché des vœux', (_) => const MarcheVoeuxScreen(), section: _s, node: '87:2'),
  ScreenEntry('217', 'Fiche d’un vœu', (_) => const FicheVoeuScreen(), section: _s, node: '87:80'),
  ScreenEntry('218', 'Publier un vœu', (_) => const PublierVoeuScreen(), section: _s, node: '87:148'),
  ScreenEntry('219', 'Nouveau duel', (_) => const NouveauDuelScreen(), section: _s, node: '87:222'),
  ScreenEntry('220', 'Duel de talents', (_) => const DuelTalentsScreen(), section: _s, node: '87:299'),
  ScreenEntry('221', 'Résultat du duel', (_) => const ResultatDuelScreen(), section: _s, node: '87:357'),
  ScreenEntry('222', 'Atelier en direct', (_) => const AtelierDirectScreen(), section: _s, node: '87:409'),
  ScreenEntry('223', 'Ateliers en direct', (_) => const AteliersDirectScreen(), section: _s, node: '87:468'),
  ScreenEntry(
    '224',
    'Validation des vœux',
    (_) => const ValidationVoeuxScreen(),
    section: _s,
    node: '87:532',
    format: _web,
  ),
  ScreenEntry('225', 'Jumeau 3D', (_) => const Jumeau3dScreen(), section: _s, node: '87:582'),
  ScreenEntry(
    '226',
    'Modération des duels',
    (_) => const ModerationDuelsScreen(),
    section: _s,
    node: '87:629',
    format: _web,
  ),
  ScreenEntry(
    '227',
    'Régie des ateliers en direct',
    (_) => const RegieAteliersScreen(),
    section: _s,
    node: '87:673',
    format: _web,
  ),
  ScreenEntry('228', 'Partager mon CV', (_) => const PartagerCvScreen(), section: _s, node: '87:765'),
  ScreenEntry('229', 'CV vivant', (_) => const CvVivantScreen(), section: _s, node: '87:1082'),
];
