import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gen.dart';
import 'auth.dart';
import 'store.dart';

/// Documents téléchargeables : reçu de paiement et facture (PDF réel, avec le logo de la plateforme).

const _logo = 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png';
const _ink = PdfColor.fromInt(0xFF111015);
const _muted = PdfColor.fromInt(0xFF66636E);
const _violet = PdfColor.fromInt(0xFF5A3FE0);
const _line = PdfColor.fromInt(0xFFE4E0EC);

Future<pw.Document> _build(Order o, Account who, {required bool invoice}) async {
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-700.ttf'));
  final logo = pw.MemoryImage((await rootBundle.load(_logo)).buffer.asUint8List());
  final num = o.id.replaceAll(RegExp(r'[^0-9]'), '');
  final docNo = invoice ? 'FA-2026-$num' : 'RC-2026-${num.padLeft(5, '0')}';
  final title = invoice ? 'FACTURE' : 'REÇU DE PAIEMENT';

  pw.TextStyle st(double s, {bool b = false, PdfColor c = _ink}) => pw.TextStyle(font: b ? bold : reg, fontSize: s, color: c);
  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(k, style: st(10, c: _muted)), pw.Text(v, style: st(10.5, b: true))]),
      );
  pw.Widget cell(String t, {bool b = false, pw.TextAlign a = pw.TextAlign.left, PdfColor c = _ink}) =>
      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6), child: pw.Text(t, textAlign: a, style: st(10, b: b, c: c)));

  final doc = pw.Document(title: '$title $docNo', author: 'Boutik-École');
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(44, 40, 44, 40),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Row(children: [
          pw.Image(logo, width: 58, height: 50, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 12),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Boutik-École', style: st(20, b: true)),
            pw.Text('Marketplace de l’expertise et des productions\nde l’IUT de Douala', style: st(8.5, c: _muted)),
          ]),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(title, style: st(16, b: true, c: _violet)),
          pw.SizedBox(height: 4),
          pw.Text('N° $docNo', style: st(10.5, b: true)),
          pw.Text('Date : ${o.date}', style: st(10, c: _muted)),
          pw.Text('Commande : ${o.id}', style: st(10, c: _muted)),
        ]),
      ]),
      pw.SizedBox(height: 22),
      pw.Container(height: 1, color: _line),
      pw.SizedBox(height: 16),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FACTURÉ À', style: st(8.5, b: true, c: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(who.name, style: st(12, b: true)),
            pw.Text('${who.email}\n+237 ${who.phone}\n${who.city}, Cameroun', style: st(10, c: _muted)),
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ÉMETTEUR', style: st(8.5, b: true, c: _muted)),
            pw.SizedBox(height: 4),
            pw.Text('Boutik-École · IUT de Douala', style: st(12, b: true)),
            pw.Text('Université de Douala\nDouala, Cameroun\ncontact@boutik-ecole.cm', style: st(10, c: _muted)),
          ]),
        ),
      ]),
      pw.SizedBox(height: 22),
      pw.Table(
        columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2)},
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: .6), bottom: pw.BorderSide(color: _line, width: .6)),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F1F8)),
            children: [cell('Désignation', b: true), cell('Qté', b: true, a: pw.TextAlign.center), cell('Prix unitaire', b: true, a: pw.TextAlign.right), cell('Montant', b: true, a: pw.TextAlign.right)],
          ),
          for (final l in o.lines)
            pw.TableRow(children: [
              cell('${l.title}\n${l.department}'),
              cell('${l.qty}', a: pw.TextAlign.center),
              cell(fcfa(l.price), a: pw.TextAlign.right),
              cell(fcfa(l.price * l.qty), a: pw.TextAlign.right),
            ]),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 230,
          child: pw.Column(children: [
            kv('Sous-total', fcfa(o.subtotal)),
            kv('Frais de service', o.fee == 0 ? 'Gratuit' : fcfa(o.fee)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(invoice ? 'Total TTC' : 'Total payé', style: st(11, b: true, c: PdfColors.white)),
                pw.Text(fcfa(o.total), style: st(12, b: true, c: PdfColors.white)),
              ]),
            ),
          ]),
        ),
      ),
      pw.SizedBox(height: 22),
      pw.Text('PAIEMENT', style: st(8.5, b: true, c: _muted)),
      pw.SizedBox(height: 4),
      kv('Moyen de paiement', o.method),
      kv('Référence de transaction', o.reference),
      kv('Statut', o.paid ? 'Payé' : 'En attente de paiement'),
      if (invoice) ...[
        pw.SizedBox(height: 10),
        pw.Text('Répartition indicative : fonds d’innovation de l’établissement (20 %) ${fcfa(o.total * 0.20)}.', style: st(9, c: _muted)),
      ],
      pw.Spacer(),
      pw.Container(height: 1, color: _line),
      pw.SizedBox(height: 8),
      pw.Text('Document généré par Boutik-École. Merci de votre confiance. Conservez ce document comme justificatif d’achat.', style: st(8.5, c: _muted)),
    ]),
  ));
  return doc;
}

/// Télécharge (web) ou partage (mobile) le PDF.
Future<void> downloadDocument(BuildContext context, WidgetRef ref, {required bool invoice}) async {
  final o = ref.read(lastOrderProvider);
  final who = ref.read(profileAccountProvider);
  gToast(context, invoice ? 'Préparation de la facture…' : 'Préparation du reçu…');
  try {
    final doc = await _build(o, who, invoice: invoice);
    final bytes = await doc.save();
    final name = '${invoice ? 'facture' : 'recu'}-${o.id.replaceAll('#', '')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  } catch (e) {
    if (context.mounted) gToast(context, 'Téléchargement impossible : $e');
  }
}
