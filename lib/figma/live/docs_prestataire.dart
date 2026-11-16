import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gen.dart';
import 'backend.dart';
import 'store.dart' show fcfa;

/// Justificatifs du prestataire (étudiant-vendeur) : relevé de ventes et de missions réglées (fonction serveur seller_statement)
/// et facture d'une mission (accord entre le client et le prestataire, fonction serveur mission_invoice). PDF réels.

const _logo = 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png';
const _ink = PdfColor.fromInt(0xFF111015);
const _muted = PdfColor.fromInt(0xFF57545F);
const _violet = PdfColor.fromInt(0xFF5A3FE0);
const _line = PdfColor.fromInt(0xFFE4E0EC);

int _n(Object? v) => ((v as num?) ?? 0).toInt();

String _date(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Totaux d'un relevé : montant brut des ventes, nombre de commandes, montant des missions réglées (confirmées par le prestataire).
({int sales, int orders, int missions}) statementTotals(Map<String, dynamic> s) {
  final sales = [for (final x in (s['sales'] as List? ?? const [])) x as Map];
  final missions = [for (final x in (s['missions'] as List? ?? const [])) x as Map];
  return (
    sales: sales.fold(0, (a, x) => a + _n(x['total'])),
    orders: sales.length,
    missions: missions.fold(0, (a, x) => a + _n(x['amount'])),
  );
}

/// Libellé du règlement d'un jalon sur la facture de mission.
String milestonePayLabel(String payStatus) => switch (payStatus) {
      'confirmed' => 'Réglé (réception confirmée)',
      'declared' => 'Paiement déclaré, à confirmer',
      _ => 'Non réglé',
    };

Future<({pw.Font reg, pw.Font bold, pw.MemoryImage logo})> _assets() async => (
      reg: pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-700.ttf')),
      logo: pw.MemoryImage((await rootBundle.load(_logo)).buffer.asUint8List()),
    );

pw.Widget _header(({pw.Font reg, pw.Font bold, pw.MemoryImage logo}) a, String title, List<String> right) {
  pw.TextStyle st(double s, {bool b = false, PdfColor c = _ink}) => pw.TextStyle(font: b ? a.bold : a.reg, fontSize: s, color: c);
  return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Row(children: [
      pw.Image(a.logo, width: 58, height: 50, fit: pw.BoxFit.contain),
      pw.SizedBox(width: 12),
      pw.Text('Boutik-École', style: st(20, b: true)),
    ]),
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      pw.Text(title, style: st(15, b: true, c: _violet)),
      for (final r in right) pw.Text(r, style: st(10, c: _muted)),
    ]),
  ]);
}

Future<pw.Document> buildStatementPdf(Map<String, dynamic> s) async {
  final a = await _assets();
  pw.TextStyle st(double sz, {bool b = false, PdfColor c = _ink}) => pw.TextStyle(font: b ? a.bold : a.reg, fontSize: sz, color: c);
  pw.Widget cell(String t, {bool b = false, pw.TextAlign al = pw.TextAlign.left}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5), child: pw.Text(t, textAlign: al, style: st(9, b: b)));
  final sales = [for (final x in (s['sales'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  final missions = [for (final x in (s['missions'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  final t = statementTotals(s);
  final doc = pw.Document(title: 'Relevé de ventes', author: 'Boutik-École');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40),
    build: (ctx) => [
      _header(a, 'RELEVÉ DE VENTES', ['Période : ${_date(s['from'])} au ${_date(s['to'])}', 'Établi le ${_date(s['generated_at'])}']),
      pw.SizedBox(height: 18),
      pw.Text('VENDEUR', style: st(8.5, b: true, c: _muted)),
      pw.Text('${s['seller'] ?? ''}', style: st(12, b: true)),
      pw.SizedBox(height: 16),
      pw.Text('VENTES DE LA PLATEFORME (commandes payées ou à payer à la livraison, non annulées)', style: st(8.5, b: true, c: _muted)),
      pw.SizedBox(height: 4),
      if (sales.isEmpty)
        pw.Text('Aucune vente sur la période.', style: st(10))
      else
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(4), 3: const pw.FlexColumnWidth(1), 4: const pw.FlexColumnWidth(2), 5: const pw.FlexColumnWidth(2)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .6), bottom: pw.BorderSide(color: _line, width: .6)),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F1F8)), children: [cell('Date', b: true), cell('Commande', b: true), cell('Article', b: true), cell('Qté', b: true), cell('Montant brut', b: true, al: pw.TextAlign.right), cell('Règlement', b: true)]),
            for (final x in sales)
              pw.TableRow(children: [
                cell(_date(x['created_at'])),
                cell('${x['number']}'),
                cell('${x['title']}'),
                cell('${x['qty']}'),
                cell(fcfa(_n(x['total'])), al: pw.TextAlign.right),
                cell(x['payment'] == 'paid' ? 'Payé en ligne' : 'À la livraison'),
              ]),
          ],
        ),
      pw.SizedBox(height: 6),
      pw.Text('Total des ventes : ${fcfa(t.sales)} (${t.orders} commande${t.orders > 1 ? 's' : ''})', style: st(11, b: true)),
      pw.SizedBox(height: 16),
      pw.Text('MISSIONS RÉGLÉES (paiements confirmés par vous)', style: st(8.5, b: true, c: _muted)),
      pw.SizedBox(height: 4),
      if (missions.isEmpty)
        pw.Text('Aucun règlement de mission confirmé sur la période.', style: st(10))
      else
        pw.Table(
          columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(5), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .6), bottom: pw.BorderSide(color: _line, width: .6)),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F1F8)), children: [cell('Date', b: true), cell('Mission · jalon', b: true), cell('Moyen', b: true), cell('Montant', b: true, al: pw.TextAlign.right)]),
            for (final x in missions)
              pw.TableRow(children: [
                cell(_date(x['confirmed_at'])),
                cell('${x['title']} · ${x['milestone']}'),
                cell('${x['pay_method'] ?? ''}'),
                cell(fcfa(_n(x['amount'])), al: pw.TextAlign.right),
              ]),
          ],
        ),
      pw.SizedBox(height: 6),
      pw.Text('Total des missions réglées : ${fcfa(t.missions)}', style: st(11, b: true)),
      pw.SizedBox(height: 22),
      pw.Container(height: 1, color: _line),
      pw.SizedBox(height: 8),
      pw.Text(
          'Les montants des ventes sont bruts (prix × quantité de vos articles) : ils ne tiennent compte ni de la répartition du séquestre ni des remises. '
          'Ce relevé atteste des ventes enregistrées par Boutik-École ; il ne remplace pas une déclaration fiscale.',
          style: st(8.5, c: _muted)),
    ],
  ));
  return doc;
}

Future<pw.Document> buildMissionInvoicePdf(Map<String, dynamic> inv) async {
  final a = await _assets();
  pw.TextStyle st(double sz, {bool b = false, PdfColor c = _ink}) => pw.TextStyle(font: b ? a.bold : a.reg, fontSize: sz, color: c);
  pw.Widget cell(String t, {bool b = false, pw.TextAlign al = pw.TextAlign.left}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5), child: pw.Text(t, textAlign: al, style: st(9.5, b: b)));
  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(k, style: st(10, c: _muted)), pw.Text(v, style: st(10.5, b: true))]),
      );
  final miles = [for (final x in (inv['milestones'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
  final doc = pw.Document(title: 'Facture de mission ${inv['number']}', author: 'Boutik-École');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40),
    build: (ctx) => [
      _header(a, 'FACTURE DE MISSION', ['N° ${inv['number']}', 'Accord du ${_date(inv['issued_at'])}', 'Mission ${inv['mission_number']}']),
      pw.SizedBox(height: 20),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('CLIENT', style: st(8.5, b: true, c: _muted)), pw.Text('${inv['client_name']}', style: st(11.5, b: true))])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('PRESTATAIRE', style: st(8.5, b: true, c: _muted)), pw.Text('${inv['provider_name']}', style: st(11.5, b: true))])),
      ]),
      pw.SizedBox(height: 14),
      pw.Text('${inv['title']}', style: st(13, b: true)),
      pw.SizedBox(height: 10),
      pw.Table(
        columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(4), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .6), bottom: pw.BorderSide(color: _line, width: .6)),
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F1F8)), children: [cell('N°', b: true), cell('Jalon', b: true), cell('Montant', b: true, al: pw.TextAlign.right), cell('Règlement', b: true)]),
          for (final j in miles)
            pw.TableRow(children: [
              cell('${j['position']}'),
              cell('${j['title']}${j['status'] == 'validated' ? ' (validé)' : ''}'),
              cell(fcfa(_n(j['amount'])), al: pw.TextAlign.right),
              cell('${milestonePayLabel('${j['pay_status']}')}${'${j['pay_method'] ?? ''}'.isEmpty ? '' : ' · ${j['pay_method']}'}${'${j['pay_reference'] ?? ''}'.isEmpty ? '' : ' (réf. ${j['pay_reference']})'}'),
            ]),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(width: 250, child: pw.Column(children: [
          kv('Montant convenu', fcfa(_n(inv['agreed_amount']))),
          kv('Jalons validés', fcfa(_n(inv['validated_amount']))),
          kv('Paiements déclarés (à confirmer)', fcfa(_n(inv['declared_amount']))),
          kv('Paiements confirmés', fcfa(_n(inv['confirmed_amount']))),
        ])),
      ),
      pw.SizedBox(height: 22),
      pw.Container(height: 1, color: _line),
      pw.SizedBox(height: 8),
      pw.Text('${inv['notice'] ?? ''}', style: st(8.5, c: _muted)),
    ],
  ));
  return doc;
}

Future<void> _share(BuildContext context, Future<pw.Document> Function() build, String name) async {
  try {
    final bytes = await (await build()).save();
    await Printing.sharePdf(bytes: bytes, filename: name);
  } catch (e) {
    if (context.mounted) gToast(context, 'Téléchargement impossible : $e');
  }
}

/// « Relevé de ventes » : ventes et missions réglées des douze derniers mois, en PDF.
Future<void> downloadSellerStatement(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Le relevé nécessite la connexion au serveur.');
  final r = await Backend.rpc('seller_statement', const {});
  if (!context.mounted) return;
  if (r.error != null || r.data is! Map) return gAlert(context, 'Relevé indisponible', r.error ?? 'Réponse inattendue du serveur.');
  final data = Map<String, dynamic>.from(r.data as Map);
  gToast(context, 'Préparation du relevé…');
  await _share(context, () => buildStatementPdf(data), 'releve-ventes-${DateTime.now().toIso8601String().substring(0, 10)}.pdf');
}

/// Facture de la mission [missionId] (identifiant serveur) : accord, jalons, règlements tracés entre les parties.
Future<void> downloadMissionInvoice(BuildContext context, WidgetRef ref, String missionId) async {
  if (!Backend.ready || missionId.isEmpty) return gAlert(context, 'Aucune mission', 'Choisissez d’abord une mission réelle.');
  final r = await Backend.rpc('mission_invoice', {'p_mission': missionId});
  if (!context.mounted) return;
  if (r.error != null || r.data is! Map) return gAlert(context, 'Facture indisponible', r.error ?? 'Réponse inattendue du serveur.');
  final data = Map<String, dynamic>.from(r.data as Map);
  gToast(context, 'Préparation de la facture…');
  await _share(context, () => buildMissionInvoicePdf(data), 'facture-mission-${data['number']}.pdf');
}
