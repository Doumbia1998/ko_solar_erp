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

  // --- FACTURES (AVEC DESIGN PROFESSIONNEL) ---
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

    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(25),
      build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _buildProfessionalHeader(logo),
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
          _signatureBox('SIGNATURE CLIENT'),
          _signatureBox('LA DIRECTION (CACHET)'),
        ]),
        _buildProfessionalFooter(),
      ]);
    }));
    return pdf;
  }

  static Future<void> generateInvoice(AppTransaction transaction, {List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final logo = await _getLogo();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo, allTierPayments: allTierPayments, allTierTransactions: allTierTransactions);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Facture_${transaction.invoiceNumber}.pdf');
  }

  // --- BON DE LIVRAISON ---
  static Future<void> generateDeliveryNote(AppTransaction transaction) async {
    final pdf = pw.Document();
    final logo = await _getLogo();
    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(25),
      build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _buildProfessionalHeader(logo),
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
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          _signatureBox('LE LIVREUR'),
          _signatureBox('LE RÉCEPTIONNAIRE (CLIENT)'),
          _signatureBox('LA DIRECTION'),
        ]),
        _buildProfessionalFooter(),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'BL_${transaction.invoiceNumber}.pdf');
  }

  // --- RAPPORT DE CHANTIER ---
  static Future<void> generateTechnicianReport(Task task) async {
    final pdf = pw.Document();
    final logo = await _getLogo();

    pdf.addPage(pw.Page(
      margin: const pw.EdgeInsets.all(30),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tête stylé
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(logo, width: 120),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('RAPPORT DE CHANTIER', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('Réf: ${task.invoiceNumber}', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ]
              )
            ]
          ),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
          pw.SizedBox(height: 20),

          // Section Informations
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENT', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                        pw.Text(task.clientName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('TECHNICIEN', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                        pw.Text(task.technicianName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ]
                    ),
                  ]
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('LIEU DU CHANTIER', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                        pw.Text(task.siteLocation ?? 'Non précisé', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DATE D\'INTERVENTION', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
                        pw.Text(task.completedAt != null ? DateFormat('dd/MM/yyyy').format(task.completedAt!) : 'En cours', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ),
                  ]
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 25),
          pw.Text('COMPTE-RENDU DES TRAVAUX', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 5),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
            child: pw.Text(task.reportDescription ?? 'Aucune description fournie.', textAlign: pw.TextAlign.justify, style: const pw.TextStyle(lineSpacing: 1.5)),
          ),

          pw.SizedBox(height: 25),
          if (task.usedProducts != null && task.usedProducts!.isNotEmpty) ...[
            pw.Text('MATÉRIEL UTILISÉ SUR SITE', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 5),
            pw.TableHelper.fromTextArray(
              headers: ['Désignation Article', 'Quantité'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              data: task.usedProducts!.map((p) => [p['productName'].toString().toUpperCase(), p['quantity'].toString()]).toList(),
            ),
          ],

          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureBox('LE TECHNICIEN'),
              _signatureBox('LE CLIENT'),
              _signatureBox('LE SUPÉRIEUR'),
            ],
          ),
          pw.SizedBox(height: 10),
          _developerMention(),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Rapport_Chantier_${task.invoiceNumber}.pdf');
  }

  // --- BALANCE DES COMPTES (PAYSAGE) ---
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
    double totalDebit = 0, totalCredit = 0, totalSoldeDebit = 0, totalSoldeCredit = 0;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('BALANCE DES COMPTES', 'MLD Consulting - Système ERP'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Numéro', 'Intitulé du compte', 'Mvt Débit', 'Mvt Crédit', 'Solde Débit', 'Solde Crédit'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(80),
            4: const pw.FixedColumnWidth(80),
            5: const pw.FixedColumnWidth(80),
          },
          data: sortedCodes.map((code) {
            double d = balances[code]!['debit'];
            double c = balances[code]!['credit'];
            double s = d - c;
            totalDebit += d; totalCredit += c;
            if (s > 0) totalSoldeDebit += s; else totalSoldeCredit += s.abs();
            return [
              code,
              balances[code]!['label'].toString().toUpperCase(),
              _currencyFormat.format(d),
              _currencyFormat.format(c),
              s > 0 ? _currencyFormat.format(s) : '',
              s < 0 ? _currencyFormat.format(s.abs()) : ''
            ];
          }).toList(),
        ),
        pw.Divider(),
        pw.Row(children: [
          pw.Expanded(flex: 3, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAUX : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalDebit), style: const pw.TextStyle(fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalCredit), style: const pw.TextStyle(fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalSoldeDebit), style: const pw.TextStyle(fontSize: 9)))),
          pw.Container(width: 80, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_currencyFormat.format(totalSoldeCredit), style: const pw.TextStyle(fontSize: 9)))),
        ]),
        pw.SizedBox(height: 20),
        _developerMention(),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balance_Comptes.pdf');
  }

  // --- RAPPORT DE DEPENSES ---
  static Future<void> generateExpenseReport(List<Expense> expenses, String type, {DateTimeRange? range}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('RAPPORT DE DEPENSES', type),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Libellé de la dépense', 'Mode', 'Montant'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
          columnWidths: {
            0: const pw.FixedColumnWidth(80),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(120),
            3: const pw.FixedColumnWidth(100),
          },
          data: expenses.map((e) => [
            DateFormat('dd/MM/yyyy').format(e.date),
            e.label.toUpperCase(),
            e.paymentMethod,
            _currencyFormat.format(e.amount)
          ]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL DEPENSES : ${_currencyFormat.format(expenses.fold(0.0, (sum, e) => sum + e.amount))} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
        pw.Spacer(),
        _developerMention(),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- AUTRES RAPPORTS ---
  static Future<void> generateUnpaidReport({required String type, required DateTime start, required DateTime end, required List<Map<String, dynamic>> unpaidDetails}) async {
    final pdf = pw.Document();
    final double totalUnpaid = unpaidDetails.fold(0.0, (sum, d) => sum + (d['remaining'] as double));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('ETAT DES IMPAYES ${type.toUpperCase()}S', 'Période du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'N Facture', 'Tiers', 'Total Net', 'Deja Paye', 'Reste'],
          data: unpaidDetails.map((d) {
            final AppTransaction t = d['transaction'];
            return [DateFormat('dd/MM/yyyy').format(t.date), t.invoiceNumber, t.tierName.toUpperCase(), _currencyFormat.format(t.netToPay), _currencyFormat.format(d['totalPaid']), _currencyFormat.format(d['remaining'])];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL A RECOUVRER : ${_currencyFormat.format(totalUnpaid)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Spacer(),
        _developerMention(),
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
        ),
        pw.Spacer(),
        _developerMention(),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateReconciliationReport({required Account account, required DateTime date, required List<JournalEntry> entries, required String filter}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('RAPPROCHEMENT BANCAIRE', account.label),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Piece', 'Libelle', 'Debit', 'Credit'],
          data: entries.map((e) => [DateFormat('dd/MM/yy').format(e.date), e.reference, e.label, _currencyFormat.format(e.debit), _currencyFormat.format(e.credit)]).toList(),
        ),
        pw.Spacer(),
        _developerMention(),
      ],
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTransferBordereau(StockTransfer t) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _simpleHeader('BORDEREAU DE TRANSFERT', 'REF: ${t.reference}'),
        pw.SizedBox(height: 20),
        pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey50), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          pw.Column(children: [pw.Text('DÉPÔT SOURCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)), pw.Text(t.fromWarehouseName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
          pw.Icon(const pw.IconData(0xe5c8), size: 30, color: PdfColors.grey700),
          pw.Column(children: [pw.Text('DÉPÔT DESTINATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green900)), pw.Text(t.toWarehouseName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
        ])),
        pw.SizedBox(height: 30),
        pw.TableHelper.fromTextArray(
          headers: ['Désignation du Produit', 'Quantité Transférée'],
          data: t.items.map((item) => [item.productName.toUpperCase(), item.quantity.toString()]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [
              pw.Text('Visa Expéditeur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 40),
              pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Column(children: [
              pw.Text('Visa Transporteur', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 40),
              pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.Column(children: [
              pw.Text('Visa Réceptionnaire', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 40),
              pw.Text('........................', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ]
        ),
        pw.Spacer(),
        _developerMention(),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateAgedBalance({required String type, required List<Map<String, dynamic>> agedData}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('BALANCE AGÉE', type),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Compte', 'Intitulé', 'Solde', 'Non échu', '1 à 15j', '16 à 30j', '31 à 45j', '+ 46j'],
          data: agedData.map((d) => [
            d['code'], d['name'].toString().toUpperCase(), _currencyFormat.format(d['total']), _currencyFormat.format(d['notDue']), _currencyFormat.format(d['1-15']), _currencyFormat.format(d['16-30']), _currencyFormat.format(d['31-45']), _currencyFormat.format(d['46+']),
          ]).toList(),
        ),
        pw.Spacer(),
        _developerMention(),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // --- WIDGETS INTERNES REUTILISABLES ---
  static pw.Widget _signatureBox(String title) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Container(
          width: 160,
          height: 70,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed)),
          child: pw.Center(child: pw.Text('Signature Numérique / Cachet', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400))),
        ),
      ],
    );
  }

  static pw.Widget _developerMention() {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Développé par MLD Consulting', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
    );
  }

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
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 1), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Image(logo, width: 240)]),
        pw.SizedBox(height: 4),
        pw.Text('Electricité - Solaire - Climatisation - Ventilation - Adduction d\'eau', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.Text('Distributeur de la Marque ( FELICITY - RITAR & CAPRARI )', style: pw.TextStyle(color: PdfColors.green800, fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.Text('Tel : 76 73 76 22 / 66 73 76 22 / 50 57 01 11', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.Text('SOTUBA à coté de Station OLA - Bamako - Mali', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  static pw.Widget _buildProfessionalFooter() {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.orange, thickness: 2),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Adresse : Bamako, Bougouba Rue pasteur près station Ola', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('Phone : +223 66 73 76 22 / 70 21 16 16 / 70 21 09 09', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('Email : kosolarmali@gmail.com', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
          pw.Text('N°Compte Banque: 005001204583 - BNDA', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold)),
        ]),
        _developerMention(),
      ]),
    ]);
  }

  static Future<Uint8List> getInvoiceBytes(AppTransaction transaction) async {
    final logo = await _getLogo();
    final pdf = await _buildInvoiceDoc(transaction, logo: logo);
    return pdf.save();
  }

  // --- AUTRES METHODES RESTAUREES ---
  static Future<void> generateDailyPaymentsReport(List<Payment> payments, String type, {String? tierName, DateTime? start, DateTime? end}) async {
    final pdf = pw.Document();

    // On sépare les encaissements réels des utilisations d'avances
    final realPayments = payments.where((p) => p.method != 'Utilisation Avance').toList();
    final advanceUsages = payments.where((p) => p.method == 'Utilisation Avance').toList();

    final double totalReal = realPayments.fold(0.0, (sum, p) => sum + p.amount);
    final double totalAdvances = advanceUsages.fold(0.0, (sum, p) => sum + p.amount);

    pdf.addPage(pw.MultiPage(
      header: (context) => _simpleHeader('RÉCAPITULATIF DES RÈGLEMENTS ${type.toUpperCase()}', ''),
      build: (context) => [
        pw.Text('Encaissements Réels (Argent reçu)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 5),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Tiers', 'Mode', 'Montant'],
          data: realPayments.map((p) => [DateFormat('dd/MM/yy').format(p.date), p.tierName, p.method, _currencyFormat.format(p.amount)]).toList()
        ),
        pw.SizedBox(height: 10),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL ENCAISSÉ : ${_currencyFormat.format(totalReal)} F', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),

        if (advanceUsages.isNotEmpty) ...[
          pw.SizedBox(height: 25),
          pw.Text('Utilisations d\'Avances (Compensations)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue900)),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Tiers', 'Facture liée', 'Montant'],
            data: advanceUsages.map((p) => [DateFormat('dd/MM/yy').format(p.date), p.tierName, p.invoiceNumber ?? '', _currencyFormat.format(p.amount)]).toList()
          ),
          pw.SizedBox(height: 10),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('TOTAL COMPENSÉ : ${_currencyFormat.format(totalAdvances)} F', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900))),
        ],

        pw.Spacer(),
        _developerMention()
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateProfitReport({required DateTime start, required DateTime end, required double totalCA, required double totalCout, required double marge, required double pourcentage, required List<Map<String, dynamic>> productStats}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('ANALYSE RENTABILITE', ''), build: (context) => [
      pw.Text('CA GLOBAL : ${_currencyFormat.format(totalCA)} F'), pw.Text('MARGE : ${_currencyFormat.format(marge)} F (${pourcentage.toStringAsFixed(1)}%)'), pw.SizedBox(height: 20),
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Qte', 'CA', 'Marge'], data: productStats.map((s) => [s['name'], s['qty'].toString(), _currencyFormat.format(s['ca']), _currencyFormat.format(s['margin'])]).toList()),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateInventoryReport(List<Map<String, dynamic>> data, double totalValue) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('RAPPORT D\'INVENTAIRE VALORISE', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Produit', 'Stock', 'Valeur'], data: data.map((d) => [d['name'], d['qty'].toString(), _currencyFormat.format(d['total'])]).toList()),
      pw.SizedBox(height: 20), pw.Text('VALEUR TOTALE : ${_currencyFormat.format(totalValue)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateSalesRankingReport({
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> productStats,
    required double grandTotalCA,
  }) async {
    final pdf = pw.Document();

    // Tri par CA décroissant par défaut
    productStats.sort((a, b) => (b['ca'] as double).compareTo(a['ca'] as double));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _simpleHeader('ANALYSE STATISTIQUES ARTICLES', 'Palmarès plus fortes ventes'),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: ['Référence', 'Désignation', 'CA Net HT', 'Qtés vendues', 'Marge', '% mar sur CA', '% CA sur total'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
          cellStyle: const pw.TextStyle(fontSize: 9),
          data: productStats.map((s) {
            final double ca = s['ca'];
            final double margin = s['margin'];
            final double marginPercent = ca > 0 ? (margin / ca) * 100 : 0;
            final double caContribution = grandTotalCA > 0 ? (ca / grandTotalCA) * 100 : 0;

            return [
              s['reference'] ?? '',
              s['name'].toString().toUpperCase(),
              _currencyFormat.format(ca),
              s['qty'].toInt().toString(),
              _currencyFormat.format(margin),
              "${marginPercent.toStringAsFixed(2)}%",
              "${caContribution.toStringAsFixed(2)}%",
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Text('CHIFFRE D\'AFFAIRE GLOBAL : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('${_currencyFormat.format(grandTotalCA)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
        ]),
        pw.Spacer(),
        _developerMention(),
      ]
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateDetailedStockMovementReport({
    required List<Product> products,
    required List<AppTransaction> transactions,
    required List<StockTransfer> transfers,
    required DateTime start,
    required DateTime end,
    String? warehouseName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => _simpleHeader('MOUVEMENTS DE STOCK', 'Période du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
      build: (context) {
        List<pw.Widget> content = [];

        for (var p in products) {
          // 1. Calcul du stock initial au début de la période
          double reportStock = p.totalQuantity.toDouble(); // On commence par le stock actuel

          // On remonte le temps en inversant tous les mouvements après la date de début
          final afterStartTrans = transactions.where((t) => t.date.isAfter(start) && t.items.any((i) => i.productId == p.id));
          for (var t in afterStartTrans) {
            final item = t.items.firstWhere((i) => i.productId == p.id);
            if (t.type == TransactionType.sale || t.type == TransactionType.purchaseReturn) reportStock += item.quantity;
            else reportStock -= item.quantity;
          }

          final afterStartTrf = transfers.where((tr) => tr.date.isAfter(start) && tr.items.any((i) => i.productId == p.id));
          for (var tr in afterStartTrf) {
            final item = tr.items.firstWhere((i) => i.productId == p.id);
            if (warehouseName != null) {
              if (tr.toWarehouseName == warehouseName) reportStock -= item.quantity;
              if (tr.fromWarehouseName == warehouseName) reportStock += item.quantity;
            }
          }

          // Liste des mouvements de la période
          List<Map<String, dynamic>> movements = [];
          final periodTrans = transactions.where((t) => t.date.isAfter(start) && t.date.isBefore(end) && t.items.any((i) => i.productId == p.id));
          for (var t in periodTrans) {
            final item = t.items.firstWhere((i) => i.productId == p.id);
            movements.add({
              'date': t.date,
              'type': t.type == TransactionType.sale ? 'Fac' : 'Ach',
              'ref': t.invoiceNumber,
              'tiers': t.tierName,
              'qty': (t.type == TransactionType.sale || t.type == TransactionType.purchaseReturn ? -item.quantity : item.quantity).toDouble(),
            });
          }

          final periodTrf = transfers.where((tr) => tr.date.isAfter(start) && tr.date.isBefore(end) && tr.items.any((i) => i.productId == p.id));
          for (var tr in periodTrf) {
            final item = tr.items.firstWhere((i) => i.productId == p.id);
            double qtyChange = 0;
            if (warehouseName != null) {
              if (tr.toWarehouseName == warehouseName) qtyChange = item.quantity.toDouble();
              else if (tr.fromWarehouseName == warehouseName) qtyChange = -item.quantity.toDouble();
            }
            movements.add({
              'date': tr.date,
              'type': 'Trf',
              'ref': tr.reference,
              'tiers': '${tr.fromWarehouseName} -> ${tr.toWarehouseName}',
              'qty': qtyChange,
            });
          }

          if (movements.isEmpty && reportStock == 0) continue;

          movements.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

          // Construction du tableau pour cet article
          content.add(pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            color: PdfColors.grey200,
            child: pw.Row(children: [
              pw.Text(p.reference, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(width: 20),
              pw.Text(p.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ])
          ));

          double currentSolde = reportStock;
          List<List<String>> rows = [['${DateFormat('dd/MM/yy').format(start)}', 'Report', '', 'Stock Initial', '', currentSolde.toInt().toString()]];

          for (var m in movements) {
            currentSolde += m['qty'];
            rows.add([
              DateFormat('dd/MM/yy').format(m['date']),
              m['type'],
              m['ref'],
              m['tiers'],
              m['qty'].toString(),
              currentSolde.toInt().toString(),
            ]);
          }

          content.add(pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Pièce', 'Référence / Tiers', '+/-', 'Solde'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {0: const pw.FixedColumnWidth(50), 1: const pw.FixedColumnWidth(30), 2: const pw.FixedColumnWidth(70), 3: const pw.FlexColumnWidth(2), 4: const pw.FixedColumnWidth(40), 5: const pw.FixedColumnWidth(40)},
            data: rows,
          ));
          content.add(pw.SizedBox(height: 15));
        }
        return content;
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Mouvements_Stock.pdf');
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
            _developerMention(),
          ],
        ),
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTruckReport(Truck truck, List<Trip> trips) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('RAPPORT CAMION', truck.plateNumber), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Trajet', 'Résultat'], data: trips.map((t) => [DateFormat('dd/MM/yy').format(t.departureDate), t.mainAxis, _currencyFormat.format(t.netProfit)]).toList()),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateTransferReport(List<StockTransfer> transfers) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('HISTORIQUE TRANSFERTS', ''), build: (context) => [
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Réf', 'Article', 'Qte'],
        data: transfers.expand((t) => t.items.map((item) => [
          DateFormat('dd/MM/yy').format(t.date),
          t.reference,
          item.productName.toUpperCase(),
          item.quantity.toString()
        ])).toList(),
      ),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateCashControlReport({required DateTime start, required DateTime end, required double initialBalance, required List<JournalEntry> entries}) async {
    final pdf = pw.Document();
    double runningBalance = initialBalance;
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('CONTROLE DE CAISSE', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['Date', 'Libellé', 'Recettes', 'Dépenses', 'Solde'], data: [['', 'SOLDE INITIAL', '', '', _currencyFormat.format(initialBalance)], ...entries.map((e) { runningBalance += (e.debit - e.credit); return [DateFormat('dd/MM').format(e.date), e.label.toUpperCase(), e.debit > 0 ? _currencyFormat.format(e.debit) : '', e.credit > 0 ? _currencyFormat.format(e.credit) : '', _currencyFormat.format(runningBalance)]; })]),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generateDailyDeliveryReport(List<AppTransaction> txs) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(header: (context) => _simpleHeader('ETAT DES LIVRAISONS', ''), build: (context) => [
      pw.TableHelper.fromTextArray(headers: ['BL', 'Client', 'Status'], data: txs.map((t) => [t.invoiceNumber, t.tierName, t.deliveryStatus]).toList()),
      pw.Spacer(), _developerMention()
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
