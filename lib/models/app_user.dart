enum UserRole { admin, manager, employee, storekeeper, technician, tech_manager }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? warehouseId;

  // Permissions Commerciales
  final bool canViewPurchases;
  final bool canViewSales;
  final bool canDeleteSales;
  final bool canViewProducts;
  final bool canEditProducts;
  final bool canDeleteProducts;
  final bool canManageUsers;
  
  // Tiers & Transport
  final bool canViewClients;
  final bool canViewSuppliers;
  final bool canEditTiers;
  final bool canDeleteTiers;
  final bool canViewTransport;
  final bool canEditTransport;

  // Règlements
  final bool canViewPayments;
  final bool canAddClientPayment;
  final bool canAddSupplierPayment;
  final bool canDeletePayment;

  // Comptabilité Détaillée (Le découpage qui marche)
  final bool canViewAccounting;
  final bool canViewUnpaidReport;
  final bool canViewPlanComptable;
  final bool canViewJournalComptable;
  final bool canViewTrialBalance;
  final bool canViewAgedBalance;
  final bool canViewCashControl;
  final bool canManageFiscalYears;
  final bool canManageReconciliation;

  // Autres Modules
  final bool canViewAudit;
  final bool canViewExpenses;
  final bool canViewAdvances;
  final bool canViewTransfers;
  final bool canViewReminders;
  final bool canViewWeather;
  final bool canViewDeliveries;
  final bool canManagePayroll;
  final bool canImportExport;
  final bool canManageWarehouses;
  final bool canManageTasks;
  final bool canViewStockMovements;
  final bool canSuperviseTasks;

  // Traçabilité en temps réel
  final String? lastAction;
  final DateTime? lastSeen;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.warehouseId,
    this.canViewPurchases = false,
    this.canViewSales = true,
    this.canDeleteSales = false,
    this.canViewProducts = true,
    this.canEditProducts = false,
    this.canDeleteProducts = false,
    this.canManageUsers = false,
    this.canViewClients = true,
    this.canViewSuppliers = true,
    this.canEditTiers = false,
    this.canDeleteTiers = false,
    this.canViewTransport = false,
    this.canEditTransport = false,
    this.canViewPayments = false,
    this.canAddClientPayment = false,
    this.canAddSupplierPayment = false,
    this.canDeletePayment = false,
    this.canViewAccounting = false,
    this.canViewUnpaidReport = false,
    this.canViewPlanComptable = false,
    this.canViewJournalComptable = false,
    this.canViewTrialBalance = false,
    this.canViewAgedBalance = false,
    this.canViewCashControl = false,
    this.canManageFiscalYears = false,
    this.canManageReconciliation = false,
    this.canViewAudit = false,
    this.canViewExpenses = false,
    this.canViewAdvances = false,
    this.canViewTransfers = false,
    this.canViewReminders = false,
    this.canViewWeather = false,
    this.canViewDeliveries = false,
    this.canManagePayroll = false,
    this.canImportExport = false,
    this.canManageWarehouses = false,
    this.canManageTasks = false,
    this.canViewStockMovements = false,
    this.canSuperviseTasks = false,
    this.lastAction,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last,
      'warehouseId': warehouseId,
      'canViewPurchases': canViewPurchases,
      'canViewSales': canViewSales,
      'canDeleteSales': canDeleteSales,
      'canViewProducts': canViewProducts,
      'canEditProducts': canEditProducts,
      'canDeleteProducts': canDeleteProducts,
      'canManageUsers': canManageUsers,
      'canViewClients': canViewClients,
      'canViewSuppliers': canViewSuppliers,
      'canEditTiers': canEditTiers,
      'canDeleteTiers': canDeleteTiers,
      'canViewTransport': canViewTransport,
      'canEditTransport': canEditTransport,
      'canViewPayments': canViewPayments,
      'canAddClientPayment': canAddClientPayment,
      'canAddSupplierPayment': canAddSupplierPayment,
      'canDeletePayment': canDeletePayment,
      'canViewAccounting': canViewAccounting,
      'canViewUnpaidReport': canViewUnpaidReport,
      'canViewPlanComptable': canViewPlanComptable,
      'canViewJournalComptable': canViewJournalComptable,
      'canViewTrialBalance': canViewTrialBalance,
      'canViewAgedBalance': canViewAgedBalance,
      'canViewCashControl': canViewCashControl,
      'canManageFiscalYears': canManageFiscalYears,
      'canManageReconciliation': canManageReconciliation,
      'canViewAudit': canViewAudit,
      'canViewExpenses': canViewExpenses,
      'canViewAdvances': canViewAdvances,
      'canViewTransfers': canViewTransfers,
      'canViewReminders': canViewReminders,
      'canViewWeather': canViewWeather,
      'canViewDeliveries': canViewDeliveries,
      'canManagePayroll': canManagePayroll,
      'canImportExport': canImportExport,
      'canManageWarehouses': canManageWarehouses,
      'canManageTasks': canManageTasks,
      'canViewStockMovements': canViewStockMovements,
      'canSuperviseTasks': canSuperviseTasks,
      'lastAction': lastAction,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.employee,
      ),
      warehouseId: map['warehouseId'],
      canViewPurchases: map['canViewPurchases'] ?? false,
      canViewSales: map['canViewSales'] ?? true,
      canDeleteSales: map['canDeleteSales'] ?? false,
      canViewProducts: map['canViewProducts'] ?? true,
      canEditProducts: map['canEditProducts'] ?? false,
      canDeleteProducts: map['canDeleteProducts'] ?? false,
      canManageUsers: map['canManageUsers'] ?? false,
      canViewClients: map['canViewClients'] ?? true,
      canViewSuppliers: map['canViewSuppliers'] ?? true,
      canEditTiers: map['canEditTiers'] ?? false,
      canDeleteTiers: map['canDeleteTiers'] ?? false,
      canViewTransport: map['canViewTransport'] ?? false,
      canEditTransport: map['canEditTransport'] ?? false,
      canViewPayments: map['canViewPayments'] ?? false,
      canAddClientPayment: map['canAddClientPayment'] ?? false,
      canAddSupplierPayment: map['canAddSupplierPayment'] ?? false,
      canDeletePayment: map['canDeletePayment'] ?? false,
      canViewAccounting: map['canViewAccounting'] ?? false,
      canViewUnpaidReport: map['canViewUnpaidReport'] ?? false,
      canViewPlanComptable: map['canViewPlanComptable'] ?? false,
      canViewJournalComptable: map['canViewJournalComptable'] ?? false,
      canViewTrialBalance: map['canViewTrialBalance'] ?? false,
      canViewAgedBalance: map['canViewAgedBalance'] ?? false,
      canViewCashControl: map['canViewCashControl'] ?? false,
      canManageFiscalYears: map['canManageFiscalYears'] ?? false,
      canManageReconciliation: map['canManageReconciliation'] ?? false,
      canViewAudit: map['canViewAudit'] ?? false,
      canViewExpenses: map['canViewExpenses'] ?? false,
      canViewAdvances: map['canViewAdvances'] ?? false,
      canViewTransfers: map['canViewTransfers'] ?? false,
      canViewReminders: map['canViewReminders'] ?? false,
      canViewWeather: map['canViewWeather'] ?? false,
      canViewDeliveries: map['canViewDeliveries'] ?? false,
      canManagePayroll: map['canManagePayroll'] ?? false,
      canImportExport: map['canImportExport'] ?? false,
      canManageWarehouses: map['canManageWarehouses'] ?? false,
      canManageTasks: map['canManageTasks'] ?? false,
      canViewStockMovements: map['canViewStockMovements'] ?? false,
      canSuperviseTasks: map['canSuperviseTasks'] ?? false,
      lastAction: map['lastAction'],
      lastSeen: map['lastSeen'] != null ? DateTime.tryParse(map['lastSeen']) : null,
    );
  }
}
