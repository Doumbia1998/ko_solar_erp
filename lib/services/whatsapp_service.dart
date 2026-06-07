import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';

class WhatsAppService {
  static Future<void> sendTransactionToWhatsApp(AppTransaction t, String phone) async {
    // Nettoyer le numéro de téléphone (garder que les chiffres)
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Ajouter l'indicatif pays si manquant (ex: 223 pour le Mali, à adapter selon votre pays)
    if (!cleanPhone.startsWith('223') && cleanPhone.length == 8) {
      cleanPhone = '223$cleanPhone';
    }

    String type = t.type == TransactionType.quote ? "DEVIS" : "FACTURE";
    String message = "Bonjour,\n\nVoici votre $type : ${t.invoiceNumber}\n"
        "Montant Total : ${t.netToPay.toInt()} FCFA\n\n"
        "Détail des articles :\n";
    
    for (var item in t.items) {
      message += "- ${item.productName} (x${item.quantity})\n";
    }
    
    message += "\nMerci de votre confiance !\n*KO SOLAR ERP*";

    final url = "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      throw 'Impossible de lancer WhatsApp';
    }
  }
}
