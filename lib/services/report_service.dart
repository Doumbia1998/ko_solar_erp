import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/payment.dart';

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
          ],
        ),
        build: (pw.Context context) {
          List<pw.Widget> rows = [];
          for (var t in txs) {
            String shortTierId = t.tierId.length > 8 ? t.tierId.substring(0, 8) : t.tierId;
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
            rows.add(
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                child: pw.Row(
                  children: [
                    pw.Text('Total  Facture cpta', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
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

  static Future<void> generateDailyPaymentsReport(List<Payment> payments, String type, {String? tierName, DateTime? start, DateTime? end}) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    String period = "Période : ";
    if (start != null && end != null) {
      period += "${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}";
    } else {
      period += dateStr;
    }

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('KO SOLAR ERP', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text(period, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                tierName != null
                  ? 'HISTORIQUE DES RÈGLEMENTS : ${tierName.toUpperCase()}'
                  : 'RÉCAPITULATIF GLOBAL DES RÈGLEMENTS ${type.toUpperCase()}S',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
              )
            ),
            pw.SizedBox(height: 20),
          ]
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Tiers', 'Référence / Facture', 'Mode', 'Journal', 'Montant'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellAlignment: pw.Alignment.center,
            data: payments.map((p) => [
              DateFormat('dd/MM/yy').format(p.date),
              p.tierName.toUpperCase(),
              p.invoiceNumber != null ? 'ENC FA${p.invoiceNumber}' : p.reference,
              p.method,
              p.journalCode ?? '',
              _format.format(p.amount) + ' F',
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
              child: pw.Text('TOTAL : ${_format.format(payments.fold(0.0, (sum, p) => sum + p.amount))} FCFA',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateDailyDeliveryReport(List<AppTransaction> txs) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('KO SOLAR ERP - ETAT DES LIVRAISONS (BL)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(dateStr),
          ],
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Text('RAPPORT JOURNALIER DES LIVRAISONS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['N° BL', 'Client', 'Destination', 'Statut'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: txs.map((t) => [
              'BL-${t.invoiceNumber}',
              t.tierName.toUpperCase(),
              t.destination,
              t.deliveryStatus == 'delivered' ? 'LIVRÉ' : 'EN ATTENTE',
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Text('RÉSUMÉ : ${txs.where((t) => t.deliveryStatus == 'delivered').length} Livrés / ${txs.where((t) => t.deliveryStatus != 'delivered').length} En attente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
