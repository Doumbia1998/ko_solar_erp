import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/tier.dart';

class WeatherAlertScreen extends StatefulWidget {
  const WeatherAlertScreen({super.key});

  @override
  State<WeatherAlertScreen> createState() => _WeatherAlertScreenState();
}

class _WeatherAlertScreenState extends State<WeatherAlertScreen> {
  final _messageController = TextEditingController(
    text: "☀️ *ALERTE PRÉVENTION KO SOLAR*\n\n"
         "Cher client, une alerte météo est annoncée. Pour protéger vos installations :\n"
         "1️⃣ Vérifiez la fixation de vos panneaux.\n"
         "2️⃣ Surveillez vos batteries lithium.\n"
         "3️⃣ Évitez les surcharges.\n\n"
         "Besoin d'aide ? Contactez-nous !\n*KO SOLAR ERP*"
  );

  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DIFFUSION ALERTE MÉTEO'),
        backgroundColor: Colors.orange.shade900,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Partie gauche : Rédaction du message
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. RÉDIGER LE MESSAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _messageController,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      hintText: 'Saisissez votre message ici...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const Text('Le message sera envoyé individuellement à chaque client sélectionné.', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                ],
              ),
            ),
          ),

          // Partie droite : Liste des clients
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. SÉLECTIONNER LES DESTINATAIRES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un client...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: StreamBuilder<List<Tier>>(
                      stream: service.getTiers(TierType.client),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        var clients = snapshot.data!;
                        if (_searchQuery.isNotEmpty) {
                          clients = clients.where((c) => c.name.toLowerCase().contains(_searchQuery)).toList();
                        }

                        return ListView.separated(
                          itemCount: clients.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final c = clients[index];
                            return ListTile(
                              title: Text(c.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c.phone),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _sendToClient(c),
                                icon: const Icon(Icons.send, size: 16),
                                label: const Text('ENVOYER'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToClient(Tier client) async {
    if (client.phone.isEmpty) return;

    // Nettoyage du numéro
    String phone = client.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 8) phone = '223$phone';

    final message = Uri.encodeFull(_messageController.text);
    final url = "https://wa.me/$phone?text=$message";

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
