import 'backend.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store.dart';

/// Journal d'audit : chaque action sensible de l'application y laisse une trace (écrans 126 et 137).
class AuditEntry {
  const AuditEntry(this.time, this.actor, this.action, this.target, this.cat, {this.level = 'Normal', this.institution = 'IUT Douala', this.ip = '41.202.x.x'});
  final String time, actor, action, target, cat, level, institution, ip;
}

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String auditNow() {
  final d = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.day} ${_mois[d.month - 1]} ${two(d.hour)}:${two(d.minute)}';
}

const _seedAudit = [
  AuditEntry('22 oct. 10:31', 'Super admin', 'Commission modifiée', 'Produits 5 %', 'Paramètres', level: 'Critique', institution: 'Plateforme'),
  AuditEntry('22 oct. 10:24', 'Dr Mbarga', 'Annonce validée', 'Lampe en bois recyclé', 'Validations'),
  AuditEntry('22 oct. 10:12', 'Support 01', 'Contenu retiré', 'Annonce #4412', 'Modération', level: 'Sensible'),
  AuditEntry('22 oct. 09:58', 'Direction', 'Circuit modifié', 'Annonces produits', 'Paramètres', level: 'Sensible'),
  AuditEntry('22 oct. 09:40', 'Finance', 'Rapprochement validé', 'Lot du 21 oct.', 'Finances'),
  AuditEntry('21 oct. 17:12', 'Admin', 'Compte suspendu', 'Carine Mbarga', 'Comptes', level: 'Sensible', ip: '197.15.x.x'),
  AuditEntry('21 oct. 17:05', 'Super admin', 'Rôle attribué', 'Finance', 'Comptes', level: 'Sensible', institution: 'Plateforme'),
  AuditEntry('21 oct. 11:03', 'Direction', 'Export des données', 'Ventes 12 mois', 'Paramètres', level: 'Sensible'),
];

class AuditLog extends Notifier<List<AuditEntry>> {
  @override
  List<AuditEntry> build() => const [];

  void log(String actor, String action, String target, String cat, {String level = 'Normal'}) {
    state = [AuditEntry(auditNow(), actor, action, target, cat, level: level), ...state];
    Backend.audit(actor, action, target, cat, level);
  }
}

final auditProvider = NotifierProvider<AuditLog, List<AuditEntry>>(AuditLog.new);

/// Onglets : 126 (Toutes, Connexions, Validations, Paramètres, Suppressions) et 137 (Tout, Comptes, Finances, Modération, Configuration).
final auditTabProvider = NotifierProvider<IntV, int>(IntV.new);
final auditQueryProvider = NotifierProvider<StrV, String>(StrV.new);

Set<String>? _cats(int tab, bool institutional) {
  if (tab == 0) return null;
  if (institutional) {
    return const [<String>{'Connexions'}, <String>{'Validations', 'Modération'}, <String>{'Paramètres'}, <String>{'Suppressions'}][tab - 1];
  }
  return const [<String>{'Comptes', 'Connexions'}, <String>{'Finances'}, <String>{'Modération', 'Validations'}, <String>{'Paramètres'}][tab - 1];
}

List<AuditEntry> _filtered(Ref ref, bool institutional) {
  final cats = _cats(ref.watch(auditTabProvider), institutional);
  final q = ref.watch(auditQueryProvider).trim().toLowerCase();
  return [
    for (final e in [...ref.watch(auditProvider), ..._seedAudit])
      if ((cats == null || cats.contains(e.cat)) && (q.isEmpty || '${e.actor} ${e.action} ${e.target}'.toLowerCase().contains(q))) e,
  ];
}

final institutionAuditProvider = Provider<List<AuditEntry>>((ref) => _filtered(ref, true));
final globalAuditProvider = Provider<List<AuditEntry>>((ref) => _filtered(ref, false));

Color levelFill(String l) => switch (l) {
      'Critique' => const Color(0xFFFDE6E7),
      'Sensible' => const Color(0xFFEEE9FF),
      _ => const Color(0xFFDDF5EC),
    };

Color levelInk(String l) => switch (l) {
      'Critique' => const Color(0xFFE5484D),
      'Sensible' => const Color(0xFF8F5400),
      _ => const Color(0xFF0F7A52),
    };
