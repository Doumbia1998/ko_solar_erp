import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../models/payment.dart';

class UnpaidReminderScreen extends StatefulWidget {
  const UnpaidReminderScreen({super.key});

  @override
  State<UnpaidReminderScreen> createState() => _UnpaidReminderScreenState();
}

class _UnpaidReminderScreenState extends State<UnpaidReminderScreen> {
  final NumberFormat _currency = NumberFormat('#,###', 'fr_FR');
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RELANCE DES IMPAYÉS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des paiements',
            onPressed: () => _showHonoredMaturities(context, service),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un client ou une facture...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade900)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppTransaction>>(
              stream: service.getTransactions(type: TransactionType.sale),
              builder: (context, snapshotTx) {
                return StreamBuilder<List<Payment>>(
                  stream: service.getPayments(),
                  builder: (context, snapshotPay) {
                    if (!snapshotTx.hasData || !snapshotPay.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTxs = snapshotTx.data!;
                    final allPays = snapshotPay.data!;

                    // Logique de filtrage en temps réel
                    var pendingMaturities = <Map<String, dynamic>>[];

                    for (var t in allTxs) {
                      if (t.dueDate == null) continue;

                      if (_searchQuery.isNotEmpty) {
                        if (!t.tierName.toLowerCase().contains(_searchQuery) &&
                            !t.invoiceNumber.toLowerCase().contains(_searchQuery)) {
                          continue;
                        }
                      }

                      // Calcul du reste à payer réel
                      double paidForThis = allPays
                          .where((p) => p.invoiceNumber == t.invoiceNumber || (p.reference.toUpperCase().contains(t.invoiceNumber.toUpperCase())))
                          .fold(0.0, (sum, p) => sum + p.amount);

                      bool acompteInPay = allPays.any((p) => p.invoiceNumber == t.invoiceNumber && p.reference.contains('Acompte'));
                      if (!acompteInPay) paidForThis += t.amountPaid;

                      double reste = t.netToPay - paidForThis;

                      if (reste > 50) {
                        pendingMaturities.add({
                          'transaction': t,
                          'remaining': reste,
                        });
                      }
                    }

                    if (pendingMaturities.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 60, color: Colors.green),
                            SizedBox(height: 10),
                            Text('Aucune échéance trouvée.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }

                    pendingMaturities.sort((a, b) => (a['transaction'] as AppTransaction).dueDate!.compareTo((b['transaction'] as AppTransaction).dueDate!));

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: pendingMaturities.length,
                      itemBuilder: (context, index) {
                        final d = pendingMaturities[index];
                        final AppTransaction t = d['transaction'] as AppTransaction;
                        final double reste = d['remaining'] as double;

                        final now = DateTime.now();
                        final diff = t.dueDate!.difference(now).inDays;
                        Color alertColor = Colors.green;
                        IconData alertIcon = Icons.timer;

                        if (diff < 0) {
                          alertColor = Colors.red;
                          alertIcon = Icons.dangerous;
                        } else if (diff <= 2) {
                          alertColor = Colors.orange;
                          alertIcon = Icons.warning_amber_rounded;
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: alertColor.withOpacity(0.1), shape: BoxShape.circle),
                              child: Icon(alertIcon, color: alertColor, size: 28),
                            ),
                            title: Text(t.tierName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Facture : ${t.invoiceNumber}', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                Text('Échéance : ${DateFormat('dd/MM/yyyy').format(t.dueDate!)}',
                                  style: TextStyle(color: alertColor, fontWeight: FontWeight.bold)),
                                Text('SOLDE RESTANT : ${_currency.format(reste).replaceAll(',', ' ')} F',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _sendReminder(t, reste),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('RELANCER'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _sendReminder(AppTransaction t, double reste) async {
    final service = Provider.of<FirestoreService>(context, listen: false);
    final tiers = await service.getTiers(TierType.client).first;
    final client = tiers.firstWhere((c) => c.id == t.tierId, orElse: () => Tier(id: '', name: t.tierName, type: TierType.client, phone: '', address: '', compteGeneral: '', compteTiers: ''));

    if (client.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le client n\'a pas de numéro de téléphone enregistré.')));
      return;
    }

    String cleanPhone = client.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 8) cleanPhone = '223$cleanPhone';

    String message = "📢 *RELANCE PAIEMENT KO SOLAR*\n\n"
        "Cher client *${t.tierName.toUpperCase()}*,\n"
        "Sauf erreur de notre part, votre facture *${t.invoiceNumber}* dont l'échéance était le *${DateFormat('dd/MM/yy').format(t.dueDate!)}* n'a pas encore été totalement soldée.\n\n"
        "🔹 Montant restant : *${_currency.format(reste).replaceAll(',', ' ')} FCFA*\n\n"
        "Nous vous prions de bien vouloir régulariser cette situation rapidement.\n"
        "Merci de votre confiance !\n*L'équipe KO SOLAR*";

    final url = "https://wa.me/$cleanPhone?text=${Uri.encodeFull(message)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _showHonoredMaturities(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rapport : Échéances Honorées', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 800,
          height: 500,
          child: StreamBuilder<List<AppTransaction>>(
            stream: service.getTransactions(type: TransactionType.sale),
            builder: (context, snapshotTx) {
              return StreamBuilder<List<Payment>>(
                stream: service.getPayments(),
                builder: (context, snapshotPay) {
                  if (!snapshotTx.hasData || !snapshotPay.hasData) return const Center(child: CircularProgressIndicator());

                  final allTxs = snapshotTx.data!;
                  final allPays = snapshotPay.data!;

                  List<Map<String, dynamic>> honored = [];
                  for (var t in allTxs) {
                    if (t.dueDate == null) continue;

                    final pays = allPays.where((p) => p.invoiceNumber == t.invoiceNumber || p.reference.contains(t.invoiceNumber)).toList();
                    double totalPaid = pays.fold(0.0, (sum, p) => sum + p.amount);

                    bool acompteInPay = allPays.any((p) => p.invoiceNumber == t.invoiceNumber && p.reference.contains('Acompte'));
                    if (!acompteInPay) totalPaid += t.amountPaid;

                    if (totalPaid >= t.netToPay - 100) {
                      final List<Payment> sortedPays = List<Payment>.from(pays);
                      sortedPays.sort((a, b) => b.date.compareTo(a.date));
                      honored.add({'tx': t, 'payDate': sortedPays.isNotEmpty ? sortedPays.first.date : t.date});
                    }
                  }

                  if (honored.isEmpty) return const Center(child: Text('Aucune échéance honorée pour le moment.'));

                  return ListView.builder(
                    itemCount: honored.length,
                    itemBuilder: (context, index) {
                      final h = honored[index];
                      final AppTransaction t = h['tx'] as AppTransaction;
                      final DateTime pDate = h['payDate'] as DateTime;
                      bool late = pDate.isAfter(t.dueDate!);

                      return ListTile(
                        leading: Icon(Icons.verified, color: late ? Colors.orange : Colors.green),
                        title: Text(t.tierName.toUpperCase()),
                        subtitle: Text('Facture : ${t.invoiceNumber}\nÉchéance : ${DateFormat('dd/MM/yy').format(t.dueDate!)}\nPayé le : ${DateFormat('dd/MM/yy').format(pDate)}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: late ? Colors.orange : Colors.green, borderRadius: BorderRadius.circular(4)),
                          child: Text(late ? 'TARDIF' : 'À TEMPS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER'))],
      ),
    );
  }
}
