import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart' show gToast;
import 'company_home.dart' show frDate;
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Ressources numériques (migration 20261126050000) : « Mes téléchargements » côté acheteur et mention sur la fiche produit.
/// Le droit de téléchargement naît côté serveur quand la commande est payée ; l'URL est signée pour 60 s après vérification serveur
/// (paiement, remboursement, limite). Aucune ressource n'est inventée : tout vient de `my_downloads` / `product_digital_info`.

const licenseKindLabels = {'personal': 'Personnelle', 'commercial': 'Commerciale', 'educational': 'Éducative'};

String digitalSizeText(Object? bytes) {
  final n = ((bytes as num?) ?? 0).toInt();
  if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  if (n >= 1024) return '${(n / 1024).round()} Ko';
  return '$n o';
}

String digitalFormatOf(Map<String, dynamic> f) {
  final name = '${f['file_name'] ?? ''}';
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) return name.substring(dot + 1).toUpperCase();
  final mime = '${f['mime_type'] ?? ''}';
  return mime.contains('/') ? mime.split('/').last.toUpperCase() : (f['format'] ?? '').toString();
}

/// Création de l'URL signée courte (le serveur a posé un ticket de 60 s, sans lequel le stockage refuse). Remplaçable dans les tests.
@visibleForTesting
Future<String?> Function(String bucket, String path, int seconds) digitalSigner = (bucket, path, seconds) async {
  try {
    return await Supabase.instance.client.storage.from(bucket).createSignedUrl(path, seconds);
  } catch (_) {
    return null;
  }
};

/// Ouverture de l'URL signée. Remplaçable dans les tests.
@visibleForTesting
Future<bool> Function(String url) digitalOpener = (url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
};

class DownloadsException implements Exception {
  DownloadsException(this.message);
  final String message;
  @override
  String toString() => message;
}

final myDownloadsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await marcheCall('my_downloads', const {});
  if (r.error != null) {
    final e = r.error!;
    throw DownloadsException(e == 'offline'
        ? 'Vos téléchargements sont disponibles une fois l’application connectée au serveur.'
        : (e == 'missing' ? 'Les téléchargements ne sont pas encore installés sur le serveur.' : Backend.userMessage(e)));
  }
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
}, retry: (_, _) => null);

final digitalInfoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final r = await marcheCall('product_digital_info', {'p_listing': id});
  if (r.error != null) {
    // hors connexion ou fonction absente : la fiche s'affiche sans mention (rien n'est inventé)
    if (r.error == 'offline' || r.error == 'missing') return const {'digital': false};
    throw DownloadsException(Backend.userMessage(r.error!));
  }
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const {'digital': false};
}, retry: (_, _) => null);

/// Demande l'URL au serveur (qui compte et journalise le téléchargement) puis l'ouvre ; renvoie le message à afficher.
Future<String> startDigitalDownload(String orderLine, String assetId) async {
  final r = await Backend.rpc('digital_download_url', {'p_order_line': orderLine, 'p_asset': assetId});
  if (r.error != null) return Backend.userMessage(r.error!);
  final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const <String, dynamic>{};
  final path = '${d['path'] ?? ''}';
  if (path.isEmpty) return 'Le serveur n’a pas renvoyé de fichier. Réessayez.';
  final secs = ((d['expires_in'] as num?) ?? 60).toInt();
  final url = await digitalSigner('${d['bucket'] ?? 'digital-files'}', path, secs);
  if (url == null || url.isEmpty) return 'Le lien de téléchargement n’a pas pu être créé (ce téléchargement a été compté). Réessayez dans un instant.';
  if (!await digitalOpener(url)) return 'Impossible d’ouvrir le téléchargement. Réessayez.';
  return 'Téléchargement lancé : ${d['file_name'] ?? 'fichier'}';
}

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String? busyKey;

  Future<void> _download(Map<String, dynamic> it, Map<String, dynamic> f) async {
    final key = '${it['order_line']}/${f['id']}';
    if (busyKey != null) return;
    setState(() => busyKey = key);
    final msg = await startDigitalDownload('${it['order_line']}', '${f['id']}');
    if (!mounted) return;
    setState(() => busyKey = null);
    gToast(context, msg);
    ref.invalidate(myDownloadsProvider);
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Mes téléchargements',
        child: ref.watch(myDownloadsProvider).when(
              loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                mNote(e is DownloadsException ? e.message : Backend.userMessage('$e')),
                mButton('Réessayer', () => ref.invalidate(myDownloadsProvider), dark: false),
              ]),
              data: (items) => items.isEmpty
                  ? mNote('Vous n’avez aucune ressource numérique pour le moment. Une ressource achetée apparaît ici dès que son paiement est confirmé.')
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [for (final it in items) _card(it)]),
            ),
      );

  Widget _card(Map<String, dynamic> it) {
    final revoked = it['status'] == 'revoked';
    final used = mInt(it['downloads_used']), max = mInt(it['max_downloads']);
    final limitReached = !revoked && used >= max;
    final files = [for (final f in (it['files'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
    final history = [for (final h in (it['history'] as List? ?? const [])) Map<String, dynamic>.from(h as Map)];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${it['title']}', style: mst(15, w: FontWeight.w800)),
        Text('Commande ${it['order_number']}', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        Text(revoked ? 'Accès révoqué : ${it['reason'] ?? 'téléchargement impossible'}' : (limitReached ? 'Limite de téléchargements atteinte ($used sur $max)' : 'Disponible · $used téléchargement${used > 1 ? 's' : ''} sur $max'),
            style: mst(12.5, w: FontWeight.w700, c: revoked ? kRed : (limitReached ? kRed : kGreen))),
        const SizedBox(height: 6),
        Text('Licence ${(licenseKindLabels['${it['license_kind']}'] ?? '').toLowerCase()} : ${it['license_label'] ?? ''}', style: mst(12.5, c: kGrey)),
        if (!revoked && files.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucun fichier disponible pour le moment : contactez le vendeur.', style: mst(12.5, c: kGrey))),
        for (final f in files)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              const Icon(Icons.insert_drive_file_outlined, size: 20, color: kViolet),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f['file_name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13, w: FontWeight.w700)),
                Text('${digitalFormatOf(f)} · ${digitalSizeText(f['size_bytes'])} · version ${f['version']}', style: mst(12, c: kGrey)),
              ])),
              mButton('Télécharger', limitReached || busyKey != null ? null : () => _download(it, f), dark: false, busy: busyKey == '${it['order_line']}/${f['id']}', icon: Icons.download_outlined),
            ]),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Derniers téléchargements : ${history.map((h) => '${h['file_name']} (${frDate(h['at'])})').join(', ')}', style: mst(11.5, c: kGrey)),
        ],
      ]),
    );
  }
}

/// Mention sur la fiche produit : ressource numérique, licence (libellé du vendeur), formats, tailles, versions et limite de téléchargements.
class DigitalProductInfo extends ConsumerWidget {
  const DigitalProductInfo({super.key, required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready || listingId.isEmpty) return const SizedBox.shrink();
    return ref.watch(digitalInfoProvider(listingId)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('Informations de licence indisponibles pour le moment.', style: mst(12.5, c: kGrey))),
          data: (d) {
            if (d['digital'] != true) return const SizedBox.shrink();
            final files = [for (final f in (d['files'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.cloud_download_outlined, color: kViolet), const SizedBox(width: 8), Expanded(child: Text('Ressource numérique', style: mst(14.5, w: FontWeight.w800)))]),
                const SizedBox(height: 6),
                Text('Licence ${(licenseKindLabels['${d['license_kind']}'] ?? '').toLowerCase()} : ${d['license_label'] ?? ''}', style: mst(13, w: FontWeight.w600)),
                for (final f in files) Text('${digitalFormatOf(f)} · ${digitalSizeText(f['size_bytes'])} · version ${f['version']}', style: mst(12.5, c: kGrey)),
                const SizedBox(height: 4),
                Text('Aucun envoi physique : le téléchargement s’ouvre dans « Mes téléchargements » dès que le paiement est confirmé (${mInt(d['max_downloads'])} téléchargement${mInt(d['max_downloads']) > 1 ? 's' : ''} au maximum).', style: mst(12, c: kGrey)),
              ]),
            );
          },
        );
  }
}
