import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gdata.dart' show gNetImage;
import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'company_public_page.dart' show companyPublicProvider;
import 'f4_api.dart';
import 'company_screens.dart' show companyContextProvider, companyProvider;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'social_posts.dart' show uploadPostMedia;

/// Identité de facturation de l'entreprise (reprise sur les commandes et factures passées en son nom) et couverture de la page publique.
/// Fonctions serveur : company_billing_get / company_billing_set, company_cover_set (migrations 20261118040000 et 20261118040100).

/// Identité de facturation de l'entreprise [owner] (null : la mienne) ; null si la fiche n'existe pas encore.
final companyBillingProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String?>((ref, owner) async {
  final r = await ref.read(f4RpcProvider)('company_billing_get', {'p_owner': ?owner});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

class CompanyBillingCard extends ConsumerStatefulWidget {
  const CompanyBillingCard({super.key});

  @override
  ConsumerState<CompanyBillingCard> createState() => _BillingState();
}

class _BillingState extends ConsumerState<CompanyBillingCard> {
  final _tax = TextEditingController(), _addr = TextEditingController(), _city = TextEditingController(), _mail = TextEditingController();
  bool _filled = false, _busy = false;

  @override
  void dispose() {
    for (final c in [_tax, _addr, _city, _mail]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> b) {
    if (_filled) return;
    _filled = true;
    _tax.text = '${b['tax_id'] ?? ''}';
    _addr.text = '${b['address'] ?? ''}';
    _city.text = '${b['city'] ?? ''}';
    _mail.text = '${b['email'] ?? ''}';
  }

  Future<void> _save(String? owner) async {
    setState(() => _busy = true);
    final r = await ref.read(f4RpcProvider)('company_billing_set', {
      'p_owner': ?owner,
      'p': {'tax_id': _tax.text, 'billing_address': _addr.text, 'billing_city': _city.text, 'billing_email': _mail.text},
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(companyBillingProvider(owner));
    gToast(context, 'Identité de facturation enregistrée.');
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, counterText: '', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)));

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(companyContextProvider);
    final async = ref.watch(companyBillingProvider(owner));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      mSectionTitle('Facturation des achats'),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text('Reprise automatiquement sur les commandes et factures passées au nom de l’organisation. La raison sociale et le RCCM viennent de la fiche.', style: mst(12, c: kGrey).copyWith(height: 1.4)),
      ),
      async.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text(e is MarcheException ? e.toString() : marcheErrorText('$e'), style: mst(12.5, c: kGrey))),
        data: (b) {
          if (b == null) return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text('Enregistrez d’abord la fiche de l’organisation pour renseigner sa facturation.', style: mst(12.5, c: kGrey)));
          _fill(b);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Facturé à : ${b['company_name'] ?? ''}${'${b['registration_number'] ?? ''}'.isEmpty ? '' : ' · RCCM ${b['registration_number']}'}', style: mst(13, w: FontWeight.w700)))),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _tax, maxLength: 40, decoration: _dec('NIU (numéro d’identifiant unique)'))),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _addr, maxLength: 200, maxLines: 2, decoration: _dec('Adresse de facturation'))),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _city, maxLength: 80, decoration: _dec('Ville'))),
              Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _mail, maxLength: 120, keyboardType: TextInputType.emailAddress, decoration: _dec('E-mail de facturation', hint: 'comptabilite@organisation.cm'))),
              mButton('Enregistrer la facturation', () => _save(owner), busy: _busy, icon: Icons.receipt_long_outlined),
            ]),
          );
        },
      ),
    ]);
  }
}

/// Couverture de la page publique de l'entreprise (photo) : modifiable par le propriétaire et les administrateurs.
class CompanyCoverCard extends ConsumerStatefulWidget {
  const CompanyCoverCard({super.key, required this.canEdit});
  final bool canEdit;

  @override
  ConsumerState<CompanyCoverCard> createState() => _CoverState();
}

class _CoverState extends ConsumerState<CompanyCoverCard> {
  bool _busy = false;

  Future<void> _set(String? path) async {
    setState(() => _busy = true);
    final owner = ref.read(companyContextProvider);
    final r = await ref.read(f4RpcProvider)('company_cover_set', {'p_path': path ?? '', 'p_owner': ?owner});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gToast(context, Backend.userMessage('${r.error}'));
    ref.invalidate(companyProvider);
    final id = (ref.read(companyProvider).asData?.value?['owner_id'] ?? owner) as String?;
    if (id != null) ref.invalidate(companyPublicProvider(id));
    gToast(context, path == null ? 'Couverture retirée.' : 'Couverture enregistrée : elle s’affiche sur la page publique.');
  }

  Future<void> _pick() async {
    final p = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (p.isEmpty || !mounted) return;
    final up = await uploadPostMedia(context, p.first);
    if (up == null || !mounted) return;
    await _set(up.path);
  }

  @override
  Widget build(BuildContext context) {
    final cover = '${ref.watch(companyProvider).asData?.value?['cover_path'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Couverture de la page publique', style: mst(13.5, w: FontWeight.w700)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 110,
          width: double.infinity,
          child: cover.isEmpty
              ? Container(color: const Color(0xFFEFEBFA), alignment: Alignment.center, child: Text('Aucune couverture', style: mst(12.5, c: kGrey)))
              : gNetImage(Backend.postMediaUrl(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEFEBFA))),
        ),
      ),
      if (widget.canEdit) ...[
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: mButton(cover.isEmpty ? 'Ajouter une couverture' : 'Changer la couverture', _pick, dark: false, busy: _busy, icon: Icons.image_outlined)),
          if (cover.isNotEmpty) ...[const SizedBox(width: 8), Expanded(child: mButton('Retirer', _busy ? null : () => _set(null), dark: false))],
        ]),
      ],
      const SizedBox(height: 12),
    ]);
  }
}
