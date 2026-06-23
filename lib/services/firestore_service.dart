import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/warehouse.dart';
import '../models/transport.dart';
import '../models/payment.dart';
import '../models/account.dart';
import '../models/stock_transfer.dart';
import '../models/journal_entry.dart';
import '../models/daily_closing.dart';
import '../models/app_user.dart';
import '../models/task.dart';
import '../models/journal_config.dart';
import '../models/expense.dart';
import '../models/payment_method_config.dart';
import '../models/advance.dart';
import '../models/salary_payment.dart';
import '../models/fiscal_year.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // --- TRACEABILITE (AUDIT LOGS) ---
  Stream<List<Map<String, dynamic>>> getAuditLogs({int limit = 100}) {
    return _db.collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Future<void> logAction({
    required String action,
    required String entity,
    required String entityId,
    required String userName,
    String? details,
  }) async {
    await _db.collection('audit_logs').add({
      'action': action,
      'entity': entity,
      'entityId': entityId,
      'userName': userName,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- AVANCES CLIENTS ---
  Stream<List<Advance>> getAdvances({String? tierId}) {
    Query query = _db.collection('advances');
    if (tierId != null) query = query.where('tierId', isEqualTo: tierId);
    return query.orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => Advance.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addAdvance(Advance a) async {
    DocumentReference ref = await _db.collection('advances').add(a.toMap());
    await logAction(action: 'add_advance', entity: 'advances', entityId: ref.id, userName: a.createdBy, details: 'Avance de ${a.amount} F pour ${a.tierName}');
  }

  Future<void> deleteAdvance(String id, String userName) async {
    await _db.collection('advances').doc(id).delete();
    await logAction(action: 'delete_advance', entity: 'advances', entityId: id, userName: userName, details: 'Suppression avance ID: $id');
  }

  // --- PAIE (SALAIRES) ---
  Stream<List<SalaryPayment>> getSalaryPayments({int limit = 50}) {
    return _db.collection('salaries').orderBy('date', descending: true).limit(limit).snapshots().map((snap) =>
        snap.docs.map((doc) => SalaryPayment.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addSalaryPayment(SalaryPayment s) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('salaries').doc();
    batch.set(ref, s.toMap());

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: s.date, reference: 'PAIE-${DateFormat('MMyy').format(s.date)}',
      journalCode: s.journalCode, label: 'Salaire ${s.month} : ${s.employeeName}',
      accountCode: '66110000', accountLabel: 'Remuneration du personnel',
      debit: s.amount, credit: 0, createdBy: s.createdBy
    ).toMap());

    String cashAccount = s.method.toLowerCase().contains('banque') || s.method.toLowerCase().contains('virement') ? '52110000' : '57110000';
    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: s.date, reference: 'PAIE-${DateFormat('MMyy').format(s.date)}',
      journalCode: s.journalCode, label: 'Contrepartie Salaire : ${s.employeeName}',
      accountCode: cashAccount, accountLabel: 'Tresorerie',
      debit: 0, credit: s.amount, createdBy: s.createdBy
    ).toMap());

    await batch.commit();
    await logAction(action: 'add_salary', entity: 'salaries', entityId: ref.id, userName: s.createdBy, details: 'Paiement salaire ${s.month} pour ${s.employeeName}');
  }

  // --- EXERCICES COMPTABLES ---
  Stream<List<FiscalYear>> getFiscalYears() {
    return _db.collection('fiscal_years').orderBy('startDate', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => FiscalYear.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addFiscalYear(FiscalYear fy) async {
    await _db.collection('fiscal_years').add(fy.toMap());
    await logAction(action: 'add_fiscal_year', entity: 'fiscal_years', entityId: 'new', userName: fy.createdBy, details: 'Ouverture exercice ${fy.label}');
  }

  Future<void> closeFiscalYear(String id, String userName) async {
    await _db.collection('fiscal_years').doc(id).update({'isClosed': true});
    await logAction(action: 'close_fiscal_year', entity: 'fiscal_years', entityId: id, userName: userName, details: 'Cloture de l\'exercice');
  }

  // --- CONFIGURATION MODES REGLEMENT ---
  Stream<List<PaymentMethodConfig>> getPaymentMethodConfigs() {
    return _db.collection('payment_method_configs').snapshots().map((snap) =>
        snap.docs.map((doc) => PaymentMethodConfig.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addPaymentMethodConfig(PaymentMethodConfig config) => _db.collection('payment_method_configs').add(config.toMap());
  Future<void> deletePaymentMethodConfig(String id) => _db.collection('payment_method_configs').doc(id).delete();

  // --- DEPENSES & FOND DE CAISSE ---
  Stream<List<Expense>> getExpenses() {
    return _db.collection('expenses').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addCashFund(double amount, String journalCode, String label, String userName) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('expenses').doc();
    final e = Expense(
      id: '', date: DateTime.now(), label: 'ALIMENTATION CAISSE : $label',
      amount: -amount, category: 'FOND_DE_CAISSE', accountCode: '57110000',
      journalCode: journalCode, paymentMethod: 'Virement/Interne', createdBy: userName
    );
    batch.set(ref, e.toMap());
    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: e.date, reference: 'FOND-${DateFormat('ddMMyy').format(e.date)}',
      journalCode: journalCode, label: e.label, accountCode: '57110000', accountLabel: 'Caisse',
      debit: amount, credit: 0, createdBy: userName
    ).toMap());
    await batch.commit();
    await logAction(action: 'add_cash_fund', entity: 'expenses', entityId: ref.id, userName: userName, details: 'Alimentation caisse de $amount F');
  }

  Future<void> addExpense(Expense e) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('expenses').doc();
    batch.set(ref, e.toMap());

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: e.date, reference: 'DEP-${DateFormat('ddMMyy').format(e.date)}',
      journalCode: e.journalCode, label: 'Depense : ${e.label}',
      accountCode: e.accountCode, accountLabel: 'Charges',
      debit: e.amount, credit: 0, createdBy: e.createdBy,
    ).toMap());

    String cashAccount = '57110000';
    if (e.paymentMethod.toLowerCase().contains('banque') || e.paymentMethod.toLowerCase().contains('cheque') || e.paymentMethod.toLowerCase().contains('virement')) {
      cashAccount = '52110000';
    }

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: e.date, reference: 'DEP-${DateFormat('ddMMyy').format(e.date)}',
      journalCode: e.journalCode, label: 'Contrepartie Depense : ${e.label}',
      accountCode: cashAccount, accountLabel: 'Tresorerie',
      debit: 0, credit: e.amount, createdBy: e.createdBy,
    ).toMap());

    await batch.commit();
    await logAction(action: 'add_expense', entity: 'expenses', entityId: ref.id, userName: e.createdBy, details: 'Depense de ${e.amount} F : ${e.label}');
  }

  Future<void> deleteExpense(String id, String userName) async {
    await _db.collection('expenses').doc(id).delete();
    await logAction(action: 'delete_expense', entity: 'expenses', entityId: id, userName: userName, details: 'Suppression depense ID: $id');
  }

  // --- CONFIGURATION JOURNAUX ---
  Stream<List<JournalConfig>> getJournalConfigs() {
    return _db.collection('journal_configs').snapshots().map((snap) =>
        snap.docs.map((doc) => JournalConfig.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addJournalConfig(JournalConfig config) => _db.collection('journal_configs').add(config.toMap());
  Future<void> deleteJournalConfig(String id) => _db.collection('journal_configs').doc(id).delete();

  // --- MODULE TECHNICIENS ---
  Stream<List<Task>> getTasks({String? technicianId}) {
    Query query = _db.collection('tasks');
    if (technicianId != null && technicianId.isNotEmpty) {
      query = query.where('technicianId', isEqualTo: technicianId);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addTask(Task task) => _db.collection('tasks').add(task.toMap());

  Future<void> updateTaskStatus(String taskId, TaskStatus status, String userName, {Map<String, dynamic>? reportData}) {
    Map<String, dynamic> data = {
      'status': status.toString().split('.').last,
      'updatedAt': Timestamp.now(),
      'lastModifiedBy': userName,
    };
    if (reportData != null) {
      data.addAll(reportData);
      if (status == TaskStatus.completed) {
        data['completedAt'] = Timestamp.now();
      }
    }
    return _db.collection('tasks').doc(taskId).update(data);
  }

  Future<void> approveTask(String taskId, String managerName, String comment, bool isApproved) {
    return _db.collection('tasks').doc(taskId).update({
      'status': isApproved ? 'approved' : 'rejected',
      'managerComment': comment,
      'approvedBy': managerName,
      'updatedAt': Timestamp.now(),
    });
  }

  Stream<List<AppUser>> getTechnicians() {
    return _db.collection('users').where('role', isEqualTo: 'technician').snapshots().map((snap) =>
        snap.docs.map((doc) => AppUser.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  // --- COMPTABILITE (JOURNAL) ---
  Stream<List<JournalEntry>> getJournalEntries({int limit = 200}) {
    return _db.collection('journal').orderBy('date', descending: true).limit(limit).snapshots().map((snap) =>
        snap.docs.map((doc) => JournalEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addJournalEntry(JournalEntry entry) => _db.collection('journal').add(entry.toMap());
  Future<void> updateJournalEntry(JournalEntry entry) => _db.collection('journal').doc(entry.id).update(entry.toMap());
  Future<void> deleteJournalEntry(String id) => _db.collection('journal').doc(id).delete();

  Future<void> updateReconciliationStatus(String entryId, bool isReconciled, DateTime? date) {
    return _db.collection('journal').doc(entryId).update({
      'isReconciled': isReconciled,
      'reconciliationDate': date != null ? Timestamp.fromDate(date) : null,
    });
  }

  Future<void> updateLettering(String entryId, String? lettering) {
    return _db.collection('journal').doc(entryId).update({'lettering': lettering});
  }

  // --- TRANSFERTS DE STOCK ---
  Stream<List<StockTransfer>> getStockTransfers() {
    return _db.collection('stock_transfers').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => StockTransfer.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addStockTransfer(StockTransfer t) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('stock_transfers').doc();
    batch.set(ref, t.toMap());
    await batch.commit();
    await logAction(action: 'stock_transfer', entity: 'stock_transfers', entityId: ref.id, userName: t.createdBy, details: 'Transfert ${t.quantity} de ${t.productName}');
  }

  Future<int> getWarehouseStock(String productId, String warehouseId) async {
    final stockDoc = await _db.collection('stocks').doc('${warehouseId}_${productId}').get();
    if (stockDoc.exists) {
      return (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  // --- PRODUITS ---
  Stream<List<Product>> getProducts() {
    return _db.collection('products').snapshots().map((snap) =>
        snap.docs.map((doc) => Product.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  Future<void> addProduct(Product p, {String? warehouseId}) async {
    DocumentReference ref = await _db.collection('products').add(p.toMap());
    if (warehouseId != null && p.totalQuantity > 0) {
      await _db.collection('stocks').doc('${warehouseId}_${ref.id}').set({
        'warehouseId': warehouseId,
        'productId': ref.id,
        'quantity': p.totalQuantity
      });
    }
  }
  Future<void> updateProduct(Product p) => _db.collection('products').doc(p.id).update(p.toMap());
  Future<void> deleteProduct(String id) async {
    // Verification des operations existantes
    final txSnap = await _db.collection('transactions').get();
    final hasTx = txSnap.docs.any((doc) {
      final items = (doc.data()['items'] as List?) ?? [];
      return items.any((item) => item['productId'] == id);
    });
    if (hasTx) throw Exception("Action interdite : cet article a deja effectue des operations (Achats/Ventes).");

    return _db.collection('products').doc(id).delete();
  }

  // --- TIERS ---
  Stream<List<Tier>> getTiers(TierType? type) {
    return _db.collection('tiers').snapshots().map((snap) {
      var list = snap.docs.map((doc) => Tier.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      if (type != null) list = list.where((t) => t.type == type).toList();
      return list;
    });
  }
  Future<void> addTier(Tier t) => _db.collection('tiers').add(t.toMap());
  Future<void> updateTier(Tier t) => _db.collection('tiers').doc(t.id).update(t.toMap());

  Future<void> deleteTier(String id) async {
    // Verification des operations existantes
    final txSnap = await _db.collection('transactions').where('tierId', isEqualTo: id).get();
    final paySnap = await _db.collection('payments').where('tierId', isEqualTo: id).get();

    if (txSnap.docs.isNotEmpty || paySnap.docs.isNotEmpty) {
      throw Exception("Action interdite : ce tiers a deja effectue des operations (Factures/Reglements).");
    }

    return _db.collection('tiers').doc(id).delete();
  }

  // --- STOCKS ---
  Stream<List<Map<String, dynamic>>> getAllStocks() {
    return _db.collection('stocks').snapshots().map((snap) =>
        snap.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // --- TRANSACTIONS ---
  Stream<List<AppTransaction>> getTransactions({TransactionType? type, int? limit}) {
    return _db.collection('transactions').snapshots().map((snap) {
      var list = snap.docs.map((doc) => AppTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      if (type != null) {
        final typeStr = type.toString().split('.').last;
        list = list.where((t) => t.type.toString().split('.').last == typeStr).toList();
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      if (limit != null && list.length > limit) {
        list = list.take(limit).toList();
      }
      return list;
    });
  }

  Future<void> addTransaction(AppTransaction t, String userName) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('transactions').doc();
    Map<String, dynamic> data = t.toMap();
    data['createdBy'] = userName;
    batch.set(ref, data);

    if (t.type == TransactionType.quote) return batch.commit();

    // 0. Verification du stock par depot pour les ventes
    if (t.type == TransactionType.sale) {
      for (var item in t.items) {
        final stockDoc = await _db.collection('stocks').doc('${t.warehouseId}_${item.productId}').get();
        int warehouseStock = (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;

        if (warehouseStock < item.quantity) {
          throw Exception('Stock insuffisant dans ce depot pour ${item.productName} ($warehouseStock disponible)');
        }
      }
    }

    // 1. Mise a jour du stock et CMUP
    for (var item in t.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);

      final pDoc = await pRef.get();
      if (!pDoc.exists) continue;
      final pData = pDoc.data() as Map<String, dynamic>;

      int change;
      if (t.type == TransactionType.sale || t.type == TransactionType.purchaseReturn) {
        change = -item.quantity;
      } else {
        change = item.quantity;

        if (t.type == TransactionType.purchase) {
          double stockActuel = (pData['totalQuantity'] as num?)?.toDouble() ?? 0;
          double cmupActuel = (pData['weightedAverageCost'] as num?)?.toDouble() ?? (pData['purchasePrice'] as num?)?.toDouble() ?? 0;

          double nouvelleQty = stockActuel + item.quantity;
          double nouvelleValeur = (stockActuel * cmupActuel) + (item.quantity * item.unitPrice);

          double nouveauCmup = nouvelleQty > 0 ? nouvelleValeur / nouvelleQty : item.unitPrice;
          batch.update(pRef, {
            'weightedAverageCost': nouveauCmup,
            'purchasePrice': item.unitPrice
          });
        }
      }

      batch.update(pRef, {'totalQuantity': FieldValue.increment(change)});

      DocumentReference sRef = _db.collection('stocks').doc('${t.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'warehouseId': t.warehouseId,
        'productId': item.productId,
        'quantity': FieldValue.increment(change)
      }, SetOptions(merge: true));
    }

    // 2. Ecritures Comptables
    final String journal = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'VEN' : 'ACH';

    String tierAccount = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? '41110000' : '40110000';
    String tierLabel = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'Clients' : 'Fournisseurs';
    String htAccount = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? '70110000' : '60110000';
    String htLabel = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'Ventes' : 'Achats';

    if (t.items.isNotEmpty) {
      final pDoc = await _db.collection('products').doc(t.items.first.productId).get();
      if (pDoc.exists) {
        final pData = pDoc.data()!;
        if (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) {
          htAccount = pData['compteVente'] ?? '70110000';
        } else {
          htAccount = pData['compteAchat'] ?? '60110000';
        }
      }
    }

    double amount = (t.totalHT).abs();

    double tierDebit = 0, tierCredit = 0, htDebit = 0, htCredit = 0;

    if (t.type == TransactionType.sale) {
      tierDebit = amount; htCredit = amount;
    } else if (t.type == TransactionType.saleReturn) {
      tierCredit = amount; htDebit = amount;
    } else if (t.type == TransactionType.purchase) {
      tierCredit = amount; htDebit = amount;
    } else if (t.type == TransactionType.purchaseReturn) {
      tierDebit = amount; htCredit = amount;
    }

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${_getTypeLabel(t.type)} - ${t.tierName}',
      accountCode: tierAccount, accountLabel: tierLabel,
      debit: tierDebit, credit: tierCredit,
      tierId: t.tierId, tierName: t.tierName,
      createdBy: userName,
    ).toMap());

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${_getTypeLabel(t.type)} - ${t.tierName}',
      accountCode: htAccount, accountLabel: htLabel,
      debit: htDebit, credit: htCredit,
      createdBy: userName,
    ).toMap());

    // 3. Gestion de l'Acompte
    if (t.amountPaid > 0 && (t.type == TransactionType.sale || t.type == TransactionType.purchase)) {
      DocumentReference pRef = _db.collection('payments').doc();
      batch.set(pRef, {
        'id': pRef.id,
        'tierId': t.tierId, 'tierName': t.tierName,
        'tierType': t.type == TransactionType.sale ? 'client' : 'supplier',
        'amount': t.amountPaid, 'date': Timestamp.fromDate(t.date),
        'method': t.paymentMethod, 'reference': 'Acompte ${t.invoiceNumber}',
        'invoiceNumber': t.invoiceNumber, 'createdBy': userName,
      });

      final String cashAccount = t.paymentMethod == 'Especes' ? '57110000' : '52110000';
      final String cashLabel = t.paymentMethod == 'Especes' ? 'Caisse' : 'Banque';

      batch.set(_db.collection('journal').doc(), JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Especes' ? 'CAI' : 'BQ',
        label: 'Reglement Acompte - ${t.tierName}',
        accountCode: cashAccount, accountLabel: cashLabel,
        debit: t.type == TransactionType.sale ? t.amountPaid : 0,
        credit: t.type == TransactionType.sale ? 0 : t.amountPaid,
        createdBy: userName,
      ).toMap());

      batch.set(_db.collection('journal').doc(), JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Especes' ? 'CAI' : 'BQ',
        label: 'Contrepartie Acompte - ${t.tierName}',
        accountCode: tierAccount, accountLabel: tierLabel,
        debit: t.type == TransactionType.sale ? 0 : t.amountPaid,
        credit: t.type == TransactionType.sale ? t.amountPaid : 0,
        createdBy: userName,
      ).toMap());
    }

    await batch.commit();
    await logAction(action: 'add_transaction', entity: 'transactions', entityId: ref.id, userName: userName, details: 'Facture ${t.invoiceNumber} (${t.type}) pour ${t.tierName}');

    // --- LOGIQUE AUTOMATIQUE DES AVANCES ---
    if (t.type == TransactionType.sale) {
      await applyAdvancesToInvoice(t.tierId, t.tierName, t.invoiceNumber, t.netToPay - t.amountPaid);
    }
  }

  Future<void> applyAdvancesToInvoice(String tierId, String tierName, String invoiceNumber, double amountToCover) async {
    if (amountToCover <= 50) return;

    final advancesSnap = await _db.collection('advances')
        .where('tierId', isEqualTo: tierId)
        .where('isUsed', isEqualTo: false)
        .get();

    if (advancesSnap.docs.isNotEmpty) {
      WriteBatch advBatch = _db.batch();
      double remainingToPay = amountToCover;

      for (var doc in advancesSnap.docs) {
        if (remainingToPay <= 50) break;

        final advData = doc.data();
        double advAmount = (advData['amount'] ?? 0).toDouble();
        double amountToApply = advAmount > remainingToPay ? remainingToPay : advAmount;

        advBatch.update(doc.reference, {
          'isUsed': true,
          'usedInInvoice': invoiceNumber,
        });

        DocumentReference pRef = _db.collection('payments').doc();
        advBatch.set(pRef, {
          'id': pRef.id,
          'tierId': tierId,
          'tierName': tierName,
          'tierType': 'client',
          'amount': amountToApply,
          'date': Timestamp.fromDate(DateTime.now()),
          'method': 'Utilisation Avance',
          'reference': 'AVANCE-$invoiceNumber',
          'invoiceNumber': invoiceNumber,
          'createdBy': 'SYSTEME',
        });

        remainingToPay -= amountToApply;
      }
      await advBatch.commit();
    }
  }

  String _getTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.sale: return "Vente";
      case TransactionType.purchase: return "Achat";
      case TransactionType.quote: return "Devis";
      case TransactionType.saleReturn: return "Retour Vente";
      case TransactionType.purchaseReturn: return "Retour Achat";
    }
  }

  Future<void> updateTransaction(AppTransaction newTx, AppTransaction oldTx, String userName) async {
    WriteBatch batch = _db.batch();
    final journals = await _db.collection('journal').where('reference', isEqualTo: oldTx.invoiceNumber).get();
    for (var doc in journals.docs) batch.delete(doc.reference);

    final payments = await _db.collection('payments').where('invoiceNumber', isEqualTo: oldTx.invoiceNumber).get();
    for (var doc in payments.docs) batch.delete(doc.reference);

    batch.update(_db.collection('transactions').doc(newTx.id), newTx.toMap());

    if (newTx.amountPaid > 0 && (newTx.type == TransactionType.sale || newTx.type == TransactionType.purchase)) {
      DocumentReference pRef = _db.collection('payments').doc();
      batch.set(pRef, {
        'id': pRef.id,
        'tierId': newTx.tierId, 'tierName': newTx.tierName,
        'tierType': newTx.type == TransactionType.sale ? 'client' : 'supplier',
        'amount': newTx.amountPaid, 'date': Timestamp.fromDate(newTx.date),
        'method': newTx.paymentMethod, 'reference': 'Acompte ${newTx.invoiceNumber}',
        'invoiceNumber': newTx.invoiceNumber, 'createdBy': userName,
      });
    }

    await batch.commit();
    await logAction(action: 'update_transaction', entity: 'transactions', entityId: newTx.id, userName: userName, details: 'Modif. Facture ${newTx.invoiceNumber}');
  }

  Future<void> deleteTransaction(String id, String userName) async {
    final txDoc = await _db.collection('transactions').doc(id).get();
    if (!txDoc.exists) return;
    final txData = txDoc.data()!;
    if (txData['isPosted'] == true) throw Exception("Facture deja comptabilisee.");
    final tx = AppTransaction.fromMap(txData, id);
    WriteBatch batch = _db.batch();
    for (var item in tx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange;
      if (tx.type == TransactionType.sale || tx.type == TransactionType.purchaseReturn) {
        reverseChange = item.quantity;
      } else {
        reverseChange = -item.quantity;
      }
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});
      DocumentReference sRef = _db.collection('stocks').doc('${tx.warehouseId}_${item.productId}');
      batch.set(sRef, {'quantity': FieldValue.increment(reverseChange)}, SetOptions(merge: true));
    }
    final journals = await _db.collection('journal').where('reference', isEqualTo: tx.invoiceNumber).get();
    for (var doc in journals.docs) batch.delete(doc.reference);

    final payments = await _db.collection('payments').where('invoiceNumber', isEqualTo: tx.invoiceNumber).get();
    for (var doc in payments.docs) batch.delete(doc.reference);

    batch.delete(_db.collection('transactions').doc(id));
    await batch.commit();
    await logAction(action: 'delete_transaction', entity: 'transactions', entityId: id, userName: userName, details: 'Suppression Facture ${tx.invoiceNumber}');
  }

  // --- TRANSPORT ---
  Stream<List<Truck>> getTrucks() {
    return _db.collection('trucks').snapshots().map((snap) =>
        snap.docs.map((doc) => Truck.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  Future<void> addTruck(Truck t) => _db.collection('trucks').add(t.toMap());
  Future<void> updateTruck(Truck t) => _db.collection('trucks').doc(t.id).update(t.toMap());
  Future<void> deleteTruck(String id) => _db.collection('trucks').doc(id).delete();

  Stream<List<Trip>> getTrips({String? truckId}) {
    return _db.collection('trips').snapshots().map((snap) {
      var list = snap.docs.map((doc) => Trip.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      if (truckId != null) list = list.where((t) => t.truckId == truckId).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
  Future<void> addTrip(Trip t, String userName) async {
    Map<String, dynamic> data = t.toMap();
    data['createdBy'] = userName;
    await _db.collection('trips').add(data);
  }
  Future<void> updateTrip(Trip t) => _db.collection('trips').doc(t.id).update(t.toMap());
  Future<void> deleteTrip(String id) => _db.collection('trips').doc(id).delete();

  // --- REGLEMENTS ---
  Stream<List<Payment>> getPayments({String? tierId}) {
    return _db.collection('payments').snapshots().map((snap) {
      var list = snap.docs.map((doc) => Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      if (tierId != null) list = list.where((p) => p.tierId == tierId).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
  Future<void> addPayment(Payment p, String userName) async {
    Map<String, dynamic> data = p.toMap();
    data['createdBy'] = userName;
    DocumentReference ref = await _db.collection('payments').add(data);
    await logAction(action: 'add_payment', entity: 'payments', entityId: ref.id, userName: userName, details: 'Reglement de ${p.amount} F pour ${p.tierName}');
  }
  Future<void> deletePayment(String id, String userName) async {
    final doc = await _db.collection('payments').doc(id).get();
    if (!doc.exists) return;
    final pData = doc.data() as Map<String, dynamic>;
    final amount = pData['amount'] ?? 0;
    final tier = pData['tierName'] ?? '';

    await _db.collection('payments').doc(id).delete();
    await logAction(action: 'delete_payment', entity: 'payments', entityId: id, userName: userName, details: 'Suppression reglement de $amount F ($tier)');
  }

  Future<void> updatePaymentJournal(String paymentId, String journalCode) {
    return _db.collection('payments').doc(paymentId).update({'journalCode': journalCode});
  }

  // --- DEPOTS ---
  Stream<List<Warehouse>> getWarehouses() {
    return _db.collection('warehouses').snapshots().map((snap) =>
        snap.docs.map((doc) => Warehouse.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  Future<void> addWarehouse(Warehouse w) => _db.collection('warehouses').add(w.toMap());
  Future<void> deleteWarehouse(String id) => _db.collection('warehouses').doc(id).delete();

  // --- COMPTES ---
  Stream<List<Account>> getAccounts() {
    return _db.collection('accounts').snapshots().map((snap) =>
        snap.docs.map((doc) => Account.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }
  Future<void> addAccount(Account a) => _db.collection('accounts').add(a.toMap());
  Future<void> updateAccount(Account a) => _db.collection('accounts').doc(a.id).update(a.toMap());
  Future<void> deleteAccount(String id) => _db.collection('accounts').doc(id).delete();

  Future<void> updateTransactionStatus(String id, bool isPosted) => _db.collection('transactions').doc(id).update({'isPosted': isPosted});
  Future<void> updateDeliveryStatus(String id, String status) => _db.collection('transactions').doc(id).update({'deliveryStatus': status});

  Future<void> convertQuoteToSale(AppTransaction quote, String userName) async {
    WriteBatch batch = _db.batch();
    final newInvoiceNumber = 'FA${DateFormat('ddMMyyHHmm').format(DateTime.now())}';
    final sale = AppTransaction(
      id: _db.collection('transactions').doc().id,
      invoiceNumber: newInvoiceNumber, date: DateTime.now(),
      tierId: quote.tierId, tierName: quote.tierName,
      type: TransactionType.sale, items: quote.items,
      totalHT: quote.totalHT, amountPaid: 0,
      paymentMethod: 'Especes', warehouseId: quote.warehouseId,
      destination: quote.destination, transportFees: quote.transportFees,
      addTransport: quote.addTransport, createdBy: userName,
    );
    batch.set(_db.collection('transactions').doc(sale.id), sale.toMap());
    batch.delete(_db.collection('transactions').doc(quote.id));
    for (var item in sale.items) {
      batch.update(_db.collection('products').doc(item.productId), {'totalQuantity': FieldValue.increment(-item.quantity)});
      batch.set(_db.collection('stocks').doc('${sale.warehouseId}_${item.productId}'), {
        'warehouseId': sale.warehouseId, 'productId': item.productId, 'quantity': FieldValue.increment(-item.quantity)
      }, SetOptions(merge: true));
    }
    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: sale.date, reference: sale.invoiceNumber, journalCode: 'VEN',
      label: 'Vente (ex-Devis) - ${sale.tierName}', accountCode: '41110000', accountLabel: 'Clients',
      debit: sale.totalHT, credit: 0, tierId: sale.tierId, tierName: sale.tierName,
    ).toMap());
    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: sale.date, reference: sale.invoiceNumber, journalCode: 'VEN',
      label: 'Vente (ex-Devis) - ${sale.tierName}', accountCode: '70110000', accountLabel: 'Ventes',
      debit: 0, credit: sale.totalHT,
      createdBy: userName,
    ).toMap());
    await batch.commit();
    await applyAdvancesToInvoice(sale.tierId, sale.tierName, sale.invoiceNumber, sale.totalHT);
    await logAction(action: 'convert_quote', entity: 'transactions', entityId: sale.id, userName: userName, details: 'Devis ${quote.invoiceNumber} -> Facture ${sale.invoiceNumber}');
  }
    
  Future<void> updatePaymentStatus(String id, bool isPosted) => _db.collection('payments').doc(id).update({'isPosted': isPosted});

  Future<void> syncManagementToAccounting() async {
    final txsSnap = await _db.collection('transactions').get();
    final paysSnap = await _db.collection('payments').get();
    final expensesSnap = await _db.collection('expenses').get();

    final List<AppTransaction> transactions = txsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    final List<Payment> payments = paysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    final List<Expense> expenses = expensesSnap.docs.map((d) => Expense.fromMap(d.data(), d.id)).toList();

    WriteBatch batch = _db.batch();

    for (var e in expenses) {
      String expRef = 'DEP-${DateFormat('ddMMyy').format(e.date)}';
      batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: e.date, reference: expRef, journalCode: e.journalCode, label: 'Depense : ${e.label}', accountCode: e.accountCode, accountLabel: 'Charges', debit: e.amount, credit: 0, createdBy: e.createdBy).toMap());
      String cashAccount = e.paymentMethod.toLowerCase().contains('banque') ? '52110000' : '57110000';
      batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: e.date, reference: expRef, journalCode: e.journalCode, label: 'Contrepartie Depense : ${e.label}', accountCode: cashAccount, accountLabel: 'Tresorerie', debit: 0, credit: e.amount, createdBy: e.createdBy).toMap());
    }
    await batch.commit();
  }

  Future<void> performDailyClosing(DailyClosing closing) async {
    WriteBatch batch = _db.batch();
    batch.set(_db.collection('closings').doc(), closing.toMap());
    DateTime start = DateTime(closing.date.year, closing.date.month, closing.date.day);
    DateTime end = start.add(const Duration(days: 1));
    final txs = await _db.collection('transactions').where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).where('date', isLessThan: Timestamp.fromDate(end)).get();
    for (var doc in txs.docs) batch.update(doc.reference, {'isPosted': true});
    final payments = await _db.collection('payments').where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)).where('date', isLessThan: Timestamp.fromDate(end)).get();
    for (var doc in payments.docs) batch.update(doc.reference, {'isPosted': true});
    return batch.commit();
  }

  // --- IMPORT SAGE SOLDES ---
  Future<int> importSageBalances(String content, String userName) async {
    // Suppression du BOM si présent et découpage par ligne (supporte Windows/Linux)
    final cleanedContent = content.replaceAll('\uFEFF', '');
    final lines = cleanedContent.split(RegExp(r'\r?\n'));
    int count = 0;

    // Récupération des tiers existants
    final tiersSnap = await _db.collection('tiers').get();
    final tiers = tiersSnap.docs.map((d) => Tier.fromMap(d.data(), d.id)).toList();

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Séparateurs supportés : Tabulation, Point-virgule, Virgule, Barre verticale
      final parts = trimmedLine.split(RegExp(r'[\t;|]'));
      if (parts.length < 5) continue;

      // Format attendu : Date(0) / N° Facture(1) / Compte Tiers(2) / Intitule(3) / Montant facturé(4) / Montant réglé(5)
      final dateStr = parts[0].trim();
      final invoiceRef = parts[1].trim();
      final tierCode = parts[2].trim().toUpperCase();
      final clientNameInFile = parts[3].trim().toUpperCase();

      // Nettoyage robuste des nombres (enlève tout ce qui n'est pas chiffre, virgule ou point)
      String cleanNum(String s) => s.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');

      final totalAmount = double.tryParse(cleanNum(parts[4])) ?? 0;
      double amountPaid = 0;
      if (parts.length > 5) {
        amountPaid = double.tryParse(cleanNum(parts[5])) ?? 0;
      }

      if (totalAmount <= 0) continue;

      // RECHERCHE DU TIERS (3 étapes de sécurité)
      Tier? tier;

      // 1. Recherche par Code Tiers Sage (le plus fiable)
      if (tierCode.isNotEmpty) {
        tier = tiers.where((t) => t.compteTiers.toUpperCase() == tierCode).firstOrNull;
      }

      // 2. Recherche par Nom exact
      if (tier == null) {
        tier = tiers.where((t) => t.name.toUpperCase() == clientNameInFile).firstOrNull;
      }

      // 3. Recherche par correspondance partielle (Flexible)
      if (tier == null) {
        tier = tiers.where((t) {
          final appName = t.name.toUpperCase();
          return clientNameInFile.contains(appName) || appName.contains(clientNameInFile);
        }).firstOrNull;
      }

      if (tier == null) continue;

      // Parsing de la date (JJ/MM/AAAA ou JJ/MM/YY)
      DateTime txDate = DateTime.now();
      try {
        final dateParts = dateStr.split(RegExp(r'[/.-]'));
        if (dateParts.length == 3) {
          int day = int.parse(dateParts[0]);
          int month = int.parse(dateParts[1]);
          int year = int.parse(dateParts[2]);
          if (year < 100) year += 2000;
          txDate = DateTime(year, month, day);
        }
      } catch (_) {}

      final tx = AppTransaction(
        id: '',
        invoiceNumber: invoiceRef,
        date: txDate,
        tierId: tier.id,
        tierName: tier.name,
        type: tier.type == TierType.client ? TransactionType.sale : TransactionType.purchase,
        items: [
          TransactionItem(productId: 'REPRISE', productName: 'REPRISE SOLDE SAGE', quantity: 1, unitPrice: totalAmount)
        ],
        totalHT: totalAmount,
        amountPaid: amountPaid,
        paymentMethod: 'Import Sage',
        warehouseId: 'PRINCIPAL',
        createdBy: userName,
      );

      await _db.collection('transactions').add(tx.toMap());

      if (amountPaid > 0) {
        DocumentReference pRef = _db.collection('payments').doc();
        await pRef.set({
          'id': pRef.id,
          'tierId': tier.id,
          'tierName': tier.name,
          'tierType': tier.type.toString().split('.').last,
          'amount': amountPaid,
          'date': Timestamp.fromDate(txDate),
          'method': 'Import Sage',
          'reference': 'PREV-$invoiceRef',
          'invoiceNumber': invoiceRef,
          'createdBy': userName,
        });
      }
      count++;
    }
    return count;
  }

  Stream<List<DailyClosing>> getClosings() {
    return _db.collection('closings').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => DailyClosing.fromMap(doc.data(), doc.id)).toList());
  }

  Future<List<Map<String, dynamic>>> getUnpaidReport({required TierType tierType, required DateTime start, required DateTime end}) async {
    final transType = tierType == TierType.client ? TransactionType.sale : TransactionType.purchase;
    final returnType = tierType == TierType.client ? TransactionType.saleReturn : TransactionType.purchaseReturn;

    // Récupération des factures principales
    final allTxsSnap = await _db.collection('transactions').where('type', isEqualTo: transType.toString().split('.').last).get();
    // Récupération des règlements
    final allPaysSnap = await _db.collection('payments').where('tierType', isEqualTo: tierType == TierType.client ? 'client' : 'supplier').get();
    // Récupération des retours (avoirs) qui agissent comme des crédits
    final allReturnsSnap = await _db.collection('transactions').where('type', isEqualTo: returnType.toString().split('.').last).get();

    // Récupération des avances non encore consommées (uniquement pour les clients)
    List<Advance> allAdvances = [];
    if (tierType == TierType.client) {
      final advancesSnap = await _db.collection('advances').where('isUsed', isEqualTo: false).get();
      allAdvances = advancesSnap.docs.map((d) => Advance.fromMap(d.data(), d.id)).toList();
    }

    List<AppTransaction> allTxs = allTxsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    List<Payment> allPays = allPaysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    List<AppTransaction> allReturns = allReturnsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();

    allTxs.sort((a, b) => a.date.compareTo(b.date));

    Map<String, double> globalCreditsByTier = {};
    Map<String, double> specificCreditsByInvoice = {};

    // 1. Ventiler les règlements : par facture ou global
    for (var p in allPays) {
      if (p.invoiceNumber != null && p.invoiceNumber!.isNotEmpty) {
        specificCreditsByInvoice[p.invoiceNumber!] = (specificCreditsByInvoice[p.invoiceNumber!] ?? 0) + p.amount;
      } else {
        globalCreditsByTier[p.tierId] = (globalCreditsByTier[p.tierId] ?? 0) + p.amount;
      }
    }

    // 2. Ajouter les avoirs au pool global
    for (var ret in allReturns) {
      globalCreditsByTier[ret.tierId] = (globalCreditsByTier[ret.tierId] ?? 0) + ret.netToPay.abs();
    }

    // 3. Ajouter les avances au pool global
    for (var adv in allAdvances) {
      globalCreditsByTier[adv.tierId] = (globalCreditsByTier[adv.tierId] ?? 0) + adv.amount;
    }

    List<Map<String, dynamic>> results = [];
    Map<String, double> remainingGlobalCredits = Map.from(globalCreditsByTier);

    for (var t in allTxs) {
      double amountToCover = t.netToPay;

      // Priorité 1 : Règlement spécifiquement lié au numéro de facture (très courant dans l'import Sage)
      double specificPaid = specificCreditsByInvoice[t.invoiceNumber] ?? 0;

      // Priorité 2 : Compléter avec le pool global du client (FIFO)
      double resteAPayer = amountToCover - specificPaid;
      double globalApplied = 0;

      if (resteAPayer > 0) {
        double available = remainingGlobalCredits[t.tierId] ?? 0;
        globalApplied = available >= resteAPayer ? resteAPayer : available;
        remainingGlobalCredits[t.tierId] = available - globalApplied;
      }

      double totalPaid = specificPaid + globalApplied;
      double resteFinal = amountToCover - totalPaid;

      if (resteFinal > 10 && t.date.isAfter(start.subtract(const Duration(days: 1))) && t.date.isBefore(end.add(const Duration(days: 1)))) {
        results.add({
          'transaction': t,
          'totalPaid': totalPaid,
          'remaining': resteFinal
        });
      }
    }
    return results;
  }
}
