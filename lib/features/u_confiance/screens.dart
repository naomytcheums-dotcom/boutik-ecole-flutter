import '../../core/router/screen_entry.dart';
import 's170_signaler/signaler_screen.dart';
import 's171_paiement_securise/paiement_securise_screen.dart';
import 's172_confiance_vendeur/confiance_vendeur_screen.dart';
import 's173_partager/partager_screen.dart';
import 's174_centre_confiance/centre_confiance_screen.dart';
import 's211_passeport_produit/passeport_produit_screen.dart';
import 's212_verifier_certificat/verifier_certificat_screen.dart';
import 's213_registre_certificats/registre_certificats_screen.dart';

const _s = 'U';

final sectionUScreens = <ScreenEntry>[
  ScreenEntry('170', 'Signaler une annonce', (_) => const SignalerScreen(), section: _s, node: '61:2'),
  ScreenEntry('171', 'Paiement sécurisé', (_) => const PaiementSecuriseScreen(), section: _s, node: '61:47'),
  ScreenEntry('172', 'Confiance du vendeur', (_) => const ConfianceVendeurScreen(), section: _s, node: '61:92'),
  ScreenEntry('173', 'Partager', (_) => const PartagerScreen(), section: _s, node: '61:160'),
  ScreenEntry('174', 'Centre de confiance', (_) => const CentreConfianceScreen(), section: _s, node: '61:221'),
  ScreenEntry('211', 'Passeport du produit', (_) => const PasseportProduitScreen(), section: _s, node: '83:847'),
  ScreenEntry('212', 'Vérifier un certificat', (_) => const VerifierCertificatScreen(), section: _s, node: '83:911'),
  ScreenEntry(
    '213',
    'Registre des certificats',
    (_) => const RegistreCertificatsScreen(),
    section: _s,
    node: '83:1614',
    format: ScreenFormat.web,
  ),
];
