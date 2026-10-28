/// Chemin go_router d'un écran du manifeste (`03` → `/s/03`, `146-1` → `/s/146-1`).
String screenPath(String id) => '/s/$id';

/// Cibles du menu bas « verre liquide ».
abstract final class NavTargets {
  static const search = '22';
  static const messages = '50';
  static const home = '03';
  static const kela = '230';
  static const profile = '57';
}
