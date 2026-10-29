import '../../core/router/screen_entry.dart';
import '../../figma/s257.dart';
import 's074_talent_passport/talent_passport_screen.dart';
import 's250b_nouvelle_publication/nouvelle_publication_screen.dart';
import 's255_suivi_publication/suivi_publication_screen.dart';
import 's256_controles_fiche/controles_fiche_screen.dart';
import 's258_paiement_echoue/paiement_echoue_screen.dart';
import 's259_recu/recu_screen.dart';
import 's260_facture/facture_screen.dart';
import 's261_espace_client/espace_client_screen.dart';
import 's262_accueil_b2b/accueil_b2b_screen.dart';
import 's263_mediatheque/mediatheque_screen.dart';
import 's264_pages_editoriales/pages_editoriales_screen.dart';
import 's265_modeles_notifications/modeles_notifications_screen.dart';
import 's266_etat_technique/etat_technique_screen.dart';
import 's267_reseau/reseau_screen.dart';
import 's268_analytics_borne/analytics_borne_screen.dart';
import 's269_innovation_radar/innovation_radar_screen.dart';
import 's270_showroom_national/showroom_national_screen.dart';
import 's271_liens_reseaux/liens_reseaux_screen.dart';
import 's272_double_authentification/double_authentification_screen.dart';
import 's273_mes_donnees/mes_donnees_screen.dart';
import 's274_conditions_generales/conditions_generales_screen.dart';
import 's275_depot_produit_erreurs/depot_produit_erreurs_screen.dart';
import 's276_borne_hors_ligne/borne_hors_ligne_screen.dart';
import 's277_supervision_bornes/supervision_bornes_screen.dart';
import 's278_fiche_projet_pi/fiche_projet_pi_screen.dart';
import 's279_ajout_fichiers/ajout_fichiers_screen.dart';
import 's280_integrations/integrations_screen.dart';
import 's281_roles_perimetres/roles_perimetres_screen.dart';
import 's282_qr_transfert/qr_transfert_screen.dart';
import 's283_registre_certificats/registre_certificats_screen.dart';
import 's284_registre_financier/registre_financier_screen.dart';
import 's285_espace_projet/espace_projet_screen.dart';
import 's286_soumissions_equipe/soumissions_equipe_screen.dart';
import 's287_catalogue_tablette/catalogue_tablette_screen.dart';
import 's288_catalogue_web/catalogue_web_screen.dart';

const _s = 'NOUVEAUX';
const _web = ScreenFormat.web;

/// Section « Nouveaux écrans » (255–288, 74, 250b), dans l'ordre du manifeste.
final nouveauxScreens = <ScreenEntry>[
  ScreenEntry('255', 'Suivi de publication', (_) => const SuiviPublicationScreen(), section: _s, node: '184:16'),
  ScreenEntry('256', 'Contrôles de la fiche', (_) => const ControlesFicheScreen(), section: _s, node: '184:90'),
  ScreenEntry('257', 'Paiement en attente de confirmation', (_) => const F257(), section: _s, node: '184:174'),
  ScreenEntry('258', 'Paiement échoué', (_) => const PaiementEchoueScreen(), section: _s, node: '184:210'),
  ScreenEntry('259', 'Reçu', (_) => const RecuScreen(), section: _s, node: '184:253'),
  ScreenEntry('260', 'Facture', (_) => const FactureScreen(), section: _s, node: '184:290'),
  ScreenEntry('261', 'Mon espace client', (_) => const EspaceClientScreen(), section: _s, node: '184:342'),
  ScreenEntry('270', 'Showroom national', (_) => const ShowroomNationalScreen(), section: _s, node: '190:928'),
  ScreenEntry('271', 'Mes liens et réseaux', (_) => const LiensReseauxScreen(), section: _s, node: '197:129'),
  ScreenEntry('272', 'Vérification en 2 étapes', (_) => const DoubleAuthentificationScreen(), section: _s, node: '200:16'),
  ScreenEntry('273', 'Mes données', (_) => const MesDonneesScreen(), section: _s, node: '200:137'),
  ScreenEntry('274', 'Conditions générales', (_) => const ConditionsGeneralesScreen(), section: _s, node: '200:253'),
  ScreenEntry('275', 'Déposer un produit (erreurs)', (_) => const DepotProduitErreursScreen(), section: _s, node: '200:366'),
  ScreenEntry('276', 'Borne hors ligne', (_) => const BorneHorsLigneScreen(), section: _s, node: '200:484'),
  ScreenEntry('277', 'Supervision des bornes', (_) => const SupervisionBornesScreen(), section: _s, node: '200:598'),
  ScreenEntry('278', 'Fiche projet · liens et PI', (_) => const FicheProjetPiScreen(), section: _s, node: '209:16'),
  ScreenEntry('279', 'Ajouter des fichiers', (_) => const AjoutFichiersScreen(), section: _s, node: '209:142'),
  ScreenEntry('280', 'Intégrations', (_) => const IntegrationsScreen(), section: _s, node: '209:270'),
  ScreenEntry('281', 'Rôles et périmètres', (_) => const RolesPerimetresScreen(), section: _s, node: '209:396'),
  ScreenEntry('282', 'QR de transfert', (_) => const QrTransfertScreen(), section: _s, node: '209:540'),
  ScreenEntry('283', 'Registre des certificats', (_) => const RegistreCertificatsScreen(), section: _s, node: '209:660'),
  ScreenEntry('284', 'Registre financier', (_) => const RegistreFinancierScreen(), section: _s, node: '209:785'),
  ScreenEntry('285', 'Espace projet', (_) => const EspaceProjetScreen(), section: _s, node: '209:907'),
  ScreenEntry('286', 'Soumissions et équipe', (_) => const SoumissionsEquipeScreen(), section: _s, node: '209:1035'),
  ScreenEntry('74', 'Talent Passport', (_) => const TalentPassportScreen(), section: _s, node: '213:119'),
  ScreenEntry('287', 'Catalogue département (tablette)', (_) => const CatalogueTabletteScreen(), section: _s, node: '210:16', format: ScreenFormat.tablet),
  ScreenEntry('262', 'Accueil B2B', (_) => const AccueilB2bScreen(), section: _s, node: '190:16', format: _web),
  ScreenEntry('263', 'Médiathèque', (_) => const MediathequeScreen(), section: _s, node: '190:149', format: _web),
  ScreenEntry('264', 'Pages éditoriales', (_) => const PagesEditorialesScreen(), section: _s, node: '190:275', format: _web),
  ScreenEntry('265', 'Modèles de notifications', (_) => const ModelesNotificationsScreen(), section: _s, node: '190:371', format: _web),
  ScreenEntry('266', 'État technique', (_) => const EtatTechniqueScreen(), section: _s, node: '190:468', format: _web),
  ScreenEntry('267', 'Boutik-École Network', (_) => const ReseauScreen(), section: _s, node: '190:576', format: _web),
  ScreenEntry('268', 'Analytics de la borne', (_) => const AnalyticsBorneScreen(), section: _s, node: '190:681', format: _web),
  ScreenEntry('269', 'Innovation Radar', (_) => const InnovationRadarScreen(), section: _s, node: '190:819', format: _web),
  ScreenEntry('288', 'Catalogue département (web)', (_) => const CatalogueWebScreen(), section: _s, node: '210:68', format: _web),
  ScreenEntry('250b', 'Nouvelle publication', (_) => const NouvellePublicationScreen(), section: _s, node: '197:23'),
];
