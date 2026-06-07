import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/journal_entry.dart';
import '../models/account.dart';
import '../models/tier.dart';
import 'package:uuid/uuid.dart';

class JournalFormScreen extends StatefulWidget {
  final JournalEntry? existingEntry; // Pour la modification
  final String? initialJournalCode; // Journal suggéré
  final DateTime? initialDate;      // Date suggérée

  const JournalFormScreen({
    super.key, 
    this.existingEntry,
    this.initialJournalCode,
    this.initialDate,
  });

  @override
  State<JournalFormScreen> createState() => _JournalFormScreenState();
}

class _JournalFormScreenState extends State<JournalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _labelController;
  late TextEditingController _referenceController;
  late String _selectedJournal;
  final List<String> _journals = ['ACH', 'VEN', 'BQ', 'CAI', 'OD', 'PAIE', 'RAN', 'CAS', 'CAP', 'CAD'];

  late List<JournalLine> _lines;

  @override
  void initState() {
    super.initState();
    final entry = widget.existingEntry;
    
    // Priorité : 1. Entrée existante, 2. Paramètre initial, 3. Date du jour
    _selectedDate = entry?.date ?? widget.initialDate ?? DateTime.now();
    _labelController = TextEditingController(text: entry?.label);
    _referenceController = TextEditingController(text: entry?.reference);
    
    // Priorité : 1. Entrée existante, 2. Paramètre initial, 3. Valeur par défaut
    _selectedJournal = entry?.journalCode ?? widget.initialJournalCode ?? 'OD';

    if (entry != null) {
      _lines = [
        JournalLine(
          debit: entry.debit,
          credit: entry.credit,
        )
      ];
    } else {
      _lines = [JournalLine(), JournalLine()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry == null ? 'Nouvelle Écriture' : 'Modifier l\'Écriture'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Account>>(
        stream: service.getAccounts(),
        builder: (context, snapshotAcc) {
          return StreamBuilder<List<Tier>>(
            stream: service.getTiers(null),
            builder: (context, snapshotTier) {
              if (!snapshotAcc.hasData || !snapshotTier.hasData) return const Center(child: CircularProgressIndicator());
              
              final accounts = snapshotAcc.data!;
              final allTiers = snapshotTier.data!;

              // Initialisation des comptes pour le mode édition
              if (widget.existingEntry != null && _lines[0].account == null) {
                try {
                  _lines[0].account = accounts.firstWhere((a) => a.code == widget.existingEntry!.accountCode);
                } catch(_) {}
                
                if (widget.existingEntry!.tierId != null) {
                  try {
                    _lines[0].tier = allTiers.firstWhere((t) => t.id == widget.existingEntry!.tierId);
                  } catch(_) {}
                }
              }

              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedJournal,
                              decoration: const InputDecoration(labelText: 'Journal', border: OutlineInputBorder()),
                              items: _journals.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                              onChanged: (val) => setState(() => _selectedJournal = val!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(labelText: 'Libellé de l\'opération', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _referenceController,
                        decoration: const InputDecoration(labelText: 'Référence (N° Pièce)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 24),
                      Text(widget.existingEntry == null ? 'Détails de l\'écriture' : 'Détail de la ligne', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(),
                      ..._lines.asMap().entries.map((entry) {
                        int idx = entry.key;
                        JournalLine line = entry.value;
                        
                        bool needsTier = line.account != null && 
                            (line.account!.nature == 'Client' || line.account!.nature == 'Fournisseur');
                        
                        List<Tier> filteredTiers = allTiers.where((t) => 
                          (line.account?.nature == 'Client' && t.type == TierType.client) ||
                          (line.account?.nature == 'Fournisseur' && t.type == TierType.supplier)
                        ).toList();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<Account>(
                                        value: line.account,
                                        hint: const Text('Compte Général'),
                                        isExpanded: true,
                                        items: accounts.map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text('${a.code} - ${a.label}', overflow: TextOverflow.ellipsis),
                                        )).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            line.account = val;
                                            line.tier = null;
                                          });
                                        },
                                        validator: (val) => val == null ? 'Requis' : null,
                                      ),
                                    ),
                                    if (widget.existingEntry == null)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        if (_lines.length > 2) {
                                          setState(() => _lines.removeAt(idx));
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (needsTier) ...[
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<Tier>(
                                    value: line.tier,
                                    hint: Text('Sélectionner le ${line.account!.nature}'),
                                    isExpanded: true,
                                    items: filteredTiers.map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.name.toUpperCase()),
                                    )).toList(),
                                    onChanged: (val) => setState(() => line.tier = val),
                                    validator: (val) => needsTier && val == null ? 'Tier obligatoire' : null,
                                  ),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: line.debit == 0 ? '' : line.debit.toString(),
                                        decoration: const InputDecoration(labelText: 'Débit'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          line.debit = double.tryParse(val) ?? 0;
                                          if (line.debit > 0) line.credit = 0;
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: line.credit == 0 ? '' : line.credit.toString(),
                                        decoration: const InputDecoration(labelText: 'Crédit'),
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          line.credit = double.tryParse(val) ?? 0;
                                          if (line.credit > 0) line.debit = 0;
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      if (widget.existingEntry == null)
                      TextButton.icon(
                        onPressed: () => setState(() => _lines.add(JournalLine())),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une ligne'),
                      ),
                      const SizedBox(height: 24),
                      if (widget.existingEntry == null) _buildTotalsRow(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
                          onPressed: () => _saveEntry(service),
                          child: Text(widget.existingEntry == null ? 'ENREGISTRER L\'ÉCRITURE' : 'MODIFIER L\'ÉCRITURE', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTotalsRow() {
    double totalDebit = _lines.fold(0, (sum, item) => sum + item.debit);
    double totalCredit = _lines.fold(0, (sum, item) => sum + item.credit);
    bool isBalanced = (totalDebit - totalCredit).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBalanced ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isBalanced ? Colors.green : Colors.red),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Débit: ${NumberFormat('#,###').format(totalDebit)} F'),
              Text('Total Crédit: ${NumberFormat('#,###').format(totalCredit)} F'),
            ],
          ),
          if (isBalanced && totalDebit > 0)
            const Icon(Icons.check_circle, color: Colors.green)
          else
            const Text('Non équilibré', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _saveEntry(FirestoreService service) async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.existingEntry == null) {
      double totalDebit = _lines.fold(0, (sum, item) => sum + item.debit);
      double totalCredit = _lines.fold(0, (sum, item) => sum + item.credit);
      if ((totalDebit - totalCredit).abs() > 0.01 || totalDebit == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'écriture doit être équilibrée.')));
        return;
      }
    }

    try {
      final String ref = _referenceController.text.isEmpty ? 'PIECE-${const Uuid().v4().substring(0, 8).toUpperCase()}' : _referenceController.text;

      if (widget.existingEntry != null) {
        // Mode Modification
        final line = _lines[0];
        await service.updateJournalEntry(JournalEntry(
          id: widget.existingEntry!.id,
          date: _selectedDate,
          label: _labelController.text,
          accountCode: line.account!.code,
          accountLabel: line.account!.label,
          debit: line.debit,
          credit: line.credit,
          reference: ref,
          journalCode: _selectedJournal,
          tierId: line.tier?.id,
          tierName: line.tier?.name,
        ));
      } else {
        // Mode Création
        for (var line in _lines) {
          if (line.debit == 0 && line.credit == 0) continue;
          await service.addJournalEntry(JournalEntry(
            id: '',
            date: _selectedDate,
            label: _labelController.text,
            accountCode: line.account!.code,
            accountLabel: line.account!.label,
            debit: line.debit,
            credit: line.credit,
            reference: ref,
            journalCode: _selectedJournal,
            tierId: line.tier?.id,
            tierName: line.tier?.name,
          ));
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.existingEntry == null ? 'Enregistré' : 'Mis à jour')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}

class JournalLine {
  Account? account;
  Tier? tier;
  double debit;
  double credit;

  JournalLine({this.account, this.tier, this.debit = 0, this.credit = 0});
}
