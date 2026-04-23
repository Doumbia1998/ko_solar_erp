import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/transport.dart';
import '../models/stock_transfer.dart';
import '../models/journal_entry.dart';
import '../models/payment.dart';
import '../utils/number_to_words.dart';

class PdfService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  static Future<void> generateInvoice(AppTransaction transaction, {List<Payment>? allTierPayments, List<AppTransaction>? allTierTransactions}) async {
    final pdf = pw.Document();

    // --- LOGIQUE DE CALCUL DU SOLDE RÉEL ---
    double currentBalance = transaction.netToPay;
    double totalPaidForThisInvoice = 0;

    if (allTierPayments != null && allTierTransactions != null) {
      // 1. Calculer le crédit total du tiers (Acomptes + Règlements)
      double totalCredit = allTierPayments.fold(0.0, (sum, p) => sum + p.amount);
      
      // Ajouter les acomptes des transactions (si pas déjà dans payments)
      for (var t in allTierTransactions) {
        if (t.amountPaid > 0) {
          bool acompteInPay = allTierPayments.any((p) => 
            p.invoiceNumber == t.invoiceNumber || (p.reference.toUpperCase().contains(t.invoiceNumber.toUpperCase()))
          );
          if (!acompteInPay) totalCredit += t.amountPaid;
        }
      }

      // 2. Distribuer le crédit sur les factures par ordre chronologique
      final sortedTxs = List<AppTransaction>.from(allTierTransactions);
      sortedTxs.sort((a, b) => a.date.compareTo(b.date));

      double remainingCredit = totalCredit;
      for (var t in sortedTxs) {
        double amountToApply = remainingCredit >= t.netToPay ? t.netToPay : remainingCredit;
        if (t.id == transaction.id) {
          totalPaidForThisInvoice = amountToApply;
          currentBalance = t.netToPay - amountToApply;
          break;
        }
        remainingCredit -= amountToApply;
        if (remainingCredit <= 0) break;
      }
    } else {
      // Fallback si on n'a pas tout l'historique
      totalPaidForThisInvoice = transaction.amountPaid;
      currentBalance = transaction.netToPay - totalPaidForThisInvoice;
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SSF', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Column(
                      children: [
                        pw.Text('SOCIETE SANOGO & FRERE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Commerçant Import - Export - Transport'),
                        pw.Text('Tel: 67 63 64 47 / 70 12 68 14'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('N° Facture: ${transaction.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
                      if (transaction.destination.isNotEmpty)
                        pw.Text('Destination: ${transaction.destination}', style: pw.TextStyle(color: PdfColors.blueGrey700, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${transaction.type == TransactionType.sale ? "Client" : "Fournisseur"}: ${transaction.tierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('ID: ${transaction.tierId}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text(transaction.type == TransactionType.sale ? 'FACTURE DE VENTE' : 'FACTURE D\'ACHAT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Désignation', 'Qté', 'Px unitaire', 'Remise', 'Total Net'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                data: transaction.items.map((item) => [
                  item.productName,
                  item.quantity.toString(),
                  _currencyFormat.format(item.unitPrice),
                  _currencyFormat.format(item.discount),
                  _currencyFormat.format((item.quantity * item.unitPrice) - item.discount),
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: (allTierPayments != null && allTierPayments.any((p) => p.invoiceNumber == transaction.invoiceNumber)) 
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Historique des Règlements :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.SizedBox(height: 5),
                            ...allTierPayments.where((p) => p.invoiceNumber == transaction.invoiceNumber).map((p) => 
                              pw.Text('- ${DateFormat('dd/MM/yy').format(p.date)} (${p.method}): ${_currencyFormat.format(p.amount)} F', style: const pw.TextStyle(fontSize: 9))
                            ),
                          ],
                        )
                      : pw.SizedBox(),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Articles (Net): ${_currencyFormat.format(transaction.totalHT)} FCFA'),
                        if (transaction.transportFees > 0)
                          pw.Text('Frais de Transport: ${transaction.addTransport ? "+" : "-"} ${_currencyFormat.format(transaction.transportFees)} FCFA'),
                        pw.SizedBox(width: 200, child: pw.Divider()),
                        pw.Text('NET À PAYER: ${_currencyFormat.format(transaction.netToPay)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.SizedBox(height: 5),
                        pw.Text('Total Déjà Réglé: ${_currencyFormat.format(totalPaidForThisInvoice)} FCFA'),
                        pw.Text('SOLDE À RÉGLER: ${_currencyFormat.format(currentBalance)} FCFA', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: currentBalance > 0 ? PdfColors.red900 : PdfColors.green900, fontSize: 12)),
                        pw.SizedBox(height: 10),
                        pw.Text('Arrêté la présente facture à la somme de :', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8)),
                        pw.Text(NumberToWords.convertToFr(transaction.netToPay), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Signature Client / Fournisseur', style: const pw.TextStyle(fontSize: 10, decoration: pw.TextDecoration.underline)),
                  pw.Text('Pour la Direction (Cachet & Signature)', style: const pw.TextStyle(fontSize: 10, decoration: pw.TextDecoration.underline)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateTruckReport(Truck truck, List<Trip> trips) async {
    final pdf = pw.Document();
    double totalRevenue = trips.fold(0, (sum, t) => sum + t.totalRevenue);
    double totalExpenses = trips.fold(0, (sum, t) => sum + t.totalExpenses);
    double totalBenefice = totalRevenue - totalExpenses;

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Rapport de Camion : ${truck.registrationNumber}'),
              pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
            ]
          )),
          pw.Text('Chauffeur : ${truck.driverName}'),
          pw.Text('Téléphone : ${truck.driverPhone}'),
          pw.SizedBox(height: 20),
          
          pw.Text('DÉTAIL DES VOYAGES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Destination', 'Revenus', 'Dépenses', 'Bénéfice'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.center,
            data: trips.map((t) => [
              DateFormat('dd/MM/yyyy').format(t.date),
              t.destination,
              _currencyFormat.format(t.totalRevenue),
              _currencyFormat.format(t.totalExpenses),
              _currencyFormat.format(t.netProfit),
            ]).toList(),
          ),
          
          pw.SizedBox(height: 30),
          pw.Text('DÉTAIL DES DÉPENSES PAR COMPTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Divider(),
          pw.TableHelper.fromTextArray(
            headers: ['Libellé', 'Compte', 'Montant'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: trips.expand((t) => t.expenses).map((e) => [
              e.label,
              e.compteComptable,
              _currencyFormat.format(e.amount),
            ]).toList(),
          ),

          pw.SizedBox(height: 30),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
            child: pw.Column(
              children: [
                _buildPdfRow('TOTAL REVENUS', _currencyFormat.format(totalRevenue)),
                _buildPdfRow('TOTAL DÉPENSES', '- ${_currencyFormat.format(totalExpenses)}'),
                pw.Divider(),
                _buildPdfRow('BÉNÉFICE NET GLOBAL', '${_currencyFormat.format(totalBenefice)} FCFA', isBold: true),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateTransferReport(List<StockTransfer> transfers) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SSF - HISTORIQUE DES TRANSFERTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue900)),
                  pw.Text('SOCIETE SANOGO & FRERE', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
            ]
          )),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Article', 'Source (De)', 'Destination (Vers)', 'Quantité'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            data: transfers.map((t) => [
              DateFormat('dd/MM/yyyy HH:mm').format(t.date),
              t.productName,
              t.fromWarehouseName,
              t.toWarehouseName,
              t.quantity.toString(),
            ]).toList(),
          ),
          pw.Footer(
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())),
            trailing: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Transferts_Stock_${DateFormat('ddMMyy').format(DateTime.now())}.pdf'
    );
  }

  static Future<void> generateDeliveryNote(AppTransaction transaction) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SSF', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Column(
                      children: [
                        pw.Text('SOCIETE SANOGO & FRERE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Bon de Livraison - Détail Dépôt'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('N° BL: BL-${transaction.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
                      pw.Text('Dépôt Source: ${transaction.warehouseId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                    ],
                  ),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Text('Destinataire: ${transaction.tierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text('BON DE LIVRAISON', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Désignation', 'Qté Commandée', 'Qté Livrée', 'Observation'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                data: transaction.items.map((item) => [
                  item.productName,
                  item.quantity.toString(),
                  item.quantity.toString(),
                  '',
                ]).toList(),
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Le Livreur', style: pw.TextStyle(decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 40),
                      pw.Text('........................'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Réceptionnaire', style: pw.TextStyle(decoration: pw.TextDecoration.underline)),
                      pw.SizedBox(height: 40),
                      pw.Text('........................'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 50),
              pw.Center(
                child: pw.Text(
                  'Marchandise livrée en bon état et conforme à la commande.',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'BL_${transaction.invoiceNumber}.pdf');
  }

  static Future<void> generateUnpaidReport({
    required String type,
    required DateTime start,
    required DateTime end,
    required List<Map<String, dynamic>> unpaidDetails,
  }) async {
    final pdf = pw.Document();
    final double totalUnpaid = unpaidDetails.fold(0, (sum, d) => sum + (d['remaining'] as double));

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - ÉTAT DÉTAILLÉ DES IMPAYÉS ${type.toUpperCase()}S', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.red900)),
                pw.Text('Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'N° Facture', 'Nom', 'Total Net', 'Déjà Payé', 'Reste à Payer'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
            cellAlignment: pw.Alignment.center,
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
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
              child: pw.Text('TOTAL GÉNÉRAL À RECOUVRER : ${_currencyFormat.format(totalUnpaid)} FCFA', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red900)),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Impayes_Detailles_${type}_${DateFormat('ddMMyy').format(DateTime.now())}.pdf');
  }

  static Future<void> generateTrialBalance(List<JournalEntry> entries) async {
    final pdf = pw.Document();
    
    // Calculer les soldes par compte
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('BALANCE DES COMPTES (SYSCOHADA)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Compte', 'Libellé', 'Total Débit', 'Total Crédit', 'Solde'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            data: balances.keys.map((code) {
              double d = balances[code]!['debit'];
              double c = balances[code]!['credit'];
              double solde = d - c;
              return [
                code,
                balances[code]!['label'],
                _currencyFormat.format(d),
                _currencyFormat.format(c),
                _currencyFormat.format(solde.abs()) + (solde >= 0 ? ' (D)' : ' (C)'),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAgedBalance(List<JournalEntry> entries) async {
    final pdf = pw.Document();
    // Simulation Balance Agée simplifiée (Etat des créances)
    var clientEntries = entries.where((e) => e.accountCode.startsWith('411')).toList();

    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('ÉTAT GLOBAL DES CRÉANCES CLIENTS')),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Client / Référence', 'Date', 'Montant Initial', 'Reste à recouvrir'],
            data: clientEntries.map((e) => [
              e.label,
              DateFormat('dd/MM/yy').format(e.date),
              _currencyFormat.format(e.debit > 0 ? e.debit : e.credit),
              _currencyFormat.format(e.debit - e.credit),
            ]).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generatePaymentReport(List<Payment> payments, DateTime? start, DateTime? end) async {
    final pdf = pw.Document();
    double total = payments.fold(0, (sum, p) => sum + p.amount);
    String period = (start != null && end != null) 
        ? "Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}"
        : "Le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - RAPPORT DE RÈGLEMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
                pw.Text(period, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Tiers', 'Type', 'Mode', 'Référence', 'Montant'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            data: payments.map((p) => [
              DateFormat('dd/MM/yy').format(p.date),
              p.tierName.toUpperCase(),
              p.tierType.toString().split('.').last == 'client' ? 'CLIENT' : 'FOURN.',
              p.method,
              p.reference,
              _currencyFormat.format(p.amount),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
              child: pw.Text('TOTAL GÉNÉRAL : ${_currencyFormat.format(total)} FCFA', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Reglements_${DateFormat('ddMMyy').format(DateTime.now())}.pdf'
    );
  }

  static Future<void> generatePaymentReceipt(Payment payment) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        orientation: pw.PageOrientation.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('REÇU DE PAIEMENT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° ${payment.id.substring(0, 8).toUpperCase()}'),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text('Reçu de : ${payment.tierName.toUpperCase()}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('La somme de :'),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(5),
                  color: PdfColors.grey200,
                  child: pw.Text(NumberToWords.convertToFr(payment.amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text('Motif : ${payment.reference}')),
                    pw.Text('Mode : ${payment.method}'),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(payment.date)}'),
                        pw.SizedBox(height: 5),
                        pw.Text('Montant : ${_currencyFormat.format(payment.amount)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('Signature & Cachet'),
                        pw.SizedBox(height: 40),
                        pw.Text('SOCIETE SANOGO & FRERE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Recu_${payment.tierName}_${DateFormat('ddMMyy').format(payment.date)}.pdf'
    );
  }

  static Future<void> generateInventoryReport(List<Map<String, dynamic>> data, double totalValue) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - RAPPORT D\'INVENTAIRE VALORISÉ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue900)),
                pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Produit', 'Quantité', 'Prix Achat', 'Valeur Totale'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            data: data.map((d) => [
              d['name'],
              d['qty'].toString(),
              _currencyFormat.format(d['price']),
              _currencyFormat.format(d['total']),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.blue50),
              child: pw.Text('VALEUR TOTALE DU STOCK : ${_currencyFormat.format(totalValue)} FCFA', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Inventaire_${DateFormat('ddMMyy').format(DateTime.now())}.pdf');
  }

  static Future<void> generateStockMovementReport(List<Map<String, dynamic>> movements, DateTime start, DateTime end) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - MOUVEMENTS DE STOCK', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.orange900)),
                pw.Text('Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Produit', 'Type', 'Tiers / Trajet', 'Qté'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FixedColumnWidth(80),  // Date
              1: const pw.FlexColumnWidth(3),   // Produit (plus large)
              2: const pw.FixedColumnWidth(60),  // Type
              3: const pw.FlexColumnWidth(3),   // Tiers
              4: const pw.FixedColumnWidth(40),  // Qté (ajustée)
            },
            data: movements.map((m) => [
              DateFormat('dd/MM HH:mm').format(m['date']),
              m['product'],
              m['type'],
              m['tier'],
              m['qty'].toString(),
            ]).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Mouvements_Stock_${DateFormat('ddMMyy').format(DateTime.now())}.pdf');
  }

  static Future<void> generateGlobalTransactionReport({
    required String type,
    required DateTime start,
    required DateTime end,
    required List<AppTransaction> transactions,
  }) async {
    final pdf = pw.Document();
    final double total = transactions.fold(0, (sum, t) => sum + t.netToPay);

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - RÉCAPITULATIF DES ${type.toUpperCase()}S', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: type == 'Vente' ? PdfColors.blue900 : PdfColors.teal900)),
                pw.Text('Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'N° Facture', 'Client / Fournisseur', 'Total Net'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: type == 'Vente' ? PdfColors.blue900 : PdfColors.teal900),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FixedColumnWidth(70),
              1: const pw.FixedColumnWidth(90),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(80),
            },
            data: transactions.map((t) => [
              DateFormat('dd/MM/yy').format(t.date),
              t.invoiceNumber,
              t.tierName,
              _currencyFormat.format(t.netToPay),
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(), color: PdfColors.grey100),
              child: pw.Text('TOTAL GÉNÉRAL DES ${type.toUpperCase()}S : ${_currencyFormat.format(total)} FCFA', 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Recap_${type}_${DateFormat('ddMMyy').format(DateTime.now())}.pdf');
  }

  static Future<void> generateProfitReport({
    required DateTime start,
    required DateTime end,
    required double totalCA,
    required double totalCout,
    required double marge,
    required double pourcentage,
    required List<Map<String, dynamic>> productStats,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('SSF - ANALYSE DE RENTABILITÉ DÉTAILLÉE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Du ${DateFormat('dd/MM/yy').format(start)} au ${DateFormat('dd/MM/yy').format(end)}'),
              ],
            ),
            pw.Divider(),
          ],
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          pw.Text('RÉCAPITULATIF FINANCIER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 5),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
              children: [
                _buildPdfRow('CHIFFRE D\'AFFAIRES TOTAL', _currencyFormat.format(totalCA) + ' F'),
                _buildPdfRow('COÛT DE REVIENT TOTAL', _currencyFormat.format(totalCout) + ' F'),
                pw.Divider(),
                _buildPdfRow('MARGE BRUTE GLOBALE', _currencyFormat.format(marge) + ' F', isBold: true),
                _buildPdfRow('TAUX DE RENTABILITÉ', pourcentage.toStringAsFixed(1) + '%', isBold: true),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('DÉTAIL PAR PRODUIT (MARGE SUR VENTES)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Produit', 'Qté Vendue', 'CA', 'Coût', 'Marge'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellAlignment: pw.Alignment.center,
            data: productStats.map((s) => [
              s['name'],
              s['qty'].toString(),
              _currencyFormat.format(s['ca']),
              _currencyFormat.format(s['cost']),
              _currencyFormat.format(s['margin']),
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Text('Signature & Cachet Direction', style: pw.TextStyle(decoration: pw.TextDecoration.underline, fontSize: 10)),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Rapport_Marge_Detaille.pdf');
  }

  static pw.Widget _buildPdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null)),
        ],
      ),
    );
  }
}
