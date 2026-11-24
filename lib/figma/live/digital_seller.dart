import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;

import '../gen.dart' show gToast;
import 'backend.dart';
import 'downloads.dart' show digitalFormatOf, digitalSizeText, licenseKindLabels;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Formulaire vendeur « Ressource numérique » (migration 20261126050000) : licence (type + libellé saisi par le vendeur), limite de téléchargements,
/// fichiers téléversés dans le compartiment PRIVÉ `digital-files`, versions, soumission à la validation. La plateforme ne rédige aucun texte juridique.

const digitalMaxBytes = 50 * 1024 * 1024;

const _mimeByExt = {
  'pdf': 'application/pdf',
  'zip': 'application/zip',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'mp4': 'video/mp4',
  'mp3': 'audio/mpeg',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'glb': 'model/gltf-binary',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};

/// Choix d'un fichier sur l'appareil (nom, octets) ; remplaçable dans les tests.
@visibleForTesting
Future<({String name, Uint8List bytes})?> Function() pickDigitalFile = () async {
  try {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _mimeByExt.keys.toList());
    if (r.isEmpty) return null;
    return (name: r.first.name, bytes: await r.first.readAsBytes());
  } catch (_) {
    return null;
  }
};

class DigitalResourceScreen extends StatefulWidget {
  const DigitalResourceScreen({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  State<DigitalResourceScreen> createState() => _DigitalResourceScreenState();
}

class _DigitalResourceScreenState extends State<DigitalResourceScreen> {
  final label = TextEditingController();
  final maxDl = TextEditingController(text: '5');
  final version = TextEditingController(text: '1.0');
  String kind = 'personal';
  bool loading = true, busy = false, digital = false;
  String? loadError, error;
  late String status = '${widget.listing['status'] ?? 'draft'}';
  List<Map<String, dynamic>> assets = const [];
  List<Map<String, dynamic>> sales = const [];

  String get id => '${widget.listing['id']}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    label.dispose();
    maxDl.dispose();
    version.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    final r = await marcheCall('my_digital_listing', {'p_listing': id});
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        loading = false;
        loadError = r.error == 'offline' ? 'Disponible une fois l’application connectée au serveur.' : (r.error == 'missing' ? 'Les ressources numériques ne sont pas encore installées sur le serveur.' : Backend.userMessage(r.error!));
      });
      return;
    }
    final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
    final s = await marcheCall('seller_digital_sales', const {});
    if (!mounted) return;
    setState(() {
      loading = false;
      digital = d['digital'] == true;
      if (digital) {
        kind = '${d['license_kind']}';
        label.text = '${d['license_label'] ?? ''}';
        maxDl.text = '${d['max_downloads'] ?? 5}';
      }
      assets = [for (final a in (d['assets'] as List? ?? const [])) Map<String, dynamic>.from(a as Map)];
      final all = s.data is List ? [for (final x in (s.data as List)) Map<String, dynamic>.from(x as Map)] : const <Map<String, dynamic>>[];
      sales = [for (final x in all) if ('${x['listing_id']}' == id) x];
    });
  }

  Future<void> _saveLicense() async {
    final n = int.tryParse(maxDl.text.trim());
    if (label.text.trim().length < 3) return setState(() => error = 'Décrivez votre licence (3 caractères minimum) : ce texte est le vôtre, il est affiché tel quel à l’acheteur.');
    if (n == null || n < 1 || n > 50) return setState(() => error = 'La limite de téléchargements doit être comprise entre 1 et 50.');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.rpc('digital_listing_save', {'p_listing': id, 'p_kind': kind, 'p_label': label.text.trim(), 'p_max': n});
    if (!mounted) return;
    setState(() {
      busy = false;
      error = r.error == null ? null : Backend.userMessage(r.error!);
      if (r.error == null) digital = true;
    });
    if (r.error == null) {
      gToast(context, 'Licence enregistrée.');
      await _load();
    }
  }

  Future<void> _addFile({String? replaces}) async {
    if (!digital) return setState(() => error = 'Enregistrez d’abord la licence de cette ressource.');
    final uid = Backend.userId;
    if (uid == null) return setState(() => error = 'Connexion requise.');
    final picked = await pickDigitalFile();
    if (picked == null || !mounted) return;
    final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : '';
    final mime = _mimeByExt[ext];
    if (mime == null) return setState(() => error = 'Type de fichier refusé (PDF, ZIP, images, MP4, MP3, texte, documents Office, modèle 3D GLB).');
    if (picked.bytes.isEmpty || picked.bytes.length > digitalMaxBytes) return setState(() => error = 'Fichier trop lourd (50 Mo au maximum).');
    setState(() {
      busy = true;
      error = null;
    });
    final safe = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = '$uid/$id/${DateTime.now().microsecondsSinceEpoch}-$safe';
    final up = await Backend.uploadFile('digital-files', path, picked.bytes, mime);
    if (up != null) {
      if (!mounted) return;
      return setState(() {
        busy = false;
        error = up;
      });
    }
    final reg = await Backend.rpc('digital_asset_register', {'p_listing': id, 'p_path': path, 'p_name': picked.name, 'p_mime': mime, 'p_size': picked.bytes.length, 'p_version': version.text.trim().isEmpty ? '1.0' : version.text.trim(), 'p_replaces': replaces});
    if (reg.error != null) await Backend.removeFile('digital-files', path);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = reg.error == null ? null : Backend.userMessage(reg.error!);
    });
    if (reg.error == null) {
      gToast(context, 'Fichier ajouté : ${picked.name}');
      await _load();
    }
  }

  Future<void> _remove(Map<String, dynamic> a) async {
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.rpc('digital_asset_remove', {'p_asset': '${a['id']}'});
    if (!mounted) return;
    setState(() {
      busy = false;
      error = r.error == null ? null : Backend.userMessage(r.error!);
    });
    if (r.error == null) {
      gToast(context, 'Fichier retiré.');
      await _load();
    }
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    final err = await Backend.setListingStatus(id, 'pending');
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err == null ? null : Backend.userMessage(err);
      if (err == null) status = 'pending';
    });
    if (err == null) gToast(context, 'Ressource envoyée en validation.');
  }

  Widget _field(TextEditingController c, String l, {int lines = 1, TextInputType? type, String? hint, int? max}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, minLines: lines, maxLines: lines, keyboardType: type, maxLength: max, decoration: InputDecoration(labelText: l, hintText: hint, border: const OutlineInputBorder(), counterText: '')),
      );

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Ressource numérique',
        child: loading
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : loadError != null
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [mNote(loadError!), mButton('Réessayer', _load, dark: false)])
                : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                    Text('${widget.listing['title']}', style: mst(16, w: FontWeight.w800)),
                    Text('Les fichiers sont stockés dans un espace privé : seul un acheteur dont le paiement est confirmé peut les télécharger, dans la limite fixée ci-dessous.', style: mst(12.5, c: kGrey)),
                    const SizedBox(height: 14),
                    Text('Licence', style: mst(15, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final e in licenseKindLabels.entries) MChip(e.value, selected: kind == e.key, onTap: () {
                      if (!busy) setState(() => kind = e.key);
                    })]),
                    const SizedBox(height: 10),
                    _field(label, 'Conditions de la licence (votre texte)', lines: 3, max: 500, hint: 'Ex. usage dans un seul projet, redistribution interdite'),
                    Text('Ce texte est le vôtre : Boutik-École ne rédige ni ne valide vos conditions et l’affiche tel quel à l’acheteur.', style: mst(12, c: kGrey)),
                    const SizedBox(height: 10),
                    _field(maxDl, 'Téléchargements autorisés par achat (1 à 50)', type: TextInputType.number),
                    mButton('Enregistrer la licence', busy ? null : _saveLicense, busy: busy),
                    const SizedBox(height: 22),
                    Text('Fichiers (${assets.length}/10)', style: mst(15, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (!digital) Text('Enregistrez la licence pour pouvoir ajouter des fichiers.', style: mst(12.5, c: kGrey)),
                    if (digital && assets.isEmpty) Text('Aucun fichier pour le moment : une ressource sans fichier ne peut pas être publiée.', style: mst(12.5, c: kGrey)),
                    for (final a in assets)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${a['file_name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13, w: FontWeight.w700)),
                            Text('${digitalFormatOf(a)} · ${digitalSizeText(a['size_bytes'])} · version ${a['version']}', style: mst(12, c: kGrey)),
                          ])),
                          TextButton(onPressed: busy ? null : () => _addFile(replaces: '${a['id']}'), child: const Text('Nouvelle version')),
                          IconButton(tooltip: 'Retirer le fichier', constraints: const BoxConstraints(minWidth: 48, minHeight: 48), icon: const Icon(Icons.delete_outline), onPressed: busy ? null : () => _remove(a)),
                        ]),
                      ),
                    if (digital) ...[
                      _field(version, 'Version du fichier à ajouter', max: 30),
                      mButton('Ajouter un fichier', busy ? null : _addFile, dark: false, icon: Icons.upload_file_outlined),
                      const Padding(padding: EdgeInsets.only(top: 6), child: Text('PDF, ZIP, images, MP4, MP3, texte, documents Office, modèle 3D GLB · 50 Mo maximum par fichier.')),
                    ],
                    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: mst(13, w: FontWeight.w600, c: kRed))),
                    const SizedBox(height: 18),
                    if (digital && assets.isNotEmpty && (status == 'draft' || status == 'rejected')) mButton('Envoyer en validation', busy ? null : _submit, busy: busy),
                    if (status == 'pending') Text('Cette ressource est en validation.', style: mst(13, w: FontWeight.w700, c: kViolet)),
                    if (status == 'approved') Text('Cette ressource est publiée.', style: mst(13, w: FontWeight.w700, c: kGreen)),
                    const SizedBox(height: 22),
                    Text('Ventes de cette ressource', style: mst(15, w: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (sales.isEmpty) Text('Aucune vente pour le moment.', style: mst(12.5, c: kGrey)),
                    for (final s in sales)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('Commande ${s['order_number']} · ${s['status'] == 'revoked' ? 'accès révoqué' : 'accès ouvert'} · ${mInt(s['downloads_used'])}/${mInt(s['max_downloads'])} téléchargements', style: mst(12.5)),
                      ),
                  ]),
      );
}
