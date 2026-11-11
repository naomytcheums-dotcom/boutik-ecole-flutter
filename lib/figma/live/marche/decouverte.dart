/// Découverte dans la marketplace : filières de l'IUT, besoins courants et recherche par problème.
/// Aucune intelligence cachée : les mots de la phrase tapée (« mon stock se perd ») sont comparés au titre et à la description des offres,
/// complétés par quelques synonymes métier ; le serveur classe les offres par nombre de mots retrouvés.

/// Filières proposées : libellé affiché → mot recherché dans la filière de l'offre.
const marcheFilieres = {
  '': 'Toutes les filières',
  'lectrique': 'Génie électrique',
  'informatique': 'Génie informatique',
  'civil': 'Génie civil',
  'agro': 'Agroalimentaire',
};

/// Besoins courants : libellé affiché → mots recherchés.
const marcheBesoins = {
  '': 'Tous les besoins',
  'boutique': 'Une solution pour ma boutique',
  'coder': 'Un étudiant qui sait coder',
  'agricole': 'Équiper mon exploitation agricole',
  'logo': 'Un logo, une affiche, du design',
  'reseau': 'Un réseau ou une installation électrique',
  'formation': 'Former mon personnel',
};

const _besoinTermes = {
  'boutique': ['boutique', 'caisse', 'stock', 'gestion', 'vente', 'commerce'],
  'coder': ['code', 'développeur', 'application', 'site', 'web', 'logiciel', 'flutter'],
  'agricole': ['irrigation', 'agricole', 'culture', 'ferme', 'transformation', 'séchoir'],
  'logo': ['logo', 'design', 'affiche', 'graphisme', 'identité'],
  'reseau': ['réseau', 'wifi', 'électrique', 'installation', 'câblage', 'solaire'],
  'formation': ['formation', 'atelier', 'cours', 'initiation'],
};

List<String> besoinTerms(String key) => _besoinTermes[key] ?? const [];

const _stop = {
  'mon', 'ma', 'mes', 'ton', 'ses', 'les', 'des', 'une', 'un', 'le', 'la', 'de', 'du', 'et', 'ou', 'pour', 'que', 'qui', 'quoi', 'dans', 'sur', 'avec', 'sans', 'par',
  'est', 'sont', 'suis', 'veux', 'voudrais', 'cherche', 'besoin', 'avoir', 'faire', 'fait', 'plus', 'pas', 'très', 'tres', 'comment', 'aide', 'trouver', 'quelqu', 'quelqu\'un',
  'nous', 'vous', 'notre', 'votre', 'leur', 'cette', 'ces', 'son', 'sa', 'aux', 'au', 'en', 'se', 'ne', 'je', 'tu', 'il', 'elle', 'on',
};

/// Synonymes métier : un mot de la phrase ajoute les mots proches (un stock « qui se perd » mène aux outils de gestion de stock).
const _synonymes = {
  'stock': ['inventaire', 'gestion'],
  'perd': ['stock', 'inventaire', 'gestion'],
  'perdu': ['stock', 'inventaire', 'gestion'],
  'client': ['caisse', 'fidélité', 'vente'],
  'clients': ['caisse', 'fidélité', 'vente'],
  'caisse': ['vente', 'boutique', 'gestion'],
  'coder': ['code', 'développeur', 'application'],
  'code': ['développeur', 'application', 'site'],
  'site': ['web', 'application'],
  'eau': ['irrigation', 'arrosage'],
  'arroser': ['irrigation', 'arrosage'],
  'courant': ['électrique', 'solaire', 'installation'],
  'électricité': ['électrique', 'solaire', 'installation'],
  'electricite': ['électrique', 'solaire', 'installation'],
  'logo': ['design', 'graphisme', 'identité'],
  'affiche': ['design', 'graphisme'],
  'wifi': ['réseau', 'installation'],
  'internet': ['réseau', 'wifi', 'installation'],
  'former': ['formation', 'atelier', 'cours'],
  'apprendre': ['formation', 'atelier', 'cours'],
};

String _norm(String w) => w.toLowerCase().replaceAll(RegExp(r'[^a-zà-ÿ\-]'), '');

/// Mots utiles d'une phrase décrivant un problème ; vide si la phrase n'a qu'un mot (la recherche simple s'applique alors).
List<String> problemTerms(String text) {
  final words = <String>[];
  for (final raw in text.split(RegExp(r"[\s,.;:!?'’]+"))) {
    final w = _norm(raw);
    if (w.length < 3 || _stop.contains(w)) continue;
    words.add(w);
  }
  if (words.length < 2) return const [];
  final out = <String>{};
  for (final w in words) {
    out.add(w);
    final singular = w.length > 4 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;
    out.add(singular);
    out.addAll(_synonymes[w] ?? _synonymes[singular] ?? const []);
  }
  return out.where((e) => e.length >= 3).take(12).toList();
}
