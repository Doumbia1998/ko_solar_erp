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
  static pw.ImageProvider? _cachedHeader;
  static pw.ImageProvider? _cachedFooter;

  static Future<pw.ImageProvider> _getLogo() async {
    if (_cachedLogo != null) return _cachedLogo!;
    final byteData = await rootBundle.load('assets/images/logo.png');
    _cachedLogo = pw.MemoryImage(byteData.buffer.asUint8List());
    return _cachedLogo!;
  }

  // Tentative de chargement des images d'entête/pied fournies par le client
  static Future<pw.ImageProvider?> _getHeaderImg() async {
    if (_cachedHeader != null) return _cachedHeader!;
    try {
      final byteData = await rootBundle.load('assets/images/header_facture.png');
      _cachedHeader = pw.MemoryImage(byteData.buffer.asUint8List());
      return _cachedHeader;
    } catch (e) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> _getFooterImg() async {
    if (_cachedFooter != null) return _cachedFooter!;
    try {
      final byteData = await rootBundle.load('assets/images/footer_facture.png');
      _cachedFooter = pw.MemoryImage(byteData.buffer.asUint8List());
      return _cachedFooter;
    } catch (e) {
      return null;
    }
  }

  // --- FACTURES (AVEC DESIGN PROFESSIONNEL) ---
  static Future<pw.Document> _buildInvoiceDoc(AppTransaction transaction, {required pw.ImageProvider logo, pw.ImageProvider? headerImg, pw.ImageProvider? footerImg, List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
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

    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(25),
      build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (headerImg != null) pw.Image(headerImg) else _buildProfessionalHeader(logo),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(transaction.type == TransactionType.sale ? 'FACTURE DE VENTE' : (transaction.type == TransactionType.quote ? 'DEVIS PROFORMA' : 'FACTURE D\'ACHAT'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
          pw.Text('N° ${transaction.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
        ]),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}', style: const pw.TextStyle(fontSize: 10)),
            if (transaction.destination.isNotEmpty) pw.Text('Lieu: ${transaction.destination}', style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.Container(width: 220, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CLIENT :', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text(transaction.tierName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text('Compte: ${transaction.tierId.substring(0, 8)}', style: const pw.TextStyle(fontSize: 9)),
          ])),
        ]),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headers: ['Designation', 'Qte', 'Prix Unitaire', 'Remise', 'Total Net'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          cellStyle: const pw.TextStyle(fontSize: 9),
          data: transaction.items.map((item) => [
            item.productName.toUpperCase(),
            item.quantity.toString(),
            _currencyFormat.format(item.unitPrice),
            _currencyFormat.format(item.discount),
            _currencyFormat.format((item.quantity * item.unitPrice) - item.discount)
          ]).toList(),
        ),
        pw.SizedBox(height: 15),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey), color: PdfColors.grey50),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('NET A PAYER : ${_currencyFormat.format(transaction.netToPay)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.Text('Déjà Réglé : ${_currencyFormat.format(totalRegle)} FCFA', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(color: PdfColors.grey),
              pw.Text('SOLDE DU : ${_currencyFormat.format(resteAPayer)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: resteAPayer > 10 ? PdfColors.red900 : PdfColors.green900)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Arrêté la présente facture à la somme de :', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
        pw.Text(NumberToWords.convertToFr(transaction.netToPay).toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Text('Signature Client', style: const pw.TextStyle(fontSize: 9, decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 40)]),
          pw.Column(children: [pw.Text('La Direction (Cachet)', style: const pw.TextStyle(fontSize: 9, decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 40)]),
        ]),
        if (footerImg != null) pw.Image(footerImg) else _buildProfessionalFooter(),
      ]);
    }));
    return pdf;
  }

  static Future<void> generateInvoice(AppTransaction transaction, {List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final logo = await _getLogo();
    final headerImg = await _getHeaderImg();
    final footerImg = await _getFooterImg();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo, headerImg: headerImg, footerImg: footerImg, allTierPayments: allTierPayments, allTierTransactions: allTierTransactions);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Facture_${transaction.invoiceNumber}.pdf');
  }

  // --- BON DE LIVRAISON ---
  static Future<void> generateDeliveryNote(AppTransaction transaction) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    final headerImg = await _getHeaderImg();
    final footerImg = await _getFooterImg();
    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(25),
      build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (headerImg != null) pw.Image(headerImg) else _buildProfessionalHeader(logo),
        pw.SizedBox(height: 10),
        pw.Center(child: pw.Text('BON DE LIVRAISON', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900, decoration: pw.TextDecoration.underline))),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('N° BL : BL-${transaction.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('DESTINATAIRE : ${transaction.tierName.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (transaction.destination.isNotEmpty) pw.Text('Lieu : ${transaction.destination}'),
          ]),
        ]),
        pw.SizedBox(height: 15),
        pw.TableHelper.fromTextArray(
          headers: ['Designation', 'Quantité Commandée', 'Quantité Livrée', 'Observation'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          data: transaction.items.map((item) => [item.productName.toUpperCase(), item.quantity.toString(), item.quantity.toString(), '']).toList(),
        ),
        pw.SizedBox(height: 40),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Text('Le Livreur', style: const pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 50), pw.Text('........................')]),
          pw.Column(children: [pw.Text('Le Réceptionnaire', style: const pw.TextStyle(decoration: pw.TextDecoration.underline)), pw.SizedBox(height: 50), pw.Text('........................')]),
        ]),
        pw.Spacer(),
        if (footerImg != null) pw.Image(footerImg) else _buildProfessionalFooter(),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'BL_${transaction.invoiceNumber}.pdf');
  }

  static Future<void> generateTransferBordereau(StockTransfer t) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _simpleHeader('BORDEREAU DE TRANSFERT', 'TR-${DateFormat('ddMMyyHHmm').format(t.date)}'),
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
        pw.Text('Edité par : ${t.createdBy}', style: const pw.TextStyle(fontSize: 8)),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Transfert_${t.productName}.pdf');
  }

  // --- RAPPORTS SANS LOGO (RAPIDES) ---
  static Future<void> generateAgedBalance({required String type, required List<Map<String, dynamic>> agedData}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('BALANCE AGÉE', type),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Compte', 'Intitulé', 'Solde', 'Non échu', '1 à 15j', '16 à 30j', '31 à 45j', '+ 46j'],
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
      String code = e.accountCode.trim();
      String label = e.accountLabel;
      if (code.startsWith('411')) { code = '41100000'; label = 'CLIENTS CPTES COLLECTIFS'; }
      else if (code.startsWith('401')) { code = '40100000'; label = 'FOURNISSEURS'; }
      if (!balances.containsKey(code)) balances[code] = {'label': label, 'debit': 0.0, 'credit': 0.0};
      balances[code]!['debit'] += e.debit;
      balances[code]!['credit'] += e.credit;
    }
    final sortedCodes = balances.keys.toList()..sort();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('BALANCE DES COMPTES', ''),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Numero', 'Intitule', 'Mvt Debit', 'Mvt Credit', 'Solde Debit', 'Solde Credit'],
          data: sortedCodes.map((code) {
            double d = balances[code]!['debit']; double c = balances[code]!['credit']; double s = d - c;
            return [code, balances[code]!['label'].toString().toUpperCase(), _currencyFormat.format(d), _currencyFormat.format(c), s > 0 ? _currencyFormat.format(s) : '', s < 0 ? _currencyFormat.format(s.abs()) : ''];
          }).toList(),
        ),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balance_Comptes.pdf');
  }

  static Future<void> generateUnpaidReport({required String type, required DateTime start, required DateTime end, required List<Map<String, dynamic>> unpaidDetails}) async {
    final pdf = pw.Document();
    final double totalUnpaid = unpaidDetails.fold(0.0, (sum, d) => sum + (d['remaining'] as double));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('ETAT DES IMPAYES ${type.toUpperCase()}S', 'Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) => [
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'N Facture', 'Tiers', 'Total Net', 'Deja Paye', 'Reste'],
          columnWidths: {
            0: const pw.FixedColumnWidth(80),
            1: const pw.FixedColumnWidth(110),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FixedColumnWidth(100),
            4: const pw.FixedColumnWidth(100),
            5: const pw.FixedColumnWidth(100),
          },
          data: unpaidDetails.map((d) {
            final AppTransaction t = d['transaction'];
            return [DateFormat('dd/MM/yyyy').format(t.date), t.invoiceNumber, t.tierName.toUpperCase(), _currencyFormat.format(t.netToPay), _currencyFormat.format(d['totalPaid']), _currencyFormat.format(d['remaining'])];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL A RECOUVRER : ${_currencyFormat.format(totalUnpaid)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateGlobalTransactionReport({required String type, required DateTime start, required DateTime end, required List<AppTransaction> transactions}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('RECAPITULATIF $type', 'Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'N Facture', 'Tiers', 'Montant'],
          data: transactions.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.invoiceNumber, t.tierName, _currencyFormat.format(t.netToPay)]).toList(),
        )
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateProfitReport({required DateTime start, required DateTime end, required double totalCA, required double totalCout, required double marge, required double pourcentage, required List<Map<String, dynamic>> productStats}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('ANALYSE RENTABILITE', ''),
      build: (context) => [
        pw.Text('CA GLOBAL : ${_currencyFormat.format(totalCA)} F'),
        pw.Text('MARGE : ${_currencyFormat.format(marge)} F (${pourcentage.toStringAsFixed(1)}%)'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['Produit', 'Qte', 'CA', 'Marge'],
          data: productStats.map((s) => [s['name'], s['qty'].toString(), _currencyFormat.format(s['ca']), _currencyFormat.format(s['margin'])]).toList(),
        )
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateExpenseReport(List<Expense> expenses, String type, {DateTimeRange? range}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('RAPPORT DE DEPENSES', type),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Libellé', 'Mode', 'Montant'],
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(100),
            3: const pw.FixedColumnWidth(100),
          },
          data: expenses.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.label.toUpperCase(), e.paymentMethod, _currencyFormat.format(e.amount)]).toList(),
        )
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryReport(List<Map<String, dynamic>> data, double totalValue) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('RAPPORT D\'INVENTAIRE VALORISE', ''),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Produit', 'Stock', 'Valeur'],
          data: data.map((d) => [d['name'], d['qty'].toString(), _currencyFormat.format(d['total'])]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text('VALEUR TOTALE : ${_currencyFormat.format(totalValue)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateStockMovementReport(List<Map<String, dynamic>> movements, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('MOUVEMENTS DE STOCK', ''),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Produit', 'Type', 'Qte'],
          data: movements.map((m) => [DateFormat('dd/MM HH:mm').format(m['date']), m['product'], m['type'], m['qty'].toString()]).toList(),
        )
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generatePayslip(SalaryPayment s) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('BULLETIN DE PAIE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Text('Période: ${s.month.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
            ]),
          ]),
          pw.Divider(thickness: 1, color: PdfColors.blueGrey),
          pw.SizedBox(height: 20),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey100), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [pw.Text('NOM DU SALARIÉ : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(s.employeeName.toUpperCase())]),
            pw.SizedBox(height: 10),
            pw.Row(children: [pw.Text('DATE DE PAIEMENT : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy').format(s.date))]),
          ])),
          pw.SizedBox(height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('NET À PAYER :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('${_currencyFormat.format(s.amount)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green900)),
          ]),
          pw.Spacer(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(children: [pw.Text('Signature Salarié', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)), pw.SizedBox(height: 40), pw.Text('........................')]),
            pw.Column(children: [pw.Text('La Direction (Cachet)', style: const pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 9)), pw.SizedBox(height: 40), pw.Text('........................')]),
          ]),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTruckReport(Truck truck, List<Trip> trips) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('RAPPORT CAMION', truck.plateNumber), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Trajet', 'Resultat'], data: trips.map((t) => [DateFormat('dd/MM/yy').format(t.departureDate), t.mainAxis, _currencyFormat.format(t.netProfit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTransferReport(List<StockTransfer> transfers) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('HISTORIQUE TRANSFERTS', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Article', 'Qte'], data: transfers.map((t) => [DateFormat('dd/MM/yy').format(t.date), t.productName, t.quantity.toString()]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTechnicianReport(Task task) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (context) => pw.Column(children: [
      _simpleHeader('RAPPORT DE CHANTIER', task.clientName),
      pw.SizedBox(height: 20),
      pw.Text('TECHNICIEN : ${task.technicianName}'),
      pw.Text('DESCRIPTION : ${task.reportDescription}'),
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateReconciliationReport({required Account account, required DateTime date, required List<JournalEntry> entries, required String filter}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('RAPPROCHEMENT BANCAIRE', account.label), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Piece', 'Libelle', 'Debit', 'Credit'], data: entries.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.reference, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)]).toList())
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateCashControlReport({required DateTime start, required DateTime end, required double initialBalance, required List<JournalEntry> entries}) async {
    final pdf = pw.Document();
    double runningBalance = initialBalance;
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('CONTROLE DE CAISSE', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'N° pièce', 'Libellé', 'Recettes', 'Dépenses', 'Solde'], data: [['', '', 'SOLDE INITIAL', '', '', _currencyFormat.format(initialBalance)], ...entries.map((e) { runningBalance += (e.debit - e.credit); return [DateFormat('dd/MM').format(e.date), e.reference, e.label.toUpperCase(), e.debit > 0 ? _currencyFormat.format(e.debit) : '', e.credit > 0 ? _currencyFormat.format(e.credit) : '', _currencyFormat.format(runningBalance)]; })]),
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateDailyPaymentsReport(List<Payment> payments, String type, {String? tierName, DateTime? start, DateTime? end}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('RECAPITULATIF DES REGLEMENTS ${type.toUpperCase()}', ''), build: (context) => [
      pw.SizedBox(height: 10),
      pw.TableHelper.fromTextArray(headers: ['Date', 'Tiers', 'Mode', 'Montant'], data: payments.map((p) => [DateFormat('dd/MM/yy').format(p.date), p.tierName, p.method, _currencyFormat.format(p.amount)]).toList()),
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- WIDGETS INTERNES REUTILISABLES ---
  static pw.Widget _simpleHeader(String title, String sub) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('K-O SOLAR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
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

  static pw.Widget _buildProfessionalHeader(pw.ImageProvider logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Image(logo, width: 180)]),
        pw.SizedBox(height: 5),
        pw.Text('Electricité - Solaire - Climatisation - Ventilation - Adduction d\'eau', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Text('Distributeur de la Marque ( FELICITY - RITAR & CAPRARI )', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Text('Tel : 76 73 76 22 / 66 73 76 22 / 50 57 01 11', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text('SOTUBA à coté de Station OLA - Bamako - Mali', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _buildProfessionalFooter() {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.orange, thickness: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
        pw.SizedBox(width: 10),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Adresse : Bamako, Bougouba Rue pasteur près station Ola', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('Phone : +223 66 73 76 22 / 70 21 16 16 / 70 21 09 09', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('Email : kosolarmali@gmail.com', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('N°Compte Banque: 005001204583 - BNDA', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
        ]),
      ]),
    ]);
  }

  static Future<Uint8List> getInvoiceBytes(AppTransaction transaction) async {
    final logo = await _getLogo();
    final headerImg = await _getHeaderImg();
    final footerImg = await _getFooterImg();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo, headerImg: headerImg, footerImg: footerImg);
    return pdf.save();
  }
}
