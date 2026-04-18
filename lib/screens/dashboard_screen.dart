import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/dashboard_card.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../models/transport.dart';
import '../models/payment.dart';
import 'transaction_list_screen.dart';
import 'transport_screen.dart';
import '../models/app_user.dart';
import 'tier_list_screen.dart';
import 'stock_screen.dart';
import 'warehouse_list_screen.dart';
import 'payment_screen.dart';
import 'account_list_screen.dart';
import 'journal_screen.dart';
import 'user_management_screen.dart';
import 'statistics_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // On utilise le Provider directement pour avoir l'utilisateur en temps réel
    final currentUser = Provider.of<AppUser?>(context);
    
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = currentUser.role == UserRole.admin;
    
    // Permissions avec "Passe-partout" Admin
    final canViewPurchases = isAdmin || currentUser.canViewPurchases;
    final canViewSales = isAdmin || currentUser.canViewSales;
    final canViewTransport = isAdmin || currentUser.canViewTransport;
    final canViewAccounting = isAdmin || currentUser.canViewAccounting;
    final canViewTiers = isAdmin || currentUser.canViewTiers;
    final canManageUsers = isAdmin || currentUser.canManageUsers;

    final List<Widget> pages = [
      const DashboardContent(),
      const TransactionListScreen(type: TransactionType.purchase),
      const TransactionListScreen(type: TransactionType.sale),
      const TransportScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentUser.displayName.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const Text('SSF ERP VENTES & TRANSPORT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A237E)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SSF GESTION', style: TextStyle(color: Colors.white, fontSize: 24)),
                  Text(currentUser.role.toString().split('.').last.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerTile(context, Icons.inventory, 'Stocks', Colors.blueGrey, const StockScreen()),
            _buildDrawerTile(context, Icons.warehouse, 'Gestion des Dépôts', Colors.brown, const WarehouseListScreen()),
            _buildDrawerTile(context, Icons.payments, 'Règlements', Colors.green, const PaymentScreen()),
            const Divider(),
            if (canViewTiers) ...[
              _buildDrawerTile(context, Icons.people, 'Clients', Colors.indigo, const TierListScreen(type: TierType.client)),
              _buildDrawerTile(context, Icons.business_center, 'Fournisseurs', Colors.teal, const TierListScreen(type: TierType.supplier)),
            ],
            if (canViewAccounting) ...[
              const Divider(),
              _buildDrawerTile(context, Icons.account_balance, 'Plan Comptable', Colors.indigo, const AccountListScreen()),
              _buildDrawerTile(context, Icons.menu_book, 'Journal Comptable', Colors.brown, const JournalScreen()),
            ],
            if (canManageUsers) ...[
              const Divider(),
              _buildDrawerTile(context, Icons.analytics, 'Statistiques & Marges', Colors.orange, const StatisticsScreen()),
              _buildDrawerTile(context, Icons.admin_panel_settings, 'Gestion Utilisateurs', Colors.red, const UserManagementScreen()),
            ],
          ],
        ),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A237E),
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Accueil'),
          if (canViewPurchases) const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Achats'),
          if (canViewSales) const BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Ventes'),
          if (canViewTransport) const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Transport'),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(BuildContext context, IconData icon, String title, Color color, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
      },
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);
    final currencyFormat = NumberFormat('#,###', 'fr_FR');

    if (currentUser == null) return const SizedBox.shrink();
    
    final isAdmin = currentUser.role == UserRole.admin;
    final canViewSales = isAdmin || currentUser.canViewSales;
    final canViewPurchases = isAdmin || currentUser.canViewPurchases;
    final canViewTransport = isAdmin || currentUser.canViewTransport;

    return StreamBuilder<List<AppTransaction>>(
      stream: firestoreService.getTransactions(),
      builder: (context, snapshotTrans) {
        return StreamBuilder<List<Trip>>(
          stream: firestoreService.getTrips(),
          builder: (context, snapshotTrips) {
            return StreamBuilder<List<Payment>>(
              stream: firestoreService.getPayments(),
              builder: (context, snapshotPay) {
                final transactions = snapshotTrans.data ?? [];
                final trips = snapshotTrips.data ?? [];
                final payments = snapshotPay.data ?? [];

                // --- CALCULS CLIENTS (VENTES) ---
                final sales = transactions.where((t) => t.type == TransactionType.sale).toList();
                double caSales = sales.fold(0.0, (sum, t) => sum + t.netToPay);
                double paidInitialSales = sales.fold(0.0, (sum, t) => sum + t.amountPaid);
                double reglementsSales = payments.where((p) => p.tierType == TierType.client).fold(0.0, (sum, p) => sum + p.amount);
                double totalEncaisseSales = paidInitialSales + reglementsSales;
                double totalImpayesSales = caSales - totalEncaisseSales;

                // --- CALCULS FOURNISSEURS (ACHATS) ---
                final purchases = transactions.where((t) => t.type == TransactionType.purchase).toList();
                double caPurchases = purchases.fold(0.0, (sum, t) => sum + t.netToPay);
                double paidInitialPurchases = purchases.fold(0.0, (sum, t) => sum + t.amountPaid);
                double reglementsPurchases = payments.where((p) => p.tierType == TierType.supplier).fold(0.0, (sum, p) => sum + p.amount);
                double totalPayePurchases = paidInitialPurchases + reglementsPurchases;
                double totalImpayesPurchases = caPurchases - totalPayePurchases;

                // --- TRANSPORT ---
                double beneficeTrans = trips.fold(0.0, (sum, t) => sum + t.netProfit);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (canViewSales) ...[
                        const Text('SITUATION CLIENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.sale))),
                              child: DashboardCard(title: 'CHIFFRE D\'AFFAIRE', value: '${currencyFormat.format(caSales)} F', icon: Icons.trending_up, iconColor: Colors.blue),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
                              child: DashboardCard(title: 'ENCAISSÉ', value: '${currencyFormat.format(totalEncaisseSales)} F', icon: Icons.check_circle_outline, iconColor: Colors.green),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.client))),
                              child: DashboardCard(title: 'IMPAYÉS CLIENTS', value: '${currencyFormat.format(totalImpayesSales < 0 ? 0 : totalImpayesSales)} F', icon: Icons.warning_amber_rounded, iconColor: Colors.red),
                            )),
                            if (canViewTransport)
                              Expanded(child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransportScreen())),
                                  child: DashboardCard(title: 'BÉNÉFICE TRANS.', value: '${currencyFormat.format(beneficeTrans)} F', icon: Icons.local_shipping, iconColor: Colors.purple),
                                ),
                              )),
                            if (!canViewTransport) const Spacer(),
                          ],
                        ),
                      ],
                      const SizedBox(height: 25),
                      if (canViewPurchases) ...[
                        const Text('SITUATION FOURNISSEURS (ACHATS)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.purchase))),
                              child: DashboardCard(title: 'TOTAL ACHATS', value: '${currencyFormat.format(caPurchases)} F', icon: Icons.shopping_cart, iconColor: Colors.teal),
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.supplier))),
                              child: DashboardCard(title: 'DETTES FOURN.', value: '${currencyFormat.format(totalImpayesPurchases < 0 ? 0 : totalImpayesPurchases)} F', icon: Icons.money_off, iconColor: Colors.orange),
                            )),
                          ],
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Text('Dernières Activités', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                      const SizedBox(height: 10),
                      if (transactions.isEmpty)
                        const Center(child: Text('Aucune activité', style: TextStyle(color: Colors.grey)))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: transactions.length > 5 ? 5 : transactions.length,
                          itemBuilder: (context, index) {
                            final t = transactions[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(t.type == TransactionType.sale ? Icons.arrow_upward : Icons.arrow_downward, color: t.type == TransactionType.sale ? Colors.blue : Colors.teal),
                              title: Text(t.tierName),
                              subtitle: Text(DateFormat('dd/MM/yyyy').format(t.date)),
                              trailing: Text('${currencyFormat.format(t.totalHT)} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                    ],
                  ),
                );
              }
            );
          }
        );
      },
    );
  }
}
