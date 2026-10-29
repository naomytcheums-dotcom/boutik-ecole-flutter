/// Validateurs des échantillons de référence (section REF).
String? validateLiveTitle(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Donne un titre à ton live.';
  if (v.length < 10) return 'Le titre doit faire au moins 10 caractères.';
  if (v.length > 80) return 'Le titre ne doit pas dépasser 80 caractères.';
  return null;
}
