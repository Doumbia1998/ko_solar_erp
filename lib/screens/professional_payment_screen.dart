import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/payment.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/app_user.dart';
import '../models/journal_config.dart';
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
  String _selectedMethod = 'Espèces';

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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
          _toolbarButton(Icons.history, 'Historique'),
          const SizedBox(width: 10),
          if (_selectedTier != null)
            _toolbarButton(Icons.playlist_add_check, 'Sélectionner',
              onTap: () => _openMaturitySelection(context, service)),
          const SizedBox(width: 10),
          _toolbarButton(Icons.remove_red_eye, 'Visualiser'),
          const SizedBox(width: 10),
          _toolbarButton(Icons.print, 'Imprimer', onTap: () => _printDailyPayments(service)),
          const SizedBox(width: 20),
        ],
      ),
      body: Row(
        children: [
          // Sidebar (Filtres)
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
                if (_filterStartDate != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0, bottom: 12.0),
                    child: TextButton(onPressed: () => setState(() { _filterStartDate = null; _filterEndDate = null; }), child: const Text('Effacer les filtres', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold))),
                  ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: Column(
              children: [
                // Sélection Tiers & Journal (Ligne 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300))
                  ),
                  child: Row(
                    children: [
                      Text(isClient ? 'Client' : 'Fournisseur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 25),
                      const Text('Numéro', style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: StreamBuilder<List<Tier>>(
                          stream: service.getTiers(widget.type),
                          builder: (context, snapshot) {
                            final tiers = snapshot.data ?? [];
                            return Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<Tier>(
                                  isExpanded: true,
                                  value: _selectedTier,
                                  style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),
                                  items: tiers.map((t) => DropdownMenuItem(value: t, child: Text('${t.accountNumber} ${t.name.toUpperCase()}'))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedTier = val;
                                      _libelleController.text = 'RÈGLEMENT ${_selectedTier!.name.toUpperCase()}';
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 30),
                      const Text('Code Journal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      StreamBuilder<List<JournalConfig>>(
                        stream: service.getJournalConfigs(),
                        builder: (context, snapshot) {
                          final configs = snapshot.data ?? [];
                          if (_selectedJournalCode == null && configs.isNotEmpty) _selectedJournalCode = configs.first.code;

                          return Container(
                            height: 40,
                            width: 130,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedJournalCode,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
                                items: configs.map((c) => DropdownMenuItem(value: c.code, child: Text(c.code))).toList(),
                                onChanged: (val) => setState(() => _selectedJournalCode = val!),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F3F4), foregroundColor: Colors.black, elevation: 1, minimumSize: const Size(100, 40)),
                        child: const Text('AFFICHER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),

                // Ligne de saisie rapide (Ligne 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  color: const Color(0xFFE2E8F0),
                  child: Row(
                    children: [
                      _inputBox('Date', 90, controller: _dateController),
                      _inputBox('N° Pièce', 140, controller: _pieceController),
                      _inputBox('Libellé du règlement', 320, controller: _libelleController),
                      _dropdownBox('Mode', 160, _selectedMethod, ['Espèces', 'Chèque', 'Virement', 'Mobile Money', 'Banque BIM SA'], (val) => setState(() => _selectedMethod = val!)),
                      _inputBox('Montant', 150, controller: _montantController, isNumeric: true),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _saveFastEntry,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F855A), foregroundColor: Colors.white, minimumSize: const Size(130, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _resetEntry,
                        style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(100, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('NOUVEAU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                ),

                // Tableau des écritures (Corps)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    child: _selectedTier == null
                        ? const Center(child: Text('Veuillez sélectionner un compte tiers pour afficher l\'historique des règlements.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                        : StreamBuilder<List<Payment>>(
                            stream: service.getPayments(tierId: _selectedTier!.id),
                            builder: (context, snapshot) {
                              var payments = snapshot.data ?? [];

                              // Application des filtres de date
                              if (_filterStartDate != null && _filterEndDate != null) {
                                payments = payments.where((p) =>
                                  p.date.isAfter(_filterStartDate!.subtract(const Duration(days: 1))) &&
                                  p.date.isBefore(_filterEndDate!.add(const Duration(days: 1)))
                                ).toList();
                              }

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    headingRowHeight: 45,
                                    dataRowHeight: 38,
                                    columnSpacing: 30,
                                    headingRowColor: MaterialStateProperty.all(const Color(0xFF2D3748)),
                                    headingTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                                    columns: const [
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('N° pièce')),
                                      DataColumn(label: Text('Libellé')),
                                      DataColumn(label: Text('Mode règlement')),
                                      DataColumn(label: Text('Compte général')),
                                      DataColumn(label: Text('Montant')),
                                      DataColumn(label: Text('Code journal')),
                                      DataColumn(label: Text('Solde')),
                                    ],
                                    rows: payments.map((p) => DataRow(cells: [
                                      DataCell(Text(DateFormat('dd/MM/yy').format(p.date), style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(p.reference, style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(p.invoiceNumber != null ? 'ENC FA${p.invoiceNumber}' : p.reference, style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(p.method, style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(_selectedTier!.accountNumber, style: const TextStyle(fontSize: 13))),
                                      DataCell(Text(_format.format(p.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue))),
                                      DataCell(Text(p.journalCode ?? _selectedJournalCode ?? '', style: const TextStyle(fontSize: 13))),
                                      const DataCell(Text('0', style: TextStyle(fontSize: 13))),
                                    ])).toList(),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Footer (Résumé vert géant)
                if (_selectedTier != null)
                  StreamBuilder<List<Payment>>(
                    stream: service.getPayments(tierId: _selectedTier!.id),
                    builder: (context, snapshot) {
                      final payments = snapshot.data ?? [];
                      double total = payments.fold(0, (sum, p) => sum + p.amount);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0FFF4),
                          border: Border(top: BorderSide(color: Color(0xFFC6F6D5), width: 3))
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _summary('Total règlement', total),
                            _summary('Total imputé', total),
                            _summary('Solde', 0, isBold: true),
                            const SizedBox(width: 80),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey, width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                              child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
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

  void _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _filterStartDate != null ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!) : null,
    );
    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
    }
  }

  void _printDailyPayments(FirestoreService service) async {
    final payments = await service.getPayments().first;
    final now = DateTime.now();

    final start = _filterStartDate ?? now;
    final end = _filterEndDate ?? now;

    final filtered = payments.where((p) =>
      p.date.isAfter(start.subtract(const Duration(days: 1))) &&
      p.date.isBefore(end.add(const Duration(days: 1))) &&
      p.tierType == widget.type
    ).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun règlement à imprimer pour cette période')));
      return;
    }
    ReportService.generateDailyPaymentsReport(filtered, widget.type == TierType.client ? 'Clients' : 'Fournisseurs');
  }

  void _saveFastEntry() async {
    if (_selectedTier == null) return;
    double amount = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    final service = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = await auth.user.first;
    final appUser = await auth.getAppUser(user!.uid);

    final p = Payment(
      id: '',
      tierId: _selectedTier!.id,
      tierName: _selectedTier!.name,
      tierType: widget.type,
      amount: amount,
      date: DateTime.now(),
      method: _selectedMethod,
      journalCode: _selectedJournalCode,
      reference: _pieceController.text.isEmpty ? 'RC${DateFormat('ddMMyy').format(DateTime.now())}' : _pieceController.text,
    );

    await service.addPayment(p, appUser?.displayName ?? 'User');
    _resetEntry();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Règlement enregistré avec succès !'), backgroundColor: Colors.green));
  }

  void _resetEntry() {
    setState(() {
      _pieceController.clear();
      _libelleController.text = _selectedTier != null ? 'RÈGLEMENT ${_selectedTier!.name.toUpperCase()}' : '';
      _montantController.clear();
    });
  }

  Widget _inputBox(String hint, double width, {TextEditingController? controller, bool isNumeric = false}) {
    return Container(
      width: width,
      height: 38,
      margin: const EdgeInsets.only(right: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _dropdownBox(String label, double width, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      width: width,
      height: 38,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w500),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _sidebarItem(String label) {
    bool isSelected = _filter == label;
    return InkWell(
      onTap: () => setState(() => _filter = label),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : null,
          border: isSelected ? Border(left: const BorderSide(color: Colors.blue, width: 5), right: BorderSide(color: Colors.grey.shade400)) : null
        ),
        child: Text(label, style: TextStyle(fontSize: 14, color: isSelected ? Colors.blue.shade800 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, {VoidCallback? onTap}) {
    return TextButton.icon(
      onPressed: onTap ?? () {},
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _summary(String label, double val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(_format.format(val), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w700, fontSize: 18, color: isBold ? Colors.black : Colors.green.shade800)),
        ],
      ),
    );
  }

  void _showJournalConfig(BuildContext context, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Codes Journaux (Comptabilité)', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<JournalConfig>>(
                  stream: service.getJournalConfigs(),
                  builder: (context, snapshot) {
                    final configs = snapshot.data ?? [];
                    return ListView.builder(
                      itemCount: configs.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(configs[index].code, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        subtitle: Text(configs[index].name),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 22), onPressed: () => service.deleteJournalConfig(configs[index].id)),
                      ),
                    );
                  },
                ),
              ),
              const Divider(thickness: 1.5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addJournalDialog(context, service),
                  icon: const Icon(Icons.add),
                  label: const Text('AJOUTER UN CODE JOURNAL'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addJournalDialog(BuildContext context, FirestoreService service) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau Code Journal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code (ex: CA, BQ, CAS)', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Désignation (ex: Caisse Principale)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          ElevatedButton(onPressed: () {
            if (codeCtrl.text.isNotEmpty) {
              service.addJournalConfig(JournalConfig(id: '', code: codeCtrl.text.toUpperCase(), name: nameCtrl.text));
              Navigator.pop(context);
            }
          }, child: const Text('CRÉER')),
        ],
      ),
    );
  }

  void _openMaturitySelection(BuildContext context, FirestoreService service) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.user.first;
    final appUser = await authService.getAppUser(user!.uid);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => MaturitySelectionDialog(
        tier: _selectedTier!,
        service: service,
        userName: appUser?.displayName ?? 'User',
        journalCode: _selectedJournalCode,
      ),
    );
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
            // Top Section (Imputer)
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
                  ElevatedButton(
                    onPressed: _autoImpute,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE2E8F0), foregroundColor: Colors.black, elevation: 1, minimumSize: const Size(120, 40)),
                    child: const Text('IMPUTER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                  ),
                ],
              ),
            ),

            // Grid Echéances
            Expanded(
              child: StreamBuilder<List<AppTransaction>>(
                stream: widget.service.getTransactions(type: widget.tier.type == TierType.client ? TransactionType.sale : TransactionType.purchase),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  return StreamBuilder<List<Payment>>(
                    stream: widget.service.getPayments(tierId: widget.tier.id),
                    builder: (context, paySnapshot) {
                      final payments = paySnapshot.data ?? [];
                      final txs = snapshot.data!.where((t) => t.tierId == widget.tier.id).toList();

                      List<Map<String, dynamic>> dueTxs = [];
                      for (var t in txs) {
                        double paid = payments.where((p) => p.invoiceNumber == t.invoiceNumber).fold(0, (sum, p) => sum + p.amount);
                        if (paid < t.netToPay - 10) {
                          dueTxs.add({'tx': t, 'solde': t.netToPay - paid});
                        }
                      }

                      if (dueTxs.isEmpty) return const Center(child: Text('Aucune facture impayée pour ce client.', style: TextStyle(fontSize: 16, color: Colors.grey)));

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
                            DataColumn(label: Text('N° client', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Mode règlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('À payer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Solde', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Règlement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue))),
                          ],
                          rows: dueTxs.map((item) {
                            final t = item['tx'] as AppTransaction;
                            final solde = item['solde'] as double;

                            if (!_controllers.containsKey(t.invoiceNumber)) {
                              _controllers[t.invoiceNumber] = TextEditingController();
                            }

                            return DataRow(cells: [
                              DataCell(Text(DateFormat('dd/MM/yy').format(t.date), style: const TextStyle(fontSize: 13))),
                              DataCell(Text(t.invoiceNumber, style: const TextStyle(fontSize: 13))),
                              DataCell(Text(widget.tier.accountNumber, style: const TextStyle(fontSize: 13))),
                              const DataCell(Text('COMPTA..', style: TextStyle(fontSize: 13))),
                              DataCell(Text(NumberFormat('#,###').format(t.netToPay), style: const TextStyle(fontSize: 13))),
                              DataCell(Text(NumberFormat('#,###').format(solde), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red))),
                              DataCell(Container(
                                width: 140,
                                height: 32,
                                child: TextField(
                                  controller: _controllers[t.invoiceNumber],
                                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
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

            // Footer (Vert)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FFF4),
                border: Border(top: BorderSide(color: Color(0xFFC6F6D5), width: 3))
              ),
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ANNULER', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold))
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _validate,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22543D), foregroundColor: Colors.white, minimumSize: const Size(120, 45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                child: const Text('VALIDER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
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
      if (remaining > 0) {
        controller.text = remaining.toString();
        remaining = 0;
      } else {
        controller.clear();
      }
    });
    setState(() {});
  }

  Widget _footerVal(String label, double val) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(NumberFormat('#,###').format(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  void _validate() async {
    final Map<String, double> finalAllocations = {};
    _controllers.forEach((key, controller) {
      double val = double.tryParse(controller.text.replaceAll(' ', '')) ?? 0;
      if (val > 0) finalAllocations[key] = val;
    });

    if (finalAllocations.isEmpty) {
      Navigator.pop(context);
      return;
    }

    for (var entry in finalAllocations.entries) {
      final p = Payment(
        id: '',
        tierId: widget.tier.id,
        tierName: widget.tier.name,
        tierType: widget.tier.type,
        amount: entry.value,
        date: DateTime.now(),
        method: 'Virement',
        journalCode: widget.journalCode,
        reference: 'RC${DateFormat('ddMMyy').format(DateTime.now())}',
        invoiceNumber: entry.key,
      );
      await widget.service.addPayment(p, widget.userName);
    }
    if (mounted) Navigator.pop(context);
  }
}
