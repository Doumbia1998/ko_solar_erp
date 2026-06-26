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
  final List<String> _selectedClientIds = [];

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
                  const Spacer(),
                  if (_selectedClientIds.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sendToSelected,
                        icon: const Icon(Icons.send),
                        label: Text('ENVOYER À (${_selectedClientIds.length}) SÉLECTIONNÉS'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. SÉLECTIONNER LES DESTINATAIRES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      StreamBuilder<List<Tier>>(
                        stream: service.getTiers(TierType.client),
                        builder: (context, snapshot) {
                          final clients = snapshot.data ?? [];
                          return TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (_selectedClientIds.length == clients.length) {
                                  _selectedClientIds.clear();
                                } else {
                                  _selectedClientIds.clear();
                                  _selectedClientIds.addAll(clients.map((c) => c.id));
                                }
                              });
                            },
                            icon: Icon(_selectedClientIds.length == clients.length ? Icons.deselect : Icons.select_all),
                            label: Text(_selectedClientIds.length == clients.length ? 'TOUT DÉSELECTIONNER' : 'TOUT SÉLECTIONNER'),
                          );
                        }
                      ),
                    ],
                  ),
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
                            final isSelected = _selectedClientIds.contains(c.id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedClientIds.add(c.id);
                                  } else {
                                    _selectedClientIds.remove(c.id);
                                  }
                                });
                              },
                              title: Text(c.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(c.phone),
                              secondary: CircleAvatar(
                                backgroundColor: isSelected ? Colors.green : Colors.grey.shade200,
                                child: Icon(isSelected ? Icons.check : Icons.person, color: isSelected ? Colors.white : Colors.grey),
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

  void _sendToSelected() async {
    final service = Provider.of<FirestoreService>(context, listen: false);
    final allClients = await service.getTiers(TierType.client).first;
    final selectedClients = allClients.where((c) => _selectedClientIds.contains(c.id)).toList();

    for (var client in selectedClients) {
      await _sendToClient(client);
      // On ajoute un petit délai pour éviter de saturer le navigateur
      await Future.delayed(const Duration(milliseconds: 500));
    }
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
