import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rxdart/rxdart.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'models/app_user.dart';
import 'firebase_options.dart'; 

import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('fr_FR', null);
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Erreur Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        StreamProvider<AppUser?>(
          create: (context) {
            final authService = context.read<AuthService>();
            return authService.user.switchMap((user) {
              if (user == null) return Stream.value(null);
              return authService.userProfile(user.uid);
            });
          },
          initialData: null,
        ),
      ],
      child: MaterialApp(
         title: 'K-O SOLAR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A237E),
            primary: const Color(0xFF1A237E),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Timer? _inactivityTimer;

  void _resetTimer(AuthService authService) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 10), () {
      debugPrint('Déconnexion automatique pour inactivité (10 min)');
      authService.signOut();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<AppUser?>(
      stream: authService.user.switchMap((user) {
        if (user == null) return Stream.value(null);
        return authService.userProfile(user.uid);
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            ),
          );
        }
        
        final appUser = snapshot.data;
        if (appUser != null) {
          // On enveloppe le Dashboard dans un Listener pour détecter l'activité
          return Listener(
            onPointerDown: (_) => _resetTimer(authService),
            onPointerMove: (_) => _resetTimer(authService),
            child: const DashboardScreen(),
          );
        } else {
          _inactivityTimer?.cancel();
          return const LoginScreen();
        }
      },
    );
  }
}
