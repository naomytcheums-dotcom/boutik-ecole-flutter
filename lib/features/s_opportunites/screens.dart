import '../../core/router/screen_entry.dart';
import 's151_opportunites/opportunites_ia_screen.dart';
import 's152_kela_recommande/kela_recommande_screen.dart';
import 's153_pourquoi_offre/pourquoi_offre_screen.dart';
import 's154_mon_dossier/mon_dossier_screen.dart';
import 's155_alertes/alertes_screen.dart';
import 's156_preferences_alertes/preferences_alertes_screen.dart';
import 's157_resume_kela/resume_kela_screen.dart';
import 's158_candidatures_classees/candidatures_classees_screen.dart';
import 's159_candidature_envoyee/candidature_envoyee_screen.dart';

const _s = 'S';

/// Section S · Opportunités et alertes IA (151–159).
final sectionSScreens = <ScreenEntry>[
  ScreenEntry('151', 'Opportunités', (_) => const OpportunitesIaScreen(), section: _s, node: '60:2'),
  ScreenEntry('152', 'Kéla te recommande', (_) => const KelaRecommandeScreen(), section: _s, node: '60:117'),
  ScreenEntry('153', 'Pourquoi cette offre ?', (_) => const PourquoiOffreScreen(), section: _s, node: '60:226'),
  ScreenEntry('154', 'Mon dossier', (_) => const MonDossierScreen(), section: _s, node: '60:298'),
  ScreenEntry('155', 'Alertes', (_) => const AlertesScreen(), section: _s, node: '60:377'),
  ScreenEntry('156', 'Préférences d’alertes', (_) => const PreferencesAlertesScreen(), section: _s, node: '60:471'),
  ScreenEntry('157', 'Résumé de Kéla', (_) => const ResumeKelaScreen(), section: _s, node: '60:546'),
  ScreenEntry('158', 'Candidatures classées', (_) => const CandidaturesClasseesScreen(), section: _s, node: '60:651'),
  ScreenEntry('159', 'Candidature envoyée', (_) => const CandidatureEnvoyeeScreen(), section: _s, node: '60:707'),
];
