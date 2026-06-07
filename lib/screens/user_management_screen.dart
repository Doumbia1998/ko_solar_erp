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
  bool _canViewAccounting = false;
  bool _canManageUsers = false;
  bool _canViewTiers = true;
  bool _canEditTiers = false;
  bool _canDeleteTiers = false;
  bool _canViewTransport = false;
  bool _canEditTransport = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'storekeeper': return Colors.green;
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
    _canViewAccounting = user.canViewAccounting;
    _canManageUsers = user.canManageUsers;
    _canViewTiers = user.canViewTiers;
    _canEditTiers = user.canEditTiers;
    _canDeleteTiers = user.canDeleteTiers;
    _canViewTransport = user.canViewTransport;
    _canEditTransport = user.canEditTransport;

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
                const Text('Permissions détaillées', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildPermissionSwitch(setDialogState, 'Voir Achats', _canViewPurchases, (v) => _canViewPurchases = v),
                _buildPermissionSwitch(setDialogState, 'Voir Ventes', _canViewSales, (v) => _canViewSales = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Ventes', _canDeleteSales, (v) => _canDeleteSales = v),
                _buildPermissionSwitch(setDialogState, 'Voir Produits', _canViewProducts, (v) => _canViewProducts = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modif Produits', _canEditProducts, (v) => _canEditProducts = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Produits', _canDeleteProducts, (v) => _canDeleteProducts = v),
                _buildPermissionSwitch(setDialogState, 'Voir Comptabilité', _canViewAccounting, (v) => _canViewAccounting = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Utilisateurs', _canManageUsers, (v) => _canManageUsers = v),
                const Divider(),
                _buildPermissionSwitch(setDialogState, 'Voir Clients/Fourn.', _canViewTiers, (v) => _canViewTiers = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modifier Tiers', _canEditTiers, (v) => _canEditTiers = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Tiers', _canDeleteTiers, (v) => _canDeleteTiers = v),
                _buildPermissionSwitch(setDialogState, 'Voir Transport', _canViewTransport, (v) => _canViewTransport = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Transport', _canEditTransport, (v) => _canEditTransport = v),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
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
                  canViewAccounting: _canViewAccounting,
                  canManageUsers: _canManageUsers,
                  canViewTiers: _canViewTiers,
                  canEditTiers: _canEditTiers,
                  canDeleteTiers: _canDeleteTiers,
                  canViewTransport: _canViewTransport,
                  canEditTransport: _canEditTransport,
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
    // Reset permissions to default employee
    _canViewSales = _canViewProducts = _canViewTiers = true;
    _canViewPurchases = _canDeleteSales = _canEditProducts = _canDeleteProducts = _canViewAccounting = _canManageUsers = _canEditTiers = _canDeleteTiers = _canViewTransport = _canEditTransport = false;
    
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
                      // Pré-configuration par défaut selon le rôle
                      if (_selectedRole == UserRole.admin) {
                        _canViewPurchases = _canViewSales = _canDeleteSales = _canViewProducts = _canEditProducts = _canDeleteProducts = _canViewAccounting = _canManageUsers = true;
                      } else if (_selectedRole == UserRole.storekeeper) {
                        _canViewProducts = true;
                        _canViewPurchases = _canViewSales = _canDeleteSales = _canEditProducts = _canDeleteProducts = _canViewAccounting = _canManageUsers = false;
                      } else if (_selectedRole == UserRole.manager) {
                        _canViewPurchases = _canViewSales = _canViewProducts = _canEditProducts = _canViewTiers = _canEditTiers = true;
                        _canDeleteSales = _canDeleteProducts = _canViewAccounting = _canManageUsers = _canDeleteTiers = _canViewTransport = _canEditTransport = false;
                      } else {
                        _canViewSales = _canViewProducts = _canViewTiers = true;
                        _canViewPurchases = _canDeleteSales = _canEditProducts = _canDeleteProducts = _canViewAccounting = _canManageUsers = _canEditTiers = _canDeleteTiers = _canViewTransport = _canEditTransport = false;
                      }
                    });
                  },
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
                const Text('Permissions détaillées', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildPermissionSwitch(setDialogState, 'Voir Achats', _canViewPurchases, (v) => _canViewPurchases = v),
                _buildPermissionSwitch(setDialogState, 'Voir Ventes', _canViewSales, (v) => _canViewSales = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Ventes', _canDeleteSales, (v) => _canDeleteSales = v),
                _buildPermissionSwitch(setDialogState, 'Voir Produits', _canViewProducts, (v) => _canViewProducts = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modifier Produits', _canEditProducts, (v) => _canEditProducts = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Produits', _canDeleteProducts, (v) => _canDeleteProducts = v),
                _buildPermissionSwitch(setDialogState, 'Voir Comptabilité', _canViewAccounting, (v) => _canViewAccounting = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Utilisateurs', _canManageUsers, (v) => _canManageUsers = v),
                const Divider(),
                const Text('Clients, Fournisseurs & Transport', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildPermissionSwitch(setDialogState, 'Voir Clients/Fourn.', _canViewTiers, (v) => _canViewTiers = v),
                _buildPermissionSwitch(setDialogState, 'Créer/Modifier Tiers', _canEditTiers, (v) => _canEditTiers = v),
                _buildPermissionSwitch(setDialogState, 'Supprimer Tiers', _canDeleteTiers, (v) => _canDeleteTiers = v),
                _buildPermissionSwitch(setDialogState, 'Voir Transport', _canViewTransport, (v) => _canViewTransport = v),
                _buildPermissionSwitch(setDialogState, 'Gérer Transport', _canEditTransport, (v) => _canEditTransport = v),
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
                    // Passer les permissions
                    canViewPurchases: _canViewPurchases,
                    canViewSales: _canViewSales,
                    canDeleteSales: _canDeleteSales,
                    canViewProducts: _canViewProducts,
                    canEditProducts: _canEditProducts,
                    canDeleteProducts: _canDeleteProducts,
                    canViewAccounting: _canViewAccounting,
                    canManageUsers: _canManageUsers,
                    canViewTiers: _canViewTiers,
                    canEditTiers: _canEditTiers,
                    canDeleteTiers: _canDeleteTiers,
                    canViewTransport: _canViewTransport,
                    canEditTransport: _canEditTransport,
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
