import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';

class WhatsAppService {
  static Future<void> sendTransactionToWhatsApp(AppTransaction t, String phone) async {
    try {
      // 1. Nettoyage du numéro
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length == 8) cleanPhone = '223$cleanPhone';

      // 2. Préparation du message texte uniquement (0 stockage utilisé)
      String type = t.type == TransactionType.quote ? "DEVIS" : "FACTURE";
      double reste = t.netToPay - t.amountPaid;
      
      String message = "*KO SOLAR ERP - INFORMATION*\n\n"
          "Bonjour, voici le résumé de votre $type :\n"
          "▫️ N° : *${t.invoiceNumber}*\n"
          "▫️ Date : *${t.date.day}/${t.date.month}/${t.date.year}*\n"
          "▫️ Montant Total : *${t.netToPay.toInt()} FCFA*\n";

      if (t.type != TransactionType.quote) {
        message += "▫️ Déjà réglé : *${t.amountPaid.toInt()} FCFA*\n"
                   "▫️ *RESTE À PAYER : ${reste.toInt()} FCFA*\n";
      }

      message += "\nMerci de votre confiance !\n*L'équipe KO SOLAR*";

      final whatsappUrl = "https://wa.me/$cleanPhone?text=${Uri.encodeFull(message)}";

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      } else {
        throw "Impossible d'ouvrir WhatsApp.";
      }
      
    } catch (e) {
      rethrow;
    }
  }
}
