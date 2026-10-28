/// Validateurs des formulaires de la section Y (missions sur mesure).
String? validateNeedDescription(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Décrivez votre besoin pour recevoir un devis.';
  if (t.length < 15) return 'Ajoutez quelques détails (15 caractères minimum).';
  return null;
}

String? validateProofDescription(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Décrivez ce qui a été réalisé.';
  return null;
}

String? validateProjectName(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Donnez un nom à votre projet.';
  if (t.length < 3) return 'Le nom doit contenir au moins 3 caractères.';
  return null;
}

String? validateProjectProblem(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Expliquez le problème que votre projet résout.';
  if (t.length < 15) return 'Ajoutez quelques détails (15 caractères minimum).';
  return null;
}

String? validateFundingAmount(String? v) {
  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 'Indiquez le montant recherché (0 si aucun).';
  if (int.parse(digits) > 50000000) return 'Le montant ne peut pas dépasser 50 000 000 FCFA.';
  return null;
}
