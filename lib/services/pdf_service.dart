import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/services.dart' show rootBundle;
import '../models/transaction.dart';
import '../models/transport.dart';
import '../models/stock_transfer.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../models/account.dart';
import '../models/tier.dart';
import '../models/task.dart';
import '../models/expense.dart';
import '../models/salary_payment.dart';
import '../models/product.dart';
import '../models/warehouse.dart';
import '../utils/number_to_words.dart';

class PdfService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');
  static pw.ImageProvider? _cachedLogo;

  static Future<pw.ImageProvider> _getLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final byteData = await rootBundle.load('assets/images/logo.png');
    _cachedLogo = pw.MemoryImage(byteData.buffer.asUint8List());
    return _cachedLogo!;
  }

  // --- FACTURES ---
  static Future<pw.Document> _buildInvoiceDoc(AppTransaction transaction, {required pw.ImageProvider logo, List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final pdf = pw.Document();
    double totalRegle = 0;
    if (allTierPayments != null) {
      final String invNorm = transaction.invoiceNumber.trim().toUpperCase();
      totalRegle = allTierPayments.where((p) => (p.invoiceNumber?.trim().toUpperCase() == invNorm) || (p.reference.trim().toUpperCase().contains(invNorm))).fold(0.0, (sum, p) => sum + p.amount);
      bool acompteFound = allTierPayments.any((p) => p.invoiceNumber == transaction.invoiceNumber && p.reference.contains('Acompte'));
      if (!acompteFound && transaction.amountPaid > 0) totalRegle += transaction.amountPaid;
    } else {
      totalRegle = transaction.amountPaid;
    }
    double resteAPayer = transaction.netToPay - totalRegle;
    if (resteAPayer < 0) resteAPayer = 0;

    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Image(logo, width: 100),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(children: [
            pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Commercant Import - Export - Transport'),
            pw.Text('Tel: 76 73 76 22 / 66 73 76 22'),
          ])),
        ]),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('N Facture: ${transaction.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
          ]),
          pw.Container(width: 200, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Client: ${transaction.tierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('ID: ${transaction.tierId}'),
          ])),
        ]),
        pw.SizedBox(height: 30),
        pw.Text(transaction.type == TransactionType.sale ? 'FACTURE DE VENTE' : 'FACTURE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Designation', 'Qte', 'Px unitaire', 'Total Net'],
          data: transaction.items.map((item) => [item.productName, item.quantity.toString(), _currencyFormat.format(item.unitPrice), _currencyFormat.format((item.quantity * item.unitPrice) - item.discount)]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('NET A PAYER: ${_currencyFormat.format(transaction.netToPay).replaceAll(',', ' ')} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('Total Deja Regle: ${_currencyFormat.format(totalRegle).replaceAll(',', ' ')} FCFA'),
            pw.Text('SOLDE A REGLER: ${_currencyFormat.format(resteAPayer).replaceAll(',', ' ')} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: resteAPayer > 10 ? PdfColors.red900 : PdfColors.green900)),
          ]),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Signature Client', style: const pw.TextStyle(decoration: pw.TextDecoration.underline)),
          pw.Text('La Direction (Cachet)', style: const pw.TextStyle(decoration: pw.TextDecoration.underline)),
        ]),
      ]);
    }));
    return pdf;
  }

  static Future<void> generateInvoice(AppTransaction transaction, {List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final logo = await _getLogo();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo, allTierPayments: allTierPayments, allTierTransactions: allTierTransactions);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- RAPPORTS GLOBAUX ---
  static Future<void> generateGlobalTransactionReport({required String type, required DateTime start, required DateTime end, required List<AppTransaction> transactions}) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Recapitulatif $type', 'Periode: ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'N Facture', 'Tiers', 'Montant'], data: transactions.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.invoiceNumber, t.tierName, _currencyFormat.format(t.netToPay)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateUnpaidReport({required String type, required DateTime start, required DateTime end, required List<Map<String, dynamic>> unpaidDetails}) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final double totalUnpaid = unpaidDetails.fold(0.0, (sum, d) => sum + (d['remaining'] as double));

    pdf.addPage(pw.MultiPage(
      header: (context) => _header(logo, 'ETAT DES IMPAYES ${type.toUpperCase()}S', 'Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'N Facture', 'Tiers', 'Total Net', 'Deja Paye', 'Reste'],
          data: unpaidDetails.map((d) {
            final AppTransaction t = d['transaction'];
            return [
              DateFormat('dd/MM/yy').format(t.date),
              t.invoiceNumber,
              t.tierName.toUpperCase(),
              _currencyFormat.format(t.netToPay),
              _currencyFormat.format(d['totalPaid']),
              _currencyFormat.format(d['remaining']),
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL A RECOUVRER : ${_currencyFormat.format(totalUnpaid)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateProfitReport({required DateTime start, required DateTime end, required double totalCA, required double totalCout, required double marge, required double pourcentage, required List<Map<String, dynamic>> productStats}) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Analyse Rentabilite', ''), build: (context) => [
      pw.Text('CA GLOBAL : ${_currencyFormat.format(totalCA)} F'),
      pw.Text('MARGE : ${_currencyFormat.format(marge)} F (${pourcentage.toStringAsFixed(1)}%)'),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Qte', 'CA', 'Marge'], data: productStats.map((s) => [s['name'], s['qty'].toString(), _currencyFormat.format(s['ca']), _currencyFormat.format(s['margin'])]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateExpenseReport(List<Expense> expenses, String type, {DateTimeRange? range}) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Rapport de Depenses', type), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Libelle', 'Mode', 'Montant'], data: expenses.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.label, e.paymentMethod, _currencyFormat.format(e.amount)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- INVENTAIRES ---
  static Future<void> generatePreparatoryInventory(List<Product> products, List<Warehouse> warehouses, List<Map<String, dynamic>> allStocks) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    for (var w in warehouses) {
      final warehouseProducts = products.where((p) {
        final stock = allStocks.firstWhere((s) => s['productId'] == p.id && s['warehouseId'] == w.id, orElse: () => {'quantity': 0});
        return (stock['quantity'] as num).toInt() > 0;
      }).toList();
      if (warehouseProducts.isEmpty) continue;
      pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Inventaire Preparatoire', w.name), build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Reference', 'Designation', 'Stock', 'Releve', 'Ecart'],
          data: warehouseProducts.map((p) => [p.reference, p.name, p.totalQuantity.toString(), '....', '....']).toList(),
        )
      ]));
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryBook(List<Product> products, List<Warehouse> warehouses, List<Map<String, dynamic>> allStocks) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    for (var w in warehouses) {
      final warehouseProducts = products.where((p) {
        final stock = allStocks.firstWhere((s) => s['productId'] == p.id && s['warehouseId'] == w.id, orElse: () => {'quantity': 0});
        return (stock['quantity'] as num).toInt() > 0;
      }).toList();
      if (warehouseProducts.isEmpty) continue;
      pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Livre d\'Inventaire', w.name), build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Reference', 'Designation', 'Stock', 'CMUP', 'Valeur'],
          data: warehouseProducts.map((p) => [p.reference, p.name, p.totalQuantity.toString(), _currencyFormat.format(p.weightedAverageCost), _currencyFormat.format(p.totalQuantity * p.weightedAverageCost)]).toList(),
        )
      ]));
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTrialBalance(List<JournalEntry> entries) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    Map<String, Map<String, dynamic>> balances = {};
    for (var e in entries) {
      if (!balances.containsKey(e.accountCode)) {
        balances[e.accountCode] = {'label': e.accountLabel, 'debit': 0.0, 'credit': 0.0};
      }
      balances[e.accountCode]!['debit'] += e.debit;
      balances[e.accountCode]!['credit'] += e.credit;
    }
    final sortedCodes = balances.keys.toList()..sort();

    double totalDebitMvt = 0;
    double totalCreditMvt = 0;
    double totalDebitSolde = 0;
    double totalCreditSolde = 0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('MLD Consulting - ERP', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text('Balance des comptes', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Complete', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Periode du 01/01/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('au $dateStr', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Tenue de compte : XOF', style: const pw.TextStyle(fontSize: 8)),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Date de tirage $dateStr  a  $timeStr', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Page : ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        ]),
        pw.Divider(),
      ]),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Numero', 'Intitule', 'Mvt Debit', 'Mvt Credit', 'Solde Debit', 'Solde Credit'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          columnWidths: {0: const pw.FixedColumnWidth(60), 1: const pw.FlexColumnWidth(2)},
          data: sortedCodes.map((code) {
            double d = balances[code]!['debit'];
            double c = balances[code]!['credit'];
            double s = d - c;
            totalDebitMvt += d; totalCreditMvt += c;
            if (s > 0) totalDebitSolde += s; else totalCreditSolde += s.abs();
            return [code, balances[code]!['label'].toString().toUpperCase(), _currencyFormat.format(d), _currencyFormat.format(c), s > 0 ? _currencyFormat.format(s) : '', s < 0 ? _currencyFormat.format(s.abs()) : ''];
          }).toList(),
        ),
        pw.Divider(),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Totaux de la balance : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalDebitMvt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalCreditMvt), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalDebitSolde), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalCreditSolde), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)))),
        ])
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balance_Comptes.pdf');
  }

  static Future<void> generateReconciliationReport({required Account account, required DateTime date, required List<JournalEntry> entries, required String filter}) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Rapprochement Bancaire', account.label), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Piece', 'Libelle', 'Debit', 'Credit'], data: entries.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.reference, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- LOGISTIQUE ET STOCK ---
  static Future<void> generateTransferBordereau(StockTransfer t) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (context) => pw.Column(children: [
      _header(logo, 'Bordereau de Transfert', ''),
      pw.Text('PRODUIT : ${t.productName}'),
      pw.Text('QTE : ${t.quantity}'),
      pw.Text('DE : ${t.fromWarehouseName} VERS : ${t.toWarehouseName}'),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryReport(List<Map<String, dynamic>> data, double totalValue) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Rapport d\'Inventaire Valorise', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Stock', 'Valeur'], data: data.map((d) => [d['name'], d['qty'].toString(), _currencyFormat.format(d['total'])]).toList()),
      pw.SizedBox(height: 20),
      pw.Text('VALEUR TOTALE : ${_currencyFormat.format(totalValue)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateStockMovementReport(List<Map<String, dynamic>> movements, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Mouvements de Stock', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Produit', 'Type', 'Qte'], data: movements.map((m) => [DateFormat('dd/MM HH:mm').format(m['date']), m['product'], m['type'], m['qty'].toString()]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateDeliveryNote(AppTransaction transaction) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (context) => pw.Column(children: [
      _header(logo, 'Bon de Livraison', 'BL-${transaction.invoiceNumber}'),
      pw.Text('DESTINATAIRE : ${transaction.tierName}'),
      pw.TableHelper.fromTextArray(headers: ['Article', 'Qte'], data: transaction.items.map((i) => [i.productName, i.quantity.toString()]).toList())
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- RH ET TRANSPORT ---
  static Future<void> generatePayslip(SalaryPayment s) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a5, build: (context) => pw.Column(children: [
      _header(logo, 'Bulletin de Paie', s.month),
      pw.Text('SALARIE : ${s.employeeName}'),
      pw.Text('NET A PAYER : ${_currencyFormat.format(s.amount)} FCFA'),
      pw.Spacer(),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Salarie'), pw.Text('Direction')])
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTruckReport(Truck truck, List<Trip> trips) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Rapport Camion', truck.plateNumber), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Trajet', 'Resultat'], data: trips.map((t) => [DateFormat('dd/MM/yy').format(t.departureDate), t.mainAxis, _currencyFormat.format(t.netProfit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTransferReport(List<StockTransfer> transfers) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(logo, 'Historique Transferts', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Article', 'Qte'], data: transfers.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.productName, t.quantity.toString()]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTechnicianReport(Task task) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (context) => pw.Column(children: [
      _header(logo, 'Rapport de Chantier', task.clientName),
      pw.Text('TECHNICIEN : ${task.technicianName}'),
      pw.Text('DESCRIPTION : ${task.reportDescription}'),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- INTERNE ---
  static pw.Widget _header(pw.ImageProvider logo, String title, String sub) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Image(logo, width: 60),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          if (sub.isNotEmpty) pw.Text(sub),
          pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
        ])
      ]),
      pw.Divider(),
      pw.SizedBox(height: 10),
    ]);
  }

  static Future<Uint8List> getInvoiceBytes(AppTransaction transaction) async {
    final logo = await _getLogo();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo);
    return pdf.save();
  }
}
