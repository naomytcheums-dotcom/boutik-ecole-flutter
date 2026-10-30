import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'store.dart';

/// Messagerie réelle : conversations et messages enregistrés sur le serveur, visibles des seuls participants (RLS).
class ConversationItem {
  const ConversationItem({required this.id, required this.listingTitle, required this.otherName, required this.lastBody, required this.lastAt, required this.unread});
  final String id, listingTitle, otherName, lastBody;
  final DateTime? lastAt;
  final int unread;

  factory ConversationItem.fromRow(Map<String, dynamic> r) => ConversationItem(
        id: (r['id'] ?? '').toString(),
        listingTitle: (r['listing_title'] ?? '').toString(),
        otherName: (r['other_name'] ?? 'Utilisateur').toString(),
        lastBody: (r['last_body'] ?? '').toString(),
        lastAt: DateTime.tryParse((r['last_at'] ?? '').toString())?.toLocal(),
        unread: (r['unread'] as num?)?.toInt() ?? 0,
      );
}

class Conversations extends Notifier<List<ConversationItem>> {
  @override
  List<ConversationItem> build() {
    if (!Backend.ready) return const [];
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(refresh);
      final t = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
      ref.onDispose(t.cancel);
    }
    return const [];
  }

  Future<void> refresh() async {
    final rows = await Backend.conversations();
    if (!ref.mounted) return;
    state = [for (final r in rows) ConversationItem.fromRow(r)];
  }
}

final conversationsProvider = NotifierProvider<Conversations, List<ConversationItem>>(Conversations.new);

/// Conversation ouverte (identifiant serveur).
final selectedConversationProvider = NotifierProvider<StrV, String>(StrV.new);

final selectedConversationItemProvider = Provider<ConversationItem?>((ref) {
  final id = ref.watch(selectedConversationProvider);
  for (final c in ref.watch(conversationsProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

String _ago(DateTime? d) {
  if (d == null) return '';
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'À l’instant';
  if (m < 60) return '$m min';
  if (m < 1440) return '${m ~/ 60} h';
  return '${m ~/ 1440} j';
}

TextStyle _t(double size, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  return p.isEmpty ? '?' : (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Liste réelle des conversations (écran 52).
Widget conversationsPanel() => gP(
      24, 180, 342, 560,
      Consumer(builder: (context, ref, _) {
        final items = ref.watch(conversationsProvider);
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
            child: Align(
              alignment: Alignment.topCenter,
              child: Text('Aucune conversation pour le moment.\nOuvrez une commande ou une annonce, puis touchez « Contacter le vendeur ».', textAlign: TextAlign.center, style: _t(13, FontWeight.w500, const Color(0xFF66636E)).copyWith(height: 1.5)),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72, color: Color(0xFFF2EFF6)),
          itemBuilder: (context, i) {
            final c = items[i];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                ref.read(selectedConversationProvider.notifier).set(c.id);
                gOpen(context, '53');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Color(0xFFEDE9F6), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(_initials(c.otherName), style: _t(15, FontWeight.w600, const Color(0xFF4A4854))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(13.5, FontWeight.w600, const Color(0xFF111015))),
                      const SizedBox(height: 3),
                      Text(c.lastBody, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(11.5, c.unread > 0 ? FontWeight.w600 : FontWeight.w400, const Color(0xFF66636E))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_ago(c.lastAt), style: _t(10.5, FontWeight.w400, const Color(0xFF9A98A3))),
                    const SizedBox(height: 6),
                    if (c.unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF5A3FE0), borderRadius: BorderRadius.circular(10)),
                        child: Text('${c.unread}', style: _t(11, FontWeight.w700, Colors.white)),
                      ),
                  ]),
                ]),
              ),
            );
          },
        );
      }),
      show: !demoContent,
    );

/// Titre de l'écran 53 : interlocuteur réel. Hors connexion, le nom d'exemple de la maquette est conservé.
Widget chatHeaderName(String demo) => gP(
      76, 70, 240, 26,
      Consumer(builder: (context, ref, _) {
        final c = ref.watch(selectedConversationItemProvider);
        final t = demoContent ? demo : (c?.otherName ?? 'Conversation');
        return Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(21, FontWeight.w700, const Color(0xFF111015)));
      }),
    );

Widget chatHeaderSub() => gP(
      76, 96, 240, 15,
      Consumer(builder: (context, ref, _) {
        final c = ref.watch(selectedConversationItemProvider);
        if (demoContent) return Text('En ligne', style: _t(12, FontWeight.w400, const Color(0xFF66636E)));
        return Text(c == null || c.listingTitle.isEmpty ? '' : 'À propos de « ${c.listingTitle} »', maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(12, FontWeight.w400, const Color(0xFF66636E)));
      }),
    );

/// « Contacter le vendeur » : ouvre (ou retrouve) la conversation avec le vendeur du produit. Un compte est demandé à ce moment seulement.
Future<void> contactSeller(WidgetRef ref, BuildContext context, String productTitle) async {
  if (!Backend.ready) {
    gToast(context, 'La messagerie nécessite la connexion au serveur.');
    return;
  }
  if (!await requireLogin(context, ref, 'écrire au vendeur')) return;
  if (!context.mounted) return;
  final info = await Backend.listingContact(productTitle);
  if (!context.mounted) return;
  if (info == null) return gAlert(context, 'Annonce introuvable', 'Ce produit n’est plus disponible à la vente.');
  if (!info.hasSeller) {
    return gAlert(context, 'Produit de la plateforme', 'Ce produit est vendu directement par Boutik-École : il n’a pas de vendeur étudiant à qui écrire.');
  }
  final r = await Backend.startConversation(info.listingId, 'Bonjour, je vous contacte au sujet de « $productTitle ».');
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Message non envoyé', r.error!);
  ref.read(selectedConversationProvider.notifier).set(r.id!);
  await ref.read(conversationsProvider.notifier).refresh();
  if (context.mounted) gOpen(context, '53');
}

/// Titre du produit de la dernière commande consultée (contexte des boutons « Contacter le vendeur »).
String viewedOrderProductTitle(WidgetRef ref) {
  final o = ref.read(viewedOrderProvider);
  return o.lines.isEmpty ? '' : o.lines.first.title;
}
