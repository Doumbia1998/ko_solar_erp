import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../models/transaction.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../models/journal_entry.dart';

class ReportService {
  static final _format = NumberFormat('#,###', 'fr_FR');
  static pw.ImageProvider? _cachedLogo;

  static Future<pw.ImageProvider> _getLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final byteData = await rootBundle.load('assets/images/logo.png');
    _cachedLogo = pw.MemoryImage(byteData.buffer.asUint8List());
    return _cachedLogo!;
  }

  static Future<void> generatePreparatoryInventory(List<Product> products, List<Warehouse> warehouses, List<Map<String, dynamic>> allStocks) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    for (var w in warehouses) {
      final warehouseProducts = products.where((p) {
        final stock = allStocks.firstWhere(
          (s) => s['productId'] == p.id && s['warehouseId'] == w.id,
          orElse: () => {'quantity': 0},
        );
        return (stock['quantity'] as num).toInt() > 0;
      }).toList();

      if (warehouseProducts.isEmpty) continue;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildInventoryHeader(context, logo, 'Inventaire Preparatoire', w.name, dateStr, timeStr),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['Reference', 'Designation', 'Qte Stock', 'Qte Relevee', 'Ecart'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(70),
                4: const pw.FixedColumnWidth(60),
              },
              data: warehouseProducts.map((p) {
                final stock = allStocks.firstWhere(
                  (s) => s['productId'] == p.id && s['warehouseId'] == w.id,
                  orElse: () => {'quantity': 0},
                );
                return [
                  p.reference,
                  p.name.toUpperCase(),
                  stock['quantity'].toString(),
                  '................',
                  '................',
                ];
              }).toList(),
            ),
          ],
          footer: (context) => _buildInventoryFooter(context),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryBook(List<Product> products, List<Warehouse> warehouses, List<Map<String, dynamic>> allStocks) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    for (var w in warehouses) {
      final warehouseProducts = products.where((p) {
        final stock = allStocks.firstWhere(
          (s) => s['productId'] == p.id && s['warehouseId'] == w.id,
          orElse: () => {'quantity': 0},
        );
        return (stock['quantity'] as num).toInt() > 0;
      }).toList();

      if (warehouseProducts.isEmpty) continue;

      double totalWarehouse = 0;
      final rows = warehouseProducts.map((p) {
        final stock = (allStocks.firstWhere(
          (s) => s['productId'] == p.id && s['warehouseId'] == w.id,
          orElse: () => {'quantity': 0},
        )['quantity'] as num).toDouble();

        double lineValue = stock * p.weightedAverageCost;
        totalWarehouse += lineValue;

        return [
          p.reference,
          p.name.toUpperCase(),
          stock.toInt().toString(),
          _format.format(p.weightedAverageCost),
          _format.format(lineValue),
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildInventoryHeader(context, logo, 'Livre d\'Inventaire (Valorise)', w.name, dateStr, timeStr),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headers: ['Reference', 'Designation', 'Qte Stock', 'P.R. Unit (CMUP)', 'P.R. Global'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FixedColumnWidth(80),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(80),
                4: const pw.FixedColumnWidth(100),
              },
              data: rows,
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Text('VALEUR TOTALE DEPOT : ${_format.format(totalWarehouse)} FCFA',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
          footer: (context) => _buildInventoryFooter(context),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _buildInventoryHeader(pw.Context context, pw.ImageProvider logo, String title, String warehouse, String date, String time) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(logo, width: 80),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('DEPOT : ${warehouse.toUpperCase()}'),
              ]
            )
          ]
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text('Date de tirage : $date a $time', style: const pw.TextStyle(fontSize: 9)),
          ]
        ),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildInventoryFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Legende : C : CMUP', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
          ]
        ),
      ],
    );
  }

  static Future<void> generateDailyActivityReport(List<AppTransaction> txs, String type) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, width: 80),
                pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: pw.Text('Liste des documents de ${type.toLowerCase()}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
                )
              ]
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
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
                    pw.Text('Date de tirage  $dateStr    a   $timeStr      Page :    ${context.pageNumber}',
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
                pw.Text('Total general', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
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
    final logo = await _getLogo();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    String period = "Periode : ";
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
                pw.Image(logo, width: 80),
                pw.Text(period, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                tierName != null
                  ? 'HISTORIQUE DES REGLEMENTS : ${tierName.toUpperCase()}'
                  : 'RECAPITULATIF GLOBAL DES REGLEMENTS ${type.toUpperCase()}S',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
              )
            ),
            pw.SizedBox(height: 20),
          ]
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Tiers', 'Reference / Facture', 'Mode', 'Journal', 'Montant'],
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
    final logo = await _getLogo();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logo, width: 80),
                pw.Text(dateStr),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              children: [
                pw.Text('K-O SOLAR - ETAT DES LIVRAISONS (BL)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ]
            ),
            pw.Divider(),
          ]
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
              t.deliveryStatus == 'delivered' ? 'LIVRE' : 'EN ATTENTE',
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Text('RESUME : ${txs.where((t) => t.deliveryStatus == 'delivered').length} Livres / ${txs.where((t) => t.deliveryStatus != 'delivered').length} En attente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateTrialBalance(List<JournalEntry> entries) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    Map<String, Map<String, dynamic>> balances = {};
    for (var e in entries) {
      if (!balances.containsKey(e.accountCode)) {
        balances[e.accountCode] = {
          'label': e.accountLabel,
          'debit': 0.0,
          'credit': 0.0
        };
      }
      balances[e.accountCode]!['debit'] += e.debit;
      balances[e.accountCode]!['credit'] += e.credit;
    }

    final sortedCodes = balances.keys.toList()..sort();

    double totalDebitMvt = 0;
    double totalCreditMvt = 0;
    double totalDebitSolde = 0;
    double totalCreditSolde = 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text('MLD Consulting - ERP', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Balance des comptes', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Complete', style: const pw.TextStyle(fontSize: 10)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Periode du 01/01/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('au $dateStr', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Tenue de compte : XOF', style: const pw.TextStyle(fontSize: 8)),
                  ]
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date de tirage $dateStr  a  $timeStr', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Page : ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
              ]
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: [
              'Numero de compte',
              'Intitule des comptes',
              'Mouvements Debit',
              'Mouvements Credit',
              'Soldes Debit',
              'Soldes Credit'
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FixedColumnWidth(80),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(80),
              5: const pw.FixedColumnWidth(80),
            },
            data: sortedCodes.map((code) {
              double d = balances[code]!['debit'];
              double c = balances[code]!['credit'];
              double solde = d - c;

              totalDebitMvt += d;
              totalCreditMvt += c;
              if (solde > 0) totalDebitSolde += solde;
              else totalCreditSolde += solde.abs();

              return [
                code,
                balances[code]!['label'].toString().toUpperCase(),
                _format.format(d),
                _format.format(c),
                solde > 0 ? _format.format(solde) : '',
                solde < 0 ? _format.format(solde.abs()) : '',
              ];
            }).toList(),
          ),
          pw.Divider(),
          pw.Row(
            children: [
              pw.Expanded(flex: 3, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Totaux de la balance : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
              pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_format.format(totalDebitMvt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
              pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_format.format(totalCreditMvt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
              pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_format.format(totalDebitSolde), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
              pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_format.format(totalCreditSolde), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
            ]
          )
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Balance_Comptes.pdf');
  }
}
