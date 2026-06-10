import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/transaction.dart';
import 'pdf_service.dart';

class WhatsAppService {
  static Future<void> sendTransactionToWhatsApp(AppTransaction t, String phone) async {
    try {
      // Nettoyer le numéro de téléphone
      String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (!cleanPhone.startsWith('223') && cleanPhone.length >= 8) {
        cleanPhone = '223$cleanPhone';
      }

      // 1. Générer le PDF en mémoire
      final Uint8List bytes = await PdfService.getInvoiceBytes(t);
      
      // 2. Envoyer sur Firebase Storage
      final fileName = "${t.type.toString().split('.').last}_${t.invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final storageRef = FirebaseStorage.instance.ref().child("temp_pdf/$fileName");
      
      await storageRef.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Préparer le message
      String type = t.type == TransactionType.quote ? "DEVIS" : "FACTURE";
      String message = "Bonjour,\n\nVoici votre $type : ${t.invoiceNumber}\n"
          "Montant : ${t.netToPay.toInt()} FCFA\n\n"
          "👉 Cliquez ici pour voir le document :\n$downloadUrl\n\n"
          "Merci de votre confiance !\n*KO SOLAR ERP*";

      final whatsappUrl = "https://api.whatsapp.com/send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}";
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      
    } catch (e) {
      rethrow;
    }
  }
}
