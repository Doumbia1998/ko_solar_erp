enum UserRole { admin, manager, employee, storekeeper, technician, tech_manager }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? warehouseId; // Dépôt assigné pour le magasinier

  // Permissions Granulaires
  final bool canViewPurchases;
  final bool canViewSales;
  final bool canDeleteSales;
  final bool canViewProducts;
  final bool canEditProducts;
  final bool canDeleteProducts;
  final bool canViewAccounting;
  final bool canManageUsers;
  
  // Nouvelles permissions demandées
  final bool canViewTiers; // Clients/Fournisseurs
  final bool canEditTiers;
  final bool canDeleteTiers;
  final bool canViewTransport;
  final bool canEditTransport;

  // Nouveaux modules
  final bool canViewAudit;
  final bool canViewExpenses;
  final bool canViewAdvances;
  final bool canViewTransfers;
  final bool canViewReminders;
  final bool canViewWeather;
  final bool canViewDeliveries;
  final bool canManagePayroll;
  final bool canImportExport;

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
    this.canViewAccounting = false,
    this.canManageUsers = false,
    this.canViewTiers = true,
    this.canEditTiers = false,
    this.canDeleteTiers = false,
    this.canViewTransport = false,
    this.canEditTransport = false,
    this.canViewAudit = false,
    this.canViewExpenses = false,
    this.canViewAdvances = false,
    this.canViewTransfers = false,
    this.canViewReminders = false,
    this.canViewWeather = false,
    this.canViewDeliveries = false,
    this.canManagePayroll = false,
    this.canImportExport = false,
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
      'canViewAccounting': canViewAccounting,
      'canManageUsers': canManageUsers,
      'canViewTiers': canViewTiers,
      'canEditTiers': canEditTiers,
      'canDeleteTiers': canDeleteTiers,
      'canViewTransport': canViewTransport,
      'canEditTransport': canEditTransport,
      'canViewAudit': canViewAudit,
      'canViewExpenses': canViewExpenses,
      'canViewAdvances': canViewAdvances,
      'canViewTransfers': canViewTransfers,
      'canViewReminders': canViewReminders,
      'canViewWeather': canViewWeather,
      'canViewDeliveries': canViewDeliveries,
      'canManagePayroll': canManagePayroll,
      'canImportExport': canImportExport,
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
      canViewAccounting: map['canViewAccounting'] ?? false,
      canManageUsers: map['canManageUsers'] ?? false,
      canViewTiers: map['canViewTiers'] ?? true,
      canEditTiers: map['canEditTiers'] ?? false,
      canDeleteTiers: map['canDeleteTiers'] ?? false,
      canViewTransport: map['canViewTransport'] ?? false,
      canEditTransport: map['canEditTransport'] ?? false,
      canViewAudit: map['canViewAudit'] ?? false,
      canViewExpenses: map['canViewExpenses'] ?? false,
      canViewAdvances: map['canViewAdvances'] ?? false,
      canViewTransfers: map['canViewTransfers'] ?? false,
      canViewReminders: map['canViewReminders'] ?? false,
      canViewWeather: map['canViewWeather'] ?? false,
      canViewDeliveries: map['canViewDeliveries'] ?? false,
      canManagePayroll: map['canManagePayroll'] ?? false,
      canImportExport: map['canImportExport'] ?? false,
    );
  }
}
