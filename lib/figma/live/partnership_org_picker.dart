import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../i18n.dart' show Text;

/// Choix de l'organisation d'un partenariat (lot K4) : une organisation INSCRITE dont la fiche est approuvée (recherche serveur `partnership_org_search` :
/// nom public, type et ville seulement) ou une organisation NON inscrite (saisie libre faite par l'écran appelant). Rien n'est inventé : la liste vient du serveur.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _accent = Color(0xFF5A3FE0);
const _red = Color(0xFFB3261E);
const _line = Color(0xFFE6E1EE);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

/// Appel de recherche : renvoie les organisations approuvées (liste JSON) ou une erreur lisible.
typedef OrgSearch = Future<({Object? data, String? error})> Function(String query);

class OrgChoice {
  const OrgChoice({required this.id, required this.name, this.typeLabel = '', this.city = ''});

  factory OrgChoice.fromJson(Map<dynamic, dynamic> m) => OrgChoice(id: '${m['id']}', name: '${m['name'] ?? ''}', typeLabel: '${m['type_label'] ?? ''}', city: '${m['city'] ?? ''}');

  final String id, name, typeLabel, city;

  String get subtitle => [typeLabel, city].where((x) => x.trim().isNotEmpty).join(' · ');
}

class PartnershipOrgPicker extends StatefulWidget {
  const PartnershipOrgPicker({super.key, required this.registered, required this.selected, required this.onMode, required this.onSelect, required this.search});

  final bool registered;
  final OrgChoice? selected;
  final ValueChanged<bool> onMode;
  final ValueChanged<OrgChoice?> onSelect;
  final OrgSearch search;

  @override
  State<PartnershipOrgPicker> createState() => _PartnershipOrgPickerState();
}

class _PartnershipOrgPickerState extends State<PartnershipOrgPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<OrgChoice>? _results;
  String? _error;
  bool _loading = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    if (widget.registered && widget.selected == null) _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final mine = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await widget.search(q.trim());
    if (!mounted || mine != _seq) return;
    setState(() {
      _loading = false;
      if (r.error != null) {
        _error = r.error;
        _results = null;
      } else {
        _results = [for (final x in (r.data is List ? r.data as List : const [])) if (x is Map) OrgChoice.fromJson(x)];
      }
    });
  }

  void _typed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Widget _mode(String label, bool on, VoidCallback tap) => Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: tap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: on ? _ink : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: on ? _ink : _line)),
              child: Text(label, style: _st(12.5, w: FontWeight.w700, c: on ? Colors.white : _ink)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _mode('Organisation inscrite', widget.registered, () {
          widget.onMode(true);
          if (_results == null && !_loading && widget.selected == null) _run(_query.text);
        }),
        _mode('Organisation non inscrite', !widget.registered, () => widget.onMode(false)),
      ]),
      const SizedBox(height: 8),
      Text(
        widget.registered
            ? 'Liée à une fiche d’organisation approuvée : l’organisation voit ce partenariat dans son espace et peut l’accepter ou le contester.'
            : 'Organisation non inscrite sur Boutik-École : nom et type saisis librement ; elle n’est pas notifiée et ne voit rien.',
        style: _st(11.5, c: _grey).copyWith(height: 1.4),
      ),
      if (widget.registered) ...[
        const SizedBox(height: 8),
        if (sel != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            decoration: BoxDecoration(color: const Color(0xFFF4F1FC), borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
            child: Row(children: [
              const Icon(Icons.verified_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sel.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700)),
                  if (sel.subtitle.isNotEmpty) Text(sel.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                ]),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () {
                  widget.onSelect(null);
                  _run(_query.text);
                },
                child: Text('Changer', style: _st(12.5, w: FontWeight.w700, c: _accent)),
              ),
            ]),
          )
        else ...[
          TextField(
            controller: _query,
            onChanged: _typed,
            textInputAction: TextInputAction.search,
            onSubmitted: _run,
            decoration: const InputDecoration(labelText: 'Rechercher une organisation approuvée', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          if (_loading)
            const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))))
          else if (_error != null)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('La recherche n’a pas abouti : $_error', style: _st(12, c: _red)),
              TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => _run(_query.text), child: Text('Réessayer', style: _st(12.5, w: FontWeight.w700, c: _accent))),
            ])
          else if ((_results ?? const []).isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Aucune organisation approuvée ne correspond. Utilisez « Organisation non inscrite » si elle n’a pas de compte.', style: _st(12, c: _grey)))
          else
            for (final o in _results!.take(8))
              Semantics(
                button: true,
                label: 'Choisir ${o.name}',
                child: InkWell(
                  onTap: () => widget.onSelect(o),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(children: [
                        const Icon(Icons.business_outlined, size: 20, color: _grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                            if (o.subtitle.isNotEmpty) Text(o.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
        ],
      ],
    ]);
  }
}

/// Étiquette de la réponse d'une organisation à un partenariat actif.
String orgResponseLabel(Object? v) => switch ('$v') {
      'pending' => 'À confirmer par l’organisation',
      'accepted' => 'Accepté par l’organisation',
      'contested' => 'Contesté par l’organisation',
      _ => '',
    };
