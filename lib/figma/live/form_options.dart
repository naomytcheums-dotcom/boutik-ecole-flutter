import 'package:flutter/material.dart' hide Text;

import '../i18n.dart' show Text;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Listes proposées dans les formulaires des entreprises : l'entreprise choisit au lieu d'écrire.

/// Les 54 pays d'Afrique, dans l'ordre alphabétique.
const africanCountries = [
  'Afrique du Sud', 'Algérie', 'Angola', 'Bénin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroun', 'Cap-Vert', 'Centrafrique', 'Comores',
  'Congo', 'Côte d’Ivoire', 'Djibouti', 'Égypte', 'Érythrée', 'Eswatini', 'Éthiopie', 'Gabon', 'Gambie', 'Ghana', 'Guinée', 'Guinée équatoriale',
  'Guinée-Bissau', 'Kenya', 'Lesotho', 'Libéria', 'Libye', 'Madagascar', 'Malawi', 'Mali', 'Maroc', 'Maurice', 'Mauritanie', 'Mozambique',
  'Namibie', 'Niger', 'Nigéria', 'Ouganda', 'RD Congo', 'Rwanda', 'Sao Tomé-et-Principe', 'Sénégal', 'Seychelles', 'Sierra Leone', 'Somalie',
  'Soudan', 'Soudan du Sud', 'Tanzanie', 'Tchad', 'Togo', 'Tunisie', 'Zambie', 'Zimbabwe',
];

/// « Pays ou zone » d'une annonce : un pays d'Afrique, ou une zone plus large.
final countryOrZoneItems = <String, String>{
  '': 'Choisir un pays ou une zone',
  'Afrique': 'Toute l’Afrique',
  'International': 'International',
  for (final c in africanCountries) c: c,
};

/// Secteurs d'activité ; « Autre » ouvre un champ pour écrire le sien.
const companySectorOther = '__other__';
const companySectors = [
  'Agriculture et agroalimentaire', 'Banque, finance et assurance', 'BTP et immobilier', 'Commerce et distribution', 'Communication et marketing',
  'Éducation et formation', 'Énergie et mines', 'Industrie et manufacture', 'Mode, art et culture', 'Numérique et télécoms', 'ONG et associations',
  'Santé et pharmacie', 'Services aux entreprises', 'Tourisme, hôtellerie et restauration', 'Transport et logistique',
];

/// Filières proposées, selon le domaine de l'annonce.
const studyFields = [
  'Informatique et numérique', 'Gestion et commerce', 'Comptabilité et finance', 'Communication et marketing', 'Génie civil et BTP',
  'Génie électrique et énergie', 'Génie mécanique et industriel', 'Agronomie et agroalimentaire', 'Santé', 'Droit', 'Lettres et langues',
  'Arts, design et audiovisuel', 'Sciences', 'Toutes les filières',
];

/// Devises acceptées par le serveur pour une participation payante.
const currencyItems = {'FCFA': 'FCFA', 'EUR': 'Euro (EUR)', 'USD': 'Dollar (USD)'};

/// Champ à choix multiples : la personne coche dans une liste ; le résultat est une liste séparée par des virgules.
class MultiPickField extends StatelessWidget {
  const MultiPickField({super.key, required this.label, required this.options, required this.value, required this.onChanged, this.emptyText = 'Aucun choix : ouvert à tous'});
  final String label, emptyText;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  List<String> get _selected => [for (final x in value.split(',')) if (x.trim().isNotEmpty) x.trim()];

  Future<void> _open(BuildContext context) async {
    final sel = {..._selected};
    final res = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 6), child: Row(children: [Expanded(child: Text(label, style: mst(16, w: FontWeight.w800))), TextButton(onPressed: () => Navigator.pop(ctx, sel), child: Text('Valider', style: mst(14, w: FontWeight.w800, c: kViolet)))])),
              Expanded(
                child: ListView(children: [
                  for (final o in options)
                    CheckboxListTile(
                      dense: true,
                      value: sel.contains(o),
                      title: Text(o, style: mst(13.5)),
                      onChanged: (v) => setS(() => v == true ? sel.add(o) : sel.remove(o)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
    if (res != null) onChanged([for (final o in options) if (res.contains(o)) o].join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final s = _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () => _open(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: kLine)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: mst(11.5, c: kGrey)),
                  Text(s.isEmpty ? emptyText : s.join(', '), style: mst(13, w: FontWeight.w600)),
                ]),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: kInk),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de date qui ne se coupe pas : le texte est ramené à une taille normale dans la fenêtre (une grande police du téléphone
/// la faisait déborder) et, sur un écran bas (paysage), la date se saisit au clavier au lieu d'un calendrier trop haut.
Future<DateTime?> pickDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  final low = MediaQuery.of(context).size.height < 600;
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    initialEntryMode: low ? DatePickerEntryMode.input : DatePickerEntryMode.calendar,
    builder: (ctx, child) {
      final mq = MediaQuery.of(ctx);
      final scale = mq.textScaler.scale(1).clamp(1.0, 1.0);
      return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(scale)), child: child ?? const SizedBox.shrink());
    },
  );
}
