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

  // --- FACTURES (AVEC LOGO) ---
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
        _header(logo, transaction.type == TransactionType.sale ? 'FACTURE DE VENTE' : (transaction.type == TransactionType.quote ? 'DEVIS PROFORMA' : 'FACTURE D\'ACHAT'), 'N° ${transaction.invoiceNumber}'),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
            if (transaction.destination.isNotEmpty) pw.Text('Destination: ${transaction.destination}', style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.Container(width: 200, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Tiers: ${transaction.tierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Compte: ${transaction.tierId.substring(0, 8)}'),
          ])),
        ]),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['Designation', 'Qte', 'Px unitaire', 'Remise', 'Total Net'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          data: transaction.items.map((item) => [item.productName, item.quantity.toString(), _currencyFormat.format(item.unitPrice), _currencyFormat.format(item.discount), _currencyFormat.format((item.quantity * item.unitPrice) - item.discount)]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('NET A PAYER: ${_currencyFormat.format(transaction.netToPay).replaceAll(',', ' ')} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('Total Deja Regle: ${_currencyFormat.format(totalRegle).replaceAll(',', ' ')} FCFA'),
            pw.Text('SOLDE A REGLER: ${_currencyFormat.format(resteAPayer).replaceAll(',', ' ')} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: resteAPayer > 10 ? PdfColors.red900 : PdfColors.green900)),
            pw.SizedBox(height: 10),
            pw.Text('Arrete la presente facture a la somme de :', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(NumberToWords.convertToFr(transaction.netToPay), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ]),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Signature Client / Fournisseur', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)),
          pw.Text('La Direction (Cachet)', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)),
        ]),
      ]);
    }));
    return pdf;
  }

  static Future<void> generateInvoice(AppTransaction transaction, {List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final logo = await _getLogo();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo, allTierPayments: allTierPayments, allTierTransactions: allTierTransactions);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Facture_${transaction.invoiceNumber}.pdf');
  }

  // --- LOGISTIQUE (AVEC LOGO) ---
  static Future<void> generateDeliveryNote(AppTransaction transaction) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header(logo, 'BON DE LIVRAISON', 'BL-${transaction.invoiceNumber}'),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('DESTINATAIRE :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(transaction.tierName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (transaction.destination.isNotEmpty) pw.Text('Lieu de livraison : ${transaction.destination}'),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Détails Logistiques', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            pw.Text('Dépôt Source : ${transaction.warehouseId}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(transaction.date)}', style: const pw.TextStyle(fontSize: 9)),
          ])),
        ]),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['Designation', 'Qté Commandée', 'Qté Livrée', 'Observation'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          data: transaction.items.map((item) => [item.productName.toUpperCase(), item.quantity.toString(), item.quantity.toString(), '']).toList(),
        ),
        pw.SizedBox(height: 40),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Text('Le Livreur', style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 40), pw.Text('........................')]),
          pw.Column(children: [pw.Text('Le Réceptionnaire', style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 40), pw.Text('........................')]),
          pw.Column(children: [pw.Text('La Direction (Cachet)', style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 40), pw.Text('........................')]),
        ]),
        pw.Spacer(),
        pw.Center(child: pw.Text('Marchandise livrée en bon état et conforme à la commande.', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'BL_${transaction.invoiceNumber}.pdf');
  }

  static Future<void> generateTransferBordereau(StockTransfer t) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _header(logo, 'BORDEREAU DE TRANSFERT', 'N° TR-${DateFormat('ddMMyyHHmm').format(t.date)}'),
        pw.SizedBox(height: 20),
        pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey50), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          pw.Column(children: [pw.Text('DEPOT SOURCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)), pw.Text(t.fromWarehouseName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
          pw.Icon(const pw.IconData(0xe5c8), size: 30, color: PdfColors.grey700),
          pw.Column(children: [pw.Text('DEPOT DESTINATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900)), pw.Text(t.toWarehouseName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
        ])),
        pw.SizedBox(height: 30),
        pw.TableHelper.fromTextArray(
          headers: ['Désignation du Produit', 'Quantité Transférée'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          cellAlignment: pw.Alignment.center,
          data: [[t.productName.toUpperCase(), t.quantity.toString()]],
        ),
        pw.SizedBox(height: 50),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Text('Visa Départ (Source)', style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 50), pw.Text('........................')]),
          pw.Column(children: [pw.Text('Visa Arrivée (Dest.)', style: pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 50), pw.Text('........................')]),
        ]),
        pw.Spacer(),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Edité par : ${t.createdBy}', style: const pw.TextStyle(fontSize: 8)), pw.Text('Date : ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}', style: const pw.TextStyle(fontSize: 8))]),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Transfert_${t.productName}.pdf');
  }

  // --- RAPPORTS SANS LOGO (RAPIDES) ---
  static Future<void> generateAgedBalance({required String type, required List<Map<String, dynamic>> agedData}) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('MLD Consulting', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Text('Balance Agée', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('D\'après date d\'échéance', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Période au $dateStr', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Tenue de compte : XOF', style: const pw.TextStyle(fontSize: 8)),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Date de tirage $dateStr  à  $timeStr', style: const pw.TextStyle(fontSize: 8)),
          pw.Text('Page : ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        ]),
        pw.Divider(),
      ]),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Compte', 'Intitulé', 'Solde', 'Non échu', '1 à 15j', '16 à 30j', '31 à 45j', '+ 46j'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FixedColumnWidth(70),
            3: const pw.FixedColumnWidth(70),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(70),
            6: const pw.FixedColumnWidth(70),
            7: const pw.FixedColumnWidth(70),
          },
          data: agedData.map((d) => [
            d['code'],
            d['name'].toString().toUpperCase(),
            _currencyFormat.format(d['total']),
            _currencyFormat.format(d['notDue']),
            _currencyFormat.format(d['1-15']),
            _currencyFormat.format(d['16-30']),
            _currencyFormat.format(d['31-45']),
            _currencyFormat.format(d['46+']),
          ]).toList(),
        ),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balance_Agee.pdf');
  }

  static Future<void> generateTrialBalance(List<JournalEntry> entries) async {
    final pdf = pw.Document();
    Map<String, Map<String, dynamic>> balances = {};
    for (var e in entries) {
      // Normalisation immediate : pad a 8 chiffres pour fusionner 411100 et 41100000
      String code = e.accountCode.trim();
      if (code.length < 8 && (code.startsWith('411') || code.startsWith('401') || code.startsWith('571') || code.startsWith('521') || code.startsWith('701') || code.startsWith('601'))) {
        code = code.padRight(8, '0');
      }

      if (!balances.containsKey(code)) balances[code] = {'label': e.accountLabel, 'debit': 0.0, 'credit': 0.0};
      balances[code]!['debit'] += e.debit;
      balances[code]!['credit'] += e.credit;
    }
    final sortedCodes = balances.keys.toList()..sort();
    double totalDebitMvt = 0; double totalCreditMvt = 0; double totalDebitSolde = 0; double totalCreditSolde = 0;

    pdf.addPage(pw.MultiPage(
      header: (context) => _header(null, 'Balance des comptes', 'Complete'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Numero', 'Intitule', 'Mvt Debit', 'Mvt Credit', 'Solde Debit', 'Solde Credit'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          data: sortedCodes.map((code) {
            double d = balances[code]!['debit']; double c = balances[code]!['credit']; double s = d - c;
            totalDebitMvt += d; totalCreditMvt += c;
            if (s > 0) totalDebitSolde += s; else totalCreditSolde += s.abs();
            return [code, balances[code]!['label'].toString().toUpperCase(), _currencyFormat.format(d), _currencyFormat.format(c), s > 0 ? _currencyFormat.format(s) : '', s < 0 ? _currencyFormat.format(s.abs()) : ''];
          }).toList(),
        ),
        pw.Divider(),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Totaux : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
          pw.Container(width: 60, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalDebitMvt), style: const pw.TextStyle(fontSize: 8)))),
          pw.Container(width: 60, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalCreditMvt), style: const pw.TextStyle(fontSize: 8)))),
          pw.Container(width: 60, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalDebitSolde), style: const pw.TextStyle(fontSize: 8)))),
          pw.Container(width: 60, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalCreditSolde), style: const pw.TextStyle(fontSize: 8)))),
        ])
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balance_Comptes.pdf');
  }

  static Future<void> generateGlobalTransactionReport({required String type, required DateTime start, required DateTime end, required List<AppTransaction> transactions}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Recapitulatif $type', 'Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'N Facture', 'Tiers', 'Montant'], data: transactions.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.invoiceNumber, t.tierName, _currencyFormat.format(t.netToPay)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateUnpaidReport({required String type, required DateTime start, required DateTime end, required List<Map<String, dynamic>> unpaidDetails}) async {
    final pdf = pw.Document();
    final double totalUnpaid = unpaidDetails.fold(0.0, (sum, d) => sum + (d['remaining'] as double));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, // Élargissement maximal
      header: (context) => _header(null, 'ETAT DES IMPAYES ${type.toUpperCase()}S', 'Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'N Facture', 'Tiers', 'Total Net', 'Deja Paye', 'Reste'],
          columnWidths: {
            0: const pw.FixedColumnWidth(80), // Date plus large
            1: const pw.FixedColumnWidth(110), // N Facture
            2: const pw.FlexColumnWidth(3), // Tiers prend l'espace
            3: const pw.FixedColumnWidth(100), // Montant
            4: const pw.FixedColumnWidth(100),
            5: const pw.FixedColumnWidth(100),
          },
          data: unpaidDetails.map((d) {
            final AppTransaction t = d['transaction'];
            return [DateFormat('dd/MM/yyyy').format(t.date), t.invoiceNumber, t.tierName.toUpperCase(), _currencyFormat.format(t.netToPay), _currencyFormat.format(d['totalPaid']), _currencyFormat.format(d['remaining'])];
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
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Analyse Rentabilite', ''), build: (context) => [
      pw.Text('CA GLOBAL : ${_currencyFormat.format(totalCA)} F'),
      pw.Text('MARGE : ${_currencyFormat.format(marge)} F (${pourcentage.toStringAsFixed(1)}%)'),
      pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Qte', 'CA', 'Marge'], data: productStats.map((s) => [s['name'], s['qty'].toString(), _currencyFormat.format(s['ca']), _currencyFormat.format(s['margin'])]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateExpenseReport(List<Expense> expenses, String type, {DateTimeRange? range}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Rapport de Depenses', type), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Libelle', 'Mode', 'Montant'], data: expenses.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.label, e.paymentMethod, _currencyFormat.format(e.amount)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryReport(List<Map<String, dynamic>> data, double totalValue) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Rapport d\'Inventaire Valorise', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Stock', 'Valeur'], data: data.map((d) => [d['name'], d['qty'].toString(), _currencyFormat.format(d['total'])]).toList()),
      pw.SizedBox(height: 20),
      pw.Text('VALEUR TOTALE : ${_currencyFormat.format(totalValue)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateStockMovementReport(List<Map<String, dynamic>> movements, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Mouvements de Stock', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Produit', 'Type', 'Qte'], data: movements.map((m) => [DateFormat('dd/MM HH:mm').format(m['date']), m['product'], m['type'], m['qty'].toString()]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generatePayslip(SalaryPayment s) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blueGrey, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('BULLETIN DE PAIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('Période: ${s.month.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.blueGrey),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Text('NOM DU SALARIÉ : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(s.employeeName.toUpperCase()),
                  ]),
                  pw.SizedBox(height: 10),
                  pw.Row(children: [
                    pw.Text('DATE DE PAIEMENT : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy').format(s.date)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET À PAYER :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Text('${_currencyFormat.format(s.amount)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green900)),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Arrêté le présent bulletin à la somme de :', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
            pw.Text(NumberToWords.convertToFr(s.amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Signature Salarié', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)),
                    pw.SizedBox(height: 40),
                    pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('La Direction (Cachet)', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)),
                    pw.SizedBox(height: 40),
                    pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('Fait à Bamako, le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7))),
          ],
        ),
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTruckReport(Truck truck, List<Trip> trips) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Rapport Camion', truck.plateNumber), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Trajet', 'Resultat'], data: trips.map((t) => [DateFormat('dd/MM/yy').format(t.departureDate), t.mainAxis, _currencyFormat.format(t.netProfit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTransferReport(List<StockTransfer> transfers) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Historique Transferts', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Article', 'Qte'], data: transfers.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.productName, t.quantity.toString()]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTechnicianReport(Task task) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (context) => pw.Column(children: [
      _header(null, 'Rapport de Chantier', task.clientName),
      pw.Text('TECHNICIEN : ${task.technicianName}'),
      pw.Text('DESCRIPTION : ${task.reportDescription}'),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateReconciliationReport({required Account account, required DateTime date, required List<JournalEntry> entries, required String filter}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _header(null, 'Rapprochement Bancaire', account.label), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Piece', 'Libelle', 'Debit', 'Credit'], data: entries.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.reference, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- INTERNE ---
  static pw.Widget _header(pw.ImageProvider? logo, String title, String sub) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        if (logo != null) pw.Image(logo, width: 60) else pw.SizedBox(width: 60, child: pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(title.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          if (sub.isNotEmpty) pw.Text(sub, style: const pw.TextStyle(fontSize: 10)),
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
