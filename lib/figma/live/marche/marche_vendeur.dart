import 'package:flutter/material.dart' hide Text;
import '../../i18n.dart' show Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException, Supabase;

import '../../gen.dart' show gToast;
import '../auth.dart';
import '../backend.dart';
import '../litiges_screens.dart' show openDisputeDialog;
import '../seller.dart' show serverSellerOrdersProvider, SellerOrder;
import 'marche_data.dart';
import 'marche_widgets.dart';

/// Espace vendeur de la marketplace : ma boutique (création, personnalisation, statuts), tableau de bord, commandes par boutique,
/// produits (4 photos + 1 vidéo, variantes, caractéristiques) et promotions (codes, ventes flash, campagnes, packs).

const publicShopBase = 'https://boutik-ecole.vercel.app/#/marche/boutique/';

Widget _field(TextEditingController c, String label, {int lines = 1, TextInputType? type, String? hint, int? max}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, minLines: lines, maxLines: lines, keyboardType: type, maxLength: max, decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), counterText: '')),
    );

Future<({Uint8List bytes, String name, String mime})?> _pickImage() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  if (x == null) return null;
  final n = x.name.toLowerCase();
  final mime = x.mimeType ?? (n.endsWith('.png') ? 'image/png' : (n.endsWith('.webp') ? 'image/webp' : 'image/jpeg'));
  return (bytes: await x.readAsBytes(), name: x.name, mime: mime);
}

/// Assistance de Kéla pour le vendeur : propose un texte, JAMAIS publié sans accord. Le texte proposé n'est qu'une suggestion affichée
/// dans une fenêtre ; le vendeur l'insère dans le champ s'il le veut, puis enregistre lui-même.
Future<String?> kelaSuggest(String prompt) async {
  if (!Backend.ready) return null;
  try {
    final r = await Supabase.instance.client.functions.invoke('kela-chat', body: {'message': prompt, 'history': const []});
    final d = r.data;
    if (d is Map && d['reply'] is String) return (d['reply'] as String).split('\n').where((l) => !l.trimLeft().startsWith('BRIEF=')).join('\n').trim();
  } on FunctionException catch (e) {
    final d = e.details;
    return d is Map && d['message'] is String ? '⚠ ${d['message']}' : '⚠ Kéla est momentanément indisponible.';
  } catch (_) {}
  return '⚠ Kéla est momentanément indisponible. Vérifiez votre connexion.';
}

/// Bouton « Suggérer avec Kéla » : affiche la proposition ; elle ne remplit le champ que si le vendeur l'accepte.
Widget kelaButton(BuildContext context, {required String prompt, required TextEditingController target}) => mButton('Suggérer avec Kéla', () async {
      final text = await kelaSuggest(prompt);
      if (!context.mounted) return;
      if (text == null) return gToast(context, 'Kéla n’est disponible qu’une fois connecté au serveur.');
      if (text.startsWith('⚠')) return gToast(context, text.substring(2));
      final useIt = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Proposition de Kéla'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ignorer')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Utiliser ce texte'))],
        ),
      );
      if (useIt == true) {
        target.text = text.length > 1000 ? text.substring(0, 1000) : text;
        if (context.mounted) gToast(context, 'Texte inséré : relisez-le puis enregistrez.');
      }
    }, dark: false, icon: Icons.auto_awesome_outlined);

// ------------------------------------------------------------------ ma boutique

class ShopEditorScreen extends ConsumerWidget {
  const ShopEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Ma boutique',
        child: ref.watch(authProvider.select((a) => a.current == null)) && Backend.ready
            ? mNote('Connectez-vous pour créer votre boutique.')
            : (Backend.ready && !ref.watch(authProvider.select((a) => a.current?.role == 1 && (a.current?.staff ?? '').isEmpty)) )
                ? mNote('La boutique est réservée aux étudiants-vendeurs.')
                : mAsync<Map<String, dynamic>>(ref.watch(marcheMyShopProvider), (s) => _ShopForm(shop: s)),
      );
}

class _ShopForm extends ConsumerStatefulWidget {
  const _ShopForm({required this.shop});
  final Map<String, dynamic> shop;

  @override
  ConsumerState<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends ConsumerState<_ShopForm> {
  late final name = TextEditingController(text: '${widget.shop['name'] ?? ''}');
  late final slug = TextEditingController(text: '${widget.shop['slug'] ?? ''}');
  late final desc = TextEditingController(text: '${widget.shop['description'] ?? ''}');
  late final city = TextEditingController(text: '${widget.shop['city'] ?? ''}');
  late final delivery = TextEditingController(text: '${widget.shop['delivery_info'] ?? ''}');
  late final terms = TextEditingController(text: '${widget.shop['terms'] ?? ''}');
  late final Map<String, TextEditingController> socials = {
    for (final k in const ['instagram', 'facebook', 'whatsapp', 'tiktok', 'website']) k: TextEditingController(text: '${(widget.shop['socials'] as Map?)?[k] ?? ''}')
  };
  late String logo = '${widget.shop['logo_url'] ?? ''}';
  late String banner = '${widget.shop['banner_url'] ?? ''}';
  late Set<String> cats = {for (final c in (widget.shop['categories'] as List? ?? const [])) '$c'};
  late String c1 = '${widget.shop['color_primary'] ?? '#111015'}';
  late String c2 = '${widget.shop['color_secondary'] ?? '#5A3FE0'}';
  bool _busy = false;

  static const palette = ['#111015', '#5A3FE0', '#0F7A52', '#E5484D', '#F5A524', '#0B6BCB', '#B83280', '#8A5A2B'];

  bool get exists => widget.shop['id'] != null;
  String get status => '${widget.shop['status'] ?? ''}';
  bool get locked => status == 'suspended';

  Future<void> _upload(bool isLogo) async {
    final p = await _pickImage();
    if (p == null) return;
    if (p.bytes.length > 5 * 1024 * 1024) return gToast(context, 'Image trop lourde (5 Mo maximum).');
    setState(() => _busy = true);
    final r = await Backend.uploadPublic('listing-images', 'boutique', p.bytes, p.name, p.mime);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.url != null) isLogo ? logo = r.url! : banner = r.url!;
    });
    if (r.error != null) gToast(context, r.error!);
  }

  Map<String, dynamic> get _payload => {
        'name': name.text.trim(),
        if (!exists || status == 'draft') 'slug': slug.text.trim(),
        'description': desc.text,
        'city': city.text,
        'delivery_info': delivery.text,
        'terms': terms.text,
        'logo_url': logo,
        'banner_url': banner,
        'categories': cats.toList(),
        'socials': {for (final e in socials.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
        'color_primary': c1,
        'color_secondary': c2,
      };

  Future<bool> _save({bool quiet = false}) async {
    if (name.text.trim().length < 3) {
      gToast(context, 'Le nom de la boutique doit compter au moins 3 caractères.');
      return false;
    }
    setState(() => _busy = true);
    final r = await marcheCall('shop_save', {'p': _payload});
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage('${r.error}'));
      return false;
    }
    if (!quiet) gToast(context, 'Boutique enregistrée.');
    ref.invalidate(marcheMyShopProvider);
    return true;
  }

  Future<void> _submit() async {
    if (!await _save(quiet: true)) return;
    final r = await marcheCall('shop_submit', const {});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Boutique envoyée à la modération pour validation.');
    ref.invalidate(marcheMyShopProvider);
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Fermer la boutique ?'), content: const Text('Vos produits disparaissent de la marketplace. Vous pourrez la rouvrir en la soumettant de nouveau.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Fermer la boutique'))]));
    if (ok != true) return;
    final r = await marcheCall('shop_close', const {});
    if (!mounted) return;
    gToast(context, r.error != null ? Backend.userMessage('${r.error}') : 'Boutique fermée.');
    ref.invalidate(marcheMyShopProvider);
  }

  @override
  Widget build(BuildContext context) {
    final allCats = ref.watch(marcheCategoriesProviderForForm).value ?? const <String>[];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
      if (exists) ...[
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Statut : ${shopStatusLabels[status] ?? status}', style: mst(14, w: FontWeight.w800, c: status == 'active' ? kGreen : (status == 'suspended' ? kRed : kInk))),
            if ('${widget.shop['review_note'] ?? ''}'.isNotEmpty) Text('Message de la modération : ${widget.shop['review_note']}', style: mst(12.5, c: kGrey)),
            const SizedBox(height: 6),
            SelectableText('$publicShopBase${widget.shop['slug']}', style: mst(12.5, c: kViolet)),
            if (status == 'active') Row(children: [
              TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: '$publicShopBase${widget.shop['slug']}')).then((_) => gToast(context, 'Lien copié')), child: const Text('Copier le lien')),
              TextButton(onPressed: () => context.push('/marche/boutique/${widget.shop['slug']}'), child: const Text('Voir ma vitrine')),
            ]),
          ]),
        ),
        if (status == 'active') Padding(padding: const EdgeInsets.only(bottom: 14), child: mButton('Tableau de bord vendeur', () => context.push('/marche/vendeur'))),
      ] else
        Padding(padding: const EdgeInsets.only(bottom: 14), child: Text('Créez votre boutique : elle sera validée par la modération avant d’apparaître dans la marketplace. Vos annonces existantes restent inchangées.', style: mst(13, c: kGrey).copyWith(height: 1.5))),
      Text('Identité', style: mst(16, w: FontWeight.w800)),
      const SizedBox(height: 10),
      _field(name, 'Nom de la boutique', max: 60),
      _field(slug, 'Adresse publique (unique)', hint: 'ma-boutique', max: 40),
      _field(desc, 'Description', lines: 4, max: 1000),
      Padding(padding: const EdgeInsets.only(bottom: 12), child: kelaButton(context, prompt: 'Rédige en français, en 400 caractères maximum, une description attrayante pour la boutique « ${name.text.trim()} » de la marketplace étudiante Boutik-École (catégories : ${cats.join(', ')}). N’invente ni prix ni promesse. Réponds uniquement par le texte de la description.', target: desc)),
      _field(city, 'Ville ou lieu'),
      Row(children: [
        Expanded(child: mButton(logo.isEmpty ? 'Ajouter le logo' : 'Changer le logo', _busy || locked ? null : () => _upload(true), dark: false, icon: Icons.image_outlined)),
        const SizedBox(width: 10),
        Expanded(child: mButton(banner.isEmpty ? 'Ajouter la bannière' : 'Changer la bannière', _busy || locked ? null : () => _upload(false), dark: false, icon: Icons.panorama_outlined)),
      ]),
      if (logo.isNotEmpty || banner.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [if (logo.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 64, child: MImage(logo))), const SizedBox(width: 10), if (banner.isNotEmpty) Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 64, child: MImage(banner))))])),
      const SizedBox(height: 18),
      Text('Catégories (5 au plus)', style: mst(16, w: FontWeight.w800)),
      Wrap(spacing: 8, children: [for (final c in allCats) MChip(c, selected: cats.contains(c), onTap: () => setState(() => cats.contains(c) ? cats.remove(c) : (cats.length < 5 ? cats.add(c) : null)))]),
      const SizedBox(height: 18),
      Text('Couleurs de la vitrine', style: mst(16, w: FontWeight.w800)),
      const SizedBox(height: 8),
      _swatches('Principale', c1, (v) => setState(() => c1 = v)),
      _swatches('Accent', c2, (v) => setState(() => c2 = v)),
      const SizedBox(height: 18),
      Text('Livraison, conditions, réseaux', style: mst(16, w: FontWeight.w800)),
      const SizedBox(height: 10),
      _field(delivery, 'Livraison (délais, zones, frais)', lines: 3, max: 500),
      _field(terms, 'Conditions (retours, paiement)', lines: 3, max: 1500),
      for (final e in socials.entries) _field(e.value, e.key[0].toUpperCase() + e.key.substring(1)),
      const SizedBox(height: 8),
      mButton(exists ? 'Enregistrer' : 'Créer ma boutique (brouillon)', locked ? null : _save, busy: _busy),
      if (exists && (status == 'draft' || status == 'closed')) ...[const SizedBox(height: 10), mButton('Soumettre à la validation', _busy ? null : _submit, dark: false)],
      if (exists && status != 'closed' && status != 'suspended') ...[const SizedBox(height: 10), mButton('Fermer la boutique', _close, dark: false)],
    ]);
  }

  Widget _swatches(String label, String value, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label, style: mst(13, c: kGrey))),
          Expanded(
            child: Wrap(children: [
              for (final h in palette)
                Semantics(
                  button: true,
                  selected: h == value,
                  label: '$label $h',
                  excludeSemantics: true,
                  child: GestureDetector(onTap: () => on(h), child: SizedBox(width: 48, height: 48, child: Center(child: Container(width: 30, height: 30, decoration: BoxDecoration(color: mHex(h, kInk), shape: BoxShape.circle, border: Border.all(color: h == value ? kViolet : kLine, width: h == value ? 3 : 1)))))),
                ),
            ]),
          ),
        ]),
      );
}

final marcheCategoriesProviderForForm = FutureProvider.autoDispose<List<String>>((ref) async {
  if (!Backend.ready) return const [];
  final r = await Backend.rows('marketplace_categories', 'label,position,active', eq: const {'active': true}, order: 'position', ascending: true, limit: 30);
  return [for (final x in r.rows) '${x['label']}'];
});

// ------------------------------------------------------------------ tableau de bord vendeur

class SellerHubScreen extends ConsumerWidget {
  const SellerHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: 4,
        child: MarchePage(
          title: 'Espace vendeur',
          child: Column(children: [
            const TabBar(isScrollable: true, labelColor: kInk, indicatorColor: kInk, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Tableau de bord'), Tab(text: 'Commandes'), Tab(text: 'Produits'), Tab(text: 'Promotions')]),
            Expanded(child: TabBarView(children: [const _DashboardTab(), const _OrdersTab(), const _ProductsTab(), const _PromotionsTab()])),
          ]),
        ),
      );
}

final _periodProvider = NotifierProvider<_Period, int>(_Period.new);

class _Period extends Notifier<int> {
  @override
  int build() => 30;
  void set(int v) => state = v;
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(_periodProvider);
    return mAsync<Map<String, dynamic>>(ref.watch(marcheDashboardProvider(days)), (d) {
      final series = [for (final x in (d['series'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      final top = [for (final x in (d['top'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
      Widget tile(String l, String v) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: mst(18, w: FontWeight.w800)), Text(l, style: mst(11.5, c: kGrey))])));
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        Row(children: [for (final p in const [7, 30, 90]) ...[MChip('$p jours', selected: days == p, onTap: () => ref.read(_periodProvider.notifier).set(p)), const SizedBox(width: 8)]]),
        const SizedBox(height: 6),
        Row(children: [tile('Chiffre d’affaires', mFcfa(d['revenue'])), const SizedBox(width: 10), tile('Commandes payées', '${mInt(d['orders'])}')]),
        const SizedBox(height: 10),
        Row(children: [tile('Vues produits', '${mInt(d['views'])}'), const SizedBox(width: 10), tile('Conversion', d['conversion'] == null ? '—' : '${d['conversion']} %')]),
        const SizedBox(height: 10),
        Row(children: [tile('À préparer', '${mInt(d['pending_orders'])}'), const SizedBox(width: 10), tile('Abonnés', '${mInt(d['followers'])}')]),
        mSectionTitle('Chiffre d’affaires par jour'),
        SizedBox(height: 140, child: _Bars(values: [for (final s in series) mInt(s['revenue'])], labels: [for (final s in series) '${s['day']}'.substring(5)])),
        mSectionTitle('Vues par jour'),
        SizedBox(height: 100, child: _Bars(values: [for (final s in series) mInt(s['views'])], labels: [for (final s in series) '${s['day']}'.substring(5)], color: kViolet)),
        mSectionTitle('Meilleurs produits'),
        if (top.isEmpty) Text('Aucune vente sur la période.', style: mst(13, c: kGrey)),
        for (final t in top) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text('${t['title']}', style: mst(13.5, w: FontWeight.w600))), Text('${mInt(t['qty'])} vendu(s) · ${mFcfa(t['revenue'])}', style: mst(12.5, c: kGrey))])),
        const SizedBox(height: 10),
        Text('La conversion rapporte les commandes payées aux vues des fiches produit.', style: mst(11.5, c: kGrey)),
      ]);
    });
  }
}

/// Histogramme simple (aucune bibliothèque de graphiques).
class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.labels, this.color = kInk});
  final List<int> values;
  final List<String> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final mx = values.fold<int>(0, (a, b) => b > a ? b : a);
    if (values.isEmpty || mx == 0) return Center(child: Text('Pas encore de données sur la période.', style: mst(13, c: kGrey)));
    return Semantics(
      label: 'Histogramme sur ${values.length} jours, maximum $mx',
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(child: Tooltip(message: '${labels[i]} : ${values[i]}', child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: FractionallySizedBox(heightFactor: values[i] == 0 ? 0.02 : values[i] / mx, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))))))),
      ]),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  static const _labels = ['Nouvelle', 'Acceptée', 'En préparation', 'Prête', 'Livrée'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(serverSellerOrdersProvider);
    if (orders.isEmpty) return mNote('Aucune commande payée à préparer pour le moment.');
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
      Text('Vous ne voyez et ne préparez que les articles de votre boutique, même si l’acheteur a commandé dans plusieurs boutiques.', style: mst(12, c: kGrey)),
      const SizedBox(height: 10),
      for (final o in orders) _OrderCard(o: o),
    ]);
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.o});
  final SellerOrder o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = o.status + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(o.id, style: mst(14, w: FontWeight.w800))), Text(mFcfa(o.total), style: mst(14, w: FontWeight.w800))]),
        Text('${o.title} · ${o.client}', style: mst(12.5, c: kGrey)),
        const SizedBox(height: 4),
        Text('État : ${_OrdersTab._labels[o.status.clamp(0, 4)]}', style: mst(12.5, w: FontWeight.w700, c: o.status >= 4 ? kGreen : kInk)),
        if (next <= 4)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: mButton('Marquer : ${_OrdersTab._labels[next]}', () async {
              final err = await Backend.setSellerOrderStatus(o.id, next);
              if (!context.mounted) return;
              gToast(context, err ?? 'Commande mise à jour, l’acheteur est prévenu.');
              ref.read(serverSellerOrdersProvider.notifier).refresh();
            }, dark: false),
          ),
        if (o.status >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(onPressed: () => openDisputeDialog(context, ref, o.id), child: Text('Le client refuse de payer', style: mst(12.5, w: FontWeight.w700, c: kRed))),
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ produits : médias, prix normal, variantes, caractéristiques

final _myListingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return const [];
  final r = await Backend.rows('listings', 'id,title,price,price_before,stock,status,images,video_url,variants,specs,description,category', eq: {'seller_id': uid}, order: 'updated_at', limit: 100);
  return r.rows;
});

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => mAsync<List<Map<String, dynamic>>>(ref.watch(_myListingsProvider), (l) {
        final l2 = [for (final x in l) if (x['status'] != 'removed') x];
        if (l2.isEmpty) return mNote('Vous n’avez pas encore de produit. Publiez une annonce depuis l’espace vendeur (écran « Mes produits »), puis enrichissez-la ici.');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          for (final p in l2)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 64, height: 80, child: MImage(mImageUrl((p['images'] as List?)?.isNotEmpty == true ? (p['images'] as List).first : '')))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13.5, w: FontWeight.w700)), Text('${mFcfa(p['price'])} · stock ${mInt(p['stock'])} · ${p['status']}', style: mst(12, c: kGrey)), Text('${(p['images'] as List?)?.length ?? 0}/4 photos · ${'${p['video_url'] ?? ''}'.isEmpty ? 'pas de vidéo' : '1 vidéo'}', style: mst(12, c: kViolet))])),
                mButton('Éditer', () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProductMediaEditor(listing: p)));
                  ref.invalidate(_myListingsProvider);
                }, dark: false),
              ]),
            ),
        ]);
      });
}

class ProductMediaEditor extends StatefulWidget {
  const ProductMediaEditor({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  State<ProductMediaEditor> createState() => _ProductMediaEditorState();
}

class _ProductMediaEditorState extends State<ProductMediaEditor> {
  late List<String> images = [for (final x in (widget.listing['images'] as List? ?? const [])) '$x'];
  late String video = '${widget.listing['video_url'] ?? ''}';
  late final before = TextEditingController(text: widget.listing['price_before']?.toString() ?? '');
  late final specs = TextEditingController(text: _specsText(widget.listing['specs']));
  late final variants = TextEditingController(text: _variantsText(widget.listing['variants']));
  bool busy = false;
  String? error;

  static String _specsText(Object? s) => s is Map ? s.entries.map((e) => '${e.key}: ${e.value}').join('\n') : '';
  static String _variantsText(Object? v) => v is List ? v.map((x) => '${(x as Map)['name']}: ${(x['options'] as List).join(', ')}').join('\n') : '';

  String get id => '${widget.listing['id']}';

  Future<void> _addImage() async {
    if (images.length >= 4) return setState(() => error = '4 photos au maximum par produit.');
    final p = await _pickImage();
    if (p == null) return;
    if (p.bytes.length > 5 * 1024 * 1024) return setState(() => error = 'Photo trop lourde (5 Mo maximum).');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.addListingImage(id, images, p.bytes, p.name, p.mime);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = r.error;
      images = r.images;
    });
  }

  Future<void> _removeImage(String path) async {
    setState(() => busy = true);
    final r = await Backend.removeListingImage(id, images, path);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = r.error;
      images = r.images;
    });
  }

  Future<void> _addVideo() async {
    final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > 30 * 1024 * 1024) return setState(() => error = 'Vidéo trop lourde (30 Mo maximum).');
    final n = x.name.toLowerCase();
    final mime = x.mimeType ?? (n.endsWith('.webm') ? 'video/webm' : 'video/mp4');
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.uploadPublic('listing-videos', id, bytes, x.name, mime);
    String? err = r.error;
    if (err == null) err = await Backend.updateListing(id, {'video_url': r.url});
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
      if (err == null) video = r.url!;
    });
  }

  Future<void> _save() async {
    final pb = before.text.trim().isEmpty ? null : int.tryParse(before.text.trim());
    if (before.text.trim().isNotEmpty && pb == null) return setState(() => error = 'Prix normal invalide.');
    final specMap = <String, String>{};
    for (final line in specs.text.split('\n')) {
      final i = line.indexOf(':');
      if (i > 0 && line.substring(i + 1).trim().isNotEmpty) specMap[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    final vars = <Map<String, Object>>[];
    for (final line in variants.text.split('\n')) {
      final i = line.indexOf(':');
      if (i > 0) {
        final opts = [for (final o in line.substring(i + 1).split(',')) if (o.trim().isNotEmpty) o.trim()];
        if (opts.isNotEmpty) vars.add({'name': line.substring(0, i).trim(), 'options': opts});
      }
    }
    if (vars.length > 5) return setState(() => error = '5 variantes au maximum.');
    setState(() => busy = true);
    final err = await Backend.updateListing(id, {'price_before': pb, 'specs': specMap, 'variants': vars});
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err == null ? null : Backend.userMessage(err);
    });
    if (err == null) {
      gToast(context, 'Produit enregistré.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => MarchePage(
        title: 'Produit : médias',
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          Text('${widget.listing['title']}', style: mst(16, w: FontWeight.w800)),
          Text('Prix actuel : ${mFcfa(widget.listing['price'])}. Pour afficher une promotion, saisissez ci-dessous le prix normal (supérieur au prix actuel).', style: mst(12.5, c: kGrey)),
          const SizedBox(height: 14),
          Text('Photos (${images.length}/4)', style: mst(15, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final p in images)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 96, height: 120, child: MImage(mImageUrl(p)))),
                Positioned(right: 0, top: 0, child: Semantics(button: true, label: 'Retirer la photo', excludeSemantics: true, child: GestureDetector(onTap: busy ? null : () => _removeImage(p), child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18))))),
              ]),
            if (images.length < 4) Semantics(button: true, label: 'Ajouter une photo', excludeSemantics: true, child: GestureDetector(onTap: busy ? null : _addImage, child: Container(width: 96, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)), child: const Icon(Icons.add_a_photo_outlined)))),
          ]),
          const SizedBox(height: 18),
          Text('Vidéo (1 maximum, MP4 ou WebM, 30 Mo)', style: mst(15, w: FontWeight.w800)),
          const SizedBox(height: 8),
          if (video.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(height: 200, child: MarcheVideo(url: video))),
          mButton(video.isEmpty ? 'Ajouter une vidéo' : 'Remplacer la vidéo', busy ? null : _addVideo, dark: false, icon: Icons.videocam_outlined),
          const SizedBox(height: 18),
          _field(before, 'Prix normal avant promotion (FCFA, facultatif)', type: TextInputType.number),
          _field(variants, 'Variantes (une ligne par type)', lines: 3, hint: 'Couleur: Rouge, Bleu\nTaille: S, M, L'),
          _field(specs, 'Caractéristiques (une ligne par élément)', lines: 4, hint: 'Matière: Bois recyclé\nPoids: 1,2 kg'),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: kelaButton(context, prompt: 'Pour le produit « ${widget.listing['title']} » (catégorie ${widget.listing['category']}), propose au plus 5 caractéristiques plausibles à vérifier par le vendeur, une par ligne au format « Nom: valeur », sans inventer de chiffre précis. Réponds uniquement par ces lignes.', target: specs)),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: mst(13, w: FontWeight.w600, c: kRed))),
          mButton('Enregistrer', _save, busy: busy),
        ]),
      );
}

// ------------------------------------------------------------------ promotions

class _PromotionsTab extends ConsumerWidget {
  const _PromotionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => mAsync<Map<String, dynamic>>(ref.watch(marchePromotionsProvider), (p) {
        List<Map<String, dynamic>> l(String k) => [for (final x in (p[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        final listings = ref.watch(_myListingsProvider).value ?? const <Map<String, dynamic>>[];
        void done(String? err, String ok) {
          if (err == 'cancel') return;
          gToast(context, err != null ? Backend.userMessage(err) : ok);
          ref.invalidate(marchePromotionsProvider);
        }

        return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
          mSectionTitle('Codes promo', trailing: TextButton(onPressed: () async => done((await _promoDialog(context)), 'Code créé.'), child: const Text('Nouveau'))),
          if (l('codes').isEmpty) Text('Aucun code. Un code peut être limité en nombre d’utilisations et en durée.', style: mst(13, c: kGrey)),
          for (final c in l('codes')) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${c['code']} · ${c['kind'] == 'percent' ? '−${c['value']} %' : '−${mFcfa(c['value'])}'} · utilisé ${mInt(c['used_count'])}${c['max_uses'] != null ? '/${c['max_uses']}' : ''} fois${c['active'] == true ? '' : ' · inactif'}', style: mst(13))),
          mSectionTitle('Ventes flash', trailing: TextButton(onPressed: () async => done(await _flashDialog(context, listings), 'Vente flash programmée : le stock est réservé.'), child: const Text('Nouvelle'))),
          if (l('flash').isEmpty) Text('Aucune vente flash. Le stock choisi est réservé pour la durée de la vente.', style: mst(13, c: kGrey)),
          for (final f in l('flash'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text('${f['title']} · ${mFcfa(f['sale_price'])} · ${mInt(f['sold'])}/${mInt(f['stock'])} vendus${f['cancelled'] == true ? ' · annulée' : ''}', style: mst(13))),
                if (f['cancelled'] != true) TextButton(onPressed: () async { final r = await marcheCall('flash_cancel', {'p_id': f['id']}); done(r.error, 'Vente flash annulée.'); }, child: const Text('Annuler')),
              ]),
            ),
          mSectionTitle('Campagnes', trailing: TextButton(onPressed: () async => done(await _campaignDialog(context, listings), 'Campagne publiée sur votre vitrine.'), child: const Text('Nouvelle'))),
          if (l('campaigns').isEmpty) Text('Aucune campagne.', style: mst(13, c: kGrey)),
          for (final c in l('campaigns')) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${c['title']} · ${(c['listing_ids'] as List?)?.length ?? 0} produit(s)', style: mst(13))),
          mSectionTitle('Packs', trailing: TextButton(onPressed: () async => done(await _packDialog(context, listings), 'Pack créé.'), child: const Text('Nouveau'))),
          if (l('packs').isEmpty) Text('Aucun pack. Un pack regroupe 2 à 6 produits à prix réduit.', style: mst(13, c: kGrey)),
          for (final k in l('packs')) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${k['title']} · ${mFcfa(k['price'])}', style: mst(13))),
        ]);
      });
}

Future<String?> _promoDialog(BuildContext context) async {
  final code = TextEditingController(), value = TextEditingController(), min = TextEditingController(), uses = TextEditingController();
  var percent = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
          title: const Text('Nouveau code promo'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(code, 'Code (lettres et chiffres)', hint: 'RENTREE10'),
            Row(children: [ChoiceChip(label: const Text('Pourcentage'), selected: percent, onSelected: (_) => set(() => percent = true)), const SizedBox(width: 8), ChoiceChip(label: const Text('Montant'), selected: !percent, onSelected: (_) => set(() => percent = false))]),
            const SizedBox(height: 10),
            _field(value, percent ? 'Réduction (%, 90 max)' : 'Réduction (FCFA)', type: TextInputType.number),
            _field(min, 'Achat minimum (FCFA, facultatif)', type: TextInputType.number),
            _field(uses, 'Nombre d’utilisations max (facultatif)', type: TextInputType.number),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer'))],
        )),
  );
  if (ok != true) return 'cancel';
  final r = await marcheCall('promo_save', {'p_code': code.text, 'p_kind': percent ? 'percent' : 'fixed', 'p_value': int.tryParse(value.text) ?? 0, 'p_min': int.tryParse(min.text) ?? 0, 'p_max_uses': int.tryParse(uses.text)});
  return r.error;
}

Future<String?> _flashDialog(BuildContext context, List<Map<String, dynamic>> listings) async {
  final approved = [for (final x in listings) if (x['status'] == 'approved') x];
  if (approved.isEmpty) return 'Aucun produit approuvé dans votre boutique.';
  var sel = approved.first;
  final price = TextEditingController(), stock = TextEditingController(text: '5');
  var hours = 24;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
          title: const Text('Nouvelle vente flash'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButton<Map<String, dynamic>>(isExpanded: true, value: sel, items: [for (final p in approved) DropdownMenuItem(value: p, child: Text('${p['title']} (${mFcfa(p['price'])})', overflow: TextOverflow.ellipsis))], onChanged: (v) => set(() => sel = v!)),
            _field(price, 'Prix flash (FCFA)', type: TextInputType.number),
            _field(stock, 'Stock réservé à la vente flash', type: TextInputType.number),
            Wrap(spacing: 8, children: [for (final h in const [6, 24, 72]) ChoiceChip(label: Text('$h h'), selected: hours == h, onSelected: (_) => set(() => hours = h))]),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lancer'))],
        )),
  );
  if (ok != true) return 'cancel';
  final now = DateTime.now().toUtc();
  final r = await marcheCall('flash_save', {'p_listing': sel['id'], 'p_price': int.tryParse(price.text) ?? 0, 'p_stock': int.tryParse(stock.text) ?? 0, 'p_starts': now.toIso8601String(), 'p_ends': now.add(Duration(hours: hours)).toIso8601String()});
  return r.error;
}

Future<String?> _campaignDialog(BuildContext context, List<Map<String, dynamic>> listings) async {
  final approved = [for (final x in listings) if (x['status'] == 'approved') x];
  final title = TextEditingController(), desc = TextEditingController();
  final chosen = <String>{};
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
          title: const Text('Nouvelle campagne'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(title, 'Titre (ex. Rentrée)'),
            _field(desc, 'Description', lines: 2),
            for (final p in approved) CheckboxListTile(dense: true, value: chosen.contains(p['id']), title: Text('${p['title']}'), onChanged: (v) => set(() => v == true ? chosen.add('${p['id']}') : chosen.remove('${p['id']}'))),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Publier'))],
        )),
  );
  if (ok != true) return 'cancel';
  final r = await marcheCall('campaign_save', {'p_title': title.text, 'p_description': desc.text, 'p_banner': null, 'p_listings': chosen.toList(), 'p_starts': DateTime.now().toUtc().toIso8601String(), 'p_ends': null});
  return r.error;
}

Future<String?> _packDialog(BuildContext context, List<Map<String, dynamic>> listings) async {
  final approved = [for (final x in listings) if (x['status'] == 'approved') x];
  final title = TextEditingController(), desc = TextEditingController(), price = TextEditingController();
  final chosen = <String>{};
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
          title: const Text('Nouveau pack'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(title, 'Nom du pack'),
            _field(desc, 'Description', lines: 2),
            _field(price, 'Prix du pack (FCFA)', type: TextInputType.number),
            for (final p in approved) CheckboxListTile(dense: true, value: chosen.contains(p['id']), title: Text('${p['title']} (${mFcfa(p['price'])})'), onChanged: (v) => set(() => v == true ? chosen.add('${p['id']}') : chosen.remove('${p['id']}'))),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer'))],
        )),
  );
  if (ok != true) return 'cancel';
  final r = await marcheCall('pack_save', {'p_title': title.text, 'p_description': desc.text, 'p_price': int.tryParse(price.text) ?? 0, 'p_items': [for (final id in chosen) {'listing': id, 'qty': 1}]});
  return r.error;
}

// ------------------------------------------------------------------ modération et administration

class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarchePage(
        title: 'Modération marketplace',
        child: mAsync<Map<String, dynamic>>(ref.watch(marcheModerationProvider), (d) {
          List<Map<String, dynamic>> l(String k) => [for (final x in (d[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
          Future<void> act(String fn, Map<String, dynamic> p, String ok) async {
            final r = await marcheCall(fn, p);
            if (!context.mounted) return;
            gToast(context, r.error != null ? Backend.userMessage('${r.error}') : ok);
            ref.invalidate(marcheModerationProvider);
          }

          Future<String?> note(String title) async {
            final c = TextEditingController();
            final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: Text(title), content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Motif (obligatoire)')), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Valider'))]));
            return ok == true ? c.text : null;
          }

          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
            mSectionTitle('Boutiques à valider (${l('pending_shops').length})'),
            if (l('pending_shops').isEmpty) Text('Aucune boutique en attente.', style: mst(13, c: kGrey)),
            for (final s in l('pending_shops'))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']} · ${s['owner']}', style: mst(14, w: FontWeight.w800)),
                  if ('${s['description'] ?? ''}'.isNotEmpty) Text('${s['description']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: mst(12.5, c: kGrey)),
                  TextButton(onPressed: () => context.push('/marche/boutique/${s['slug']}'), child: const Text('Voir la vitrine')),
                  Row(children: [
                    Expanded(child: mButton('Valider', () => act('shop_decide', {'p_shop': s['id'], 'p_action': 'approve'}, 'Boutique validée.'))),
                    const SizedBox(width: 10),
                    Expanded(child: mButton('Refuser', () async { final n = await note('Motif du refus'); if (n != null) act('shop_decide', {'p_shop': s['id'], 'p_action': 'reject', 'p_note': n}, 'Boutique renvoyée au vendeur.'); }, dark: false)),
                  ]),
                ]),
              ),
            mSectionTitle('Boutiques actives et suspendues'),
            for (final s in l('active_shops'))
              Row(children: [
                Expanded(child: Text('${s['name']} · ${shopStatusLabels[s['status']]}', style: mst(13.5))),
                if (s['status'] == 'active') TextButton(onPressed: () async { final n = await note('Motif de la suspension'); if (n != null) act('shop_decide', {'p_shop': s['id'], 'p_action': 'suspend', 'p_note': n}, 'Boutique suspendue.'); }, child: const Text('Suspendre')) else TextButton(onPressed: () => act('shop_decide', {'p_shop': s['id'], 'p_action': 'restore'}, 'Boutique rétablie.'), child: const Text('Rétablir')),
              ]),
            mSectionTitle('Signalements de boutiques (${l('shop_reports').length})'),
            if (l('shop_reports').isEmpty) Text('Aucun signalement ouvert.', style: mst(13, c: kGrey)),
            for (final r in l('shop_reports'))
              Row(children: [
                Expanded(child: Text('${r['shop']} · ${r['reason']}${'${r['details'] ?? ''}'.isEmpty ? '' : ' : ${r['details']}'}', style: mst(13))),
                TextButton(onPressed: () => act('shop_report_set_status', {'p_id': r['id'], 'p_status': 'closed'}, 'Signalement clos.'), child: const Text('Clore')),
              ]),
            mSectionTitle('Litiges ouverts (${l('disputes').length})'),
            if (l('disputes').isEmpty) Text('Aucun litige ouvert.', style: mst(13, c: kGrey)),
            for (final r in l('disputes'))
              Row(children: [
                Expanded(child: Text('${r['reason']} : ${r['details']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(13))),
                TextButton(onPressed: () => act('dispute_close', {'p_id': r['id']}, 'Litige clos.'), child: const Text('Clore')),
              ]),
            mSectionTitle('Catégories'),
            Wrap(spacing: 8, children: [for (final c in l('categories')) Chip(label: Text('${c['label']}${c['active'] == true ? '' : ' (masquée)'}'))]),
            TextButton(
              onPressed: () async {
                final label = TextEditingController();
                final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Nouvelle catégorie'), content: TextField(controller: label, decoration: const InputDecoration(hintText: 'Nom')), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Ajouter'))]));
                if (ok == true) {
                  final slug = label.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                  act('category_save', {'p_slug': slug, 'p_label': label.text, 'p_position': 50}, 'Catégorie enregistrée.');
                }
              },
              child: const Text('Ajouter une catégorie'),
            ),
          ]);
        }),
      );
}
