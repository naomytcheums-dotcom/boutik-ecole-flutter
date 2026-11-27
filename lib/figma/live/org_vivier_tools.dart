import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'company_screens.dart' show companyContextProvider;
import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
import 'lots.dart' show formDialog;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'talent_pool.dart' show poolArgs, poolErrorText, talentListsProvider;

/// Outils du vivier de l'organisation (migration 20261128061000) : renommer une liste et exporter le vivier en CSV (propriétaire et administrateurs).
/// L'export ne contient que les talents encore visibles des recruteurs et les rubriques qu'ils ont partagées : jamais d'e-mail, de téléphone ni de note interne (le serveur filtre).

/// Exporte le vivier (ou une liste) : le fichier est téléchargé dans le navigateur, sinon copié dans le presse-papiers. Aucune confirmation si le serveur refuse.
Future<void> exportPoolCsv(BuildContext context, WidgetRef ref, {String? list}) async {
  final r = await marcheCall('pool_export', poolArgs(ref.read(companyContextProvider), {'p_list': ?list}));
  if (!context.mounted) return;
  final d = r.data;
  if (r.error != null || d is! Map || '${d['csv'] ?? ''}'.isEmpty) {
    await gAlert(context, 'Export impossible', poolErrorText(r.error ?? 'Réponse inattendue du serveur.'));
    return;
  }
  final count = d['count'] is num ? (d['count'] as num).toInt() : 0;
  final saved = await saveTextFile('${d['filename'] ?? 'vivier-talents.csv'}', '\uFEFF${d['csv']}', 'text/csv;charset=utf-8');
  if (!context.mounted) return;
  gToast(context, saved ? 'Export téléchargé : $count talent(s).' : 'Export copié dans le presse-papiers (format CSV) : $count talent(s).');
}

class PoolListsManager extends ConsumerWidget {
  const PoolListsManager({super.key, required this.canWrite});
  final bool canWrite;

  Future<void> _rename(BuildContext context, WidgetRef ref, Map<String, dynamic> l) async {
    final v = await formDialog(context, 'Renommer la liste', [('Nouveau nom', '${l['name']}')], submit: 'Renommer');
    if (v == null || !context.mounted) return;
    final r = await marcheCall('pool_list_rename', poolArgs(ref.read(companyContextProvider), {'p_list': l['id'], 'p_name': v.first.trim()}));
    if (!context.mounted) return;
    if (r.error != null) {
      await gAlert(context, 'Liste non renommée', poolErrorText(r.error));
      return;
    }
    ref.invalidate(talentListsProvider);
    gToast(context, 'Liste renommée.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(talentListsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      mSectionTitle('Listes'),
      lists.when(
        loading: () => const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(e is MarcheException ? '$e' : poolErrorText(e), style: mst(13, c: kGrey)),
        data: (rows) => rows.isEmpty
            ? Text('Aucune liste pour le moment.', style: mst(13, c: kGrey))
            : Column(children: [
                for (final l in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${l['name']}', style: mst(13.5, w: FontWeight.w700)),
                    subtitle: Text('${mInt(l['count'])} talent(s)', style: mst(12, c: kGrey)),
                    trailing: canWrite
                        ? Row(mainAxisSize: MainAxisSize.min, children: [
                            if ('${l['name']}' != 'Favoris') IconButton(tooltip: 'Renommer la liste', onPressed: () => _rename(context, ref, l), icon: const Icon(Icons.edit_outlined, size: 20)),
                            IconButton(tooltip: 'Exporter cette liste (CSV)', onPressed: () => exportPoolCsv(context, ref, list: '${l['id']}'), icon: const Icon(Icons.download_rounded, size: 20)),
                          ])
                        : null,
                  ),
              ]),
      ),
      if (canWrite) ...[
        const SizedBox(height: 8),
        mButton('Exporter tout le vivier (CSV)', () => exportPoolCsv(context, ref), dark: false, icon: Icons.download_rounded),
        const SizedBox(height: 4),
        Text('Nom, filière, étape, étiquettes, listes et dernier contact. Le nom complet, les compétences et les disponibilités n’y figurent que si le talent les a partagés avec les organisations ; jamais d’e-mail, de téléphone ni de note interne.', style: mst(11.5, c: kGrey).copyWith(height: 1.4)),
      ],
    ]);
  }
}
