import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'qr.dart' show qrTokenOf;
import 'vendeur_public.dart' show certificateCodeInText, normalizeCertificateCode;

const _f = 'PlusJakartaSans';
const _ink = Color(0xFF111015);
const _grey = Color(0xFF4A4854);
const _green = Color(0xFF0F7A52);
const _red = Color(0xFFC0392B);
const _amber = Color(0xFF9A5B00);
const _violet = Color(0xFF5A3FE0);
TextStyle _t(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: _f, fontSize: s, fontWeight: w, color: c, height: 1.45, textBaseline: TextBaseline.alphabetic);

const proofDisclaimer = 'Cet horodatage prouve l’existence du document à une date donnée ; ce n’est pas un brevet ni un titre de propriété intellectuelle.';

enum VerifyKind { certificat, passeport, projet }

final _tokenFormat = RegExp(r'^[A-Za-z0-9_-]{32}$');
final _uuidFormat = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Dernier segment utile d'un lien (ou du texte brut) : /verifier/passeport/JETON, /verifier/projet/ID.
String _lastSegment(String raw) {
  final t = raw.trim();
  final u = Uri.tryParse(t);
  if (u != null && u.pathSegments.isNotEmpty && t.contains('/')) return u.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => t);
  return t;
}

/// Page PUBLIQUE de vérification (routes /verifier…, sans connexion) : certificat (verify_certificate_public, ou qr_resolve_public pour un QR),
/// lien de partage de passeport (passport_token_verify) et registre de preuves d'innovation (project_proof_verify).
/// Un état « valide » n'est affiché que si le serveur le confirme ; toute erreur (réseau, réponse illisible) est un état à part, jamais « valide ».
class VerifyPublicScreen extends StatefulWidget {
  const VerifyPublicScreen({super.key, this.kind = VerifyKind.certificat, this.code = ''});
  final VerifyKind kind;
  final String code;

  @override
  State<VerifyPublicScreen> createState() => _VerifyPublicScreenState();
}

enum _Phase { idle, loading, result, badFormat, error }

class _VerifyPublicScreenState extends State<VerifyPublicScreen> {
  final _code = TextEditingController();
  final _holder = TextEditingController();
  late VerifyKind _kind = widget.kind;
  _Phase _phase = _Phase.idle;
  Map<String, dynamic>? _res;
  bool _compared = false;
  String? _checkedCode;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _code.text = widget.code;
    if (widget.code.trim().isNotEmpty) _check();
  }

  @override
  void didUpdateWidget(VerifyPublicScreen old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code || old.kind != widget.kind) {
      _kind = widget.kind;
      _code.text = widget.code;
      if (widget.code.trim().isNotEmpty) {
        _check();
      } else {
        setState(() {
          _phase = _Phase.idle;
          _res = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _setKind(VerifyKind k) {
    if (k == _kind) return;
    _seq++;
    setState(() {
      _kind = k;
      _phase = _Phase.idle;
      _res = null;
      _code.clear();
      _holder.clear();
    });
  }

  void _fail(int seq, _Phase p) {
    if (!mounted || seq != _seq) return;
    setState(() {
      _phase = p;
      _res = null;
    });
  }

  Future<void> _check({bool compare = false}) async {
    final raw = _code.text.trim();
    final seq = ++_seq;
    final holder = compare ? _holder.text.trim() : '';
    String? value;
    switch (_kind) {
      case VerifyKind.certificat:
        value = certificateCodeInText(raw) ?? normalizeCertificateCode(raw);
        value ??= qrTokenOf(raw);
      case VerifyKind.passeport:
        final s = _lastSegment(raw);
        value = _tokenFormat.hasMatch(s) ? s : qrTokenOf(raw);
      case VerifyKind.projet:
        final s = _lastSegment(raw);
        value = _uuidFormat.hasMatch(s) ? s.toLowerCase() : null;
    }
    if (value == null) return _fail(seq, _Phase.badFormat);
    setState(() {
      _phase = _Phase.loading;
      _compared = holder.isNotEmpty;
    });
    switch (_kind) {
      case VerifyKind.certificat:
        var code = value;
        if (!code.startsWith('BE-CERT-')) {
          // Jeton d'un QR : résolu sans connexion seulement s'il désigne un certificat.
          final q = await Backend.rpc('qr_resolve_public', {'p_token': code});
          if (!mounted || seq != _seq) return;
          final d = q.data;
          if (q.error != null || d is! Map || d['valid'] is! bool) return _fail(seq, _Phase.error);
          if (d['valid'] != true) {
            return setState(() {
              _phase = _Phase.result;
              _res = {'statut': 'qr_${d['reason'] ?? 'inconnu'}'};
            });
          }
          code = '${d['code'] ?? ''}';
          if (normalizeCertificateCode(code) == null) return _fail(seq, _Phase.error);
          code = normalizeCertificateCode(code)!;
        }
        _checkedCode = code;
        final r = await Backend.rpc('verify_certificate_public', {'p_code': code, if (holder.isNotEmpty) 'p_holder': holder});
        return _done(seq, r, (d) => d['statut'] != null);
      case VerifyKind.passeport:
        final r = await Backend.rpc('passport_token_verify', {'p_token': value});
        return _done(seq, r, (d) => d['valid'] is bool);
      case VerifyKind.projet:
        final r = await Backend.rpc('project_proof_verify', {'p_project': value});
        return _done(seq, r, (d) => d['statut'] != null);
    }
  }

  void _done(int seq, ({Object? data, String? error}) r, bool Function(Map) ok) {
    if (!mounted || seq != _seq) return;
    final d = r.data;
    if (r.error != null || d is! Map || !ok(d)) return _fail(seq, _Phase.error);
    setState(() {
      _phase = _Phase.result;
      _res = Map<String, dynamic>.from(d);
    });
  }

  String get _title => switch (_kind) {
        VerifyKind.certificat => 'Vérifier un certificat',
        VerifyKind.passeport => 'Vérifier un passeport partagé',
        VerifyKind.projet => 'Vérifier une preuve d’innovation',
      };

  String get _intro => switch (_kind) {
        VerifyKind.certificat => 'Saisissez le code inscrit sur le certificat, ou ouvrez le lien de son QR. Aucune connexion n’est nécessaire.',
        VerifyKind.passeport => 'Collez le lien de partage reçu du titulaire du passeport. Seules les rubriques qu’il a choisies de partager s’affichent, pendant la durée qu’il a fixée.',
        VerifyKind.projet => 'Collez le lien ou l’identifiant du projet. Seuls les projets approuvés dont le titulaire a enregistré des preuves sont vérifiables.',
      };

  @override
  Widget build(BuildContext context) {
    final hint = switch (_kind) {
      VerifyKind.certificat => 'Ex. BE-CERT-1A2B3C4D5E6F7A8B',
      VerifyKind.passeport => 'Lien ou jeton de partage',
      VerifyKind.projet => 'Lien ou identifiant du projet',
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text('Boutik-École · Vérification publique', style: _t(13, FontWeight.w600, _violet)),
              const SizedBox(height: 8),
              Text(_title, style: _t(24, FontWeight.w800, _ink)),
              const SizedBox(height: 6),
              Text(_intro, style: _t(14, FontWeight.w400, _grey)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _chip('Certificat', VerifyKind.certificat),
                _chip('Passeport', VerifyKind.passeport),
                _chip('Innovation', VerifyKind.projet),
              ]),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('verify_input'),
                controller: _code,
                textCapitalization: _kind == VerifyKind.certificat ? TextCapitalization.characters : TextCapitalization.none,
                maxLength: 300,
                autocorrect: false,
                decoration: InputDecoration(labelText: _kind == VerifyKind.certificat ? 'Code du certificat' : 'Lien ou code', hintText: hint, counterText: '', border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 12),
              _action('Vérifier', _phase == _Phase.loading ? null : () => _check()),
              const SizedBox(height: 20),
              _body(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VerifyKind k) => Semantics(
        button: true,
        selected: _kind == k,
        label: label,
        child: GestureDetector(
          onTap: () => _setKind(k),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _kind == k ? _ink : Colors.white, border: Border.all(color: _ink), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: _t(13, FontWeight.w700, _kind == k ? Colors.white : _ink)),
          ),
        ),
      );

  Widget _action(String label, VoidCallback? onTap, {bool dark = true}) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: dark ? (onTap == null ? _grey : _ink) : Colors.white, border: dark ? null : Border.all(color: _ink), borderRadius: BorderRadius.circular(24)),
            child: Text(label, style: _t(14, FontWeight.w700, dark ? Colors.white : _ink)),
          ),
        ),
      );

  Widget _card(Color color, String title, List<Widget> rows) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: color, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _t(17, FontWeight.w800, color)),
          const SizedBox(height: 8),
          ...rows,
        ]),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(TextSpan(children: [TextSpan(text: '$label : ', style: _t(13, FontWeight.w700, _ink)), TextSpan(text: value, style: _t(13, FontWeight.w400, _grey))])),
      );

  Widget _p(String s, {Color c = _grey, FontWeight w = FontWeight.w400}) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(s, style: _t(13.5, w, c)));

  String _s(Object? v) => v == null ? '' : '$v'.trim();

  Widget _body() {
    switch (_phase) {
      case _Phase.idle:
        return const SizedBox.shrink();
      case _Phase.loading:
        return Row(children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Vérification en cours…', style: _t(14, FontWeight.w600, _ink)),
        ]);
      case _Phase.badFormat:
        return _card(_red, 'Code non reconnu', [
          _p(switch (_kind) {
            VerifyKind.certificat => 'Un code de certificat ressemble à BE-CERT-1A2B3C4D5E6F7A8B. Vérifiez la saisie.',
            VerifyKind.passeport => 'Un lien de partage de passeport se termine par un jeton de 32 caractères. Vérifiez le lien reçu.',
            VerifyKind.projet => 'Un identifiant de projet a la forme xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx. Vérifiez le lien reçu.',
          }),
        ]);
      case _Phase.error:
        return _card(_amber, 'Vérification impossible', [
          _p('Le serveur n’a pas pu répondre. Rien n’est confirmé ni infirmé : ne considérez pas ce document comme valide. Vérifiez votre connexion puis réessayez.'),
          const SizedBox(height: 8),
          _action('Réessayer', () => _check(), dark: false),
        ]);
      case _Phase.result:
        final r = _res!;
        return switch (_kind) {
          VerifyKind.certificat => _certificate(r),
          VerifyKind.passeport => _passport(r),
          VerifyKind.projet => _project(r),
        };
    }
  }

  Widget _limit() => _card(_amber, 'Trop de tentatives', [_p('Trop de vérifications sans résultat depuis cet appareil. Réessayez dans quelques minutes ; rien n’est confirmé pour l’instant.')]);

  Widget _certificate(Map<String, dynamic> r) {
    final statut = '${r['statut']}';
    if (statut == 'qr_limit' || statut == 'limite' || r['limite'] == true) return _limit();
    if (statut == 'qr_expired') return _card(_red, 'QR expiré ou révoqué', [_p('Ce code QR n’est plus valable. Demandez au titulaire de le recréer.')]);
    if (statut.startsWith('qr_')) return _card(_amber, 'QR non vérifiable ici', [_p('Ce code QR ne désigne pas un certificat public. Il ne peut pas être vérifié sans connexion.')]);
    if (statut == 'inconnu' || r['introuvable'] == true) {
      return _card(_red, 'Certificat inconnu', [_p('Aucun certificat Boutik-École ne porte ce code. Ne lui accordez aucune valeur.')]);
    }
    final sig = _s(r['signature']);
    final revoked = statut == 'revoque';
    final ok = statut == 'valide' && r['valide'] == true && sig != 'invalide';
    final Color color = revoked || sig == 'invalide' ? _red : (ok && sig == 'valide' ? _green : _amber);
    final title = revoked
        ? 'Certificat révoqué'
        : sig == 'invalide'
            ? 'Anomalie : ne pas se fier à ce certificat'
            : !ok
                ? 'Certificat non confirmé'
                : sig == 'valide'
                    ? 'Certificat authentique'
                    : sig == 'cle_indisponible'
                        ? 'Certificat enregistré, signature non vérifiable'
                        : 'Certificat enregistré · non signé';
    final hash = _s(r['empreinte']);
    final holderName = _s(r['titulaire']);
    return _card(color, title, [
      if (revoked) _p('Ce certificat n’est plus valable.', c: _red, w: FontWeight.w600),
      if (revoked && _s(r['motif_revocation']).isNotEmpty) _line('Motif', _s(r['motif_revocation'])),
      if (!revoked && sig == 'invalide') _p('La signature numérique ne correspond pas au contenu : le certificat a pu être altéré.', c: _red, w: FontWeight.w600),
      if (_s(r['objet']).isNotEmpty) _line('Intitulé', _s(r['objet'])),
      if (holderName.isNotEmpty) _line('Titulaire', holderName),
      if (_s(r['emetteur']).isNotEmpty) _line('Émetteur', _s(r['emetteur'])),
      if (_s(r['departement']).isNotEmpty) _line('Département', _s(r['departement'])),
      if (_s(r['delivre_le']).isNotEmpty) _line('Délivré le', _s(r['delivre_le'])),
      _line('Code', _s(r['code']).isEmpty ? (_checkedCode ?? '') : _s(r['code'])),
      if (hash.isNotEmpty) ...[
        Text('Empreinte ${_s(r['empreinte_algo']).isEmpty ? 'SHA-256' : _s(r['empreinte_algo'])}', style: _t(13, FontWeight.w700, _ink)),
        SelectableText(hash, style: _t(12, FontWeight.w400, _grey)),
        const SizedBox(height: 6),
      ],
      _signature(sig, _s(r['signature_algo']), 'certificat'),
      if (r['titulaire_nom_public'] != true && holderName.isNotEmpty) ...[
        const SizedBox(height: 10),
        _p('Le titulaire n’a pas autorisé l’affichage de son nom complet : seules ses initiales sont montrées.'),
      ],
      if (!revoked && r['empreinte_recalculable'] == true) ...[
        const SizedBox(height: 12),
        Text('Vérifier le nom du titulaire (facultatif)', style: _t(13, FontWeight.w700, _ink)),
        const SizedBox(height: 6),
        TextField(key: const ValueKey('verify_holder'), controller: _holder, maxLength: 120, decoration: const InputDecoration(labelText: 'Nom complet attendu', counterText: '', border: OutlineInputBorder(), filled: true, fillColor: Colors.white), onSubmitted: (_) => _check(compare: true)),
        const SizedBox(height: 8),
        _action('Comparer', () => _check(compare: true), dark: false),
        if (_compared && r['titulaire_concordant'] != null) ...[
          const SizedBox(height: 8),
          r['titulaire_concordant'] == true
              ? Text('Le nom saisi correspond au titulaire de ce certificat.', style: _t(13.5, FontWeight.w700, _green))
              : Text('Le nom saisi ne correspond pas au titulaire de ce certificat.', style: _t(13.5, FontWeight.w700, _red)),
        ],
      ],
    ]);
  }

  Widget _signature(String sig, String algo, String what) {
    switch (sig) {
      case 'valide':
        return _p('Signature numérique ${algo.isEmpty ? '' : '($algo) '}vérifiée par Boutik-École.', c: _green, w: FontWeight.w700);
      case 'invalide':
        return _p('Signature numérique INVALIDE.', c: _red, w: FontWeight.w800);
      case 'cle_indisponible':
        return _p('Signature présente mais non vérifiable pour le moment : la clé de contrôle est indisponible.', c: _amber, w: FontWeight.w700);
      default:
        return _p('Non signé : ce $what ne porte pas de signature numérique. L’empreinte permet seulement de contrôler que son contenu est celui enregistré par Boutik-École.', c: _amber, w: FontWeight.w700);
    }
  }

  Widget _passport(Map<String, dynamic> r) {
    if (r['valid'] != true) {
      final reason = _s(r['reason']);
      if (reason == 'limit') return _limit();
      final (title, msg) = switch (reason) {
        'revoked' => ('Lien révoqué', 'Le titulaire a désactivé ce lien de partage. Aucune donnée n’est disponible.'),
        'expired' => ('Lien expiré', 'La durée de partage fixée par le titulaire est dépassée. Aucune donnée n’est disponible.'),
        'unavailable' => ('Passeport indisponible', 'Ce passeport n’est plus accessible. Aucune donnée n’est disponible.'),
        _ => ('Lien inconnu', 'Aucun partage de passeport ne correspond à ce lien. Ne lui accordez aucune valeur.'),
      };
      return _card(_red, title, [_p(msg)]);
    }
    final secs = r['sections'] is Map ? Map<String, dynamic>.from(r['sections'] as Map) : const <String, dynamic>{};
    final shared = r['shared_sections'] is List ? (r['shared_sections'] as List).map((e) => '$e').toList() : const <String>[];
    final id = secs['identite'] is Map ? Map<String, dynamic>.from(secs['identite'] as Map) : null;
    List<Map<String, dynamic>> list(String k) => secs[k] is List ? (secs[k] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    final comp = list('competences'), real = list('realisations'), certs = list('certificats'), miss = list('missions');
    return _card(_green, 'Passeport partagé par son titulaire', [
      _line('Titulaire', _s(r['name'])),
      if (_s(r['expires_at']).isNotEmpty) _line('Lien valable jusqu’au', _s(r['expires_at']).split('T').first),
      _line('Rubriques partagées', shared.isEmpty ? 'aucune' : shared.map(_sectionLabel).join(', ')),
      if (id != null) ...[
        const SizedBox(height: 6),
        Text('Identité', style: _t(14, FontWeight.w800, _ink)),
        if (_s(id['headline']).isNotEmpty) _p(_s(id['headline']), c: _ink, w: FontWeight.w600),
        if (_s(id['summary']).isNotEmpty) _p(_s(id['summary'])),
        if (_s(id['department']).isNotEmpty) _line('Département', _s(id['department'])),
        if (_s(id['institution']).isNotEmpty) _line('Établissement', _s(id['institution'])),
        if (id['certified'] == true) _p('Profil certifié par Boutik-École.', c: _green, w: FontWeight.w700),
      ],
      if (secs.containsKey('competences')) _sectionList('Compétences', comp, 'Aucune compétence renseignée.', (m) => '${_s(m['skill'])}${_s(m['level']).isEmpty ? '' : ' · ${_s(m['level'])}'}${m['years'] == null ? '' : ' · ${m['years']} an(s)'}${m['proof_verified'] == true ? ' · preuve vérifiée' : ''}'),
      if (secs.containsKey('realisations')) _sectionList('Réalisations', real, 'Aucune réalisation renseignée.', (m) => '${_s(m['title'])}${_s(m['category']).isEmpty ? '' : ' · ${_s(m['category'])}'}'),
      if (secs.containsKey('certificats')) _sectionList('Certificats', certs, 'Aucun certificat valide.', (m) => '${_s(m['title'])} · ${_s(m['code'])}'),
      if (secs.containsKey('missions')) _sectionList('Missions menées', miss, 'Aucune mission terminée.', (m) => _s(m['title'])),
    ]);
  }

  static String _sectionLabel(String k) => const {'identite': 'identité', 'competences': 'compétences', 'realisations': 'réalisations', 'certificats': 'certificats', 'missions': 'missions'}[k] ?? k;

  Widget _sectionList(String title, List<Map<String, dynamic>> items, String empty, String Function(Map<String, dynamic>) label) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _t(14, FontWeight.w800, _ink)),
          if (items.isEmpty) _p(empty) else for (final m in items) _p('• ${label(m)}'),
        ]),
      );

  Widget _project(Map<String, dynamic> r) {
    final statut = _s(r['statut']);
    if (statut == 'limite') return _limit();
    if (statut != 'enregistre') {
      return _card(_red, 'Aucune preuve vérifiable', [_p('Ce projet est introuvable, n’est pas approuvé ou n’a aucune preuve enregistrée. Ne lui accordez aucune valeur.')]);
    }
    final versions = r['versions'] is List ? (r['versions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    final intact = r['valide'] == true;
    return _card(intact ? _green : _red, intact ? 'Preuves enregistrées et intègres' : 'Anomalie : la chaîne de preuves ne correspond plus', [
      if (!intact) _p('Au moins une version a été altérée ou la chaîne est rompue : ne vous fiez pas à ce registre.', c: _red, w: FontWeight.w600),
      if (_s(r['projet']).isNotEmpty) _line('Projet', _s(r['projet'])),
      if (_s(r['auteur']).isNotEmpty) _line('Auteur', _s(r['auteur'])),
      _line('Versions enregistrées', '${versions.length}'),
      for (final v in versions) ...[
        const Divider(height: 18),
        Text('Version ${_s(v['version'])}${v['integre'] == true ? '' : ' · INTÉGRITÉ NON CONFIRMÉE'}', style: _t(13.5, FontWeight.w800, v['integre'] == true ? _ink : _red)),
        if (_s(v['horodatage']).isNotEmpty) _line('Horodatage (serveur Boutik-École)', _s(v['horodatage']).replaceFirst('T', ' ').split('.').first),
        if (_s(v['note']).isNotEmpty) _line('Note', _s(v['note'])),
        if (_s(v['empreinte']).isNotEmpty) ...[
          Text('Empreinte SHA-256', style: _t(12.5, FontWeight.w700, _ink)),
          SelectableText(_s(v['empreinte']), style: _t(11.5, FontWeight.w400, _grey)),
        ],
        _signature(_s(v['signature']), 'HMAC-SHA256', 'enregistrement'),
      ],
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFF4DA), borderRadius: BorderRadius.circular(10)),
        child: Text(proofDisclaimer, style: _t(12.5, FontWeight.w700, _amber)),
      ),
    ]);
  }
}
