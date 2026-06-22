import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/payment.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';
import '../models/journal_config.dart';
import '../models/payment_method_config.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';

class ProfessionalPaymentScreen extends StatefulWidget {
  final TierType type;
  const ProfessionalPaymentScreen({super.key, required this.type});

  @override
  State<ProfessionalPaymentScreen> createState() => _ProfessionalPaymentScreenState();
}

class _ProfessionalPaymentScreenState extends State<ProfessionalPaymentScreen> {
  Tier? _selectedTier;
  final NumberFormat _format = NumberFormat('#,###', 'fr_FR');
  String _filter = 'Tous';

  final _dateController = TextEditingController(text: DateFormat('ddMMyy').format(DateTime.now()));
  final _pieceController = TextEditingController();
  final _libelleController = TextEditingController();
  final _montantController = TextEditingController();
  String? _selectedJournalCode;
  String? _selectedMethod;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  String _tierSearchQuery = "";

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FirestoreService>(context);
    final isClient = widget.type == TierType.client;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text(isClient ? 'Saisie des règlements clients' : 'Saisie des règlements fournisseurs', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF454545),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          _toolbarButton(Icons.settings, 'Paramètres', onTap: () => _showJournalConfig(context, service)),
          const SizedBox(width: 10),
          if (_selectedTier != null)
            _toolbarButton(Icons.playlist_add_check, 'Sélectionner',
              onTap: () => _openMaturitySelection(context, service)),
          const SizedBox(width: 10),
          _toolbarButton(Icons.print, 'Imprimer', onTap: () => _printDailyPayments(service)),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              border: Border(right: BorderSide(color: Colors.grey.shade400, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _sidebarItem('Tous'),
                _sidebarItem('Règlements non imputés'),
                _sidebarItem('Règlements soldés'),
                const Spacer(),
                if (_filterStartDate != null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('FILTRE : ${DateFormat('dd/MM/yy').format(_filterStartDate!)} AU ${DateFormat('dd/MM/yy').format(_filterEndDate!)}',
                      style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('PLUS DE CRITÈRES...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                  child: Row(
                    children: [
                      Text(isClient ? 'Client' : 'Fournisseur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 25),
                      Expanded(
                        child: StreamBuilder<List<Tier>>(
                          stream: service.getTiers(widget.type),
                          builder: (context, snapshot) {
                            var tiers = snapshot.data ?? [];
                            if (_tierSearchQuery.isNotEmpty) {
                              tiers = tiers.where((t) => t.name.toLowerCase().contains(_tierSearchQuery.toLowerCase()) || t.compteTiers.contains(_tierSearchQuery.toUpperCase())).toList();
                            }
                            return Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<Tier>(
                                        isExpanded: true,
                                        value: _selectedTier,
                                        hint: Text(_tierSearchQuery.isEmpty ? "Chercher un compte..." : _tierSearchQuery),
                                        style: const TextStyle(fontSize: 14, color: Colors.black),
                                        items: tiers.map((t) => DropdownMenuItem(value: t, child: Text('${t.compteTiers} ${t.name.toUpperCase()}'))).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedTier = val;
                                            _libelleController.text = 'RÈGLEMENT ${_selectedTier!.name.toUpperCase()}';
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const VerticalDivider(),
                                  SizedBox(
                                    width: 150,
                                    child: TextField(
                                      decoration: const InputDecoration(hintText: "Rechercher...", border: InputBorder.none, isDense: true),
                                      style: const TextStyle(fontSize: 12),
                                      onChanged: (v) => setState(() => _tierSearchQuery = v),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text('Journal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      StreamBuilder<List<JournalConfig>>(
                        stream: service.getJournalConfigs(),
                        builder: (context, snapshot) {
                          final configs = snapshot.data ?? [];
                          if (_selectedJournalCode == null && configs.isNotEmpty) _selectedJournalCode = configs.first.code;
                          return Container(
                            height: 40,
                            width: 100,
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedJournalCode,
                                isExpanded: true,
                                items: configs.map((c) => DropdownMenuItem(value: c.code, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(c.code)))).toList(),
                                onChanged: (val) => setState(() => _selectedJournalCode = val!),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: const Color(0xFFE2E8F0),
                  child: Row(
                    children: [
                      _inputBox('Date', 90, controller: _dateController),
                      _inputBox('N° Pièce', 140, controller: _pieceController),
                      _inputBox('Libellé', 300, controller: _libelleController),
                      StreamBuilder<List<PaymentMethodConfig>>(
                        stream: service.getPaymentMethodConfigs(),
                        builder: (context, snapshot) {
                          final methods = snapshot.data ?? [];
                          if (_selectedMethod == null && methods.isNotEmpty) _selectedMethod = methods.first.name;
                          return _dropdownBox('Mode', 160, _selectedMethod ?? '', methods.map((m) => m.name).toList(), (val) => setState(() => _selectedMethod = val!));
                        },
                      ),
                      _inputBox('Montant', 150, controller: _montantController, isNumeric: true),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _saveFastEntry,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F855A), foregroundColor: Colors.white, minimumSize: const Size(120, 40)),
                        child: const Text('ENREGISTRER'),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: _selectedTier == null
                        ? const Center(child: Text('Sélectionnez un compte tiers.'))
                        : StreamBuilder<List<Payment>>(
                            stream: service.getPayments(tierId: _selectedTier!.id),
                            builder: (context, snapshot) {
                              return StreamBuilder<List<AppTransaction>>(
                                stream: service.getTransactions(),
                                builder: (context, snapshotTrans) {
                                  var payments = snapshot.data ?? [];
                                  final allTxs = snapshotTrans.data ?? [];
                                  final returns = allTxs.where((t) => t.tierId == _selectedTier!.id && (t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn)).toList();
                                  List<dynamic> entries = [...payments, ...returns];
                                  entries.sort((a, b) {
                                    DateTime dateA = a is Payment ? a.date : (a as AppTransaction).date;
                                    DateTime dateB = b is Payment ? b.date : (b as AppTransaction).date;
                                    return dateB.compareTo(dateA);
                                  });

                                  return ListView(
                                    children: [
                                      DataTable(
                                        horizontalMargin: 10,
                                        columnSpacing: 10,
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFF2D3748)),
                                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        columns: const [
                                          DataColumn(label: Text('Date')),
                                          DataColumn(label: Text('N° pièce')),
                                          DataColumn(label: Text('Libellé')),
                                          DataColumn(label: Text('Mode règlement')),
                                          DataColumn(label: Text('Montant')),
                                          DataColumn(label: Text('Journal')),
                                          DataColumn(label: Text('Action')),
                                        ],
                                        rows: entries.map((e) {
                                          if (e is Payment) {
                                            return DataRow(cells: [
                                              DataCell(Text(DateFormat('dd/MM/yy').format(e.date))),
                                              DataCell(Text(e.reference)),
                                              DataCell(Text(e.invoiceNumber != null ? 'ENC FA${e.invoiceNumber}' : e.reference)),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(e.method),
                                                  if (e.createdBy.isNotEmpty)
                                                    Text('Fait par: ${e.createdBy}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                                                ],
                                              )),
                                              DataCell(Text(_format.format(e.amount).replaceAll(',', ' '), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                                              DataCell(_rowJournalDropdown(e, service)),
                                              DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () async {
                                                final auth = Provider.of<AuthService>(context, listen: false);
                                                final user = await auth.getAppUser((await auth.user.first)!.uid);
                                                await service.deletePayment(e.id, user?.displayName ?? 'Admin');
                                              })),
                                            ]);
                                          } else {
                                            final t = e as AppTransaction;
                                            return DataRow(color: WidgetStateProperty.all(Colors.red.shade50), cells: [
                                              DataCell(Text(DateFormat('dd/MM/yy').format(t.date))),
                                              DataCell(Text(t.invoiceNumber)),
                                              const DataCell(Text('RETOUR MARCHANDISE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Text('AVOIR'),
                                                  if (t.createdBy.isNotEmpty)
                                                    Text('Fait par: ${t.createdBy}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.red)),
                                                ],
                                              )),
                                              DataCell(Text('- ${_format.format(t.netToPay.abs()).replaceAll(',', ' ')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                              const DataCell(Text('OD')),
                                              const DataCell(SizedBox()),
                                            ]);
                                          }
                                        }).toList(),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),

                if (_selectedTier != null)
                  StreamBuilder<List<Payment>>(
                    stream: service.getPayments(tierId: _selectedTier!.id),
                    builder: (context, snapshot) {
                      final payments = snapshot.data ?? [];
                      double total = payments.fold(0, (sum, p) => sum + p.amount);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        color: const Color(0xFFF0FFF4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _summary('Total règlement', total),
                            _summary('Solde', 0, isBold: true),
                            const SizedBox(width: 80),
                            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER')),
                          ],
                        ),
                      );
                    }
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowJournalDropdown(Payment p, FirestoreService service) {
    return StreamBuilder<List<JournalConfig>>(
      stream: service.getJournalConfigs(),
      builder: (context, snapshot) {
        final configs = snapshot.data ?? [];
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: p.journalCode ?? 'CA',
            style: const TextStyle(fontSize: 12, color: Colors.black),
            items: configs.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
            onChanged: (val) async {
              await service.updatePaymentJournal(p.id, val!);
            },
          ),
        );
      },
    );
  }

  void _selectDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() { _filterStartDate = picked.start; _filterEndDate = picked.end; });
  }

  void _printDailyPayments(FirestoreService service) async {
    final payments = await service.getPayments().first;
    final now = DateTime.now();
    final start = _filterStartDate ?? now;
    final end = _filterEndDate ?? now;
    var filtered = payments.where((p) => p.date.isAfter(start.subtract(const Duration(days: 1))) && p.date.isBefore(end.add(const Duration(days: 1))) && p.tierType == widget.type).toList();
    if (_selectedTier != null) filtered = filtered.where((p) => p.tierId == _selectedTier!.id).toList();

    if (filtered.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun règlement trouvé pour l\'impression.')));
      }
      return;
    }
    ReportService.generateDailyPaymentsReport(filtered, widget.type == TierType.client ? 'Clients' : 'Fournisseurs', tierName: _selectedTier?.name, start: _filterStartDate, end: _filterEndDate);
  }

  void _saveFastEntry() async {
    if (_selectedTier == null) return;
    double amount = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = await auth.getAppUser((await auth.user.first)!.uid);
    final p = Payment(
      id: '',
      tierId: _selectedTier!.id,
      tierName: _selectedTier!.name,
      tierType: widget.type,
      amount: amount,
      date: DateTime.now(),
      method: _selectedMethod ?? 'Espèces',
      journalCode: _selectedJournalCode,
      reference: _pieceController.text.isEmpty ? 'RC${DateFormat('ddMMyy').format(DateTime.now())}' : _pieceController.text
    );
    await Provider.of<FirestoreService>(context, listen: false).addPayment(p, user?.displayName ?? 'User');
    _resetEntry();
  }

  void _resetEntry() {
    setState(() { _pieceController.clear(); _libelleController.text = _selectedTier != null ? 'RÈGLEMENT ${_selectedTier!.name.toUpperCase()}' : ''; _montantController.clear(); });
  }

  Widget _inputBox(String hint, double width, {TextEditingController? controller, bool isNumeric = false}) {
    return Container(width: width, height: 38, margin: const EdgeInsets.only(right: 12), child: TextField(controller: controller, keyboardType: isNumeric ? TextInputType.number : TextInputType.text, decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 10), filled: true, fillColor: Colors.white, border: const OutlineInputBorder()), style: const TextStyle(fontSize: 13)));
  }

  Widget _dropdownBox(String label, double width, String value, List<String> items, Function(String?) onChanged) {
    return Container(width: width, height: 38, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, style: const TextStyle(fontSize: 13, color: Colors.black), items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: onChanged)));
  }

  Widget _sidebarItem(String label) {
    bool isSelected = _filter == label;
    return InkWell(onTap: () => setState(() => _filter = label), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), decoration: BoxDecoration(color: isSelected ? Colors.white : null, border: isSelected ? const Border(left: BorderSide(color: Colors.blue, width: 5)) : null), child: Text(label, style: TextStyle(fontSize: 14, color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))));
  }

  Widget _toolbarButton(IconData icon, String label, {VoidCallback? onTap}) {
    return TextButton.icon(onPressed: onTap ?? () {}, icon: Icon(icon, color: Colors.white, size: 20), label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)));
  }

  Widget _summary(String label, double val, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.only(left: 60), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(_format.format(val).replaceAll(',', ' '), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w700, fontSize: 18, color: isBold ? Colors.black : Colors.green.shade800))]));
  }

  void _showJournalConfig(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: const Text('Paramètres Règlements'),
          content: SizedBox(
            width: 600,
            height: 500,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    Tab(text: 'COURS JOURNAUX'),
                    Tab(text: 'MODES RÈGLEMENT'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Onglet 1: Journaux
                      Column(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<JournalConfig>>(
                              stream: service.getJournalConfigs(),
                              builder: (context, snapshot) {
                                final configs = snapshot.data ?? [];
                                return ListView.builder(
                                  itemCount: configs.length,
                                  itemBuilder: (context, index) => ListTile(
                                    title: Text(configs[index].code, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(configs[index].name),
                                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => service.deleteJournalConfig(configs[index].id)),
                                  ),
                                );
                              },
                            ),
                          ),
                          ElevatedButton.icon(onPressed: () => _addJournalDialog(context, service), icon: const Icon(Icons.add), label: const Text('AJOUTER UN JOURNAL')),
                        ],
                      ),
                      // Onglet 2: Modes règlement
                      Column(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<PaymentMethodConfig>>(
                              stream: service.getPaymentMethodConfigs(),
                              builder: (context, snapshot) {
                                final methods = snapshot.data ?? [];
                                return ListView.builder(
                                  itemCount: methods.length,
                                  itemBuilder: (context, index) => ListTile(
                                    title: Text(methods[index].name),
                                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => service.deletePaymentMethodConfig(methods[index].id)),
                                  ),
                                );
                              },
                            ),
                          ),
                          ElevatedButton.icon(onPressed: () => _addPaymentMethodDialog(context, service), icon: const Icon(Icons.add), label: const Text('AJOUTER UN MODE')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('FERMER'))],
        ),
      ),
    );
  }

  void _addJournalDialog(BuildContext context, FirestoreService service) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Nouveau Journal'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')), TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Désignation'))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')), ElevatedButton(onPressed: () { if (codeCtrl.text.isNotEmpty) { service.addJournalConfig(JournalConfig(id: '', code: codeCtrl.text.toUpperCase(), name: nameCtrl.text)); Navigator.pop(context); } }, child: const Text('CRÉER'))]));
  }

  void _addPaymentMethodDialog(BuildContext context, FirestoreService service) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Mode de Règlement'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du mode (ex: BIM SA, ORANGE MONEY)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.isNotEmpty) {
              service.addPaymentMethodConfig(PaymentMethodConfig(id: '', name: nameCtrl.text));
              Navigator.pop(context);
            }
          }, child: const Text('CRÉER')),
        ],
      ),
    );
  }

  void _openMaturitySelection(BuildContext context, FirestoreService service) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = await auth.user.first;
    final appUser = await auth.getAppUser(user!.uid);
    showDialog(context: context, builder: (context) => MaturitySelectionDialog(tier: _selectedTier!, service: service, userName: appUser?.displayName ?? 'User', journalCode: _selectedJournalCode));
  }
}

class MaturitySelectionDialog extends StatefulWidget {
  final Tier tier;
  final FirestoreService service;
  final String userName;
  final String? journalCode;

  const MaturitySelectionDialog({super.key, required this.tier, required this.service, required this.userName, this.journalCode});

  @override
  State<MaturitySelectionDialog> createState() => _MaturitySelectionDialogState();
}

class _MaturitySelectionDialogState extends State<MaturitySelectionDialog> {
  final Map<String, TextEditingController> _controllers = {};
  double _montantRegle = 0;
  final _montantRegleController = TextEditingController();
  String? _selectedMode; // Nouveau

  @override
  void dispose() {
    _controllers.forEach((key, value) => value.dispose());
    _montantRegleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        color: const Color(0xFFF1F3F4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sélection des échéances à régler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 24)),
          ],
        )
      ),
      content: SizedBox(
        width: 1200,
        height: 800,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.5))),
              child: Row(
                children: [
                  const Icon(Icons.check_box_outline_blank, size: 20, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Text('Enregistrer un écart de règlement', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  const Text('Montant réglé : ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: 160,
                    height: 40,
                    child: TextField(
                      controller: _montantRegleController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      onChanged: (val) => setState(() => _montantRegle = double.tryParse(val) ?? 0),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Text('Mode : ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  StreamBuilder<List<PaymentMethodConfig>>(
                    stream: widget.service.getPaymentMethodConfigs(),
                    builder: (context, snapshot) {
                      final methods = snapshot.data ?? [];
                      if (_selectedMode == null && methods.isNotEmpty) _selectedMode = methods.first.name;
                      return Container(
                        width: 150,
                        height: 40,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedMode,
                            items: methods.map((m) => DropdownMenuItem(value: m.name, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(m.name)))).toList(),
                            onChanged: (v) => setState(() => _selectedMode = v),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 15),
                  ElevatedButton(
                    onPressed: _autoImpute,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2E8F0), foregroundColor: Colors.black, elevation: 1, minimumSize: const Size(120, 40)),
                    child: const Text('IMPUTER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<List<AppTransaction>>(
                stream: widget.service.getTransactions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  return StreamBuilder<List<Payment>>(
                    stream: widget.service.getPayments(tierId: widget.tier.id),
                    builder: (context, paySnapshot) {
                      final payments = paySnapshot.data ?? [];
                      final allTxs = snapshot.data!.where((t) => t.tierId == widget.tier.id).toList();

                      List<Map<String, dynamic>> dueTxs = [];
                      for (var t in allTxs) {
                        double paid = payments.where((p) => p.invoiceNumber == t.invoiceNumber).fold(0, (sum, p) => sum + p.amount);
                        double solde = t.netToPay - paid;
                        if (solde.abs() > 10) {
                          dueTxs.add({'tx': t, 'solde': solde});
                        }
                      }

                      if (dueTxs.isEmpty) return const Center(child: Text('Aucune facture ni avoir pour ce client.'));

                      return SingleChildScrollView(
                        child: DataTable(
                          headingRowHeight: 45,
                          dataRowHeight: 40,
                          columnSpacing: 35,
                          headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F3F4)),
                          border: TableBorder.all(color: Colors.grey.shade200, width: 1),
                          columns: const [
                            DataColumn(label: Text('Échéance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('N° pièce', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('À payer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Solde', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Règlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue))),
                          ],
                          rows: dueTxs.map((item) {
                            final t = item['tx'] as AppTransaction;
                            final solde = item['solde'] as double;
                            final isReturn = t.type == TransactionType.saleReturn || t.type == TransactionType.purchaseReturn;

                            if (!_controllers.containsKey(t.invoiceNumber)) {
                              _controllers[t.invoiceNumber] = TextEditingController();
                            }

                            return DataRow(
                              color: isReturn ? MaterialStateProperty.all(Colors.red.shade50) : null,
                              cells: [
                                DataCell(Text(DateFormat('dd/MM/yy').format(t.date), style: const TextStyle(fontSize: 13))),
                                DataCell(Text(t.invoiceNumber, style: const TextStyle(fontSize: 13))),
                                DataCell(Text(isReturn ? "RETOUR" : "FACTURE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isReturn ? Colors.red : Colors.grey))),
                                DataCell(Text(NumberFormat('#,###').format(t.netToPay.abs()).replaceAll(',', ' '), style: const TextStyle(fontSize: 13))),
                                DataCell(Text('${solde < 0 ? "-" : ""}${NumberFormat('#,###').format(solde.abs()).replaceAll(',', ' ')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: solde > 0 ? Colors.red : Colors.green))),
                                DataCell(Container(
                                  width: 140,
                                  height: 32,
                                  child: TextField(
                                    controller: _controllers[t.invoiceNumber],
                                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: solde < 0 ? Colors.green : Colors.blue),
                                    onChanged: (val) => setState(() {}),
                                  ),
                                )),
                              ]);
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(color: Color(0xFFF0FFF4), border: Border(top: BorderSide(color: Color(0xFFC6F6D5), width: 3))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _footerVal('Montant réglé', _montantRegle),
                  _footerVal('Total imputé', _getTotalImputed()),
                  _footerVal('Reste à imputer', _montantRegle - _getTotalImputed()),
                ],
              ),
            )
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0, bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              const SizedBox(width: 20),
              ElevatedButton(onPressed: _validate, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22543D), foregroundColor: Colors.white, minimumSize: const Size(120, 45)), child: const Text('VALIDER')),
            ],
          ),
        ),
      ],
    );
  }

  double _getTotalImputed() {
    double total = 0;
    _controllers.forEach((key, controller) {
      total += double.tryParse(controller.text.replaceAll(' ', '')) ?? 0;
    });
    return total;
  }

  void _autoImpute() {
    double remaining = _montantRegle;
    _controllers.forEach((key, controller) {
      if (remaining > 0) { controller.text = remaining.toString(); remaining = 0; }
      else { controller.clear(); }
    });
    setState(() {});
  }

  Widget _footerVal(String label, double val) {
    return Padding(padding: const EdgeInsets.only(left: 60), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]));
  }

  void _validate() async {
    final Map<String, double> finalAllocations = {};
    _controllers.forEach((key, controller) {
      double val = double.tryParse(controller.text.replaceAll(' ', '')) ?? 0;
      if (val != 0) finalAllocations[key] = val;
    });
    if (finalAllocations.isEmpty) { Navigator.pop(context); return; }
    for (var entry in finalAllocations.entries) {
      final p = Payment(
        id: '',
        tierId: widget.tier.id,
        tierName: widget.tier.name,
        tierType: widget.tier.type,
        amount: entry.value,
        date: DateTime.now(),
        method: _selectedMode ?? 'Imputation',
        journalCode: widget.journalCode,
        reference: 'REG-${entry.key}',
        invoiceNumber: entry.key
      );
      await widget.service.addPayment(p, widget.userName);
    }
    if (mounted) Navigator.pop(context);
  }
}
