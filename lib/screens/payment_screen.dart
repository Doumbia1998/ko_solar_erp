import 'package:flutter/material.dart';
import '../models/tier.dart';
import 'professional_payment_screen.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GESTION DES RÈGLEMENTS'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildBigButton(
              context,
              'Saisie des Règlements Clients',
              Icons.person_add_alt_1,
              Colors.blue.shade900,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfessionalPaymentScreen(type: TierType.client))),
            ),
            const SizedBox(height: 20),
            _buildBigButton(
              context,
              'Saisie des Règlements Fournisseurs',
              Icons.business_center,
              Colors.teal.shade800,
              () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfessionalPaymentScreen(type: TierType.supplier))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
