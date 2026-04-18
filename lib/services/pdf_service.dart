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

  static Future<void> generateInvoice(AppTransaction transaction) async {
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
                      pw.Text('N° Facture: ${transaction.invoiceNumber}'),
                      pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}'),
                    ],
                  ),
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all()),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Client: ${transaction.tierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('ID: ${transaction.tierId}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text('FACTURE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Désignation', 'Qté', 'Px unitaire', 'Remise', 'Total Net'],
                data: transaction.items.map((item) => [
                  item.productName,
                  item.quantity.toString(),
                  _currencyFormat.format(item.unitPrice),
                  _currencyFormat.format(item.discount),
                  _currencyFormat.format((item.quantity * item.unitPrice) - item.discount),
                ]).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Articles (Net): ${_currencyFormat.format(transaction.totalHT)} FCFA'),
                    if (transaction.transportFees > 0)
                      pw.Text('Frais de Transport: ${transaction.addTransport ? "+" : "-"} ${_currencyFormat.format(transaction.transportFees)} FCFA'),
                    pw.SizedBox(width: 200, child: pw.Divider()),
                    pw.Text('NET À PAYER: ${_currencyFormat.format(transaction.netToPay)} FCFA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 5),
                    pw.Text('Arrêté la présente facture à la somme de :', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                    pw.Text(NumberToWords.convertToFr(transaction.netToPay), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(height: 10),
                    pw.Text('Acompte versé: ${_currencyFormat.format(transaction.amountPaid)} FCFA'),
                    pw.Text('Reste à payer: ${_currencyFormat.format(transaction.balance)} FCFA', style: pw.TextStyle(color: transaction.balance > 0 ? PdfColors.red900 : PdfColors.green900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Pour acquit'),
                  pw.Text('Le Fournisseur'),
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
