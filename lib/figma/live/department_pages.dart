import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart' show screenPath;
import '../gen.dart' show gToast;
import '../nav.dart';
import 'access.dart' show canOpen;
import 'auth.dart';
import 'backend.dart';
import 'store.dart' show StrV;

/// Départements (écrans 214 et 215) : liste des départements vérifiés (lecture publique) et fiche réelle d'un département
/// (établissement, effectifs, étudiants à la une pour les comptes connectés). Aucune donnée de maquette.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

/// Département choisi dans la liste (identifiant serveur).
final selectedDepartmentProvider = NotifierProvider<StrV, String>(StrV.new);

final departmentRowsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready) return null;
  final r = await Backend.rows('departments', 'id,name,institutions(name)', eq: const {'status': 'verified'}, order: 'name', ascending: true, limit: 500);
  return r.error != null ? null : r.rows;
}, retry: (_, _) => null);

final departmentDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (id.isEmpty || !Backend.ready) return null;
  final r = await Backend.rpc('department_detail', {'p_id': id});
  return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

Widget _note(double width, String t) => Container(width: width, height: 190, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));

/// Liste des départements vérifiés ; toucher une ligne ouvre sa fiche.
Widget departmentsPanel({double width = 342, double height = 620}) => Consumer(builder: (context, ref, _) {
      final rows = ref.watch(departmentRowsProvider);
      return rows.when(
        loading: () => _note(width, 'Chargement…'),
        error: (_, _) => _note(width, 'Cette liste ne peut pas être chargée pour le moment.'),
        data: (list) {
          if (list == null) return _note(width, 'Cette liste ne peut pas être chargée pour le moment.');
          if (list.isEmpty) return _note(width, 'Aucun département publié pour le moment.');
          return SizedBox(
            width: width,
            height: height,
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 22, thickness: 1, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final d = list[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref.read(selectedDepartmentProvider.notifier).set('${d['id']}');
                    gOpen(context, '215');
                  },
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('${(d['institutions'] as Map?)?['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _grey, size: 20),
                  ]),
                );
              },
            ),
          );
        },
      );
    });

/// Nom du département affiché dans l'en-tête de l'écran 215.
Widget departmentTitle() => Consumer(builder: (context, ref, _) {
      final id = ref.watch(selectedDepartmentProvider);
      final d = ref.watch(departmentDetailProvider(id)).value;
      return Text(d == null ? 'Département' : '${d['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(21, w: FontWeight.w700));
    });

/// Fiche d'un département : établissement, effectifs réels, étudiants à la une, et dépôt d'un besoin pour les comptes qui y ont droit.
Widget departmentSheet({double width = 342, double height = 700}) => Consumer(builder: (context, ref, _) {
      final id = ref.watch(selectedDepartmentProvider);
      if (id.isEmpty) return _note(width, 'Choisissez un département dans la liste pour voir sa fiche.');
      final detail = ref.watch(departmentDetailProvider(id));
      return detail.when(
        loading: () => _note(width, 'Chargement…'),
        error: (_, _) => _note(width, 'Cette fiche ne peut pas être chargée pour le moment.'),
        data: (d) {
          if (d == null) return _note(width, 'Ce département n’est pas disponible.');
          final account = ref.watch(authProvider).current;
          final featured = [for (final s in (d['featured'] as List? ?? const [])) Map<String, dynamic>.from(s as Map)];
          Widget stat(String v, String l) => Expanded(child: Column(children: [Text(v, style: _st(20, w: FontWeight.w800)), const SizedBox(height: 4), Text(l, style: _st(11.5, c: _grey))]));
          return SizedBox(
            width: width,
            height: height,
            child: ListView(padding: const EdgeInsets.only(bottom: 120), children: [
              Text('${d['name']}', style: _st(18, w: FontWeight.w800)),
              const SizedBox(height: 4),
              Text([if ('${d['institution']}'.isNotEmpty) '${d['institution']}', if ('${d['city']}'.isNotEmpty) '${d['city']}'].join(' · '), style: _st(12.5, c: _grey)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFECE8F2))),
                child: Row(children: [stat('${d['students'] ?? 0}', 'Étudiants'), stat('${d['listings'] ?? 0}', 'Produits'), stat('${d['projects'] ?? 0}', 'Projets')]),
              ),
              const SizedBox(height: 22),
              Text('Étudiants à la une', style: _st(15, w: FontWeight.w700)),
              const SizedBox(height: 12),
              if (account == null)
                Text('Connectez-vous pour découvrir les étudiants de ce département.', style: _st(12.5, c: _grey).copyWith(height: 1.5))
              else if (featured.isEmpty)
                Text('Aucun étudiant n’a encore renseigné ses compétences dans ce département.', style: _st(12.5, c: _grey).copyWith(height: 1.5))
              else
                for (final s in featured)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => GoRouter.of(context).push('${screenPath('247')}?user=${Uri.encodeQueryComponent('${s['id']}')}'),
                      child: Row(children: [
                        CircleAvatar(radius: 22, backgroundColor: const Color(0xFFF1EEFB), backgroundImage: '${s['avatar_url'] ?? ''}'.isEmpty ? null : NetworkImage('${s['avatar_url']}'), child: '${s['avatar_url'] ?? ''}'.isEmpty ? Text('${s['name']}'.isEmpty ? '?' : '${s['name']}'.substring(0, 1).toUpperCase(), style: _st(14, w: FontWeight.w700)) : null),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${s['skills']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                          ]),
                        ),
                        Text('Voir', style: _st(12, w: FontWeight.w600, c: const Color(0xFF5A3FE0))),
                      ]),
                    ),
                  ),
              const SizedBox(height: 14),
              if (canOpen(account, '90'))
                GestureDetector(
                  onTap: () => gOpen(context, '90'),
                  child: Container(height: 54, alignment: Alignment.center, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(27)), child: Text('Déposer un brief au département', style: _st(14.5, w: FontWeight.w600, c: Colors.white))),
                )
              else
                GestureDetector(
                  onTap: () => gToast(context, 'Seules les entreprises vérifiées peuvent déposer un brief.'),
                  child: Text('Les entreprises vérifiées peuvent déposer un brief à ce département.', style: _st(12.5, c: _grey).copyWith(height: 1.5)),
                ),
            ]),
          );
        },
      );
    });
