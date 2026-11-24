import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Passeport Talent 360° (migration 20261126060100) : vue unique de l'identité professionnelle, des compétences, réalisations, certificats vérifiables, missions
/// menées à terme et disponibilités. Le PROPRIÉTAIRE choisit, rubrique par rubrique, qui voit quoi (privé par défaut, organisations vérifiées, comptes connectés) ;
/// une rubrique non partagée n'est pas révélée à un tiers. Tout vient du serveur (`talent_passport_360`) : une rubrique vide est dite vide, une erreur est dite erreur.

const passportSections = {
  'identite': 'Identité professionnelle',
  'competences': 'Compétences',
  'realisations': 'Réalisations',
  'certificats': 'Certificats vérifiables',
  'missions': 'Missions menées à terme',
  'disponibilites': 'Disponibilités',
};
const passportAudiences = {'prive': 'Privé (moi seul)', 'organisations': 'Organisations vérifiées', 'connectes': 'Comptes connectés'};
const _levelLabels = {'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'};

final passport360Provider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId));
  final r = await marcheCall('talent_passport_360', {if (userId.isNotEmpty) 'p_user': userId});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

class Passport360Screen extends ConsumerStatefulWidget {
  const Passport360Screen({super.key, this.userId = ''});

  /// Vide = mon propre passeport.
  final String userId;

  @override
  ConsumerState<Passport360Screen> createState() => _Passport360State();
}

class _Passport360State extends ConsumerState<Passport360Screen> {
  final _headline = TextEditingController(), _summary = TextEditingController();
  bool _busy = false, _seeded = false;

  @override
  void dispose() {
    _headline.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _reload() => ref.invalidate(passport360Provider(widget.userId));

  /// Écriture serveur : en cas d'échec, message et aucune confirmation ; sinon le passeport est relu depuis le serveur.
  Future<bool> _write(String fn, Map<String, dynamic> p, String failTitle, String done) async {
    setState(() => _busy = true);
    final r = await marcheCall(fn, p);
    if (!mounted) return false;
    setState(() => _busy = false);
    if (r.error != null) {
      await gAlert(context, failTitle, marcheErrorText(r.error));
      return false;
    }
    if (done.isNotEmpty) gToast(context, done);
    _reload();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(passport360Provider(widget.userId));
    return MarchePage(
      title: 'Passeport Talent 360°',
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$e', textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
              const SizedBox(height: 10),
              mButton('Réessayer', _reload, dark: false, icon: Icons.refresh_rounded),
            ]),
          ),
        ),
        data: (p) => p == null ? mNote('Ce passeport n’est pas disponible.') : _body(p),
      ),
    );
  }

  Widget _body(Map<String, dynamic> p) {
    final own = p['own'] == true;
    final sections = p['sections'] is Map ? Map<String, dynamic>.from(p['sections'] as Map) : const <String, dynamic>{};
    final shares = p['shares'] is Map ? Map<String, dynamic>.from(p['shares'] as Map) : const <String, dynamic>{};
    final ident = sections['identite'] is Map ? Map<String, dynamic>.from(sections['identite'] as Map) : const <String, dynamic>{};
    if (own && !_seeded && ident['shared'] == true) {
      _seeded = true;
      _headline.text = '${ident['headline'] ?? ''}';
      _summary.text = '${ident['summary'] ?? ''}';
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      Text('${p['name'] ?? ''}', style: mst(20, w: FontWeight.w800)),
      Text(own ? 'Vous décidez, rubrique par rubrique, qui peut voir quoi. Par défaut, tout est privé.' : 'Seules les rubriques partagées par la personne sont affichées.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
      for (final e in passportSections.entries) _section(e.key, e.value, sections[e.key] is Map ? Map<String, dynamic>.from(sections[e.key] as Map) : const {}, own, '${shares[e.key] ?? 'prive'}'),
    ]);
  }

  Widget _section(String key, String title, Map<String, dynamic> s, bool own, String audience) {
    final shared = s['shared'] == true;
    final List<Widget> body;
    if (!shared) {
      body = [Text('Rubrique non partagée par la personne.', style: mst(13, c: kGrey))];
    } else {
      body = switch (key) {
        'identite' => _identity(s, own),
        'competences' => _items(s, 'Aucune compétence déclarée.', (x) => '${x['skill']} · ${_levelLabels['${x['level']}'] ?? 'niveau non indiqué'}${x['years'] != null ? ' · ${x['years']} an(s)' : ''}${x['proof_verified'] == true ? ' · justificatif vérifié' : (x['has_proof'] == true ? ' · justificatif déposé' : '')}'),
        'realisations' => _items(s, 'Aucune réalisation publiée.', (x) => '${x['title']}${'${x['category'] ?? ''}'.isEmpty ? '' : ' · ${x['category']}'}'),
        'certificats' => _items(s, 'Aucun certificat vérifiable.', (x) => '${x['title']} · code ${x['code']}'),
        'missions' => _items(s, 'Aucune mission menée à terme.', (x) => '${x['title']} · ${'${x['ended_on'] ?? ''}'}'),
        _ => _availability(s),
      };
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: mst(15, w: FontWeight.w800)),
        const SizedBox(height: 6),
        ...body,
        if (own) ...[
          const SizedBox(height: 8),
          MDropdown(
            label: 'Qui voit : $title',
            value: audience,
            items: passportAudiences,
            onChanged: (v) {
              if (_busy || v == audience) return;
              _write('talent_passport_share_set', {'p_section': key, 'p_audience': v}, 'Partage non modifié', 'Partage mis à jour : ${passportAudiences[v]}.');
            },
          ),
        ],
      ]),
    );
  }

  List<Widget> _identity(Map<String, dynamic> s, bool own) => [
        if (own) ...[
          TextField(controller: _headline, maxLength: 120, decoration: const InputDecoration(labelText: 'Titre professionnel', counterText: '')),
          TextField(controller: _summary, maxLength: 1000, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Résumé professionnel', counterText: '')),
          mButton('Enregistrer', _busy ? null : () => _write('talent_passport_identity_set', {'p_headline': _headline.text.trim(), 'p_summary': _summary.text.trim()}, 'Identité non enregistrée', 'Identité professionnelle enregistrée.'), busy: _busy),
        ] else ...[
          if ('${s['headline'] ?? ''}'.isNotEmpty) Text('${s['headline']}', style: mst(14, w: FontWeight.w700)),
          if ('${s['summary'] ?? ''}'.isNotEmpty) Text('${s['summary']}', style: mst(13).copyWith(height: 1.4)),
        ],
        Text([for (final k in ['department', 'institution', 'city']) if ('${s[k] ?? ''}'.isNotEmpty) '${s[k]}'].join(' · '), style: mst(12.5, c: kGrey)),
      ];

  List<Widget> _items(Map<String, dynamic> s, String empty, String Function(Map<String, dynamic>) line) {
    final items = [for (final x in (s['items'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    if (items.isEmpty) return [Text(empty, style: mst(13, c: kGrey))];
    return [for (final x in items) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(line(x), style: mst(13)))];
  }

  List<Widget> _availability(Map<String, dynamic> s) {
    final a = s['availability'] is Map ? Map<String, dynamic>.from(s['availability'] as Map) : null;
    final langs = [for (final x in (s['languages'] as List? ?? const [])) '${(x as Map)['language']} (${x['level']})'];
    if (a == null && langs.isEmpty) return [Text('Aucune disponibilité indiquée.', style: mst(13, c: kGrey))];
    return [
      if (a != null) Text('Disponible pour : ${((a['kinds'] as List? ?? const []).join(', '))}${'${a['available_from'] ?? ''}'.isEmpty ? '' : ' · à partir du ${a['available_from']}'}', style: mst(13)),
      if (a != null && '${a['note'] ?? ''}'.isNotEmpty) Text('${a['note']}', style: mst(12.5, c: kGrey)),
      if (langs.isNotEmpty) Text('Langues : ${langs.join(', ')}', style: mst(13)),
    ];
  }
}
