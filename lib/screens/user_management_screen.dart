import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import '../models/warehouse.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  UserRole _selectedRole = UserRole.employee;
  String? _selectedWarehouseId;

  // États des permissions
  bool _canViewPurchases = false;
  bool _canViewSales = true;
  bool _canDeleteSales = false;
  bool _canViewProducts = true;
  bool _canEditProducts = false;
  bool _canDeleteProducts = false;
  bool _canManageUsers = false;
  bool _canViewClients = true;
  bool _canViewSuppliers = true;
  bool _canEditTiers = false;
  bool _canDeleteTiers = false;
  bool _canViewTransport = false;
  bool _canEditTransport = false;

  // Règlements
  bool _canViewPayments = false;
  bool _canAddClientPayment = false;
  bool _canAddSupplierPayment = false;
  bool _canDeletePayment = false;

  // Comptabilité spécifique
  bool _canViewUnpaidReport = false;
  bool _canViewPlanComptable = false;
  bool _canViewJournalComptable = false;
  bool _canViewTrialBalance = false;
  bool _canViewAgedBalance = false;
  bool _canViewCashControl = false;
  bool _canManageFiscalYears = false;
  bool _canManageReconciliation = false;

  // Autres modules
  bool _canViewAudit = false;
  bool _canViewExpenses = false;
  bool _canViewAdvances = false;
  bool _canViewTransfers = false;
  bool _canViewReminders = false;
  bool _canViewWeather = false;
  bool _canViewDeliveries = false;
  bool _canManagePayroll = false;
  bool _canImportExport = false;
  bool _canManageWarehouses = false;
  bool _canManageTasks = false;
  bool _canViewStockMovements = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          _buildResetRequestsBadge(context),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userData = userDoc.data() as Map<String, dynamic>;
              final role = userData['role'] ?? 'employee';
              final appUser = AppUser.fromMap(userData);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(role),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(userData['displayName']?.toString().toUpperCase() ?? ''),
                subtitle: Text("${userData['email']}\nRôle: ${role.toString().toUpperCase()}"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditUserDialog(context, appUser),
                    ),
                    IconButton(
                      icon: const Icon(Icons.lock_reset, color: Colors.orange),
                      tooltip: 'Réinitialiser le mot de passe',
                      onPressed: () => _resetUserPassword(context, userData['email']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteUser(context, userDoc.id, userData['displayName'] ?? ''),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(context),
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter Membre', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildResetRequestsBadge(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('password_resets').where('status', isEqualTo: 'en_attente').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        int count = snapshot.data!.docs.length;
        return IconButton(
          icon: Badge(
            label: Text('$count'),
            child: const Icon(Icons.notifications_active, color: Colors.orangeAccent),
          ),
          onPressed: () => _showResetRequestsDialog(context, snapshot.data!.docs),
        );
      },
    );
  }

  void _showResetRequestsDialog(BuildContext context, List<QueryDocumentSnapshot> requests) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demandes de réinitialisation'),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(req['email']),
                subtitle: const Text('Attend un nouveau mot de passe'),
                trailing: ElevatedButton(
                  onPressed: () => _approveResetRequest(context, req['email']),
                  child: const Text('Approuver'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _approveResetRequest(BuildContext context, String email) async {
    final passCtrl = TextEditingController(text: 'Solar2024');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau mot de passe pour $email'),
        content: TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mot de passe temporaire')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await context.read<AuthService>().approvePasswordReset(email, passCtrl.text.trim());
              Navigator.pop(context); // Fermer sous-dialog
              Navigator.pop(context); // Fermer liste
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour !')));
            },
            child: const Text('VALIDER'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'storekeeper': return Colors.green;
      case 'technician': return Colors.deepOrange;
      case 'tech_manager': return Colors.indigo;
      default: return Colors.blueGrey;
    }
  }

  Widget _buildPermissionSwitch(StateSetter setDialogState, String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      dense: true,
      onChanged: (v) => setDialogState(() => onChanged(v)),
    );
  }

  void _resetUserPassword(BuildContext context, String email) async {
    try {
      await context.read<AuthService>().sendPasswordResetEmail(email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email de réinitialisation envoyé à $email'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDeleteUser(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Voulez-vous vraiment supprimer $name ?\n\nNote: Cela supprimera son profil Firestore. Son accès Auth devra être retiré manuellement dans la console Firebase pour une sécurité totale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(uid).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur supprimé')));
            }, 
            child: const Text('Supprimer', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(BuildContext context, AppUser user) {
    _nameController.text = user.displayName;
    _emailController.text = user.email;
    _selectedRole = user.role;
    _selectedWarehouseId = user.warehouseId;
    _canViewPurchases = user.canViewPurchases;
    _canViewSales = user.canViewSales;
    _canDeleteSales = user.canDeleteSales;
    _canViewProducts = user.canViewProducts;
    _canEditProducts = user.canEditProducts;
    _canDeleteProducts = user.canDeleteProducts;
    _canManageUsers = user.canManageUsers;
    _canViewClients = user.canViewClients;
    _canViewSuppliers = user.canViewSuppliers;
    _canEditTiers = user.canEditTiers;
    _canDeleteTiers = user.canDeleteTiers;
    _canViewTransport = user.canViewTransport;
    _canEditTransport = user.canEditTransport;
    _canViewPayments = user.canViewPayments;
    _canAddClientPayment = user.canAddClientPayment;
    _canAddSupplierPayment = user.canAddSupplierPayment;
    _canDeletePayment = user.canDeletePayment;
    _canViewUnpaidReport = user.canViewUnpaidReport;
    _canViewPlanComptable = user.canViewPlanComptable;
    _canViewJournalComptable = user.canViewJournalComptable;
    _canViewTrialBalance = user.canViewTrialBalance;
    _canViewAgedBalance = user.canViewAgedBalance;
    _canViewCashControl = user.canViewCashControl;
    _canManageFiscalYears = user.canManageFiscalYears;
    _canManageReconciliation = user.canManageReconciliation;
    _canViewAudit = user.canViewAudit;
    _canViewExpenses = user.canViewExpenses;
    _canViewAdvances = user.canViewAdvances;
    _canViewTransfers = user.canViewTransfers;
    _canViewReminders = user.canViewReminders;
    _canViewWeather = user.canViewWeather;
    _canViewDeliveries = user.canViewDeliveries;
    _canManagePayroll = user.canManagePayroll;
    _canImportExport = user.canImportExport;
    _canManageWarehouses = user.canManageWarehouses;
    _canManageTasks = user.canManageTasks;
    _canViewStockMovements = user.canViewStockMovements;

    final service = context.read<FirestoreService>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Modifier ${user.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom complet')),
                const SizedBox(height: 20),
                const Text('Rôle :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButton<UserRole>(
                  isExpanded: true,
                  value: _selectedRole,
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(value: role, child: Text(role.toString().split('.').last.toUpperCase()));
                  }).toList(),
                  onChanged: (val) => setDialogState(() => _selectedRole = val!),
                ),
                if (_selectedRole == UserRole.storekeeper) ...[
                  const SizedBox(height: 10),
                  StreamBuilder<List<Warehouse>>(
                    stream: service.getWarehouses(),
                    builder: (context, snapshot) {
                      final warehouses = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: _selectedWarehouseId,
                        decoration: const InputDecoration(labelText: 'Assigner un dépôt', border: OutlineInputBorder()),
                        items: warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                        onChanged: (val) => setDialogState(() => _selectedWarehouseId = val),
                        validator: (val) => _selectedRole == UserRole.storekeeper && val == null ? 'Dépôt requis' : null,
                      );
                    },
                  ),
                ],
                const Divider(),
                const Text('📊 Permissions Commerciales', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir les Achats', _canViewPurchases, (v) => _canViewPurchases = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Ventes', _canViewSales, (v) => _canViewSales = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer des Ventes', _canDeleteSales, (v) => _canDeleteSales = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Produits', _canViewProducts, (v) => _canViewProducts = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modifier Produits', _canEditProducts, (v) => _canEditProducts = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer des Produits', _canDeleteProducts, (v) => _canDeleteProducts = v),
                _buildPermissionSwitch(setDialogState, 'Gérer les Utilisateurs', _canManageUsers, (v) => _canManageUsers = v),

                const Divider(),
                const Text('👥 Clients & Fournisseurs', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir les Clients', _canViewClients, (v) => _canViewClients = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Fournisseurs', _canViewSuppliers, (v) => _canViewSuppliers = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modifier Tiers', _canEditTiers, (v) => _canEditTiers = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer des Tiers', _canDeleteTiers, (v) => _canDeleteTiers = v),

                const Divider(),
                const Text('💰 Règlements & Trésorerie', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir Historique Règlements', _canViewPayments, (v) => _canViewPayments = v),
                _buildPermissionSwitch(setDialogState, 'Effectuer Règl. Client', _canAddClientPayment, (v) => _canAddClientPayment = v),
                _buildPermissionSwitch(setDialogState, 'Effectuer Règl. Fournisseur', _canAddSupplierPayment, (v) => _canAddSupplierPayment = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer des Règlements', _canDeletePayment, (v) => _canDeletePayment = v),
                _buildPermissionSwitch(setDialogState, 'Accès Contrôle de Caisse', _canViewCashControl, (v) => _canViewCashControl = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Rapprochement Bancaire', _canManageReconciliation, (v) => _canManageReconciliation = v),

                const Divider(),
                const Text('📓 Comptabilité & Rapports', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir État des Impayés', _canViewUnpaidReport, (v) => _canViewUnpaidReport = v),
                _buildPermissionSwitch(setDialogState, 'Voir Plan Comptable', _canViewPlanComptable, (v) => _canViewPlanComptable = v),
                _buildPermissionSwitch(setDialogState, 'Voir Journal Comptable', _canViewJournalComptable, (v) => _canViewJournalComptable = v),
                _buildPermissionSwitch(setDialogState, 'Voir Balance des Comptes', _canViewTrialBalance, (v) => _canViewTrialBalance = v),
                _buildPermissionSwitch(setDialogState, 'Voir Balance Agée Clients', _canViewAgedBalance, (v) => _canViewAgedBalance = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Exercices Comptables', _canManageFiscalYears, (v) => _canManageFiscalYears = v),

                const Divider(),
                const Text('🚀 Modules Avancés', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir Transport & Logistique', _canViewTransport, (v) => _canViewTransport = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Transport', _canEditTransport, (v) => _canEditTransport = v),
                _buildPermissionSwitch(setDialogState, 'Voir Audit & Traçabilité', _canViewAudit, (v) => _canViewAudit = v),
                _buildPermissionSwitch(setDialogState, 'Voir Gestion des Dépenses', _canViewExpenses, (v) => _canViewExpenses = v),
                _buildPermissionSwitch(setDialogState, 'Voir Gestion des Avances', _canViewAdvances, (v) => _canViewAdvances = v),
                _buildPermissionSwitch(setDialogState, 'Voir Transferts de Stock', _canViewTransfers, (v) => _canViewTransfers = v),
                _buildPermissionSwitch(setDialogState, 'Voir Relance des Impayés', _canViewReminders, (v) => _canViewReminders = v),
                _buildPermissionSwitch(setDialogState, 'Voir Alertes Météo', _canViewWeather, (v) => _canViewWeather = v),
                _buildPermissionSwitch(setDialogState, 'Voir Livraisons (BL)', _canViewDeliveries, (v) => _canViewDeliveries = v),
                _buildPermissionSwitch(setDialogState, 'Gérer la Paie', _canManagePayroll, (v) => _canManagePayroll = v),
                _buildPermissionSwitch(setDialogState, 'Accès Import/Export Sage', _canImportExport, (v) => _canImportExport = v),
                _buildPermissionSwitch(setDialogState, 'Gérer les Dépôts', _canManageWarehouses, (v) => _canManageWarehouses = v),
                _buildPermissionSwitch(setDialogState, 'Gérer les Chantiers', _canManageTasks, (v) => _canManageTasks = v),
                _buildPermissionSwitch(setDialogState, 'Voir Mouvements de Stock', _canViewStockMovements, (v) => _canViewStockMovements = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                // On calcule automatiquement si l'utilisateur doit voir le menu Comptabilité
                bool hasAnyAccountingPermission = _canViewUnpaidReport ||
                    _canViewPlanComptable ||
                    _canViewJournalComptable ||
                    _canViewTrialBalance ||
                    _canViewAgedBalance ||
                    _canViewCashControl ||
                    _canManageFiscalYears ||
                    _canManageReconciliation;

                final updatedUser = AppUser(
                  uid: user.uid,
                  email: user.email,
                  displayName: _nameController.text.trim(),
                  role: _selectedRole,
                  warehouseId: _selectedRole == UserRole.storekeeper ? _selectedWarehouseId : null,
                  canViewPurchases: _canViewPurchases,
                  canViewSales: _canViewSales,
                  canDeleteSales: _canDeleteSales,
                  canViewProducts: _canViewProducts,
                  canEditProducts: _canEditProducts,
                  canDeleteProducts: _canDeleteProducts,
                  canManageUsers: _canManageUsers,
                  canViewClients: _canViewClients,
                  canViewSuppliers: _canViewSuppliers,
                  canEditTiers: _canEditTiers,
                  canDeleteTiers: _canDeleteTiers,
                  canViewTransport: _canViewTransport,
                  canEditTransport: _canEditTransport,
                  canViewPayments: _canViewPayments,
                  canAddClientPayment: _canAddClientPayment,
                  canAddSupplierPayment: _canAddSupplierPayment,
                  canDeletePayment: _canDeletePayment,
                  canViewAccounting: hasAnyAccountingPermission, // Activé automatiquement
                  canViewUnpaidReport: _canViewUnpaidReport,
                  canViewPlanComptable: _canViewPlanComptable,
                  canViewJournalComptable: _canViewJournalComptable,
                  canViewTrialBalance: _canViewTrialBalance,
                  canViewAgedBalance: _canViewAgedBalance,
                  canViewCashControl: _canViewCashControl,
                  canManageFiscalYears: _canManageFiscalYears,
                  canManageReconciliation: _canManageReconciliation,
                  canViewAudit: _canViewAudit,
                  canViewExpenses: _canViewExpenses,
                  canViewAdvances: _canViewAdvances,
                  canViewTransfers: _canViewTransfers,
                  canViewReminders: _canViewReminders,
                  canViewWeather: _canViewWeather,
                  canViewDeliveries: _canViewDeliveries,
                  canManagePayroll: _canManagePayroll,
                  canImportExport: _canImportExport,
                  canManageWarehouses: _canManageWarehouses,
                  canManageTasks: _canManageTasks,
                  canViewStockMovements: _canViewStockMovements,
                );
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set(updatedUser.toMap());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Utilisateur mis à jour')));
              },
              child: const Text('ENREGISTRER'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _selectedRole = UserRole.employee;
    _selectedWarehouseId = null;
    // Reset permissions
    _canViewSales = _canViewProducts = _canViewClients = _canViewSuppliers = true;
    _canViewPurchases = _canDeleteSales = _canEditProducts = _canDeleteProducts = _canManageUsers = _canEditTiers = _canDeleteTiers = _canViewTransport = _canEditTransport = _canViewAudit = _canViewExpenses = _canViewAdvances = _canViewTransfers = _canViewReminders = _canViewWeather = _canViewDeliveries = _canManagePayroll = _canImportExport = _canManageWarehouses = _canManageTasks = _canViewTrialBalance = _canViewAgedBalance = _canViewCashControl = _canViewPayments = _canAddClientPayment = _canAddSupplierPayment = _canDeletePayment = _canManageFiscalYears = _canManageReconciliation = _canViewUnpaidReport = _canViewPlanComptable = _canViewJournalComptable = false;
    
    final service = context.read<FirestoreService>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Créer un nouveau compte'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom complet')),
                TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email (Identifiant)')),
                TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
                const SizedBox(height: 20),
                const Text('Attribuer un rôle :', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DropdownButton<UserRole>(
                  isExpanded: true,
                  value: _selectedRole,
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role, 
                      child: Text(role.toString().split('.').last.toUpperCase())
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      _selectedRole = val!;
                      if (_selectedRole == UserRole.admin) {
                        _canViewPurchases = _canViewSales = _canDeleteSales = _canViewProducts = _canEditProducts = _canDeleteProducts = _canManageUsers = _canViewAudit = _canViewExpenses = _canViewAdvances = _canViewTransfers = _canViewReminders = _canViewWeather = _canViewDeliveries = _canManagePayroll = _canImportExport = _canManageWarehouses = _canManageTasks = _canViewTrialBalance = _canViewAgedBalance = _canViewCashControl = _canViewPayments = _canAddClientPayment = _canAddSupplierPayment = _canDeletePayment = _canManageFiscalYears = _canManageReconciliation = _canViewUnpaidReport = _canViewPlanComptable = _canViewJournalComptable = true;
                        _canViewClients = _canViewSuppliers = true;
                      } else {
                        _canViewSales = _canViewProducts = _canViewClients = _canViewSuppliers = true;
                        _canViewPurchases = _canDeleteSales = _canEditProducts = _canDeleteProducts = _canManageUsers = _canEditTiers = _canDeleteTiers = _canViewTransport = _canEditTransport = _canViewAudit = _canViewExpenses = _canViewAdvances = _canViewTransfers = _canViewReminders = _canViewWeather = _canViewDeliveries = _canManageWarehouses = _canManageTasks = _canViewPayments = _canAddClientPayment = _canAddSupplierPayment = _canDeletePayment = _canManageFiscalYears = _canManageReconciliation = _canViewUnpaidReport = _canViewPlanComptable = _canViewJournalComptable = false;
                      }
                    });
                  },
                ),
                const Divider(),
                const Text('📊 Permissions détaillées', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir les Achats', _canViewPurchases, (v) => _canViewPurchases = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Ventes', _canViewSales, (v) => _canViewSales = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Produits', _canViewProducts, (v) => _canViewProducts = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Clients', _canViewClients, (v) => _canViewClients = v),
                _buildPermissionSwitch(setDialogState, 'Voir les Fournisseurs', _canViewSuppliers, (v) => _canViewSuppliers = v),
                const Divider(),
                const Text('💰 Trésorerie & Comptabilité', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir Historique Règlements', _canViewPayments, (v) => _canViewPayments = v),
                _buildPermissionSwitch(setDialogState, 'Faire Règl. Client', _canAddClientPayment, (v) => _canAddClientPayment = v),
                _buildPermissionSwitch(setDialogState, 'Faire Règl. Fournisseur', _canAddSupplierPayment, (v) => _canAddSupplierPayment = v),
                _buildPermissionSwitch(setDialogState, 'Accès Contrôle de Caisse', _canViewCashControl, (v) => _canViewCashControl = v),
                _buildPermissionSwitch(setDialogState, 'Voir Balance des Comptes', _canViewTrialBalance, (v) => _canViewTrialBalance = v),
                _buildPermissionSwitch(setDialogState, 'Voir Balance Agée', _canViewAgedBalance, (v) => _canViewAgedBalance = v),
                _buildPermissionSwitch(setDialogState, 'Voir État des Impayés', _canViewUnpaidReport, (v) => _canViewUnpaidReport = v),
                _buildPermissionSwitch(setDialogState, 'Voir Plan Comptable', _canViewPlanComptable, (v) => _canViewPlanComptable = v),
                _buildPermissionSwitch(setDialogState, 'Voir Journal Comptable', _canViewJournalComptable, (v) => _canViewJournalComptable = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Exercices Comptables', _canManageFiscalYears, (v) => _canManageFiscalYears = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Rapprochement Bancaire', _canManageReconciliation, (v) => _canManageReconciliation = v),
                const Divider(),
                const Text('🚀 Autres Modules', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                _buildPermissionSwitch(setDialogState, 'Voir Transport', _canViewTransport, (v) => _canViewTransport = v),
                _buildPermissionSwitch(setDialogState, 'Voir Audit & Traçabilité', _canViewAudit, (v) => _canViewAudit = v),
                _buildPermissionSwitch(setDialogState, 'Voir Dépenses', _canViewExpenses, (v) => _canViewExpenses = v),
                _buildPermissionSwitch(setDialogState, 'Voir Avances', _canViewAdvances, (v) => _canViewAdvances = v),
                _buildPermissionSwitch(setDialogState, 'Voir Transferts', _canViewTransfers, (v) => _canViewTransfers = v),
                _buildPermissionSwitch(setDialogState, 'Voir Relances', _canViewReminders, (v) => _canViewReminders = v),
                _buildPermissionSwitch(setDialogState, 'Voir Météo', _canViewWeather, (v) => _canViewWeather = v),
                _buildPermissionSwitch(setDialogState, 'Voir Livraisons', _canViewDeliveries, (v) => _canViewDeliveries = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
                try {
                  showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

                  await context.read<AuthService>().registerNewUser(
                    email: _emailController.text.trim(),
                    password: _passwordController.text.trim(),
                    displayName: _nameController.text.trim(),
                    role: _selectedRole,
                    warehouseId: _selectedRole == UserRole.storekeeper ? _selectedWarehouseId : null,
                    canViewPurchases: _canViewPurchases,
                    canViewSales: _canViewSales,
                    canDeleteSales: _canDeleteSales,
                    canViewProducts: _canViewProducts,
                    canEditProducts: _canEditProducts,
                    canDeleteProducts: _canDeleteProducts,
                    canManageUsers: _canManageUsers,
                    canViewClients: _canViewClients,
                    canViewSuppliers: _canViewSuppliers,
                    canEditTiers: _canEditTiers,
                    canDeleteTiers: _canDeleteTiers,
                    canViewTransport: _canViewTransport,
                    canEditTransport: _canEditTransport,
                    canViewPayments: _canViewPayments,
                    canAddClientPayment: _canAddClientPayment,
                    canAddSupplierPayment: _canAddSupplierPayment,
                    canDeletePayment: _canDeletePayment,
                    canViewAccounting: _canViewUnpaidReport || _canViewPlanComptable || _canViewJournalComptable || _canViewTrialBalance || _canViewAgedBalance || _canViewCashControl || _canManageFiscalYears || _canManageReconciliation,
                    canViewUnpaidReport: _canViewUnpaidReport,
                    canViewPlanComptable: _canViewPlanComptable,
                    canViewJournalComptable: _canViewJournalComptable,
                    canViewTrialBalance: _canViewTrialBalance,
                    canViewAgedBalance: _canViewAgedBalance,
                    canViewCashControl: _canViewCashControl,
                    canManageFiscalYears: _canManageFiscalYears,
                    canManageReconciliation: _canManageReconciliation,
                    canViewAudit: _canViewAudit,
                    canViewExpenses: _canViewExpenses,
                    canViewAdvances: _canViewAdvances,
                    canViewTransfers: _canViewTransfers,
                    canViewReminders: _canViewReminders,
                    canViewWeather: _canViewWeather,
                    canViewDeliveries: _canViewDeliveries,
                    canManagePayroll: _canManagePayroll,
                    canImportExport: _canImportExport,
                  );

                  Navigator.pop(context); // Fermer loader
                  Navigator.pop(context); // Fermer dialog

                  _emailController.clear();
                  _passwordController.clear();
                  _nameController.clear();

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compte créé avec succès !')));
                } catch (e) {
                  Navigator.pop(context); // Fermer loader
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
              child: const Text('VALIDER LA CRÉATION', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
