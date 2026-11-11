import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';

/// Tableaux des consoles web (administration : départements 119, utilisateurs 120, responsables 121…) : lignes lues sur le serveur
/// par une fonction réservée à la gestion (migration 20261105000200). Chargement, état vide et refus d'accès explicites.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Liste JSON d'une fonction serveur ; `null` : lecture en cours, serveur absent ou personne non connectée ; `error` : accès refusé ou échec.
class RpcRows extends Notifier<List<Map<String, dynamic>>?> {
  RpcRows(this.fn, [this.args = const {}]);
  final String fn;
  final Map<String, dynamic> args;
  bool error = false;

  @override
  List<Map<String, dynamic>>? build() {
    if (!Backend.ready) return null;
    if (ref.watch(authProvider.select((a) => a.current == null))) return null;
    Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc(fn, args);
    if (!ref.mounted) return;
    error = r.error != null || r.data is! List;
    state = error ? const [] : [for (final x in r.data as List) Map<String, dynamic>.from(x as Map)];
  }
}

final deptStudentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('dept_students', const {'p_limit': 200}));
final adminDepartmentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('admin_departments'));
final consoleUsersProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('admin_users', const {'p_limit': 200}));
final adminResponsablesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('admin_users', const {'p_roles': ['dept', 'direction'], 'p_limit': 200}));

const roleLabels = {
  'student': 'Étudiant',
  'client': 'Client',
  'company': 'Entreprise',
  'other': 'Autre',
  'dept': 'Responsable',
  'direction': 'Direction',
  'finance': 'Finance',
  'support': 'Support',
  'admin': 'Administrateur',
};

String roleLabel(Object? r) => roleLabels['$r'] ?? '$r';

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « Aujourd'hui 09:12 », « Hier », « 3 nov. 2026 » ou « Jamais ».
String lastLoginLabel(Object? iso, DateTime now) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return 'Jamais';
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (days == 0) return 'Aujourd’hui $hm';
  if (days == 1) return 'Hier $hm';
  return '${d.day} ${_mois[d.month - 1]} ${d.year}';
}

/// Colonnes : abscisse relative au tableau, largeur et texte de la cellule d'une ligne.
class ConsoleColumn {
  const ConsoleColumn(this.x, this.w, this.cell, {this.bold = false});
  final double x, w;
  final String Function(Map<String, dynamic> row) cell;
  final bool bold;
}

class ConsoleTable extends ConsumerWidget {
  const ConsoleTable({super.key, required this.provider, required this.columns, required this.emptyText, this.width = 940, this.height = 520});
  final NotifierProvider<RpcRows, List<Map<String, dynamic>>?> provider;
  final List<ConsoleColumn> columns;
  final String emptyText;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((a) => a.current != null));
    Widget note(String t) => SizedBox(width: width, height: height, child: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(left: 16, top: 4), child: Text(t, style: _st(13, c: _grey)))));
    if (!signedIn) return note('Connectez-vous avec un compte de gestion pour voir cette liste.');
    final rows = ref.watch(provider);
    if (rows == null) return note('Chargement…');
    if (ref.read(provider.notifier).error) return note('Accès réservé à la gestion, ou liste indisponible pour le moment.');
    if (rows.isEmpty) return note(emptyText);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemExtent: 44,
        itemBuilder: (_, i) => Stack(children: [
          for (final c in columns) Positioned(left: c.x, width: c.w, top: 0, child: Text(c.cell(rows[i]), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5, w: c.bold ? FontWeight.w600 : FontWeight.w500, c: c.bold ? _ink : const Color(0xFF3D3B37)))),
        ]),
      ),
    );
  }
}
