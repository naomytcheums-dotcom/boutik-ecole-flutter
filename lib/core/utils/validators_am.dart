/// Validateurs de la section AM (publication, commentaires).
String? validateCaption(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Ajoute une légende avant de publier.';
  if (v.length > 2200) return 'La légende ne doit pas dépasser 2 200 caractères.';
  return null;
}

String? validateComment(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Écris un commentaire avant d’envoyer.';
  if (v.length > 500) return 'Le commentaire ne doit pas dépasser 500 caractères.';
  return null;
}
