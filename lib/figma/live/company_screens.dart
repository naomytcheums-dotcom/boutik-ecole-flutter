import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'package:go_router/go_router.dart';
import 'form_options.dart';
import 'coequipiers_screens.dart' show MateNavPill;
import 'tp_ui.dart' show GlassBack;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'share.dart' show openUrl;
import 'social_posts.dart' show uploadPostMedia;

/// Profil Entreprise : fiche (nom, secteur, taille, ville, site, interlocuteur, présentation, logo), pièces justificatives et vérification par
/// l'administrateur. Tout vient du serveur (migration 20261114002500) ; les pièces restent dans le compartiment privé de la personne.

const companySizes = {'': 'Taille non indiquée', '1-10': '1 à 10 personnes', '11-50': '11 à 50 personnes', '51-200': '51 à 200 personnes', '201-1000': '201 à 1 000 personnes', '1000+': 'Plus de 1 000 personnes'};
const companyDocKinds = {
  'registration': 'Immatriculation (RCCM)',
  'tax': 'Numéro fiscal (NIU)',
  'mandate': 'Lettre de représentation',
  'attestation': 'Attestation',
  'other': 'Autre pièce',
};

/// Libellé du statut de vérification d'une entreprise.
String companyStatusLabel(String s) => switch (s) {
      'pending' => 'En cours de vérification par l’administrateur',
      'approved' => 'Entreprise vérifiée',
      'rejected' => 'Vérification refusée',
      _ => 'Brouillon : pas encore envoyée pour vérification',
    };

Color companyStatusColor(String s) => switch (s) {
      'approved' => kGreen,
      'rejected' => kRed,
      'pending' => const Color(0xFFB45309),
      _ => kGrey,
    };

/// Vrai pour une adresse web complète (même règle que le serveur).
bool validCompanyWebsite(String s) => s.trim().isEmpty || RegExp(r'^https?://[^ ]+$', caseSensitive: false).hasMatch(s.trim());

/// Entreprise consultée : null = la mienne ; sinon l'entreprise dont je suis membre (espace partagé).
class CompanyContext extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final companyContextProvider = NotifierProvider<CompanyContext, String?>(CompanyContext.new);

const companyRoleLabels = {'owner': 'Propriétaire', 'admin': 'Administrateur', 'finance': 'Finance', 'viewer': 'Lecteur'};

final companyProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final ctx = ref.watch(companyContextProvider);
  final r = await marcheCall('company_get', {if (ctx != null) 'p_owner': ctx});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
});

final companyQueueProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('company_queue', const {});
  if (r.error != null) throw MarcheException(r.error);
  return [for (final x in (r.data as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
});

Widget _field(TextEditingController c, String label, {String? hint, TextInputType? type, int lines = 1, int? max}) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(controller: c, keyboardType: type, maxLines: lines, maxLength: max, decoration: InputDecoration(labelText: label, hintText: hint, counterText: '', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)))),
    );

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key, this.showNav = true});
  final bool showNav;

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyState();
}

class _CompanyState extends ConsumerState<CompanyProfileScreen> {
  final _name = TextEditingController(), _sector = TextEditingController(), _city = TextEditingController(), _site = TextEditingController(), _phone = TextEditingController();
  final _contact = TextEditingController(), _role = TextEditingController(), _desc = TextEditingController(), _year = TextEditingController(), _reg = TextEditingController();
  String _sectorPick = '', _size = '', _docKind = 'registration', _logo = '';
  bool _filled = false, _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _sector, _city, _site, _phone, _contact, _role, _desc, _year, _reg]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic>? c) {
    if (_filled) return;
    _filled = true;
    if (c == null) {
      _phone.text = ref.read(authProvider).current?.phone ?? '';
      return;
    }
    _name.text = '${c['company_name'] ?? ''}';
    _sector.text = '${c['sector'] ?? ''}';
    _sectorPick = _sector.text.isEmpty ? '' : (companySectors.contains(_sector.text) ? _sector.text : companySectorOther);
    _city.text = '${c['city'] ?? ''}';
    _site.text = '${c['website'] ?? ''}';
    _phone.text = '${c['phone'] ?? ''}'.isNotEmpty ? '${c['phone']}' : (ref.read(authProvider).current?.phone ?? '');
    _contact.text = '${c['contact_name'] ?? ''}';
    _role.text = '${c['contact_role'] ?? ''}';
    _desc.text = '${c['description'] ?? ''}';
    _year.text = c['founded_year'] == null ? '' : '${c['founded_year']}';
    _reg.text = '${c['registration_number'] ?? ''}';
    _size = '${c['size'] ?? ''}';
    _logo = '${c['logo_path'] ?? ''}';
  }

  Future<bool> _save() async {
    if (!validCompanyWebsite(_site.text)) {
      gToast(context, 'Le site doit commencer par https://');
      return false;
    }
    setState(() => _busy = true);
    final ctx = ref.read(companyContextProvider);
    final r = await marcheCall('company_save', {
      if (ctx != null) 'p_owner': ctx,
      'p': {
        'company_name': _name.text,
        'sector': _sector.text,
        'size': _size,
        'city': _city.text,
        'website': _site.text,
        'phone': _phone.text,
        'contact_name': _contact.text,
        'contact_role': _role.text,
        'description': _desc.text,
        'founded_year': _year.text.trim().isEmpty ? null : int.tryParse(_year.text.trim()),
        'registration_number': _reg.text,
        if (_logo.isNotEmpty) 'logo_path': _logo,
      }
    });
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage('${r.error}'));
      return false;
    }
    ref.invalidate(companyProvider);
    return true;
  }

  Future<void> _pickLogo() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !mounted) return;
    final up = await uploadPostMedia(context, p.first);
    if (up == null || !mounted) return;
    setState(() => _logo = up.path);
    gToast(context, 'Logo ajouté : touchez « Enregistrer » pour le conserver.');
  }

  Future<void> _addDoc() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !mounted) return;
    if (!await _save() || !mounted) return;
    final f = p.first;
    final Uint8List bytes = await f.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 10 * 1024 * 1024) return gToast(context, 'Fichier trop lourd : 10 Mo au plus.');
    final ext = f.name.split('.').last.toLowerCase();
    final mime = const {'pdf': 'application/pdf', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'}[ext];
    if (mime == null) return gToast(context, 'Format refusé : PDF, JPG, PNG ou WebP.');
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final path = '$uid/company/${DateTime.now().microsecondsSinceEpoch}.$ext';
    try {
      await Supabase.instance.client.storage.from('profile-documents').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    } catch (_) {
      if (mounted) gToast(context, 'Envoi impossible. Vérifiez votre connexion.');
      return;
    }
    final r = await marcheCall('company_doc_add', {'p_kind': _docKind, 'p_name': f.name, 'p_path': path, 'p_mime': mime, 'p_size': bytes.length});
    if (!mounted) return;
    if (r.error != null) {
      try {
        await Supabase.instance.client.storage.from('profile-documents').remove([path]);
      } catch (_) {}
      return gToast(context, Backend.userMessage('${r.error}'));
    }
    ref.invalidate(companyProvider);
    gToast(context, 'Pièce ajoutée.');
  }

  Future<void> _deleteDoc(Map<String, dynamic> d) async {
    final r = await marcheCall('company_doc_delete', {'p_id': d['id']});
    if (!mounted) return;
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    try {
      await Supabase.instance.client.storage.from('profile-documents').remove(['${r.data}']);
    } catch (_) {}
    ref.invalidate(companyProvider);
  }

  Future<void> _submit() async {
    if (!await _save() || !mounted) return;
    final r = await marcheCall('company_submit', const {});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Demande envoyée. L’administrateur vérifie vos pièces.');
    ref.invalidate(companyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyProvider);
    final body = mAsync<Map<String, dynamic>?>(async, (c) {
      _fill(c);
      final status = '${c?['status'] ?? 'draft'}';
      final docs = [for (final x in (c?['documents'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      final myRole = '${c?['my_role'] ?? 'owner'}';
      final isOwner = myRole == 'owner';
      final canEdit = myRole == 'owner' || myRole == 'admin';
      final locked = status == 'pending' || !canEdit;
      return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, widget.showNav ? 130 : 40), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: companyStatusColor(status).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(status == 'approved' ? Icons.verified : Icons.info_outline, color: companyStatusColor(status)), const SizedBox(width: 8), Expanded(child: Text(companyStatusLabel(status), style: mst(13.5, w: FontWeight.w800, c: companyStatusColor(status))))]),
            if ('${c?['review_note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif : ${c!['review_note']}', style: mst(12.5, c: kInk))),
            if (status != 'approved') Padding(padding: const EdgeInsets.only(top: 6), child: Text('Votre entreprise doit être vérifiée par l’administrateur : complétez la fiche, ajoutez vos pièces justificatives, puis envoyez la demande.', style: mst(12, c: kGrey).copyWith(height: 1.4))),
          ]),
        ),
        if (!canEdit) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Lecture seule : votre rôle (${companyRoleLabels[myRole] ?? myRole}) ne permet pas de modifier la fiche.', style: mst(12.5, w: FontWeight.w600, c: kGrey))),
        const SizedBox(height: 14),
        Row(children: [
          GestureDetector(
            onTap: canEdit ? _pickLogo : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: const Color(0xFFEFEBFA), borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: _logo.isEmpty ? const Icon(Icons.add_photo_alternate_outlined, color: kViolet) : gNetImage(Backend.postMediaUrl(_logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.business, color: kViolet)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Logo de l’entreprise (touchez pour choisir)', style: mst(12.5, c: kGrey))),
        ]),
        const SizedBox(height: 14),
        _field(_name, 'Nom de l’entreprise', max: 120),
        MDropdown(
          label: 'Secteur d’activité',
          value: _sectorPick,
          items: {'': 'Choisir un secteur', for (final x in companySectors) x: x, companySectorOther: 'Autre (je l’écris)'},
          onChanged: (v) => setState(() {
            _sectorPick = v;
            if (v != companySectorOther) _sector.text = v;
          }),
        ),
        const SizedBox(height: 10),
        if (_sectorPick == companySectorOther) _field(_sector, 'Votre secteur d’activité', max: 80),
        MDropdown(label: 'Taille', value: _size, items: companySizes, onChanged: (v) => setState(() => _size = v)),
        const SizedBox(height: 10),
        _field(_city, 'Ville', max: 80),
        _field(_site, 'Site web', hint: 'https://…', type: TextInputType.url),
        _field(_phone, 'Téléphone', type: TextInputType.phone, max: 30),
        _field(_year, 'Année de création', type: TextInputType.number, max: 4),
        _field(_reg, 'Numéro d’immatriculation (RCCM)', max: 60),
        _field(_desc, 'Présentation', lines: 4, max: 1500),
        const SizedBox(height: 4),
        if (isOwner) ...[
        mSectionTitle('Pièces justificatives'),
        Text('Elles ne sont visibles que de vous et de l’administrateur.', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        for (final d in docs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: kViolet),
            title: Text('${d['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w600)),
            subtitle: Text(companyDocKinds['${d['kind']}'] ?? '${d['kind']}', style: mst(12, c: kGrey)),
            trailing: locked ? null : IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteDoc(d)),
          ),
        if (docs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune pièce pour le moment.', style: mst(13, c: kGrey))),
        MDropdown(label: 'Type de pièce', value: _docKind, items: companyDocKinds, onChanged: (v) => setState(() => _docKind = v)),
        const SizedBox(height: 8),
        mButton('Ajouter une pièce', locked ? null : _addDoc, dark: false, icon: Icons.upload_file),
        ],
        const SizedBox(height: 16),
        if (isOwner && (status == 'draft' || status == 'rejected'))
          mButton(status == 'rejected' ? 'Enregistrer et renvoyer pour vérification' : 'Enregistrer et envoyer pour vérification', locked ? null : _submit, busy: _busy, icon: Icons.send_outlined)
        else
          mButton('Enregistrer la fiche', locked ? null : () => _save().then((ok) { if (ok && mounted) gToast(context, 'Fiche enregistrée.'); }), busy: _busy),
      ]);
    });
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 8, 16, 4), child: Row(children: [GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03')), Expanded(child: Text('Fiche entreprise', textAlign: TextAlign.center, style: mst(20, w: FontWeight.w800))), const SizedBox(width: 44)])),
            Expanded(child: body),
          ]),
          if (widget.showNav) const Positioned(left: 0, right: 0, bottom: 14, child: Center(child: MateNavPill())),
        ]),
      ),
    );
  }
}

/// File de vérification de l'administrateur : fiche, pièces (lien temporaire de 10 minutes), valider ou refuser avec motif.
class CompanyReviewScreen extends ConsumerWidget {
  const CompanyReviewScreen({super.key});

  Future<void> _open(BuildContext context, Map<String, dynamic> d) async {
    try {
      final url = await Supabase.instance.client.storage.from('profile-documents').createSignedUrl('${d['path']}', 600);
      if (context.mounted) await openUrl(context, url);
    } catch (_) {
      if (context.mounted) gToast(context, 'Pièce illisible ou supprimée.');
    }
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, Map<String, dynamic> c, bool approve) async {
    var note = '';
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Motif du refus'),
          content: TextField(controller: ctl, maxLines: 3, maxLength: 500, autofocus: true),
          actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Refuser'))],
        ),
      );
      note = ctl.text;
      ctl.dispose();
      if (ok != true || !context.mounted) return;
    }
    final r = await marcheCall('company_decide', {'p_owner': c['owner_id'], 'p_approve': approve, 'p_note': note});
    if (!context.mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (approve ? 'Entreprise vérifiée.' : 'Demande refusée.'));
    ref.invalidate(companyQueueProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Entreprises à vérifier',
      child: mAsync<List<Map<String, dynamic>>>(
        ref.watch(companyQueueProvider),
        (l) => l.isEmpty
            ? mNote('Aucune entreprise en attente.\nLes demandes de vérification apparaissent ici.')
            : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                for (final c in l)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c['company_name']}', style: mst(16, w: FontWeight.w800)),
                      Text([for (final k in ['sector', 'city']) if ('${c[k] ?? ''}'.isNotEmpty) '${c[k]}', if ('${c['size'] ?? ''}'.isNotEmpty) companySizes['${c['size']}'] ?? ''].join(' · '), style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 6),
                      Text('Interlocuteur : ${c['contact_name']}${'${c['contact_role'] ?? ''}'.isEmpty ? '' : ' (${c['contact_role']})'}', style: mst(12.5)),
                      Text('Téléphone : ${c['phone']} · E-mail du compte : ${c['email'] ?? ''}', style: mst(12.5)),
                      if ('${c['registration_number'] ?? ''}'.isNotEmpty) Text('Immatriculation : ${c['registration_number']}', style: mst(12.5)),
                      if ('${c['website'] ?? ''}'.isNotEmpty) Text('Site : ${c['website']}', style: mst(12.5, c: kViolet)),
                      if ('${c['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c['description']}', maxLines: 5, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey).copyWith(height: 1.4))),
                      const SizedBox(height: 8),
                      Text('Pièces justificatives', style: mst(13, w: FontWeight.w800)),
                      for (final d in (c['documents'] as List? ?? const []))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined, color: kViolet),
                          title: Text('${(d as Map)['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13, w: FontWeight.w600)),
                          subtitle: Text(companyDocKinds['${d['kind']}'] ?? '${d['kind']}', style: mst(11.5, c: kGrey)),
                          trailing: TextButton(onPressed: () => _open(context, Map<String, dynamic>.from(d)), child: Text('Voir')),
                        ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: mButton('Refuser', () => _decide(context, ref, c, false), dark: false)),
                        const SizedBox(width: 10),
                        Expanded(child: mButton('Valider', () => _decide(context, ref, c, true))),
                      ]),
                    ]),
                  ),
              ]),
      ),
    );
  }
}
