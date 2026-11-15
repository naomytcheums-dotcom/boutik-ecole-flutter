import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import '../gen.dart';
import '../nav.dart';
import 'access.dart' show roleKey;
import 'auth.dart';
import 'backend.dart';
import 'l10_ui.dart';
import 'store.dart' show IntV, fcfa;

/// Marché des vœux réel (écrans 216, 217, 218) : liste filtrée côté serveur (wishes_market), fiche d'un vœu (wish_get),
/// précommande = intention enregistrée (wish_preorder), sans paiement ni séquestre, et publication d'un vœu (save_wish).

final wishFilterProvider = NotifierProvider<IntV, int>(IntV.new);
const _wishFilters = ['all', 'near', 'new', 'mine'];

final wishesMarketProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final f = _wishFilters[ref.watch(wishFilterProvider).clamp(0, 3)];
  final r = await Backend.rpc('wishes_market', {'p_filter': f, 'p_limit': 50});
  if (r.error != null) throw r.error!;
  return l10Rows(r.data);
}, retry: (_, _) => null);

final wishDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  ref.watch(authProvider.select((a) => a.current?.email));
  final r = await Backend.rpc('wish_get', {'p_id': id});
  if (r.error != null) throw r.error!;
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

const wishFormKeys = ['w_title', 'w_desc', 'w_price', 'w_threshold', 'w_duration'];

/// Brouillon (ou vœu refusé) rouvert depuis « Mes vœux » : les champs du formulaire repartent de ses valeurs, jamais de saisies périmées.
final wishDraftProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final r = await Backend.rows('wishes', 'id,title,description,price,threshold,duration_days,status,review_note', eq: {'id': id}, limit: 1);
  if (r.error != null) throw r.error!;
  ref.read(formProvider.notifier).clear(wishFormKeys);
  return r.rows.isEmpty ? null : r.rows.first;
}, retry: (_, _) => null);

void openWish(BuildContext context, String id) => GoRouter.of(context).push('${screenPath('217')}?wish=${Uri.encodeQueryComponent(id)}');
void openWishEditor(BuildContext context, String id) => GoRouter.of(context).push('${screenPath('218')}?id=${Uri.encodeQueryComponent(id)}');

String _wishPrice(Object? p) => p is num ? fcfa(p.toInt()) : '—';

class WishesMarket extends ConsumerWidget {
  const WishesMarket({super.key, this.width = 342, this.height = 480});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(wishFilterProvider);
    if (f == 3 && ref.watch(authProvider.select((a) => a.current == null))) return l10Note(width, 'Connectez-vous pour retrouver vos précommandes.');
    final rows = ref.watch(wishesMarketProvider);
    return rows.when(
      loading: () => l10Note(width, 'Chargement…'),
      error: (_, _) => l10Note(width, 'Cette liste ne peut pas être chargée pour le moment.'),
      data: (list) {
        if (list.isEmpty) {
          return l10Note(width, const [
            'Aucun vœu ouvert pour le moment.\nLes vœux validés par le département apparaissent ici.',
            'Aucun vœu n’approche de son seuil pour le moment.',
            'Aucun nouveau vœu cette semaine.',
            'Vous n’avez encore précommandé aucun vœu.',
          ][f.clamp(0, 3)]);
        }
        return SizedBox(
          width: width,
          height: height,
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _WishCard(w: list[i]),
          ),
        );
      },
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({required this.w});
  final Map<String, dynamic> w;

  @override
  Widget build(BuildContext context) {
    final count = (w['count'] as num?)?.toInt() ?? 0;
    final threshold = (w['threshold'] as num?)?.toInt() ?? 0;
    return Semantics(
      button: true,
      label: 'Ouvrir le vœu ${w['title']}',
      child: l10Card(
        onTap: () => openWish(context, '${w['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${w['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: l10St(14, w: FontWeight.w800))),
            if (w['mine'] == true) l10Chip('Précommandé ✓', fill: const Color(0xFFDDF5EC), ink: const Color(0xFF0F7A52)),
          ]),
          const SizedBox(height: 2),
          Text('par ${w['author'] ?? 'un membre'}', style: l10St(11, c: l10Grey)),
          const SizedBox(height: 10),
          if (threshold > 0) ...[l10Progress(count / threshold), const SizedBox(height: 6)],
          Row(children: [
            Expanded(child: Text(threshold > 0 ? '$count / $threshold précommandes' : '$count précommande${count > 1 ? 's' : ''}', style: l10St(11.5, w: FontWeight.w600))),
            Text(_wishPrice(w['price']), style: l10St(13, w: FontWeight.w800, c: const Color(0xFFD98A00))),
          ]),
        ]),
      ),
    );
  }
}

/// Écran 217 en production : la fiche du vœu choisi (`?wish=<id>`), avec sa précommande.
class WishDetailScreen extends ConsumerWidget {
  const WishDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = l10Query(context, 'wish');
    return L10Screen(title: 'Fiche du vœu', child: id.isEmpty || !l10IsUuid(id) ? l10Note(342, 'Ce vœu est introuvable.\nOuvrez-le depuis le marché des vœux.') : WishDetail(id: id));
  }
}

class WishDetail extends ConsumerWidget {
  const WishDetail({super.key, required this.id, this.width = 342});
  final String id;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wishDetailProvider(id));
    return async.when(
      loading: () => l10Note(width, 'Chargement…'),
      error: (_, _) => l10Note(width, 'Ce vœu ne peut pas être chargé pour le moment.'),
      data: (w) {
        if (w == null) return l10Note(width, 'Ce vœu est introuvable ou n’est plus ouvert.');
        final count = (w['count'] as num?)?.toInt() ?? 0;
        final threshold = (w['threshold'] as num?)?.toInt() ?? 0;
        final open = w['open'] == true;
        final mine = w['mine'] == true;
        final author = w['is_author'] == true;
        final ends = DateTime.tryParse('${w['ends_at'] ?? ''}')?.toLocal();
        final closed = ends != null && ends.isBefore(DateTime.now());
        final reached = threshold > 0 && count >= threshold;
        return SizedBox(
          width: width,
          child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            Text('${w['title']}', style: l10St(22, w: FontWeight.w800, h: 1.25)),
            const SizedBox(height: 4),
            Text('Vœu de ${w['author'] ?? 'un membre'}', style: l10St(12, c: l10Grey)),
            const SizedBox(height: 16),
            if ('${w['description'] ?? ''}'.isNotEmpty) ...[
              Text('${w['description']}', style: l10St(13.5, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.55)),
              const SizedBox(height: 18),
            ],
            l10Card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(threshold > 0 ? '$count sur $threshold précommandes' : '$count précommande${count > 1 ? 's' : ''}', style: l10St(15, w: FontWeight.w800)),
                const SizedBox(height: 8),
                if (threshold > 0) l10Progress(count / threshold),
                const SizedBox(height: 8),
                Text(reached ? 'Le seuil est atteint : le créateur a été prévenu.' : (threshold > 0 ? 'Encore ${threshold - count} précommande${threshold - count > 1 ? 's' : ''} pour atteindre le seuil.' : ''), style: l10St(12, c: l10Grey)),
              ]),
            ),
            const SizedBox(height: 14),
            l10Card(
              child: Column(children: [
                _line('Prix prévu', _wishPrice(w['price'])),
                const Divider(height: 18, color: Color(0xFFF2EFF6)),
                _line('Durée de la campagne', w['duration_days'] == null ? '—' : '${w['duration_days']} jours'),
                if (ends != null) ...[const Divider(height: 18, color: Color(0xFFF2EFF6)), _line(closed ? 'Précommandes closes le' : 'Précommandes jusqu’au', l10Day(w['ends_at']))],
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(18)),
              child: Text('Précommander enregistre seulement votre intention d’achat. Aucun paiement n’est demandé et aucun montant n’est bloqué. Le créateur est prévenu à chaque palier ; il décide ensuite de lancer ou non la fabrication, et vous contactera si c’est le cas.', style: l10St(12, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.5)),
            ),
            if ('${w['review_note'] ?? ''}'.isNotEmpty) ...[const SizedBox(height: 12), Text('Note du département : ${w['review_note']}', style: l10St(12, c: l10Grey))],
            const SizedBox(height: 20),
            if (author)
              l10Note(width, 'C’est votre vœu : vous ne pouvez pas le précommander.', height: 60)
            else if (!open)
              l10Note(width, 'Ce vœu n’est pas ouvert aux précommandes.', height: 60)
            else if (mine)
              l10Btn('Annuler ma précommande', () => _preorder(context, ref, w, false), dark: false, width: width)
            else if (closed)
              l10Note(width, 'Les précommandes de ce vœu sont closes.', height: 60)
            else
              l10Btn('Précommander (sans paiement)', () => _preorder(context, ref, w, true), width: width),
          ]),
        );
      },
    );
  }

  Widget _line(String k, String v) => Row(children: [Expanded(child: Text(k, style: l10St(12.5, c: l10Grey))), Text(v, style: l10St(12.5, w: FontWeight.w700))]);
}

Future<void> _preorder(BuildContext context, WidgetRef ref, Map<String, dynamic> w, bool on) async {
  if (!await requireLogin(context, ref, 'précommander ce vœu') || !context.mounted) return;
  final r = await Backend.rpc('wish_preorder', {'p_wish': w['id'], 'p_on': on});
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, on ? 'Précommande impossible' : 'Annulation impossible', r.error!);
    return;
  }
  ref.invalidate(wishDetailProvider('${w['id']}'));
  ref.invalidate(wishesMarketProvider);
  gToast(context, on ? 'Intention de précommande enregistrée. Aucun paiement n’a été demandé.' : 'Précommande annulée.');
}

// ------------------------------------------------------------------ publication (218)

/// Id du brouillon ouvert (`?id=<id>`), vide pour un nouveau vœu.
String wishEditId(BuildContext context) {
  final id = l10Query(context, 'id');
  return l10IsUuid(id) ? id : '';
}

String wishDraftValue(Map<String, dynamic>? d, String key) {
  final v = d == null ? null : d[key];
  return v == null ? '' : '$v';
}

int? _num(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// 218 : enregistre un brouillon ou envoie le vœu. Les champs envoyés sont exactement ceux affichés (saisie, sinon valeur du brouillon ouvert).
Future<void> saveWish(BuildContext context, WidgetRef ref, {required bool submit, String editId = ''}) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'publier un vœu') || !context.mounted) return;
  if (!const {'client', 'student', 'dept', 'admin'}.contains(roleKey(ref.read(authProvider).current))) {
    return gAlert(context, 'Vœu réservé', 'Les vœux sont réservés aux clients, aux étudiants et au département.');
  }
  final f = ref.read(formProvider);
  final d = editId.isEmpty ? null : ref.read(wishDraftProvider(editId)).value;
  String val(String k, String dk) => f.containsKey(k) ? f[k]!.trim() : wishDraftValue(d, dk).trim();
  final title = val('w_title', 'title');
  final desc = val('w_desc', 'description');
  final price = _num(val('w_price', 'price'));
  final threshold = _num(val('w_threshold', 'threshold'));
  final days = _num(val('w_duration', 'duration_days'));
  String? err;
  if (title.length < 3 || title.length > 120) {
    err = 'Donnez un titre de 3 à 120 caractères.';
  } else if (desc.length > 2000) {
    err = 'La description fait ${desc.length} caractères : 2 000 au plus. Raccourcissez-la, rien n’est coupé automatiquement.';
  } else if (submit && (price == null || price <= 0)) {
    err = 'Indiquez le prix prévu (en FCFA).';
  } else if (submit && (threshold == null || threshold < 1)) {
    err = 'Indiquez le seuil minimum de précommandes.';
  } else if (days != null && (days < 1 || days > 180)) {
    err = 'La durée de la campagne va de 1 à 180 jours.';
  } else if (submit && days == null) {
    err = 'Indiquez la durée de la campagne (1 à 180 jours).';
  }
  if (err != null) return gAlert(context, submit ? 'Vœu incomplet' : 'Brouillon incomplet', err);
  final r = await Backend.rpc('save_wish', {
    'p_id': editId.isEmpty ? null : editId, 'p_title': title, 'p_description': desc, 'p_price': price, 'p_threshold': threshold, 'p_duration_days': days, 'p_submit': submit,
  });
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, submit ? 'Vœu non envoyé' : 'Brouillon non enregistré', r.error!);
  if (submit) {
    ref.read(formProvider.notifier).clear(wishFormKeys);
    gToast(context, 'Vœu envoyé : le département concerné le valide avant sa mise en ligne.');
    gBack(context);
    return;
  }
  gToast(context, 'Brouillon enregistré : retrouvez-le dans « Mes vœux ».');
  if (editId.isEmpty && '${r.data}'.isNotEmpty) GoRouter.of(context).pushReplacement('${screenPath('218')}?id=${Uri.encodeQueryComponent('${r.data}')}');
}
