import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gen.dart' show gToast;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'device_prefs.dart';
import 'dictation_stub.dart' if (dart.library.js_interop) 'dictation_web.dart';
import 'entreprise.dart';
import 'store.dart';

/// Écrans qui demandaient une décision : assistante Kéla (brief par écrit, la voix n'est pas disponible), double authentification par
/// application (TOTP réelle), langue, contrôles d'une fiche calculés sur l'annonce réelle, produit sans 3D, règles de dépôt.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _note(double w, String t, {double h = 120}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));
Widget _btn(String t, VoidCallback f, {bool dark = true, double? w}) => GestureDetector(onTap: f, child: Container(width: w, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), alignment: Alignment.center, decoration: BoxDecoration(color: dark ? _ink : Colors.white, borderRadius: BorderRadius.circular(24), border: dark ? null : Border.all(color: const Color(0xFFE6E1EE))), child: Text(t, style: _st(13.5, w: FontWeight.w700, c: dark ? Colors.white : _ink))));
bool _out(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current == null));

// ------------------------------------------------------------------ Kéla : brief par écrit

class KelaBrief extends ConsumerStatefulWidget {
  const KelaBrief({super.key, this.width = 342, this.height = 620});
  final double width, height;
  @override
  ConsumerState<KelaBrief> createState() => _KelaBriefState();
}

/// Discussion avec Kéla : le texte écrit ou dicté au micro est envoyé tel quel à l'IA (fonction Edge « kela-chat »), qui répond et, s'il y a un
/// besoin à confier à des étudiants, propose un brouillon de besoin à créer. Sans clé d'IA côté serveur, Kéla le dit : aucune réponse inventée.
class _KelaBriefState extends ConsumerState<KelaBrief> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _dict = Dictation();
  final List<({bool mine, String text})> _msgs = [];
  Map<String, dynamic>? _brief;
  bool _busy = false, _listening = false;

  @override
  void dispose() {
    _dict.stop();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    final t = (override ?? _text.text).trim();
    if (t.length < 2 || _busy) return;
    setState(() {
      _msgs.add((mine: true, text: t));
      _text.clear();
      _busy = true;
      _brief = null;
    });
    _toEnd();
    String reply;
    try {
      final history = [for (final m in _msgs.take(_msgs.length - 1)) {'role': m.mine ? 'user' : 'assistant', 'content': m.text}];
      final r = await Supabase.instance.client.functions.invoke('kela-chat', body: {'message': t, 'history': history});
      final d = r.data;
      reply = d is Map && d['reply'] is String ? d['reply'] as String : 'Kéla n’a pas pu répondre pour le moment.';
      if (d is Map && d['brief'] is Map) _brief = Map<String, dynamic>.from(d['brief'] as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      reply = d is Map && d['message'] is String ? d['message'] as String : 'Kéla est momentanément indisponible.';
    } catch (_) {
      reply = 'Kéla est momentanément indisponible. Vérifiez votre connexion.';
    }
    if (!mounted) return;
    setState(() {
      _msgs.add((mine: false, text: reply));
      _busy = false;
    });
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  void _mic() {
    if (_listening) {
      _dict.stop();
      return;
    }
    if (!_dict.supported) {
      gToast(context, 'La dictée vocale n’est pas disponible sur ce navigateur. Écrivez votre message.');
      return;
    }
    setState(() => _listening = true);
    _dict.start(
      onText: (t, fin) {
        if (!mounted) return;
        setState(() => _text.text = t);
        // le texte dicté est traité directement par l'IA dès que la phrase est terminée
        if (fin && t.isNotEmpty) _send(t);
      },
      onEnd: () {
        if (mounted) setState(() => _listening = false);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _listening = false);
        gToast(context, e == 'not-allowed' ? 'Autorisez le micro dans votre navigateur pour dicter.' : e == 'no-speech' ? 'Aucune voix détectée.' : 'La dictée n’a pas fonctionné.');
      },
    );
  }

  Future<void> _createDraft() async {
    final b = _brief;
    if (b == null) return;
    final budget = (b['budget'] as num?)?.toInt();
    final r = await Backend.rpc('save_mission', {'p_id': null, 'p_title': '${b['title'] ?? 'Besoin'}', 'p_description': '${b['description'] ?? ''}', 'p_budget_min': budget, 'p_budget_max': budget, 'p_deadline': null, 'p_publish': false, 'p_kind': 'besoin'});
    if (!mounted) return;
    if (r.error != null) {
      gToast(context, Backend.userMessage(r.error!));
      return;
    }
    setState(() => _brief = null);
    gToast(context, 'Brouillon de besoin créé. Retrouvez-le dans vos briefs pour le publier.');
    await ref.read(myMissionDraftsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    if (_out(ref)) return _note(w, 'Connectez-vous pour parler à Kéla.');
    return SizedBox(
      width: w,
      height: widget.height,
      child: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('Parlez ou écrivez à Kéla : décrivez votre besoin (logo, affiche, vidéo…), posez une question sur une commande ou une mission.', textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5))))
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _msgs.length + (_busy ? 1 : 0) + (_brief != null ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i < _msgs.length) {
                      final m = _msgs[i];
                      return Align(alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: BoxConstraints(maxWidth: w * 0.82), margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: m.mine ? _ink : Colors.white, borderRadius: BorderRadius.circular(18), border: m.mine ? null : Border.all(color: const Color(0xFFECE8F2))), child: Text(m.text, style: _st(13.5, c: m.mine ? Colors.white : _ink).copyWith(height: 1.45))));
                    }
                    if (_busy && i == _msgs.length) return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(8), child: Text('Kéla réfléchit…', style: _st(12, c: _grey))));
                    final b = _brief!;
                    return Container(margin: const EdgeInsets.symmetric(vertical: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Brief proposé', style: _st(12, w: FontWeight.w800, c: const Color(0xFF5A3FE0))), const SizedBox(height: 4), Text('${b['title']}', style: _st(14, w: FontWeight.w700)), Text('${b['description']}${b['budget'] == null ? '' : '\nBudget : ${b['budget']} FCFA'}', style: _st(12.5, c: _grey)), const SizedBox(height: 10), _btn('Créer le brouillon de besoin', _createDraft)]));
                  },
                ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _text, minLines: 1, maxLines: 3, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: _listening ? 'Je vous écoute…' : 'Écrivez ou parlez à Kéla', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          const SizedBox(width: 6),
          GestureDetector(onTap: _mic, child: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: _listening ? const Color(0xFFE5484D) : Colors.white, border: Border.all(color: const Color(0xFFE6E1EE))), child: Icon(_listening ? Icons.stop_rounded : Icons.mic_none_rounded, color: _listening ? Colors.white : _ink))),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => _send(), child: Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: _ink), child: const Icon(Icons.arrow_upward_rounded, color: Colors.white))),
        ]),
      ]),
    );
  }
}

final myMissionDraftsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('missions', 'title,status,created_at,client_id', order: 'created_at'));

class KelaRecent extends ConsumerWidget {
  const KelaRecent({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_out(ref)) return _note(width, 'Connectez-vous pour voir vos briefs.');
    final all = ref.watch(myMissionDraftsProvider);
    if (all == null) return _note(width, 'Chargement…');
    final uid = Backend.userId;
    final mine = [for (final r in all) if (uid != null && '${r['client_id']}' == uid) r];
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Vos briefs', style: _st(17, w: FontWeight.w800)),
        const SizedBox(height: 10),
        if (mine.isEmpty)
          Expanded(child: _note(width, 'Aucun brief pour le moment.\nÉcrivez votre besoin à Kéla pour créer le premier.'))
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: mine.length,
              separatorBuilder: (_, _) => const Divider(height: 20, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) => Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${mine[i]['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 2), Text('Créé le ${dateCourte(mine[i]['created_at'])}', style: _st(11.5, c: _grey))])),
                Text(missionStatus(mine[i]['status']), style: _st(11.5, w: FontWeight.w700, c: const Color(0xFF5A3FE0))),
              ]),
            ),
          ),
      ]),
    );
  }
}

class KelaMenu extends ConsumerWidget {
  const KelaMenu({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(authProvider.select((s) => s.current));
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a == null ? 'Bonjour' : 'Bonjour ${a.name.split(' ').first}', style: _st(22, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Que fait-on aujourd’hui ?', style: _st(13.5, c: _grey)),
        const SizedBox(height: 20),
        _btn('Écrire mon besoin à Kéla', () => gOpen(context, '230'), w: width),
        const SizedBox(height: 12),
        _btn('Voir mes briefs', () => gOpen(context, '232'), dark: false, w: width),
        const SizedBox(height: 12),
        _btn('Publier un besoin', () => gOpen(context, '90'), dark: false, w: width),
        const SizedBox(height: 12),
        _btn('Découvrir les talents', () => gOpen(context, '70'), dark: false, w: width),
      ]),
    );
  }
}

// ------------------------------------------------------------------ produit sans 3D

class ProductNoModel extends ConsumerWidget {
  const ProductNoModel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(selectedProductProvider);
    return SizedBox(
      width: width,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset(p.image, width: width, height: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: width, height: 220, color: const Color(0xFFF2EFF6)))),
        const SizedBox(height: 14),
        Text(p.title, style: _st(17, w: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Aucun modèle 3D ni aperçu en réalité augmentée n’est disponible pour ce produit pour le moment. Seule la photo de l’annonce est affichée.', style: _st(12.5, c: _grey).copyWith(height: 1.5)),
        const SizedBox(height: 14),
        _btn('Voir la fiche du produit', () => gOpen(context, '05'), dark: false, w: width),
      ])),
    );
  }
}

// ------------------------------------------------------------------ double authentification (application)

class MfaPanel extends ConsumerStatefulWidget {
  const MfaPanel({super.key, this.width = 342});
  final double width;
  @override
  ConsumerState<MfaPanel> createState() => _MfaPanelState();
}

class _MfaPanelState extends ConsumerState<MfaPanel> {
  final _code = TextEditingController();
  bool? _active;
  String? _factorId, _secret, _uri, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  SupabaseClient? get _c {
    try {
      return Backend.ready ? Supabase.instance.client : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final c = _c;
    if (c == null || c.auth.currentUser == null) {
      if (mounted) setState(() => _error = 'La double authentification n’est pas disponible pour le moment.');
      return;
    }
    try {
      final f = await c.auth.mfa.listFactors();
      if (!mounted) return;
      setState(() => _active = f.totp.any((x) => x.status == FactorStatus.verified));
    } catch (_) {
      if (mounted) setState(() => _error = 'La double authentification n’est pas disponible pour le moment.');
    }
  }

  Future<void> _enroll() async {
    final c = _c;
    if (c == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await c.auth.mfa.enroll(factorType: FactorType.totp, issuer: 'Boutik-École', friendlyName: 'Application ${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      setState(() {
        _factorId = r.id;
        _secret = r.totp?.secret;
        _uri = r.totp?.uri;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Activation impossible : $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    final c = _c;
    final id = _factorId;
    if (c == null || id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await c.auth.mfa.challengeAndVerify(factorId: id, code: _code.text.trim());
      if (!mounted) return;
      setState(() {
        _active = true;
        _factorId = null;
        _secret = null;
        _code.clear();
      });
      gToast(context, 'Double authentification activée.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Code incorrect ou expiré.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disable() async {
    final c = _c;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final f = await c.auth.mfa.listFactors();
      for (final x in f.totp) {
        await c.auth.mfa.unenroll(x.id);
      }
      if (mounted) setState(() => _active = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Désactivation impossible pour le moment.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    if (_out(ref)) return _note(w, 'Connectez-vous pour gérer la vérification en 2 étapes.');
    if (_error != null && _active == null) return _note(w, _error!);
    if (_active == null) return _note(w, 'Chargement…');
    return SizedBox(
      width: w,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_active! ? 'Vérification en 2 étapes active' : 'Vérification en 2 étapes désactivée', style: _st(17, w: FontWeight.w800, c: _active! ? const Color(0xFF0F7A52) : _ink)),
        const SizedBox(height: 6),
        Text('Un code à 6 chiffres, généré par une application d’authentification (Google Authenticator, Authy…), est demandé en plus du mot de passe.', style: _st(12.5, c: _grey).copyWith(height: 1.5)),
        const SizedBox(height: 16),
        if (_factorId != null) ...[
          Text('1. Dans votre application, ajoutez un compte avec cette clé :', style: _st(13, w: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(width: w, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(14)), child: SelectableText(_secret ?? _uri ?? '', style: _st(13, w: FontWeight.w700))),
          const SizedBox(height: 12),
          Text('2. Saisissez le code affiché :', style: _st(13, w: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(border: OutlineInputBorder(), counterText: '')),
          const SizedBox(height: 10),
          _btn(_busy ? 'Vérification…' : 'Valider le code', _busy ? () {} : _verify, w: w),
        ] else if (_active!)
          _btn('Désactiver', _busy ? () {} : _disable, dark: false, w: w)
        else
          _btn(_busy ? 'Préparation…' : 'Activer la vérification en 2 étapes', _busy ? () {} : _enroll, w: w),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: _st(12.5, c: const Color(0xFFC0392B)))),
      ]),
    );
  }
}

// ------------------------------------------------------------------ langue

class LanguagePanel extends StatelessWidget {
  const LanguagePanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget row(String name, String state, bool on) => Container(width: width, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? _ink : const Color(0xFFECE8F2), width: on ? 1.5 : 1)), child: Row(children: [Expanded(child: Text(name, style: _st(14, w: FontWeight.w700))), Text(state, style: _st(12, w: FontWeight.w700, c: on ? const Color(0xFF0F7A52) : _grey))]));
    return SizedBox(
      width: width,
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row('Français', 'Actif', true),
        row('English', 'Bientôt disponible', false),
        const SizedBox(height: 4),
        Text('L’application est entièrement en français. L’anglais sera proposé quand les textes seront traduits.', style: _st(12, c: _grey).copyWith(height: 1.5)),
      ])),
    );
  }
}

// ------------------------------------------------------------------ contrôles d'une fiche

final checkListingsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('listings', 'title,description,price,stock,images,status,seller_id', order: 'created_at'));

class ListingChecks extends ConsumerWidget {
  const ListingChecks({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_out(ref)) return _note(width, 'Connectez-vous pour voir les contrôles de votre fiche.');
    final all = ref.watch(checkListingsProvider);
    if (all == null) return _note(width, 'Chargement…');
    final uid = Backend.userId;
    final mine = [for (final r in all) if (uid != null && '${r['seller_id']}' == uid) r];
    if (mine.isEmpty) return _note(width, 'Vous n’avez pas encore d’annonce à contrôler.');
    final l = mine.first;
    final images = (l['images'] as List?) ?? const [];
    final checks = <(String, bool)>[
      ('Titre renseigné (3 caractères minimum)', '${l['title']}'.trim().length >= 3),
      ('Description détaillée (20 caractères minimum)', '${l['description'] ?? ''}'.trim().length >= 20),
      ('Prix en FCFA supérieur à zéro', ((l['price'] as num?) ?? 0) > 0),
      ('Quantité renseignée', l['stock'] != null),
      ('Au moins une photo', images.isNotEmpty),
    ];
    final ok = checks.where((c) => c.$2).length;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${l['title']}', style: _st(17, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('$ok / ${checks.length} contrôles réussis', style: _st(13, w: FontWeight.w700, c: ok == checks.length ? const Color(0xFF0F7A52) : const Color(0xFF8F5400))),
        const SizedBox(height: 14),
        for (final c in checks) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Icon(c.$2 ? Icons.check_circle : Icons.error_outline, size: 22, color: c.$2 ? const Color(0xFF1F9D6B) : const Color(0xFFD98200)), const SizedBox(width: 12), Expanded(child: Text(c.$1, style: _st(13.5, w: FontWeight.w600))), Text(c.$2 ? 'Réussi' : 'À corriger', style: _st(11.5, w: FontWeight.w700, c: c.$2 ? const Color(0xFF0F7A52) : const Color(0xFF8F5400)))])),
      ]),
    );
  }
}

class DepositRules extends StatelessWidget {
  const DepositRules({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget r(String a, String b) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(a, style: _st(12.5, c: _grey))), Expanded(child: Text(b, style: _st(13, w: FontWeight.w600)))]));
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Règles de dépôt', style: _st(17, w: FontWeight.w800)),
        const SizedBox(height: 8),
        r('Types autorisés', 'JPG · PNG · WebP · PDF · MP4 · ZIP'),
        r('Taille maximale', '5 Mo image · 200 Mo vidéo'),
        const SizedBox(height: 10),
        Text('Les fichiers se déposent depuis le formulaire de l’annonce ; aucun fichier n’est listé ici tant que vous n’en avez pas déposé.', style: _st(12, c: _grey).copyWith(height: 1.5)),
      ]),
    );
  }
}

class InstitutionLine extends ConsumerWidget {
  const InstitutionLine({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(authProvider.select((s) => s.current));
    return SizedBox(width: width, child: Text(a == null || a.institution.isEmpty ? 'Institution non renseignée' : 'Institution : ${a.institution}', style: _st(13.5, w: FontWeight.w600)));
  }
}

/// Réglages d'accessibilité mémorisés sur l'appareil (écran 149) : mêmes interrupteurs que l'écran 186.
final accessProvider149 = accessPrefsProvider;

// ------------------------------------------------------------------ pages de texte modifiables (contenus éditoriaux)

final cmsPagesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('cms_items', 'kind,title,body,active,updated_at', order: 'updated_at'));

/// Page de texte fixe modifiable : si un contenu actif de type « page » porte ce titre (créé depuis la gestion des contenus, écran 264),
/// il remplace le texte de la maquette ; sinon le texte d'origine reste affiché.
class CmsPageOverlay extends ConsumerWidget {
  const CmsPageOverlay({super.key, required this.title, this.width = 390, this.height = 700});
  final String title;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(cmsPagesProvider);
    final hit = all?.where((r) => '${r['kind']}' == 'page' && r['active'] == true && '${r['title']}'.trim().toLowerCase() == title.toLowerCase()).toList() ?? const [];
    if (hit.isEmpty) return const SizedBox.shrink();
    final r = hit.first;
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF7F6F4),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['title']}', style: _st(20, w: FontWeight.w800)), const SizedBox(height: 4), Text('Mis à jour le ${dateCourte(r['updated_at'])}', style: _st(11.5, c: _grey)), const SizedBox(height: 16), Text('${r['body']}', style: _st(14).copyWith(height: 1.6))])),
    );
  }
}
