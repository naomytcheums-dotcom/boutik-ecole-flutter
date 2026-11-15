import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'l10_ui.dart';
import 'lives.dart' show openLive;
import 'store.dart' show IntV;

/// Ateliers en direct réels (écrans 222, 223, 224, V1) : un seul système de lives (la table « lives », celle de « Prochains lives » et de la régie).
/// « Programmer un live » crée un live planifié avec une vraie date ; l'agenda le lit ; les rappels sont enregistrés côté serveur (live_reminders).

class _ScopeV extends IntV {
  @override
  int build() => 1;
}

/// 0 = aujourd'hui, 1 = cette semaine, 2 = mes rappels.
final livesScopeProvider = NotifierProvider<IntV, int>(_ScopeV.new);

final livesAgendaProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final scope = const ['today', 'week', 'mine'][ref.watch(livesScopeProvider).clamp(0, 2)];
  final r = await Backend.rpc('lives_agenda', {'p_scope': scope, 'p_limit': 60});
  if (r.error != null) throw r.error!;
  return l10Rows(r.data);
}, retry: (_, _) => null);

final liveNowListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final r = await Backend.rpc('lives_agenda', {'p_scope': 'live', 'p_limit': 30});
  if (r.error != null) throw r.error!;
  return l10Rows(r.data);
}, retry: (_, _) => null);

Future<void> _toggleReminder(BuildContext context, WidgetRef ref, Map<String, dynamic> l) async {
  if (!await requireLogin(context, ref, 'activer un rappel') || !context.mounted) return;
  final on = l['remind'] != true;
  final r = await Backend.rpc('live_remind_set', {'p_live': l['id'], 'p_on': on});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Rappel impossible', r.error!);
  ref.invalidate(livesAgendaProvider);
  gToast(context, on ? 'Rappel activé : vous serez prévenu environ 30 minutes avant le début.' : 'Rappel retiré.');
}

Widget _liveRow(BuildContext context, WidgetRef ref, Map<String, dynamic> l, {bool bell = true}) {
  final live = '${l['status']}' == 'live';
  final when = l10When(l['scheduled_at']);
  final remind = l['remind'] == true;
  return Semantics(
    button: true,
    label: 'Ouvrir le live ${l['title']}',
    child: l10Card(
      onTap: () => openLive(context, '${l['id']}'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${l['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: l10St(14, w: FontWeight.w800))),
              if (live) l10Chip('EN DIRECT', fill: const Color(0xFFFDE6E7), ink: const Color(0xFFE5484D)),
            ]),
            const SizedBox(height: 3),
            Text([if ('${l['host'] ?? ''}'.isNotEmpty) '${l['host']}', if (live) '${l['viewer_count'] ?? 0} spectateur(s)' else if (when.isNotEmpty) when].join(' · '), style: l10St(11.5, c: l10Grey)),
          ]),
        ),
        if (bell && !live && l['mine'] != true)
          IconButton(
            tooltip: remind ? 'Retirer le rappel' : 'Me rappeler',
            onPressed: () => _toggleReminder(context, ref, l),
            icon: Icon(remind ? Icons.notifications_active : Icons.notifications_none, color: remind ? l10Violet : l10Grey),
          ),
      ]),
    ),
  );
}

/// Écran 223 : agenda des ateliers programmés (filtres Aujourd'hui, Cette semaine, Mes rappels).
class LivesAgendaPanel extends ConsumerWidget {
  const LivesAgendaPanel({super.key, this.width = 342, this.height = 390});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(livesScopeProvider);
    if (scope == 2 && ref.watch(authProvider.select((a) => a.current == null))) return l10Note(width, 'Connectez-vous pour retrouver vos rappels.');
    return ref.watch(livesAgendaProvider).when(
          loading: () => l10Note(width, 'Chargement…'),
          error: (_, _) => l10Note(width, 'L’agenda ne peut pas être chargé pour le moment.'),
          data: (rows) {
            if (rows.isEmpty) {
              return l10Note(width, const [
                'Aucun atelier aujourd’hui.\nConsultez « Cette semaine ».',
                'Aucun live programmé pour le moment.',
                'Vous n’avez activé aucun rappel.\nTouchez la cloche d’un atelier pour être prévenu.',
              ][scope.clamp(0, 2)]);
            }
            return SizedBox(
              width: width,
              height: height,
              child: ListView.separated(padding: const EdgeInsets.only(bottom: 24), itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) => _liveRow(context, ref, rows[i])),
            );
          },
        );
  }
}

/// Écran 222 sans identifiant : lives réellement en cours.
class LiveNowList extends ConsumerWidget {
  const LiveNowList({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(liveNowListProvider).when(
          loading: () => l10Note(width, 'Chargement…'),
          error: (_, _) => l10Note(width, 'Les lives ne peuvent pas être chargés pour le moment.'),
          data: (rows) {
            if (rows.isEmpty) return l10Note(width, 'Aucun live en cours pour le moment.\nLes ateliers à venir sont dans l’agenda « Ateliers en direct ».');
            return SizedBox(
              width: width,
              height: height,
              child: ListView.separated(padding: const EdgeInsets.only(bottom: 24), itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 10), itemBuilder: (_, i) => _liveRow(context, ref, rows[i], bell: false)),
            );
          },
        );
  }
}

/// Champ « Date et heure » de l'écran 224 : sélecteur de date puis d'heure (plus de texte libre).
class LiveDatePicker extends ConsumerWidget {
  const LiveDatePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = ref.watch(formProvider.select((m) => m['l_at'] ?? ''));
    final label = at.isEmpty ? '' : l10When(at);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
        if (d == null || !context.mounted) return;
        final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 16, minute: 0));
        if (t == null || !context.mounted) return;
        ref.read(formProvider.notifier).put('l_at', DateTime(d.year, d.month, d.day, t.hour, t.minute).toIso8601String());
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Align(alignment: Alignment.centerLeft, child: Text(label.isEmpty ? 'Choisir la date et l’heure' : label, style: l10St(13.5, c: label.isEmpty ? l10Grey : l10Ink))),
      ),
    );
  }
}

const liveFormKeys = ['l_title', 'l_at', 'l_product', 'l_material'];

/// 224 : crée un live planifié réel (create_live) ; il apparaît dans l'agenda des ateliers et dans « Prochains lives ».
Future<void> saveLive(BuildContext context, WidgetRef ref, {required bool schedule}) async {
  if (!schedule) return gBack(context);
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'programmer un live') || !context.mounted) return;
  final f = ref.read(formProvider);
  final title = (f['l_title'] ?? '').trim();
  final at = DateTime.tryParse(f['l_at'] ?? '');
  final product = (f['l_product'] ?? '').trim();
  final material = (f['l_material'] ?? '').trim();
  final desc = [if (product.isNotEmpty) 'Produit mis en avant : $product', if (material.isNotEmpty) 'Matériel : $material'].join('\n');
  String? err;
  if (title.length < 3 || title.length > 100) {
    err = 'Indiquez le titre du live (3 à 100 caractères).';
  } else if (at == null) {
    err = 'Choisissez la date et l’heure du live.';
  } else if (at.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
    err = 'Choisissez une date et une heure à venir.';
  } else if (desc.length > 500) {
    err = 'Le produit et le matériel font ${desc.length} caractères : 500 au plus.';
  }
  if (err != null) return gAlert(context, 'Live incomplet', err);
  final r = await Backend.rpc('create_live', {'p_title': title, 'p_description': desc, 'p_cover_path': null, 'p_scheduled_at': at!.toUtc().toIso8601String()});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Live non programmé', r.error!);
  ref.read(formProvider.notifier).clear(liveFormKeys);
  ref.invalidate(livesAgendaProvider);
  gToast(context, 'Live programmé : il apparaît dans l’agenda des ateliers et dans « Prochains lives ».');
  gBack(context);
}
