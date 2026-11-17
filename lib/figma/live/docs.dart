import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import '../../data/demo/section_a_demo.dart' show CartLine;
import 'order_summary.dart' show orderDeliveryText;
import 'store.dart';

/// Documents téléchargeables : reçu de paiement et facture (PDF réel, avec le logo de la plateforme).

const _logo = 'assets/figma/img/2e8548b8fa2eb7935169a49b6595e1aa760c7c62.png';
const _ink = PdfColor.fromInt(0xFF111015);
const _muted = PdfColor.fromInt(0xFF57545F);
const _violet = PdfColor.fromInt(0xFF5A3FE0);
const _line = PdfColor.fromInt(0xFFE4E0EC);

/// Numéro du document : dérivé du numéro de commande, donc identique à l'écran et dans le PDF (« FA-2026-0142 », « RC-2026-0142 »).
String documentNumber(Order o, {required bool invoice}) {
  final tail = o.id.replaceFirst(RegExp(r'^#(BE-)?'), '');
  return '${invoice ? 'FA' : 'RC'}-$tail';
}

/// Intitulé du document : un reçu de paiement n'est émis que pour une commande réellement payée.
String documentTitle(Order o, {required bool invoice}) {
  if (invoice) return 'FACTURE';
  if (o.paid) return 'REÇU DE PAIEMENT';
  return o.cod ? 'CONFIRMATION DE COMMANDE' : 'RÉCAPITULATIF DE COMMANDE';
}

/// État de paiement affiché sur les documents et l'écran 259.
String orderPaymentStatus(Order o) {
  if (o.paid) return 'Payé';
  if (o.cancelled) return 'Annulée';
  return o.cod ? 'À payer à la livraison' : 'En attente de paiement';
}

/// Lignes « Facturé à » d'une commande passée au nom d'une entreprise : raison sociale, NIU, RCCM, adresse, e-mail (identité figée par le serveur, fonction order_billing_get).
String companyBillingLines(Map<String, dynamic> b) {
  String v(String k) => '${b[k] ?? ''}'.trim();
  final place = [v('address'), v('city')].where((e) => e.isNotEmpty).join(', ');
  return [
    if (v('tax_id').isNotEmpty) 'NIU : ${v('tax_id')}',
    if (v('registration_number').isNotEmpty) 'RCCM : ${v('registration_number')}',
    if (place.isNotEmpty) place,
    if (v('email').isNotEmpty) v('email'),
  ].join('\n');
}

/// Identité de facturation de l'entreprise pour cette commande (null : achat personnel, ou lecture impossible : la facture porte alors la personne).
Future<Map<String, dynamic>?> _companyBilling(String orderNumber) async {
  if (!Backend.ready || orderNumber.isEmpty) return null;
  final r = await Backend.rpc('order_billing_get', {'p_number': orderNumber});
  return r.error == null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}

Future<pw.Document> _build(Order o, Account who, {required bool invoice, Map<String, dynamic>? billing, String orderedBy = ''}) async {
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-700.ttf'));
  final logo = pw.MemoryImage((await rootBundle.load(_logo)).buffer.asUint8List());
  final docNo = documentNumber(o, invoice: invoice);
  final title = documentTitle(o, invoice: invoice);

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
            if (billing != null) ...[
              pw.Text('${billing['company_name'] ?? ''}', style: st(12, b: true)),
              pw.Text(companyBillingLines(billing), style: st(10, c: _muted)),
              if (orderedBy.isNotEmpty) pw.Text('Commandé par : $orderedBy', style: st(10, c: _muted)),
            ] else ...[
              pw.Text(who.name, style: st(12, b: true)),
              pw.Text('${who.email}\n+237 ${who.phone}\n${who.city}, Cameroun', style: st(10, c: _muted)),
            ],
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
            kv('Articles', fcfa(o.subtotal + o.discount)),
            if (o.discount > 0) kv(o.promoCode.isEmpty ? 'Remise' : 'Remise (${o.promoCode})', '−${fcfa(o.discount)}'),
            kv('Livraison', o.fee == 0 ? 'Gratuite' : fcfa(o.fee)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: pw.BoxDecoration(color: _ink, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(invoice ? 'Total' : (o.paid ? 'Total payé' : 'Total à payer'), style: st(11, b: true, c: PdfColors.white)),
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
      if (o.reference.isNotEmpty && o.reference != '—') kv('Référence de transaction', o.reference),
      kv('Statut', orderPaymentStatus(o)),
      pw.SizedBox(height: 10),
      pw.Text('LIVRAISON', style: st(8.5, b: true, c: _muted)),
      pw.SizedBox(height: 4),
      pw.Text(orderDeliveryText(o), style: st(10)),
      pw.Spacer(),
      pw.Container(height: 1, color: _line),
      pw.SizedBox(height: 8),
      pw.Text('Document généré par Boutik-École. Merci de votre confiance. Conservez ce document comme justificatif d’achat.', style: st(8.5, c: _muted)),
    ]),
  ));
  return doc;
}

/// Lignes de la facture : toutes les lignes de la commande affichée, dans une zone défilante.
class InvoiceLines extends ConsumerWidget {
  const InvoiceLines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(viewedOrderProvider).lines;
    if (lines.isEmpty) return gText('Aucune commande à facturer.', 12, const Color(0xFF57545F), wrap: true);
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: lines.length,
      separatorBuilder: (_, _) => const Divider(height: 14, thickness: 1, color: Color(0xFFEEECF1)),
      itemBuilder: (_, i) {
        final l = lines[i];
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 10), child: SizedBox(width: 160, child: gText(l.title, 12, const Color(0xFF111015), weight: 500, wrap: true, maxLines: 2))),
          SizedBox(width: 34, child: gText('${l.qty}', 12, const Color(0xFF111015), wrap: true, align: TextAlign.center)),
          Expanded(child: gText(fcfa(l.price * l.qty).replaceAll(' FCFA', ''), 12, const Color(0xFF111015), weight: 600, wrap: true, align: TextAlign.right)),
        ]);
      },
    );
  }
}

/// Détail du montant de la commande affichée : articles, remise, livraison. Aucune répartition interne de la plateforme.
class InvoiceTotals extends ConsumerWidget {
  const InvoiceTotals({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = ref.watch(viewedOrderProvider);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: gText(k, 11.5, const Color(0xFF57545F), wrap: true)),
            gText(v, 11.5, const Color(0xFF111015), weight: 600, wrap: true),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      gText('Détail du montant', 12, const Color(0xFF111015), weight: 600, wrap: true),
      const SizedBox(height: 12),
      row('Articles', fcfa(o.subtotal + o.discount)),
      if (o.discount > 0) row(o.promoCode.isEmpty ? 'Remise' : 'Remise (${o.promoCode})', '−${fcfa(o.discount)}'),
      row('Livraison', o.fee == 0 ? 'Gratuite' : fcfa(o.fee)),
      row('Paiement', orderPaymentStatus(o)),
    ]);
  }
}

/// Télécharge (web) ou partage (mobile) le PDF.
Future<void> downloadDocument(BuildContext context, WidgetRef ref, {required bool invoice}) async {
  final o = ref.read(viewedOrderProvider);
  if (Backend.ready && (o.id == '#----' || o.lines.isEmpty)) return gToast(context, 'Aucune commande à télécharger.');
  final who = ref.read(profileAccountProvider);
  gToast(context, invoice ? 'Préparation de la facture…' : 'Préparation du reçu…');
  try {
    final billing = await _companyBilling(o.id);
    final doc = await _build(o, who, invoice: invoice, billing: billing, orderedBy: billing == null ? '' : who.name);
    final bytes = await doc.save();
    final name = '${invoice ? 'facture' : 'recu'}-${o.id.replaceAll('#', '')}.pdf';
    await Printing.sharePdf(bytes: bytes, filename: name);
  } catch (e) {
    if (context.mounted) gToast(context, 'Téléchargement impossible : $e');
  }
}

/// Commande d'« Achats de l'entreprise » (ligne de company_orders_list) sous la forme d'une commande pour le PDF.
Order companyOrderFromRow(Map<String, dynamic> r) {
  final d = DateTime.tryParse('${r['created_at'] ?? ''}')?.toLocal();
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final lines = [
    for (final l in (r['items'] as List? ?? const [])) CartLine('${(l as Map)['title']}', '', (l['unit_price'] as num).toInt(), '', qty: (l['qty'] as num).toInt()),
  ];
  final total = (r['total'] as num?)?.toInt() ?? 0, fee = (r['fee'] as num?)?.toInt() ?? 0;
  return Order(
    id: '${r['number']}',
    date: d == null ? '—' : '${d.day} ${mois[d.month - 1]} ${d.year}',
    lines: lines,
    subtotal: total - fee,
    fee: fee,
    method: '${r['method'] ?? ''}',
    reference: '',
    paid: r['paid'] == true,
    cancelled: r['cancelled'] == true,
    cod: r['cod'] == true,
    discount: (r['discount'] as num?)?.toInt() ?? 0,
  );
}

/// Facture (PDF) d'une commande de l'entreprise, au nom de l'entreprise ; la personne qui a commandé y figure. Disponible pour toute l'équipe finance.
Future<void> downloadCompanyOrderInvoice(BuildContext context, WidgetRef ref, Map<String, dynamic> row) async {
  final o = companyOrderFromRow(row);
  gToast(context, 'Préparation de la facture…');
  try {
    final billing = await _companyBilling(o.id);
    if (billing == null) {
      if (context.mounted) gToast(context, 'Identité de facturation introuvable pour cette commande.');
      return;
    }
    final doc = await _build(o, ref.read(profileAccountProvider), invoice: true, billing: billing, orderedBy: row['by_me'] == true ? ref.read(profileAccountProvider).name : '${row['buyer_name'] ?? ''}');
    await Printing.sharePdf(bytes: await doc.save(), filename: 'facture-${o.id.replaceAll('#', '')}.pdf');
  } catch (e) {
    if (context.mounted) gToast(context, 'Téléchargement impossible : $e');
  }
}
