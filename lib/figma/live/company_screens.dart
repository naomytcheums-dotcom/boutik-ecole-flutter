import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'access.dart' show roleKey;
import 'backend.dart';
import 'package:go_router/go_router.dart';
import 'form_options.dart';
import 'coequipiers_screens.dart' show MateNavPill;
import 'tp_ui.dart' show GlassBack;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'share.dart' show openUrl;
import 'social_posts.dart' show uploadPostMedia;
import 'company_billing.dart' show CompanyBillingCard, CompanyCoverCard;
import 'org_types.dart';

/// Profil Organisation (ancienne Entreprise) : fiche adaptée au TYPE d'organisation (entreprise commerciale, association, ONG, coopérative, fondation, institution,
/// structure partenaire, autre organisation reconnue), pièces justificatives exigées par type et vérification par l'administrateur.
/// Tout vient du serveur (migrations 20261114002500 et 20261120010000) ; les pièces restent dans le compartiment privé de la personne.

const companySizes = {'': 'Taille non indiquée', '1-10': '1 à 10 personnes', '11-50': '11 à 50 personnes', '51-200': '51 à 200 personnes', '201-1000': '201 à 1 000 personnes', '1000+': 'Plus de 1 000 personnes'};
const companyDocKinds = orgDocKindLabels;

/// Libellé du statut de vérification d'une organisation.
String companyStatusLabel(String s) => switch (s) {
      'pending' => 'En cours de vérification par l’administrateur',
      'approved' => 'Organisation vérifiée',
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

/// Champs obligatoires manquants avant l'envoi pour vérification (mêmes exigences que `company_submit` côté serveur : secteur, ville,
/// interlocuteur, téléphone, champs propres au type et pièces justificatives). Sans [docKinds], seul le nombre de pièces ([documents]) est contrôlé.
List<String> companyMissingForSubmit({
  required String sector,
  required String city,
  required String contact,
  required String phone,
  required int documents,
  OrgType? type,
  String registration = '',
  String tax = '',
  String mission = '',
  List<String>? docKinds,
}) {
  final t = type ?? orgTypeOf(kDefaultOrgType);
  return [
    if (sector.trim().isEmpty) 'le ${t.sectorLabel.toLowerCase()}',
    if (city.trim().isEmpty) 'la ville',
    if (contact.trim().isEmpty) 'l’interlocuteur',
    if (phone.trim().isEmpty) 'le téléphone',
    if (t.registrationRequired && registration.trim().isEmpty) 'le champ « ${t.registrationLabel} »',
    if (t.taxRequired && tax.trim().isEmpty) 'le NIU',
    if (t.missionRequired && mission.trim().isEmpty) 'la mission de l’organisation',
    ...(docKinds == null
        ? [if (documents <= 0) 'au moins une pièce justificative']
        : [for (final g in t.unmetGroups(docKinds)) 'la pièce justificative « ${t.groupLabel(g)} »']),
  ];
}

/// Message à afficher avant l'envoi quand [missing] n'est pas vide.
String companyMissingMessage(List<String> missing) => 'Pour envoyer la demande, renseignez : ${missing.join(', ')}.';

/// Contrôles de saisie de la fiche (null si tout est correct) : interlocuteur et fonction (80 caractères), site web, année de création.
String? companyFieldError({required String name, required String contact, required String role, required String website, required String year}) {
  if (name.trim().length < 2) return 'Indiquez le nom de l’organisation.';
  if (contact.trim().length > 80) return 'L’interlocuteur ne doit pas dépasser 80 caractères.';
  if (role.trim().length > 80) return 'La fonction ne doit pas dépasser 80 caractères.';
  if (!validCompanyWebsite(website)) return 'Le site doit commencer par https://';
  final y = year.trim();
  if (y.isNotEmpty) {
    final n = int.tryParse(y);
    if (n == null || n < 1900 || n > 2100) return 'L’année de création doit être comprise entre 1900 et 2100.';
  }
  return null;
}

/// Contenu envoyé à `company_save` / `company_submit` ; le logo n'est renvoyé que s'il vient d'être choisi (un administrateur de l'équipe ne recopie pas celui du propriétaire).
Map<String, dynamic> companySavePayload({
  required String name,
  required String sector,
  required String size,
  required String city,
  required String website,
  required String phone,
  required String contact,
  required String role,
  required String description,
  required String year,
  required String registration,
  String orgType = kDefaultOrgType,
  String tax = '',
  String mission = '',
  String? newLogoPath,
}) =>
    {
      'company_name': name.trim(),
      'org_type': orgType,
      'sector': sector.trim(),
      'size': size,
      'city': city.trim(),
      'website': website.trim(),
      'phone': phone.trim(),
      'contact_name': contact.trim(),
      'contact_role': role.trim(),
      'description': description,
      'founded_year': year.trim().isEmpty ? null : int.tryParse(year.trim()),
      'registration_number': registration.trim(),
      'tax_number': tax.trim(),
      'mission': mission.trim(),
      if (newLogoPath != null && newLogoPath.isNotEmpty) 'logo_path': newLogoPath,
    };

/// Entreprise consultée : null = la mienne ; sinon l'entreprise dont je suis membre (espace partagé).
class CompanyContext extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) {
    if (ref.mounted) state = v;
  }

  /// Referme l'espace [owner] seulement s'il est toujours le contexte courant (passage d'un espace à un autre sans écraser le nouveau).
  /// Sans effet si l'application est déjà démontée (la fermeture de l'écran arrive après la libération des fournisseurs).
  void clearIf(String owner) {
    if (ref.mounted && state == owner) state = null;
  }
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
  final _tax = TextEditingController(), _mission = TextEditingController();
  String _sectorPick = '', _size = '', _docKind = 'registration', _logo = '', _newLogo = '', _origName = '', _origReg = '', _origTax = '', _origType = '', _origStatus = '';
  String _type = kDefaultOrgType;
  bool _filled = false, _busy = false;

  OrgType get _orgType => orgTypeOf(_type);

  @override
  void dispose() {
    for (final c in [_name, _sector, _city, _site, _phone, _contact, _role, _desc, _year, _reg, _tax, _mission]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic>? c) {
    if (_filled) return;
    _filled = true;
    if (c == null) {
      _type = ref.read(signupOrgTypeProvider).isNotEmpty ? ref.read(signupOrgTypeProvider) : kDefaultOrgType;
      _docKind = _firstDocKind();
      return;
    }
    _type = orgTypeByCode.containsKey('${c['org_type']}') ? '${c['org_type']}' : kDefaultOrgType;
    _name.text = '${c['company_name'] ?? ''}';
    _sector.text = '${c['sector'] ?? ''}';
    _sectorPick = _sector.text.isEmpty ? '' : (companySectors.contains(_sector.text) ? _sector.text : companySectorOther);
    _city.text = '${c['city'] ?? ''}';
    _site.text = '${c['website'] ?? ''}';
    _phone.text = '${c['phone'] ?? ''}';
    _contact.text = '${c['contact_name'] ?? ''}';
    _role.text = '${c['contact_role'] ?? ''}';
    _desc.text = '${c['description'] ?? ''}';
    _year.text = c['founded_year'] == null ? '' : '${c['founded_year']}';
    _reg.text = '${c['registration_number'] ?? ''}';
    _tax.text = '${c['tax_number'] ?? ''}';
    _mission.text = '${c['mission'] ?? ''}';
    _size = '${c['size'] ?? ''}';
    _logo = '${c['logo_path'] ?? ''}';
    _origName = _name.text.trim();
    _origReg = _reg.text.trim();
    _origTax = _tax.text.trim();
    _origType = _type;
    _origStatus = '${c['status'] ?? 'draft'}';
    _docKind = _firstDocKind();
  }

  /// Première pièce proposée : la première pièce obligatoire du type.
  String _firstDocKind() {
    final t = _orgType;
    return t.docs.firstWhere((d) => d.required, orElse: () => t.docs.first).kind;
  }

  /// Enregistre la fiche ; avertit d'abord quand le changement du nom, du type, du numéro d'immatriculation ou du NIU d'une fiche vérifiée la repasse en vérification.
  Future<bool> _save() async {
    final err = companyFieldError(name: _name.text, contact: _contact.text, role: _role.text, website: _site.text, year: _year.text);
    if (err != null) {
      gToast(context, err);
      return false;
    }
    final reverify = _origStatus == 'approved' && (_name.text.trim() != _origName || _reg.text.trim() != _origReg || _tax.text.trim() != _origTax || _type != _origType);
    if (reverify) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Nouvelle vérification nécessaire'),
          content: Text('Modifier le nom, le type, le numéro d’immatriculation ou le NIU d’une organisation vérifiée la remet en cours de vérification : le badge « Organisation vérifiée » disparaît et la publication de besoins, d’offres et de concours est suspendue jusqu’à la nouvelle approbation de l’administrateur.'),
          actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Annuler')), TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Enregistrer quand même'))],
        ),
      );
      if (ok != true || !mounted) return false;
    }
    setState(() => _busy = true);
    final ctx = ref.read(companyContextProvider);
    final r = await marcheCall('company_save', {
      if (ctx != null) 'p_owner': ctx,
      'p': companySavePayload(
        name: _name.text,
        sector: _sector.text,
        size: _size,
        city: _city.text,
        website: _site.text,
        phone: _phone.text,
        contact: _contact.text,
        role: _role.text,
        description: _desc.text,
        year: _year.text,
        registration: _reg.text,
        orgType: _type,
        tax: _tax.text,
        mission: _mission.text,
        newLogoPath: _newLogo,
      )
    });
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage('${r.error}'));
      return false;
    }
    if (reverify && '${r.data}' == 'pending') {
      gToast(context, 'Fiche enregistrée, mais elle repasse en vérification : le badge est retiré et la publication reste suspendue jusqu’à la nouvelle approbation.');
    }
    _origName = _name.text.trim();
    _origReg = _reg.text.trim();
    _origTax = _tax.text.trim();
    _origType = _type;
    _origStatus = r.data is String && (r.data as String).isNotEmpty ? r.data as String : _origStatus;
    _newLogo = '';
    ref.invalidate(companyProvider);
    return true;
  }

  Future<void> _pickLogo() async {
    final c = ref.read(companyProvider).asData?.value;
    final allowed = c != null ? const {'owner', 'admin'}.contains('${c['my_role'] ?? 'owner'}') : const {'company', 'admin'}.contains(roleKey(ref.read(authProvider).current));
    if (Backend.ready && !allowed) return gToast(context, 'La fiche d’organisation est réservée aux comptes Organisation et à leurs administrateurs.');
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !mounted) return;
    final up = await uploadPostMedia(context, p.first);
    if (up == null || !mounted) return;
    setState(() {
      _logo = up.path;
      _newLogo = up.path;
    });
    gToast(context, 'Logo ajouté : touchez « Enregistrer » pour le conserver.');
  }

  Future<void> _addDoc() async {
    if (_name.text.trim().length < 2) return gToast(context, 'Indiquez d’abord le nom de l’organisation : la fiche est enregistrée avant l’ajout d’une pièce.');
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
    final docs = [for (final x in (ref.read(companyProvider).asData?.value?['documents'] as List? ?? const [])) '${(x as Map)['kind']}'];
    final missing = companyMissingForSubmit(
      sector: _sector.text,
      city: _city.text,
      contact: _contact.text,
      phone: _phone.text,
      documents: docs.length,
      type: _orgType,
      registration: _reg.text,
      tax: _tax.text,
      mission: _mission.text,
      docKinds: docs,
    );
    if (missing.isNotEmpty) return gToast(context, companyMissingMessage(missing));
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
            if (status != 'approved') Padding(padding: const EdgeInsets.only(top: 6), child: Text('Votre organisation doit être vérifiée par l’administrateur : complétez la fiche, ajoutez vos pièces justificatives, puis envoyez la demande.', style: mst(12, c: kGrey).copyWith(height: 1.4))),
          ]),
        ),
        if (!canEdit) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Lecture seule : votre rôle (${companyRoleLabels[myRole] ?? myRole}) ne permet pas de modifier la fiche. Le numéro d’immatriculation, le téléphone, l’interlocuteur et les pièces sont réservés au propriétaire et aux administrateurs.', style: mst(12.5, w: FontWeight.w600, c: kGrey))),
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
          Expanded(child: Text('Logo de l’organisation (touchez pour choisir)', style: mst(12.5, c: kGrey))),
        ]),
        const SizedBox(height: 14),
        CompanyCoverCard(canEdit: canEdit && c != null),
        MDropdown(
          label: 'Type d’organisation',
          value: _type,
          items: {for (final t in orgTypes) t.code: t.label},
          onChanged: (v) => setState(() {
            _type = v;
            _docKind = _firstDocKind();
          }),
        ),
        Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text(_orgType.description, style: mst(12, c: kGrey))),
        _field(_name, _orgType.commercial ? 'Nom de l’entreprise' : 'Nom de l’organisation', max: 120),
        if (_orgType.commercial) ...[
          MDropdown(
            label: _orgType.sectorLabel,
            value: _sectorPick,
            items: {'': 'Choisir un secteur', for (final x in companySectors) x: x, companySectorOther: 'Autre (je l’écris)'},
            onChanged: (v) => setState(() {
              _sectorPick = v;
              if (v != companySectorOther) _sector.text = v;
            }),
          ),
          const SizedBox(height: 10),
          if (_sectorPick == companySectorOther) _field(_sector, 'Votre secteur d’activité', max: 80),
        ] else
          _field(_sector, _orgType.sectorLabel, hint: 'Ex. éducation, santé, insertion des jeunes', max: 80),
        if (!_orgType.commercial) _field(_mission, 'Mission et activités${_orgType.missionRequired ? '' : ' (facultatif)'}', lines: 3, max: 1500),
        MDropdown(label: _orgType.commercial ? 'Taille' : 'Effectif', value: _size, items: companySizes, onChanged: (v) => setState(() => _size = v)),
        const SizedBox(height: 10),
        _field(_city, 'Ville', max: 80),
        _field(_site, 'Site web', hint: 'https://…', type: TextInputType.url),
        _field(_contact, 'Interlocuteur', hint: 'Nom de la personne à contacter', max: 80),
        _field(_role, 'Fonction', hint: _orgType.commercial ? 'Ex. Responsable RH' : 'Ex. Présidente, Directeur, Coordinateur', max: 80),
        _field(_phone, 'Téléphone de l’organisation', type: TextInputType.phone, max: 30),
        _field(_year, 'Année de création', type: TextInputType.number, max: 4),
        _field(_reg, '${_orgType.registrationLabel}${_orgType.registrationRequired ? '' : ' (facultatif)'}', max: 60),
        if (_orgType.commercial) _field(_tax, 'NIU (numéro d’identifiant unique, facultatif)', max: 60),
        _field(_desc, 'Présentation', lines: 4, max: 1500),
        const SizedBox(height: 4),
        if (isOwner) ...[
        mSectionTitle('Pièces justificatives'),
        Text('Pour ${_orgType.label.toLowerCase()}, il faut : ${[for (final g in _orgType.requirementGroups.keys.toList()..sort()) _orgType.groupLabel(g)].join(' ET ')}. Elles sont visibles de vous, des administrateurs de votre organisation, de l’administration de la plateforme et de l’équipe d’assistance (support). Elles ne sont jamais publiques.', style: mst(12, c: kGrey)),
        const SizedBox(height: 8),
        for (final g in (_orgType.requirementGroups.keys.toList()..sort()))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_orgType.unmetGroups([for (final d in docs) '${d['kind']}']).contains(g) ? Icons.radio_button_unchecked : Icons.check_circle, size: 18, color: _orgType.unmetGroups([for (final d in docs) '${d['kind']}']).contains(g) ? kGrey : kGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(_orgType.groupLabel(g), style: mst(12.5, w: FontWeight.w600))),
            ]),
          ),
        const SizedBox(height: 4),
        for (final d in docs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined, color: kViolet),
            title: Text('${d['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w600)),
            subtitle: Text(companyDocKinds['${d['kind']}'] ?? '${d['kind']}', style: mst(12, c: kGrey)),
            trailing: locked || status == 'approved' ? null : IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteDoc(d)),
          ),
        if (status == 'approved' || status == 'pending') Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Les pièces envoyées pour vérification ne peuvent plus être supprimées (elles servent de preuve).', style: mst(11.5, c: kGrey))),
        if (docs.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune pièce pour le moment.', style: mst(13, c: kGrey))),
        MDropdown(label: 'Type de pièce', value: _docKind, items: {for (final d in _orgType.docs) d.kind: d.label}, onChanged: (v) => setState(() => _docKind = v)),
        const SizedBox(height: 8),
        mButton('Ajouter une pièce', locked ? null : _addDoc, dark: false, icon: Icons.upload_file),
        ],
        if (myRole != 'viewer') const CompanyBillingCard(),
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
            Padding(padding: const EdgeInsets.fromLTRB(4, 8, 16, 4), child: Row(children: [GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03')), Expanded(child: Text('Fiche de l’organisation', textAlign: TextAlign.center, style: mst(20, w: FontWeight.w800))), const SizedBox(width: 44)])),
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
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : (approve ? 'Organisation vérifiée.' : 'Demande refusée.'));
    ref.invalidate(companyQueueProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MarchePage(
      title: 'Organisations à vérifier',
      child: mAsync<List<Map<String, dynamic>>>(
        ref.watch(companyQueueProvider),
        (l) => l.isEmpty
            ? mNote('Aucune organisation en attente.\nLes demandes de vérification apparaissent ici.')
            : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                for (final c in l)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c['company_name']}', style: mst(16, w: FontWeight.w800)),
                      Text('Type : ${orgTypeOf('${c['org_type']}').label}', style: mst(12.5, w: FontWeight.w700, c: kViolet)),
                      Text([for (final k in ['sector', 'city']) if ('${c[k] ?? ''}'.isNotEmpty) '${c[k]}', if ('${c['size'] ?? ''}'.isNotEmpty) companySizes['${c['size']}'] ?? ''].join(' · '), style: mst(12.5, c: kGrey)),
                      const SizedBox(height: 6),
                      Text('Interlocuteur : ${c['contact_name']}${'${c['contact_role'] ?? ''}'.isEmpty ? '' : ' (${c['contact_role']})'}', style: mst(12.5)),
                      Text('Téléphone : ${c['phone']} · E-mail du compte : ${c['email'] ?? ''}', style: mst(12.5)),
                      if ('${c['registration_number'] ?? ''}'.isNotEmpty) Text('${orgTypeOf('${c['org_type']}').registrationLabel} : ${c['registration_number']}', style: mst(12.5)),
                      if ('${c['tax_number'] ?? ''}'.isNotEmpty) Text('NIU : ${c['tax_number']}', style: mst(12.5)),
                      if ('${c['mission'] ?? ''}'.isNotEmpty) Text('Mission : ${c['mission']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: mst(12.5)),
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
