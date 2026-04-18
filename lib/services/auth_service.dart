import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();

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
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print('Erreur Connexion: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
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
    bool canViewAccounting = false,
    bool canManageUsers = false,
    bool canViewTiers = true,
    bool canEditTiers = false,
    bool canDeleteTiers = false,
    bool canViewTransport = false,
    bool canEditTransport = false,
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
          canViewPurchases: canViewPurchases,
          canViewSales: canViewSales,
          canDeleteSales: canDeleteSales,
          canViewProducts: canViewProducts,
          canEditProducts: canEditProducts,
          canDeleteProducts: canDeleteProducts,
          canViewAccounting: canViewAccounting,
          canManageUsers: canManageUsers,
          canViewTiers: canViewTiers,
          canEditTiers: canEditTiers,
          canDeleteTiers: canDeleteTiers,
          canViewTransport: canViewTransport,
          canEditTransport: canEditTransport,
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
