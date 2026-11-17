import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'marche/marche_data.dart' show marcheCall;

/// Appel d'une fonction serveur par les écrans du lot F4 (page publique d'entreprise, achats B2B, négociation de devis, recherche de talents).
/// Les tests remplacent ce fournisseur pour vérifier les appels réellement émis ; en production c'est [marcheCall].
typedef F4Rpc = Future<({Object? data, String? error})> Function(String fn, Map<String, dynamic> params);

final f4RpcProvider = Provider<F4Rpc>((ref) => marcheCall);
