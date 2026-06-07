import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/product.dart';

class ReportService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  static Future<void> generateSalesStatisticsReport(
      List<AppTransaction> sales, List<Product> products, DateTime start, DateTime end) async {
    final pdf = pw.Document();

    double grandTotalCA = 0;
    double grandTotalQty = 0;
    double grandTotalMarge = 0;

    // Calculer les données par produit
    List<Map<String, dynamic>> tableData = products.map((product) {
      double qtySold = 0;
      double revenue = 0;
      double cost = 0;

      for (var sale in sales) {
        // Filtrer par période si nécessaire (assumé déjà filtré en amont)
        for (var item in sale.items) {
          if (item.productId == product.id) {
            qtySold += item.quantity;
            revenue += (item.quantity * item.unitPrice) - item.discount;
            cost += (item.quantity * product.purchasePrice);
          }
        }
      }

      double marge = revenue - cost;
      grandTotalCA += revenue;
      grandTotalQty += qtySold;
      grandTotalMarge += marge;

      return {
        'ref': product.id.substring(0, 8).toUpperCase(), // Utilisation simplifiée de l'ID
        'name': product.name,
        'ca': revenue,
        'qty': qtySold,
        'marge': marge,
      };
    }).where((data) => (data['qty'] as double) > 0).toList();

    // Trier par plus fortes ventes (CA)
    tableData.sort((a, b) => (b['ca'] as double).compareTo(a['ca'] as double));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header conforme à l'image
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('KO SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('TRANSPORT & LOGISTIQUE', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Analyse statistiques articles',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text('Palmarès plus fortes ventes', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Période du : ${DateFormat('dd/MM/yy').format(start)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('au : ${DateFormat('dd/MM/yy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('© KO SOLAR - Gestion Commerciale', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Date de tirage : ${DateFormat('dd/MM/yy').format(DateTime.now())} à ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Page : 1', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.SizedBox(height: 10),

            // Table des données
            pw.TableHelper.fromTextArray(
              headers: [
                'Référence\nArticle',
                'Désignation',
                'CA Net HT',
                'Qtés\nvendues',
                'Marge',
                '% mar.\nsur CA',
                '% CA\nsur total'
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              data: [
                ...tableData.map((data) {
                  double ca = data['ca'] as double;
                  double marge = data['marge'] as double;
                  double qty = data['qty'] as double;
                  double pMargeCA = ca > 0 ? (marge / ca) * 100 : 0;
                  double pCATotal = grandTotalCA > 0 ? (ca / grandTotalCA) * 100 : 0;

                  return [
                    data['ref'],
                    data['name'],
                    _currencyFormat.format(ca),
                    qty.toStringAsFixed(0),
                    _currencyFormat.format(marge),
                    pMargeCA.toStringAsFixed(2),
                    pCATotal.toStringAsFixed(2),
                  ];
                }),
                // Ligne Total général
                [
                  '',
                  'Total général',
                  _currencyFormat.format(grandTotalCA),
                  grandTotalQty.toStringAsFixed(0),
                  _currencyFormat.format(grandTotalMarge),
                  (grandTotalCA > 0 ? (grandTotalMarge / grandTotalCA) * 100 : 0).toStringAsFixed(2),
                  '100.00'
                ],
              ],
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1),
              },
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> exportUnpaidToExcel(List<AppTransaction> unpaidTransactions) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Impayés'];

    sheetObject.appendRow([
      TextCellValue('N° Facture'),
      TextCellValue('Client'),
      TextCellValue('Date'),
      TextCellValue('Total HT'),
      TextCellValue('Payé'),
      TextCellValue('Reste'),
    ]);

    for (var trans in unpaidTransactions) {
      sheetObject.appendRow([
        TextCellValue(trans.invoiceNumber),
        TextCellValue(trans.tierName),
        TextCellValue(trans.date.toString().split(' ')[0]),
        DoubleCellValue(trans.totalHT),
        DoubleCellValue(trans.amountPaid),
        DoubleCellValue(trans.totalHT - trans.amountPaid),
      ]);
    }

    excel.save(fileName: 'impayes.xlsx');
  }
}
