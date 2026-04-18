enum UserRole { admin, manager, employee }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

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

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last,
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
    );
  }
}
