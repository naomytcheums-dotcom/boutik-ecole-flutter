import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../demo/catalog_demo.dart';
import '../demo/nouveaux_demo.dart';
import '../models/models.dart';

/// Dépôt du catalogue. Implémentation de démonstration : données locales fictives.
/// Pour brancher l'API, fournir une autre implémentation via `overrideWithValue`.
abstract interface class CatalogRepository {
  List<Product> products();
  List<Talent> talents();
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository();

  @override
  List<Product> products() => demoProducts;

  @override
  List<Talent> talents() => demoTalents;
}

final catalogRepositoryProvider = Provider<CatalogRepository>((_) => const DemoCatalogRepository());

/// Données des écrans de la section « Nouveaux écrans ».
final nouveauxDataProvider = Provider<NouveauxData>((_) => const NouveauxData());

/// Indique que l'application tourne sur des données de démonstration (affiché dans les paramètres).
final demoModeProvider = Provider<bool>((_) => true);
