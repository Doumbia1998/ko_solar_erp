import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ReportService {
  static final _format = NumberFormat('#,###', 'fr_FR');

  static Future<void> generateDailyActivityReport(List<AppTransaction> txs, String type) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          children: [
            pw.Center(
              child: pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
                padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 5),
                child: pw.Text('Liste des documents de ${type.toLowerCase()}',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))
              )
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('KO-SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Tenue de compte : XOF', style: const pw.TextStyle(fontSize: 9)),
              ]
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MLD Consulting', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                pw.Row(
                  children: [
                    pw.Text('Date de tirage  $dateStr    à   $timeStr      Page :    ${context.pageNumber}',
                      style: const pw.TextStyle(fontSize: 9)),
                  ]
                )
              ]
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Row(
                children: [
                  _headerCell('Référence', 1.5),
                  _headerCell('Désignation', 3),
                  _headerCell('Quantité', 1),
                  _headerCell('Px Unit. HT', 1.5),
                  _headerCell('Remise', 1),
                  _headerCell('Montant HT', 1.5),
                ]
              )
            ),
          ],
        ),
        build: (pw.Context context) {
          List<pw.Widget> rows = [];

          for (var t in txs) {
            String shortTierId = t.tierId.length > 8 ? t.tierId.substring(0, 8) : t.tierId;
            // Ligne en-tête de la facture
            rows.add(
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                child: pw.Row(
                  children: [
                    pw.Text('$shortTierId   ${t.tierName.toUpperCase()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Spacer(),
                    pw.Text('Facture cpta      N°   ${t.invoiceNumber}   du   ${DateFormat('dd/MM/yy').format(t.date)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ]
                )
              )
            );

            // Lignes articles
            for (var item in t.items) {
              String shortProdId = item.productId.length > 8 ? item.productId.substring(0, 8) : item.productId;
              rows.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 15, child: pw.Text(shortProdId.toUpperCase(), style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 30, child: pw.Text(item.productName.toUpperCase(), style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 10, child: pw.Text(item.quantity.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 15, child: pw.Text(_format.format(item.unitPrice), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 10, child: pw.Text(_format.format(item.discount), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 15, child: pw.Text(_format.format((item.quantity * item.unitPrice) - item.discount), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    ]
                  )
                )
              );
            }

            // Ligne total facture
            rows.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                child: pw.Row(
                  children: [
                    pw.Text('Total  Facture cpta', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(width: 50),
                    pw.Text('N°   ${t.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Spacer(),
                    pw.Text(_format.format(t.totalHT), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ]
                )
              )
            );
            rows.add(pw.SizedBox(height: 10));
          }

          return rows;
        },
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total général', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(_format.format(txs.fold(0.0, (sum, t) => sum + t.netToPay)),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              ]
            )
          ]
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _headerCell(String text, double flex) {
    return pw.Expanded(
      flex: (flex * 10).toInt(),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(5),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
        child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      )
    );
  }
}
