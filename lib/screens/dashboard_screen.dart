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
import '../models/product.dart';
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
import 'task_supervision_screen.dart';
import '../models/task.dart';
import 'weather_alert_screen.dart';
import 'unpaid_reminder_screen.dart';
import 'stock_transfer_screen.dart';
import 'audit_logs_screen.dart';
import 'expense_screen.dart';
import 'advance_management_screen.dart';
import 'payroll_screen.dart';
import 'import_export_screen.dart';
import 'fiscal_year_screen.dart';
import 'trial_balance_screen.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/advance.dart';
import 'aged_balance_screen.dart';
import 'cash_control_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _deliveryTab = 0;

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isAdmin = currentUser.role == UserRole.admin;
    final isStorekeeper = currentUser.role == UserRole.storekeeper;
    final isTechnician = currentUser.role == UserRole.technician;
    final isTechManager = currentUser.role == UserRole.tech_manager;
    final isSupervisor = currentUser.role == UserRole.supervisor;

    // Permissions
    final canViewSales = isAdmin || currentUser.canViewSales;
    final canViewPurchases = isAdmin || currentUser.canViewPurchases;
    final canViewStockMovements = isAdmin || currentUser.canViewStockMovements;
    final canViewDeliveries = isAdmin || currentUser.canViewDeliveries;
    final canViewExpenses = isAdmin || currentUser.canViewExpenses;
    final canViewAdvances = isAdmin || currentUser.canViewAdvances;
    final canManageUsers = isAdmin || currentUser.canManageUsers;
    final canViewAudit = isAdmin || currentUser.canViewAudit;
    final canViewWeather = isAdmin || currentUser.canViewWeather;
    final canViewReminders = isAdmin || currentUser.canViewReminders;
    final canManagePayroll = isAdmin || currentUser.canManagePayroll;
    final canImportExport = isAdmin || currentUser.canImportExport;
    final canViewAccounting = isAdmin || currentUser.canViewAccounting;
    final canViewTransfers = isAdmin || currentUser.canViewTransfers;
    final canViewTransport = isAdmin || currentUser.canViewTransport;
    final canViewClients = isAdmin || currentUser.canViewClients;
    final canViewSuppliers = isAdmin || currentUser.canViewSuppliers;

    // Sous-permissions comptabilité
    final canViewPlanComptable = isAdmin || currentUser.canViewPlanComptable;
    final canViewJournalComptable = isAdmin || currentUser.canViewJournalComptable;
    final canViewTrialBalance = isAdmin || currentUser.canViewTrialBalance;
    final canViewUnpaidReport = isAdmin || currentUser.canViewUnpaidReport;
    final canViewAgedBalance = isAdmin || currentUser.canViewAgedBalance;
    final canViewCashControl = isAdmin || currentUser.canViewCashControl;
    final canManageFiscalYears = isAdmin || currentUser.canManageFiscalYears;
    final canManageReconciliation = isAdmin || currentUser.canManageReconciliation;

    // Règlements
    final canViewPayments = isAdmin || currentUser.canViewPayments;

    List<Widget> pages;
    List<BottomNavigationBarItem> navItems;

    if (isStorekeeper) {
      pages = [DeliveryListScreen(key: ValueKey('delivery_$_deliveryTab'), initialTab: _deliveryTab)];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Livraisons'),
      ];
    } else if (isTechnician) {
      pages = [const TechnicianDashboard(), const TechnicianTaskScreen()];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Mon Dashboard'),
        const BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Mes Chantiers'),
      ];
    } else if (isTechManager && !isAdmin) {
      pages = [const TechManagerDashboard(), const TaskAssignmentScreen()];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Tableau Bord'),
        const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Gestion Chantiers'),
      ];
    } else if (isSupervisor && !isAdmin) {
      pages = [
        const SupervisorDashboard(),
        if (canViewSales) const TransactionListScreen(type: TransactionType.sale),
        if (canViewClients) const TierListScreen(type: TierType.client),
        const TaskSupervisionScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Mon Bureau'),
        if (canViewSales) const BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Ventes'),
        if (canViewClients) const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clients'),
        const BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Supervision'),
      ];
    } else {
      pages = [
        const DashboardContent(),
        if (canViewPurchases) const TransactionListScreen(type: TransactionType.purchase),
        if (canViewSales) const TransactionListScreen(type: TransactionType.sale),
        if (canViewTransfers) const StockTransferScreen(),
        if (canViewTransport) const TransportScreen(),
      ];
      navItems = [
        const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Accueil'),
        if (canViewPurchases) const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Achats'),
        if (canViewSales) const BottomNavigationBarItem(icon: Icon(Icons.sell), label: 'Ventes'),
        if (canViewTransfers) const BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Transferts'),
        if (canViewTransport) const BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Transport'),
      ];
    }

    return StreamBuilder<List<AppTransaction>>(
      stream: firestoreService.getTransactions(type: TransactionType.sale),
      builder: (context, snapshotTx) {
        return StreamBuilder<List<Payment>>(
          stream: firestoreService.getPayments(),
          builder: (context, snapshotPay) {
            return StreamBuilder<List<Product>>(
              stream: firestoreService.getProducts(),
              builder: (context, snapshotProd) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: firestoreService.getAllStocks(),
                  builder: (context, snapshotAllStocks) {
                    int overdueCount = 0;
                    int stockAlertCount = 0;
                    int pendingBLCount = 0;

                    if (snapshotTx.hasData && snapshotPay.hasData) {
                      final allTxs = snapshotTx.data!;
                      final allPays = snapshotPay.data!;
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);

                      for (var t in allTxs) {
                        // Comptage des BL en attente pour le magasinier
                        if (t.deliveryStatus == 'pending') {
                          pendingBLCount++;
                        }

                        if (t.dueDate == null) continue;
                        if (today.difference(t.dueDate!).inDays >= 1) {
                          double paid = allPays
                              .where((p) => p.invoiceNumber == t.invoiceNumber || (p.reference.toUpperCase().contains(t.invoiceNumber.toUpperCase())))
                              .fold(0.0, (sum, p) => sum + p.amount);
                          bool acompteInPay = allPays.any((p) => p.invoiceNumber == t.invoiceNumber && p.reference.contains('Acompte'));
                          if (!acompteInPay) paid += t.amountPaid;

                          if (t.netToPay - paid > 50) overdueCount++;
                        }
                      }
                    }

                    if (snapshotProd.hasData && snapshotAllStocks.hasData) {
                      final products = snapshotProd.data!;
                      final allStocks = snapshotAllStocks.data!;

                      for (var p in products) {
                        bool hasAlert = allStocks.any((s) => s['productId'] == p.id && (s['quantity'] as num?) != null && (s['quantity'] as num) <= 5);
                        if (hasAlert) stockAlertCount++;
                      }
                    }

                    return Scaffold(
                      appBar: AppBar(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentUser.displayName.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(isAdmin ? 'ADMINISTRATION' : (isTechManager ? 'RESPONSABLE TECHNIQUE' : (isSupervisor ? 'SUPERVISION GÉNÉRALE' : (isStorekeeper ? 'ESPACE MAGASINIER' : 'K-O SOLAR'))),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 17)),
                          ],
                        ),
                        actions: [
                          if (canViewReminders && overdueCount > 0 && !isTechnician && !isTechManager && !isSupervisor && !isStorekeeper)
                            _actionBadge(Icons.notifications_active, Colors.red, overdueCount, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UnpaidReminderScreen()))),

                          // Notification nouveaux BL pour le magasinier
                          if (isStorekeeper && pendingBLCount > 0)
                             _actionBadge(Icons.local_shipping, Colors.blue, pendingBLCount, () {
                               setState(() {
                                 _currentIndex = 0;
                                 _deliveryTab = 0; // Forcer l'onglet "À Livrer"
                               });
                             }),

                          // Alertes stock : UNIQUEMENT pour Admin
                          if (stockAlertCount > 0 && isAdmin)
                            _actionBadge(Icons.inventory, Colors.orange, stockAlertCount, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StockScreen()))),

                          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AuthService>().signOut()),
                        ],
                      ),
                      drawer: (isStorekeeper || isTechnician || isSupervisor || (isTechManager && !isAdmin)) ? null : Drawer(
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
                            _buildDrawerTile(context, Icons.inventory, 'Stocks', Colors.blueGrey, const StockScreen(), badgeCount: stockAlertCount, badgeColor: Colors.orange),
                            if (canViewStockMovements)
                              _buildDrawerTile(context, Icons.swap_vert, 'Mouvements de Stock', Colors.orange, const StockMovementScreen()),
                            if (canViewSales)
                              _buildDrawerTile(context, Icons.request_quote, 'Devis', Colors.purple, const TransactionListScreen(type: TransactionType.quote)),
                            if (canViewExpenses)
                              _buildDrawerTile(context, Icons.money_off, 'Gestion des Dépenses', Colors.redAccent, const ExpenseScreen()),
                            if (canViewAdvances)
                              _buildDrawerTile(context, Icons.savings, 'Gestion des Avances', Colors.teal, const AdvanceManagementScreen()),
                            if (canViewDeliveries)
                              _buildDrawerTile(context, Icons.local_shipping, 'Livraisons (BL)', Colors.orange, const DeliveryListScreen()),
                            if (canManagePayroll)
                              _buildDrawerTile(context, Icons.badge, 'Gestion de la Paie', Colors.blue, const PayrollScreen()),
                            if (canImportExport)
                              _buildDrawerTile(context, Icons.import_export, 'Import / Export Sage', Colors.grey, const ImportExportScreen()),

                            if (isAdmin || isTechManager || isTechnician)
                              _buildDrawerTile(context, Icons.assignment, 'Gestion des Chantiers', Colors.deepOrange, const TaskAssignmentScreen()),

                            if (isAdmin || currentUser.canSuperviseTasks)
                              _buildDrawerTile(context, Icons.map, 'Supervision & Itinéraires', Colors.blue, const TaskSupervisionScreen()),

                            if (canViewReminders)
                              _buildDrawerTile(
                                context,
                                Icons.warning_amber,
                                'Relance des Impayés',
                                Colors.red,
                                const UnpaidReminderScreen(),
                                badgeCount: overdueCount
                              ),
                            if (canViewWeather)
                              _buildDrawerTile(context, Icons.cloud, 'Avertissement Météo', Colors.orange, const WeatherAlertScreen()),

                            if (isAdmin || isStorekeeper)
                              _buildDrawerTile(context, Icons.warehouse, 'Gestion des Dépôts', Colors.brown, const WarehouseListScreen()),
                            const Divider(),
                            if (canViewPayments) ...[
                              _buildDrawerTile(context, Icons.payments, 'Règlements', Colors.green, const PaymentScreen()),
                            ],
                            if (canViewAccounting) ...[
                               if (canViewUnpaidReport) _buildDrawerTile(context, Icons.money_off, 'État des Impayés', Colors.red, const UnpaidReportScreen()),
                               if (isAdmin) _buildDrawerTile(context, Icons.lock_clock, 'Clôture de Journée', Colors.red, const DailyClosingScreen()),
                            ],
                            if (canViewClients || canViewSuppliers) ...[
                              const Divider(),
                              if (canViewClients) _buildDrawerTile(context, Icons.people, 'Clients', Colors.indigo, const TierListScreen(type: TierType.client)),
                              if (canViewSuppliers) _buildDrawerTile(context, Icons.business_center, 'Fournisseurs', Colors.teal, const TierListScreen(type: TierType.supplier)),
                            ],
                            if (canViewAccounting) ...[
                              const Divider(),
                              if (canViewPlanComptable) _buildDrawerTile(context, Icons.account_balance, 'Plan Comptable', Colors.indigo, const AccountListScreen()),
                              if (canViewJournalComptable) _buildDrawerTile(context, Icons.menu_book, 'Journal Comptable', Colors.brown, const JournalScreen()),
                              if (canViewTrialBalance) _buildDrawerTile(context, Icons.receipt_long, 'Balance des Comptes', Colors.teal, const TrialBalanceScreen()),
                              if (canViewAgedBalance) _buildDrawerTile(context, Icons.history, 'Balance Agée Clients', Colors.orange, const AgedBalanceScreen()),
                              if (canViewCashControl) _buildDrawerTile(context, Icons.account_balance_wallet, 'Contrôle de Caisse', Colors.green, const CashControlScreen()),
                              if (canManageFiscalYears) _buildDrawerTile(context, Icons.date_range, 'Exercices Comptables', Colors.blueAccent, const FiscalYearScreen()),
                              if (canManageReconciliation) _buildDrawerTile(context, Icons.account_balance_wallet, 'Rapprochement Bancaire', Colors.green, const ReconciliationScreen()),
                            ],
                            if (canManageUsers) ...[
                              const Divider(),
                              _buildDrawerTile(context, Icons.analytics, 'Statistiques & Marges', Colors.orange, const StatisticsScreen()),
                              if (canViewAudit)
                                _buildDrawerTile(context, Icons.security, 'Audit & Traçabilité', Colors.blueGrey, const AuditLogsScreen()),
                              _buildDrawerTile(context, Icons.admin_panel_settings, 'Gestion Utilisateurs', Colors.red, const UserManagementScreen()),
                            ],
                          ],
                        ),
                      ),
                      body: pages[_currentIndex >= pages.length ? 0 : _currentIndex],
                      bottomNavigationBar: BottomNavigationBar(
                        currentIndex: _currentIndex >= pages.length ? 0 : _currentIndex,
                        onTap: (index) {
                          setState(() => _currentIndex = index);
                        },
                        type: BottomNavigationBarType.fixed,
                        selectedItemColor: const Color(0xFF1A237E),
                        unselectedItemColor: Colors.grey,
                        items: navItems,
                      ),
                    );
                  }
                );
              }
            );
          }
        );
      }
    );
  }

  Widget _actionBadge(IconData icon, Color color, int count, VoidCallback onTap) {
    return Stack(
      children: [
        IconButton(icon: Icon(icon, color: color), onPressed: onTap),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
        )
      ],
    );
  }

  Widget _buildDrawerTile(BuildContext context, IconData icon, String title, Color color, Widget screen, {int badgeCount = 0, Color badgeColor = Colors.red}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (badgeCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
              child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
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
        int approved = tasks.where((t) => t.status == TaskStatus.approved).length;
        int completed = tasks.where((t) => t.status == TaskStatus.completed).length;
        int pending = total - approved - completed;

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
              const Text('STATISTIQUES DES INSTALLATIONS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: DashboardCard(title: 'TOTAL CHANTIERS', value: '$total', icon: Icons.assignment, iconColor: Colors.blue)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardCard(title: 'CLÔTURÉS', value: '$approved', icon: Icons.verified, iconColor: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: DashboardCard(title: 'À VALIDER', value: '$completed', icon: Icons.hourglass_top, iconColor: Colors.deepOrange)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: DashboardCard(title: 'EN COURS D\'INTERVENTION', value: '$pending', icon: Icons.engineering, iconColor: Colors.orange),
              ),
              const SizedBox(height: 30),
              const Text('OUTILS DE SUIVI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TaskAssignmentScreen())),
                  icon: const Icon(Icons.assignment_ind),
                  label: const Text('ACCÉDER AUX ASSIGNATIONS'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
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

class TechnicianDashboard extends StatelessWidget {
  const TechnicianDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<Task>>(
      stream: service.getTasks(technicianId: currentUser.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final tasks = snapshot.data!;

        int totalAssigned = tasks.length;
        int completed = tasks.where((t) => t.status == TaskStatus.approved).length;
        int pendingValidation = tasks.where((t) => t.status == TaskStatus.completed).length;
        int inProgress = totalAssigned - completed - pendingValidation;

        // Dernières appréciations (commentaires du manager sur les chantiers approuvés)
        final appreciations = tasks.where((t) => t.status == TaskStatus.approved && t.managerComment != null && t.managerComment!.isNotEmpty).toList()
          ..sort((a, b) => (b.updatedAt ?? DateTime.now()).compareTo(a.updatedAt ?? DateTime.now()));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MON ÉVOLUTION', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  DashboardCard(title: 'CLIENTS ASSIGNÉS', value: '$totalAssigned', icon: Icons.people, iconColor: Colors.blue),
                  DashboardCard(title: 'CHANTIERS TERMINÉS', value: '$completed', icon: Icons.task_alt, iconColor: Colors.green),
                  DashboardCard(title: 'EN ATTENTE VALID.', value: '$pendingValidation', icon: Icons.hourglass_empty, iconColor: Colors.orange),
                  DashboardCard(title: 'EN COURS', value: '$inProgress', icon: Icons.engineering, iconColor: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 30),
              const Text('DERNIÈRES APPRÉCIATIONS DU RESPONSABLE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(),
              if (appreciations.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Aucun commentaire pour le moment.', style: TextStyle(color: Colors.grey, fontSize: 12))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appreciations.length > 3 ? 3 : appreciations.length,
                  itemBuilder: (context, index) {
                    final task = appreciations[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.green.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text('Chantier : ${task.clientName.toUpperCase()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(task.managerComment!, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                        trailing: Text(DateFormat('dd/MM/yy').format(task.updatedAt ?? task.assignedAt), style: const TextStyle(fontSize: 10)),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String _temp = "--";
  String _desc = "Chargement...";

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final response = await http.get(Uri.parse('https://wttr.in/Bamako?format=j1'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current_condition'][0];
        setState(() {
          _temp = "${current['temp_C']}°C";
          _desc = current['lang_fr']?[0]['value'] ?? current['weatherDesc'][0]['value'];
        });
      }
    } catch (e) {
      setState(() {
        _desc = "Météo indisponible";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny, color: Colors.orange, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BAMAKO, MALI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              Text(_temp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(_desc, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final currentUser = Provider.of<AppUser?>(context);

    if (currentUser == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<Task>>(
      stream: service.getTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final tasks = snapshot.data!;
        int total = tasks.length;
        int completed = tasks.where((t) => t.status == TaskStatus.approved).length;
        int inProgress = tasks.where((t) => t.status == TaskStatus.in_progress || t.status == TaskStatus.completed).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TABLEAU DE BORD SUPERVISEUR',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              const SizedBox(height: 8),
              Text('Bienvenue, ${currentUser.displayName}. Voici l\'état global des chantiers.',
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 25),

              Row(
                children: [
                  Expanded(child: DashboardCard(title: 'TOTAL SITES', value: '$total', icon: Icons.location_city, iconColor: Colors.indigo)),
                  const SizedBox(width: 15),
                  Expanded(child: DashboardCard(title: 'VALIDÉS', value: '$completed', icon: Icons.verified_user, iconColor: Colors.green)),
                  const SizedBox(width: 15),
                  Expanded(child: DashboardCard(title: 'ACTIFS', value: '$inProgress', icon: Icons.directions_run, iconColor: Colors.orange)),
                ],
              ),

              const SizedBox(height: 35),
              Text('VUE D\'ENSEMBLE DES OPÉRATIONS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
              const Divider(),
              const SizedBox(height: 15),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 2.5,
                children: [
                  _buildQuickAction(context, Icons.map, 'SUPERVISION & GPS', Colors.blue, const TaskSupervisionScreen()),
                  if (currentUser.canViewSales)
                    _buildQuickAction(context, Icons.sell, 'HISTORIQUE VENTES', Colors.green, const TransactionListScreen(type: TransactionType.sale)),
                  if (currentUser.canViewClients)
                    _buildQuickAction(context, Icons.people, 'LISTE DES CLIENTS', Colors.orange, const TierListScreen(type: TierType.client)),
                  if (currentUser.canViewAccounting)
                    _buildQuickAction(context, Icons.account_balance, 'COMPTABILITÉ', Colors.indigo, const AccountListScreen()),
                  _buildQuickAction(context, Icons.picture_as_pdf, 'RAPPORTS PDF', Colors.red, const TaskSupervisionScreen()),
                ],
              ),

              const SizedBox(height: 40),
              const Text('DERNIÈRES ACTIVITÉS TERRAIN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),

              if (tasks.isEmpty)
                const Center(child: Text('Aucune activité récente.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length > 5 ? 5 : tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.person, color: Colors.blue, size: 20),
                        ),
                        title: Text(task.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Par : ${task.technicianName} • ${DateFormat('dd/MM/yy').format(task.assignedAt)}',
                          style: const TextStyle(fontSize: 11)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getStatusColor(task.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15)
                          ),
                          child: Text(task.status.toString().split('.').last.toUpperCase(),
                            style: TextStyle(color: _getStatusColor(task.status), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction(BuildContext context, IconData icon, String label, Color color, Widget screen) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => screen)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.pending: return Colors.grey;
      case TaskStatus.in_progress: return Colors.blue;
      case TaskStatus.completed: return Colors.orange;
      case TaskStatus.approved: return Colors.green;
      case TaskStatus.rejected: return Colors.red;
    }
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
    final canViewAdvances = isAdmin || currentUser.canViewAdvances;

    final canViewPayments = isAdmin || currentUser.canViewPayments;
    final canViewAccounting = isAdmin || currentUser.canViewAccounting;

    return StreamBuilder<List<AppTransaction>>(
      stream: firestoreService.getTransactions(limit: 50),
      builder: (context, snapshotTrans) {
        return StreamBuilder<List<Trip>>(
          stream: firestoreService.getTrips(),
          builder: (context, snapshotTrips) {
            return StreamBuilder<List<Payment>>(
              stream: firestoreService.getPayments(),
              builder: (context, snapshotPay) {
                return StreamBuilder<List<Advance>>(
                  stream: firestoreService.getAdvances(),
                  builder: (context, snapshotAdv) {
                    final transactions = snapshotTrans.data ?? [];
                    final trips = snapshotTrips.data ?? [];
                    final payments = snapshotPay.data ?? [];
                    final advances = snapshotAdv.data ?? [];

                    if (snapshotTrans.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // --- CALCULS AVANCES ---
                    double totalAvancesDispo = advances.where((a) => !a.isUsed).fold(0.0, (sum, a) => sum + a.amount);

                    // --- CALCULS CLIENTS ---
                    final salesAndReturns = transactions.where((t) => t.type == TransactionType.sale || t.type == TransactionType.saleReturn).toList();
                    double caSales = salesAndReturns.fold(0.0, (sum, t) => sum + t.netToPay);
                    double totalEncaisseSales = payments.where((p) => p.tierType == TierType.client).fold(0.0, (sum, p) => sum + p.amount);

                    for (var t in salesAndReturns) {
                      if (t.amountPaid > 0 && t.type == TransactionType.sale) {
                        bool alreadyCounted = payments.any((p) => p.invoiceNumber == t.invoiceNumber && p.reference.contains('Acompte'));
                        if (!alreadyCounted) totalEncaisseSales += t.amountPaid;
                      }
                    }
                    double totalImpayesSales = caSales - totalEncaisseSales;

                    // --- CALCULS FOURNISSEURS ---
                    final purchasesAndReturns = transactions.where((t) => t.type == TransactionType.purchase || t.type == TransactionType.purchaseReturn).toList();
                    double caPurchases = purchasesAndReturns.fold(0.0, (sum, t) => sum + t.netToPay);
                    double totalPayePurchases = payments.where((p) => p.tierType == TierType.supplier).fold(0.0, (sum, p) => sum + p.amount);
                    for (var t in purchasesAndReturns) {
                      if (t.amountPaid > 0 && t.type == TransactionType.purchase) {
                        bool alreadyCounted = payments.any((p) => p.invoiceNumber == t.invoiceNumber && p.reference.contains('Acompte'));
                        if (!alreadyCounted) totalPayePurchases += t.amountPaid;
                      }
                    }
                    double totalImpayesPurchases = caPurchases - totalPayePurchases;

                    double beneficeTrans = trips.fold(0.0, (sum, t) => sum + t.netProfit);
                    double soldeCaisse = totalEncaisseSales - totalPayePurchases;

                    return Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('K-O SOLAR - TABLEAU DE BORD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const WeatherWidget(),
                                  if (canViewAdvances)
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdvanceManagementScreen())),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Colors.teal, Color(0xFF00695C)]),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8)],
                                        ),
                                        child: Column(
                                          children: [
                                            const Text('AVANCES DISPO.', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text('${currencyFormat.format(totalAvancesDispo)} F', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              if (canViewSales || canViewPayments) ...[
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
                                    if (canViewSales)
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.sale))),
                                        child: DashboardCard(title: 'CHIFFRE D\'AFFAIRE', value: '${currencyFormat.format(caSales)} F', icon: Icons.trending_up, iconColor: Colors.blue),
                                      ),
                                    if (canViewPayments)
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
                                        child: DashboardCard(title: 'ENCAISSÉ', value: '${currencyFormat.format(totalEncaisseSales)} F', icon: Icons.check_circle_outline, iconColor: Colors.green),
                                      ),
                                    if (canViewSales)
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.client))),
                                        child: DashboardCard(title: 'IMPAYÉS CLIENTS', value: '${currencyFormat.format(totalImpayesSales < 0 ? 0 : totalImpayesSales)} F', icon: Icons.warning_amber_rounded, iconColor: Colors.red),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 35),
                              if (canViewPurchases || canViewPayments) ...[
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
                                    if (canViewPurchases)
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TransactionListScreen(type: TransactionType.purchase))),
                                        child: DashboardCard(title: 'TOTAL ACHATS', value: '${currencyFormat.format(caPurchases)} F', icon: Icons.shopping_cart, iconColor: Colors.teal),
                                      ),
                                    if (canViewPurchases)
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TierListScreen(type: TierType.supplier))),
                                        child: DashboardCard(title: 'DETTES FOURN.', value: '${currencyFormat.format(totalImpayesPurchases < 0 ? 0 : totalImpayesPurchases)} F', icon: Icons.money_off, iconColor: Colors.orange),
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 35),
                              if (canViewAccounting || canViewPayments) ...[
                                const Text('SITUATION TRÉSORERIE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.1, fontSize: 13)),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width > 600 ? 300 : double.infinity,
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentScreen())),
                                    child: DashboardCard(title: 'SOLDE CAISSE', value: '${currencyFormat.format(soldeCaisse)} F', icon: Icons.account_balance_wallet, iconColor: Colors.indigo),
                                  ),
                                ),
                              ],
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
          }
        );
      },
    );
  }
}
