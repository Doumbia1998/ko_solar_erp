import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/payment.dart';
import '../services/firestore_service.dart';
import 'tier_form_screen.dart';
import 'tier_detail_screen.dart';

class TierListScreen extends StatefulWidget {
  final TierType type;
  final bool isSelectionMode;

  const TierListScreen({super.key, required this.type, this.isSelectionMode = false});

  @override
  State<TierListScreen> createState() => _TierListScreenState();
}

class _TierListScreenState extends State<TierListScreen> {
  String _searchQuery = "";
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'fr_FR');

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final isClient = widget.type == TierType.client;
    final title = isClient ? 'Clients' : 'Fournisseurs';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<AppTransaction>>(
        stream: firestoreService.getTransactions(),
        builder: (context, snapshotTrans) {
          return StreamBuilder<List<Payment>>(
            stream: firestoreService.getPayments(),
            builder: (context, snapshotPay) {
              return StreamBuilder<List<Tier>>(
                stream: firestoreService.getTiers(widget.type),
                builder: (context, snapshotTiers) {
                  if (snapshotTiers.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final transactions = snapshotTrans.data ?? [];
                  final payments = snapshotPay.data ?? [];
                  final allTiers = snapshotTiers.data ?? [];

                  // Filtrer les transactions par type (Vente pour Client, Achat pour Fournisseur)
                  final relevantTrans = transactions.where((t) => isClient ? t.type == TransactionType.sale : t.type == TransactionType.purchase).toList();
                  
                  double totalGlobalHT = relevantTrans.fold(0.0, (sum, t) => sum + t.totalHT);
                  double totalPaidInitial = relevantTrans.fold(0.0, (sum, t) => sum + t.amountPaid);
                  double totalReglements = payments.where((p) => p.tierType == widget.type).fold(0.0, (sum, p) => sum + p.amount);
                  
                  double totalPayeGlobal = totalPaidInitial + totalReglements;
                  double totalImpayesGlobal = totalGlobalHT - totalPayeGlobal;

                  var displayedTiers = allTiers;
                  if (_searchQuery.isNotEmpty) {
                    displayedTiers = allTiers.where((t) => t.name.toLowerCase().contains(_searchQuery)).toList();
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Rechercher un ${isClient ? "client" : "fournisseur"}...',
                            prefixIcon: const Icon(Icons.search),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBannerRow(isClient ? 'TOTAL VENTES GLOBAL' : 'TOTAL ACHATS GLOBAL', '${_currencyFormat.format(totalGlobalHT)} FCFA'),
                            const SizedBox(height: 5),
                            _buildBannerRow('TOTAL IMPAYÉS GLOBAL', '${_currencyFormat.format(totalImpayesGlobal < 0 ? 0 : totalImpayesGlobal)} FCFA', valueColor: Colors.orange),
                          ],
                        ),
                      ),
                      Expanded(
                        child: displayedTiers.isEmpty 
                          ? const Center(child: Text('Aucun résultat trouvé'))
                          : ListView.builder(
                              itemCount: displayedTiers.length,
                              itemBuilder: (context, index) {
                                final tier = displayedTiers[index];
                                return ListTile(
                                  leading: const Icon(Icons.person, color: Color(0xFF1A237E)),
                                  title: Text(tier.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(tier.phone.isEmpty ? 'Pas de numéro' : tier.phone),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TierFormScreen(type: widget.type, tier: tier))),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _handleDeleteTier(context, firestoreService, tier, transactions, payments),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (widget.isSelectionMode) {
                                      Navigator.pop(context, tier);
                                    } else {
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => TierDetailScreen(tier: tier)));
                                    }
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  );
                }
              );
            }
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TierFormScreen(type: widget.type))),
        backgroundColor: const Color(0xFFE3F2FD),
        child: const Icon(Icons.add, color: Color(0xFF1A237E)),
      ),
    );
  }

  Widget _buildBannerRow(String label, String value, {Color valueColor = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _handleDeleteTier(BuildContext context, FirestoreService service, Tier tier, List<AppTransaction> transactions, List<Payment> payments) {
    // Vérifier si le tiers a des transactions
    final hasTransactions = transactions.any((t) => t.tierId == tier.id);
    final hasPayments = payments.any((p) => p.tierId == tier.id);

    if (hasTransactions || hasPayments) {
      String reference = "";
      if (hasTransactions) {
        reference = "la Facture N°${transactions.firstWhere((t) => t.tierId == tier.id).invoiceNumber}";
      } else {
        reference = "un Règlement du ${DateFormat('dd/MM/yyyy').format(payments.firstWhere((p) => p.tierId == tier.id).date)}";
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Suppression impossible", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text("Le compte tiers '${tier.name}' est référencé dans $reference.\n\nVous ne pouvez pas supprimer ce tiers tant que ses documents liés existent."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } else {
      _confirmDelete(context, () => service.deleteTier(tier.id));
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Voulez-vous supprimer ce tiers ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Non")),
          TextButton(onPressed: () { onDelete(); Navigator.pop(context); }, child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
