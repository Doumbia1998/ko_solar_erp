import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/tier.dart';
import '../services/firestore_service.dart';

class WhatsAppService {
  static Future<void> sendTransactionToWhatsApp(AppTransaction t, String tierId) async {
    try {
      // Pour le Web, on évite les manipulations complexes et on passe par le texte direct
      String type = "FACTURE";
      if (t.type == TransactionType.quote) type = "DEVIS";
      if (t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn) type = "RETOUR";

      double reste = t.netToPay - t.amountPaid;
      
      String message = "*KO SOLAR ERP - RÉSUMÉ*\n\n"
          "Bonjour, voici les détails de votre $type :\n"
          "▫️ N° : *${t.invoiceNumber}*\n"
          "▫️ Date : *${t.date.day}/${t.date.month}/${t.date.year}*\n"
          "▫️ Montant Total : *${t.netToPay.abs().toInt()} FCFA*\n";

      if (t.type == TransactionType.sale || t.type == TransactionType.purchase) {
        message += "▫️ Déjà réglé : *${t.amountPaid.toInt()} FCFA*\n"
                   "▫️ *RESTE À PAYER : ${reste.toInt()} FCFA*\n";
        if (t.dueDate != null && reste > 10) {
          message += "▫️ Échéance : *${t.date.day}/${t.date.month}/${t.date.year}*\n";
        }
      }

      message += "\nMerci de votre confiance !\n*KO SOLAR*";

      // On tente d'ouvrir wa.me avec le numéro du client s'il est disponible
      // Sinon on ouvre juste WhatsApp
      final url = "https://wa.me/?text=${Uri.encodeFull(message)}";
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Erreur WhatsApp: $e");
    }
  }
}
