import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

  Stream<AppUser?> userProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists) {
        return AppUser.fromMap(snap.data()!);
      }
      return null;
    });
  }

  Future<AppUser?> getAppUser(String uid) async {
    try {
      var doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      } else {
        // Optionnel : Créer un utilisateur par défaut s'il n'existe pas dans Firestore
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          AppUser newUser = AppUser(
            uid: uid,
            email: currentUser.email ?? '',
            displayName: 'Utilisateur',
            role: UserRole.admin,
          );
          await _db.collection('users').doc(uid).set(newUser.toMap());
          return newUser;
        }
      }
    } catch (e) {
      print('Erreur getAppUser: $e');
    }
    return null;
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      // 1. Essai de connexion normale
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // 2. Si échec, on vérifie si l'admin a configuré un mot de passe temporaire dans Firestore
      try {
        var userDocs = await _db.collection('users').where('email', isEqualTo: email).get();
        if (userDocs.docs.isNotEmpty) {
          var userData = userDocs.docs.first.data();
          if (userData['tempPassword'] != null && userData['tempPassword'] == password) {
            // Le mot de passe temporaire correspond !
            // On connecte l'admin sur l'instance secondaire pour changer le vrai mot de passe Firebase
            return await _auth.signInWithEmailAndPassword(email: email, password: password);
          }
        }
      } catch (err) {
        print('Erreur secours : $err');
      }
      return null;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _db.collection('password_resets').add({
      'email': email,
      'status': 'en_attente',
      'date': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approvePasswordReset(String email, String newPass) async {
    // 1. On stocke le mot de passe temporaire dans Firestore
    var userDocs = await _db.collection('users').where('email', isEqualTo: email).get();
    if (userDocs.docs.isNotEmpty) {
      await _db.collection('users').doc(userDocs.docs.first.id).update({
        'tempPassword': newPass,
      });
      // 2. On marque la demande comme traitée
      var resetDocs = await _db.collection('password_resets').where('email', isEqualTo: email).get();
      for (var doc in resetDocs.docs) {
        await _db.collection('password_resets').doc(doc.id).delete();
      }
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception("Erreur lors de l'envoi de l'email de réinitialisation : $e");
    }
  }

  Future<void> registerNewUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    bool canViewPurchases = false,
    bool canViewSales = true,
    bool canDeleteSales = false,
    bool canViewProducts = true,
    bool canEditProducts = false,
    bool canDeleteProducts = false,
    bool canManageUsers = false,
    bool canViewClients = true,
    bool canViewSuppliers = true,
    bool canEditTiers = false,
    bool canDeleteTiers = false,
    bool canViewTransport = false,
    bool canEditTransport = false,
    bool canViewAudit = false,
    bool canViewExpenses = false,
    bool canViewAdvances = false,
    bool canViewTransfers = false,
    bool canViewReminders = false,
    bool canViewWeather = false,
    bool canViewDeliveries = false,
    bool canManagePayroll = false,
    bool canImportExport = false,
    bool canManageWarehouses = false,
    bool canManageTasks = false,
    bool canViewStockMovements = false,
    bool canViewAccounting = false,
    bool canViewUnpaidReport = false,
    bool canViewPlanComptable = false,
    bool canViewJournalComptable = false,
    bool canViewTrialBalance = false,
    bool canViewAgedBalance = false,
    bool canViewCashControl = false,
    bool canManageFiscalYears = false,
    bool canManageReconciliation = false,
    bool canViewPayments = false,
    bool canAddClientPayment = false,
    bool canAddSupplierPayment = false,
    bool canDeletePayment = false,
    String? warehouseId,
  }) async {
    // 1. Créer une instance secondaire pour ne pas déconnecter l'admin
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );

    try {
      // 2. Créer l'utilisateur dans Firebase Auth
      UserCredential credential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      if (credential.user != null) {
        // 3. Créer le document dans Firestore
        AppUser newUser = AppUser(
          uid: credential.user!.uid,
          email: email,
          displayName: displayName,
          role: role,
          warehouseId: warehouseId,
          canViewPurchases: canViewPurchases,
          canViewSales: canViewSales,
          canDeleteSales: canDeleteSales,
          canViewProducts: canViewProducts,
          canEditProducts: canEditProducts,
          canDeleteProducts: canDeleteProducts,
          canManageUsers: canManageUsers,
          canViewClients: canViewClients,
          canViewSuppliers: canViewSuppliers,
          canEditTiers: canEditTiers,
          canDeleteTiers: canDeleteTiers,
          canViewTransport: canViewTransport,
          canEditTransport: canEditTransport,
          canViewAudit: canViewAudit,
          canViewExpenses: canViewExpenses,
          canViewAdvances: canViewAdvances,
          canViewTransfers: canViewTransfers,
          canViewReminders: canViewReminders,
          canViewWeather: canViewWeather,
          canViewDeliveries: canViewDeliveries,
          canManagePayroll: canManagePayroll,
          canImportExport: canImportExport,
          canManageWarehouses: canManageWarehouses,
          canManageTasks: canManageTasks,
          canViewStockMovements: canViewStockMovements,
          canViewAccounting: canViewAccounting,
          canViewUnpaidReport: canViewUnpaidReport,
          canViewPlanComptable: canViewPlanComptable,
          canViewJournalComptable: canViewJournalComptable,
          canViewTrialBalance: canViewTrialBalance,
          canViewAgedBalance: canViewAgedBalance,
          canViewCashControl: canViewCashControl,
          canManageFiscalYears: canManageFiscalYears,
          canManageReconciliation: canManageReconciliation,
          canViewPayments: canViewPayments,
          canAddClientPayment: canAddClientPayment,
          canAddSupplierPayment: canAddSupplierPayment,
          canDeletePayment: canDeletePayment,
        );
        await _db.collection('users').doc(credential.user!.uid).set(newUser.toMap());
      }
      
      // 4. Supprimer l'instance secondaire
      await secondaryApp.delete();
    } catch (e) {
      await secondaryApp.delete();
      throw Exception("Erreur lors de la création : $e");
    }
  }
}
