import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/firestore_service.dart';
import '../models/product.dart';
import '../models/tier.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMPORT / EXPORT SAGE GCM'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildImportCard(
                title: 'IMPORTER LES ARTICLES (SAGE)',
                icon: Icons.inventory_2,
                color: Colors.blue,
                description: 'Format attendu : Référence | Désignation | Compte Vente (7011...) | Compte Achat (6011...)',
                onTap: () => _importDialog(context, 'products'),
              ),
              const SizedBox(height: 20),
              _buildImportCard(
                title: 'IMPORTER LES CLIENTS / FOURNISSEURS',
                icon: Icons.people,
                color: Colors.green,
                description: 'Format attendu : Numéro | Intitulé | Téléphone | Adresse | Compte Comptable (411/401)',
                onTap: () => _importDialog(context, 'tiers'),
              ),
              const SizedBox(height: 20),
              _buildImportCard(
                title: 'IMPORTER LES SOLDES IMPAYÉS (SAGE)',
                icon: Icons.account_balance_wallet,
                color: Colors.orange,
                description: 'Format attendu : Date | N° Facture | Compte Tiers | Intitulé | Montant Facturé | Montant Réglé | Solde',
                onTap: () => _importDialog(context, 'balances'),
              ),
              const SizedBox(height: 40),
              if (_isImporting) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportCard({required String title, required IconData icon, required Color color, required String description, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 30, child: Icon(icon, color: color, size: 30)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 5),
                    Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Icon(Icons.upload_file, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _importDialog(BuildContext context, String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
    );

    if (result != null) {
      final fileBytes = result.files.first.bytes;
      if (fileBytes != null) {
        final content = utf8.decode(fileBytes);
        _processImport(type, content);
      }
    }
  }

  void _processImport(String type, String content) async {
    setState(() => _isImporting = true);
    final service = Provider.of<FirestoreService>(context, listen: false);

    int count = 0;

    if (type == 'balances') {
      count = await service.importSageBalances(content, 'Import Sage');
    } else {
      final lines = content.split('\n');
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(RegExp(r'[\t;]'));

        if (type == 'products' && parts.length >= 2) {
          final ref = parts[0].trim().toUpperCase();
          final name = parts[1].trim().toUpperCase();

          final allProducts = await service.getProducts().first;
          if (allProducts.any((p) => p.reference.toUpperCase() == ref || p.name.toUpperCase() == name)) {
            continue; // On ignore les doublons pendant l'import
          }

          final product = Product(
            id: '',
            reference: parts[0].trim(), // Référence Sage
            name: parts[1].trim(), // Désignation
            description: 'Importé Sage',
            purchasePrice: 0,
            sellingPrice: 0,
            totalQuantity: 0,
            category: 'IMPORT SAGE',
            compteVente: parts.length >= 3 ? parts[2].trim() : '70110000',
            compteAchat: parts.length >= 4 ? parts[3].trim() : '60110000',
          );
          await service.addProduct(product);
          count++;
        } else if (type == 'tiers' && parts.length >= 2) {
          final codeTiers = parts[0].trim().toUpperCase();
          final name = parts[1].trim().toUpperCase();

          final allTiers = await service.getTiers(null).first;
          if (allTiers.any((t) => t.compteTiers.toUpperCase() == codeTiers || t.name.toUpperCase() == name)) {
            continue;
          }

          final tier = Tier(
            id: '',
            name: parts[1].trim(), // Intitule
            type: parts[0].trim().toUpperCase().startsWith('401') ? TierType.supplier : TierType.client,
            // Correction du mapping Sage : 3eme colonne = Compte General, 4eme = Telephone
            compteGeneral: parts.length >= 3 ? parts[2].trim() : (parts[0].trim().toUpperCase().startsWith('401') ? '40110000' : '41110000'),
            phone: parts.length >= 4 ? parts[3].trim() : '',
            address: parts.length >= 5 ? parts[4].trim() : '',
            compteTiers: parts[0].trim().toUpperCase(), // Code Sage (ex: 411AZIZ)
          );
          await service.addTier(tier);
          count++;
        }
      }
    }

    if (mounted) {
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count enregistrements importés avec succès !'), backgroundColor: Colors.green));
    }
  }
}
