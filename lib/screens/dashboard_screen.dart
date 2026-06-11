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
import 'daily_closing_screen.dart';
import 'unpaid_report_screen.dart';
import 'inventory_report_screen.dart';
import 'stock_movement_screen.dart';
import 'delivery_list_screen.dart';
import 'reconciliation_screen.dart';
import 'task_assignment_screen.dart';
import 'technician_task_screen.dart';
import '../models/task.dart';
import 'weather_alert_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppUser?>(context);
    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isAdmin = currentUser.role == UserRole.admin;
    final isStorekeeper = currentUser.role == UserRole.storekeeper;
    final isTechnician = currentUser.role == UserRole.technician;
    final isTechManager = currentUser.role == UserRole.tech_manager;

    final canViewPurchases = isAdmin || currentUser.canViewPurchases;
    final canViewSales = isAdmin || currentUser.canViewSales;
    final canViewTransport = isAdmin || currentUser.canViewTransport;
    final canViewAccounting = isAdmin || currentUser.canViewAccounting;
    final canViewTiers = isAdmin || currentUser.canViewTiers;
    final canManageUsers = isAdmin || currentUser.canManageUsers;

    List<Widget> pages;
    List<BottomNavigationBarItem> navItems;

    if (isStorekeeper) {
      pages = [const DeliveryListScreen(), const StockScreen()];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Livraisons'),
        const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stocks'),
      ];
    } else if (isTechnician) {
      pages = [const TechnicianTaskScreen(), const StockScreen()];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Mes Chantiers'),
        const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stocks'),
      ];
    } else if (isTechManager && !isAdmin) {
      pages = [const TechManagerDashboard(), const TaskAssignmentScreen()];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tableau Bord'),
        const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Gestion Chantiers'),
      ];
    } else {
      pages = [
        const DashboardContent(),
        const TransactionListScreen(type: TransactionType.purchase),
        const TransactionListScreen(type: TransactionType.sale),
        const TransportScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Accueil'),
        if (canViewPurchases) const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Achats'),
        if (canViewSales) const BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Ventes'),
        if (canViewTransport) const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Transport'),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentUser.displayName.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(isAdmin ? 'ADMINISTRATION' : (isTechManager ? 'RESPONSABLE TECHNIQUE' : (isStorekeeper ? 'ESPACE MAGASINIER' : 'KO SOLAR ERP')),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 17)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthService>().signOut()),
        ],
      ),
      drawer: (isStorekeeper || isTechnician || (isTechManager && !isAdmin)) ? null : Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A237E)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('KO SOLAR GESTION', style: TextStyle(color: Colors.white, fontSize: 24)),
                  Text(currentUser.role.toString().split('.').last.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildDrawerTile(context, Icons.inventory, 'Stocks', Colors.blueGrey, const StockScreen()),
            _buildDrawerTile(context, Icons.request_quote, 'Devis', Colors.purple, const TransactionListScreen(type: TransactionType.quote)),
            _buildDrawerTile(context, Icons.local_shipping, 'Livraisons (BL)', Colors.orange, const DeliveryListScreen()),
            _buildDrawerTile(context, Icons.assignment, 'Gestion des Chantiers', Colors.deepOrange, const TaskAssignmentScreen()),
            _buildDrawerTile(context, Icons.warehouse, 'Gestion des Dépôts', Colors.brown, const WarehouseListScreen()),
            _buildDrawerTile(context, Icons.warning_amber, 'Avertissement Météo', Colors.orange, const WeatherAlertScreen()),
            const Divider(),
            _buildDrawerTile(context, Icons.payments, 'Règlements', Colors.green, const PaymentScreen()),
            _buildDrawerTile(context, Icons.money_off, 'État des Impayés', Colors.red, const UnpaidReportScreen()),
            _buildDrawerTile(context, Icons.lock_clock, 'Clôture de Journée', Colors.red, const DailyClosingScreen()),
            if (canViewTiers) ...[
              const Divider(),
              _buildDrawerTile(context, Icons.people, 'Clients', Colors.indigo, const TierListScreen(type: TierType.client)),
              _buildDrawerTile(context, Icons.business_center, 'Fournisseurs', Colors.teal, const TierListScreen(type: TierType.supplier)),
            ],
            if (canViewAccounting) ...[
              const Divider(),
              _buildDrawerTile(context, Icons.account_balance, 'Plan Comptable', Colors.indigo, const AccountListScreen()),
              _buildDrawerTile(context, Icons.menu_book, 'Journal Comptable', Colors.brown, const JournalScreen()),
              _buildDrawerTile(context, Icons.account_balance_wallet, 'Rapprochement Bancaire', Colors.green, const ReconciliationScreen()),
            ],
            if (canManageUsers) ...[
              const Divider(),
              _buildDrawerTile(context, Icons.analytics, 'Statistiques & Marges', Colors.orange, const StatisticsScreen()),
              _buildDrawerTile(context, Icons.admin_panel_settings, 'Gestion Utilisateurs', Colors.red, const UserManagementScreen()),
            ],
          ],
        ),
      ),
      body: pages[_currentIndex >= pages.length ? 0 : _currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex >= pages.length ? 0 : _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1A237E),
        unselectedItemColor: Colors.grey,
        items: navItems,
      ),
    );
  }

  Widget _buildDrawerTile(BuildContext context, IconData icon, String title, Color color, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
      },
    );
  }
}

class TechManagerDashboard extends StatelessWidget {
  const TechManagerDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    return StreamBuilder<List<Task>>(
      stream: service.getTasks(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data!;
        int total = tasks.length;
        int completed = tasks.where((t) => t.status == TaskStatus.approved).length;
        int pending = total - completed;
        Map<String, int> performance = {};
        for (var t in tasks) {
          if (t.status == TaskStatus.approved) performance[t.technicianName] = (performance[t.technicianName] ?? 0) + 1;
        }
        var sortedPerf = performance.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EVOLUTION DES INSTALLATIONS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: DashboardCard(title: 'TOTAL CHANTIERS', value: '$total', icon: Icons.assignment, iconColor: Colors.blue)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardCard(title: 'CLÔTURÉS', value: '$completed', icon: Icons.verified, iconColor: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardCard(title: 'EN ATTENTE', value: '$pending', icon: Icons.pending, iconColor: Colors.orange)),
                ],
              ),
              const SizedBox(height: 30),
              const Text('PERFORMANCE DES TECHNICIENS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              if (sortedPerf.isEmpty) const Center(child: Text('Aucun chantier approuvé.'))
              else ...sortedPerf.map((e) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(e.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                  child: Text('${e.value} FAITS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )),
            ],
          ),
        );
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

                final sales = transactions.where((t) => t.type == TransactionType.sale).toList();
                double caSales = sales.fold(0.0, (sum, t) => sum + t.netToPay);
                double paidInitialSales = sales.fold(0.0, (sum, t) => sum + t.amountPaid);
                double reglementsSales = payments.where((p) => p.tierType == TierType.client).fold(0.0, (sum, p) => sum + p.amount);
                double totalEncaisseSales = paidInitialSales + reglementsSales;
                double totalImpayesSales = caSales - totalEncaisseSales;

                final purchases = transactions.where((t) => t.type == TransactionType.purchase).toList();
                double caPurchases = purchases.fold(0.0, (sum, t) => sum + t.netToPay);
                double paidInitialPurchases = purchases.fold(0.0, (sum, t) => sum + t.amountPaid);
                double reglementsPurchases = payments.where((p) => p.tierType == TierType.supplier).fold(0.0, (sum, p) => sum + p.amount);
                double totalPayePurchases = paidInitialPurchases + reglementsPurchases;
                double totalImpayesPurchases = caPurchases - totalPayePurchases;

                double beneficeTrans = trips.fold(0.0, (sum, t) => sum + t.netProfit);
                double soldeCaisse = reglementsSales - reglementsPurchases;

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canViewSales) ...[
                            const Text('SITUATION CLIENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1, fontSize: 13)),
                            const SizedBox(height: 15),
                            GridView.count(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 2.5 : 1.4,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.sale))),
                                  child: DashboardCard(title: 'CHIFFRE D\'AFFAIRE', value: '${currencyFormat.format(caSales)} F', icon: Icons.trending_up, iconColor: Colors.blue),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
                                  child: DashboardCard(title: 'ENCAISSÉ', value: '${currencyFormat.format(totalEncaisseSales)} F', icon: Icons.check_circle_outline, iconColor: Colors.green),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.client))),
                                  child: DashboardCard(title: 'IMPAYÉS CLIENTS', value: '${currencyFormat.format(totalImpayesSales < 0 ? 0 : totalImpayesSales)} F', icon: Icons.warning_amber_rounded, iconColor: Colors.red),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 35),
                          if (canViewPurchases) ...[
                            const Text('SITUATION FOURNISSEURS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1, fontSize: 13)),
                            const SizedBox(height: 15),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: MediaQuery.of(context).size.width > 600 ? 3.5 : 1.4,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.purchase))),
                                  child: DashboardCard(title: 'TOTAL ACHATS', value: '${currencyFormat.format(caPurchases)} F', icon: Icons.shopping_cart, iconColor: Colors.teal),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.supplier))),
                                  child: DashboardCard(title: 'DETTES FOURN.', value: '${currencyFormat.format(totalImpayesPurchases < 0 ? 0 : totalImpayesPurchases)} F', icon: Icons.money_off, iconColor: Colors.orange),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 35),
                          const Text('SITUATION TRÉSORERIE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1, fontSize: 13)),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
                              child: DashboardCard(title: 'SOLDE CAISSE', value: '${currencyFormat.format(soldeCaisse)} F', icon: Icons.account_balance_wallet, iconColor: Colors.indigo),
                            ),
                          ),
                          if (canViewTransport) ...[
                            const SizedBox(height: 35),
                            const Text('TRANSPORT & LOGISTIQUE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1, fontSize: 13)),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: 300,
                              child: GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransportScreen())),
                                child: DashboardCard(title: 'BÉNÉFICE TRANS.', value: '${currencyFormat.format(beneficeTrans)} F', icon: Icons.local_shipping, iconColor: Colors.purple),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                          const Text('Dernières Activités', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                          const SizedBox(height: 15),
                          if (transactions.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Aucune activité récente', style: TextStyle(color: Colors.grey))))
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: transactions.length > 5 ? 5 : transactions.length,
                              itemBuilder: (context, index) {
                                final t = transactions[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: t.type == TransactionType.sale ? Colors.blue.shade50 : Colors.teal.shade50,
                                      child: Icon(t.type == TransactionType.sale ? Icons.arrow_upward : Icons.arrow_downward, color: t.type == TransactionType.sale ? Colors.blue : Colors.teal, size: 20),
                                    ),
                                    title: Text(t.tierName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(DateFormat('dd MMMM yyyy').format(t.date)),
                                    trailing: Text('${currencyFormat.format(t.totalHT)} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
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
