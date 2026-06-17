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

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirestoreService() {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // --- TRACEABILITÉ (AUDIT LOGS) ---
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

  // --- COMPTABILITÉ (JOURNAL) ---
  Stream<List<JournalEntry>> getJournalEntries() {
    return _db.collection('journal').orderBy('date', descending: true).snapshots().map((snap) =>
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

    // ... reste du code stock ...

    await batch.commit();
    await logAction(action: 'stock_transfer', entity: 'stock_transfers', entityId: ref.id, userName: t.createdBy, details: 'Transfert ${t.quantity} de ${t.productName} (${t.fromWarehouseName} -> ${t.toWarehouseName})');
  }

  Future<int> getWarehouseStock(String productId, String warehouseId) async {
    final stockDoc = await _db.collection('stocks').doc('${warehouseId}_${productId}').get();
    if (stockDoc.exists) {
      return (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
    }
    final warehouseDoc = await _db.collection('warehouses').doc(warehouseId).get();
    String wName = warehouseDoc.data()?['name']?.toString().toLowerCase() ?? '';
    if (wName.contains('principal')) {
      final allAllocated = await _db.collection('stocks').where('productId', isEqualTo: productId).get();
      if (allAllocated.docs.isEmpty) {
        final productDoc = await _db.collection('products').doc(productId).get();
        return (productDoc.data()?['totalQuantity'] as num?)?.toInt() ?? 0;
      }
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
    final txSnap = await _db.collection('transactions').get();
    final hasTx = txSnap.docs.any((doc) {
      final items = (doc.data()['items'] as List?) ?? [];
      return items.any((item) => item['productId'] == id);
    });
    if (hasTx) throw Exception("Impossible de supprimer : cet article est présent dans des factures d'achat ou de vente.");
    final transferSnap = await _db.collection('stock_transfers').where('productId', isEqualTo: id).get();
    if (transferSnap.docs.isNotEmpty) throw Exception("Impossible de supprimer : cet article a un historique de transferts.");
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
  Future<void> deleteTier(String id) => _db.collection('tiers').doc(id).delete();

  // --- TRANSACTIONS ---
  Stream<List<AppTransaction>> getTransactions({TransactionType? type}) {
    return _db.collection('transactions').snapshots().map((snap) {
      var list = snap.docs.map((doc) => AppTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
      if (type != null) list = list.where((t) => t.type == type).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
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

    // 1. Mise à jour du stock
    for (var item in t.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);

      int change;
      // Vente ou Retour Achat = Diminution de stock
      if (t.type == TransactionType.sale || t.type == TransactionType.purchaseReturn) {
        change = -item.quantity;
      } else { // Achat ou Retour Vente = Augmentation de stock
        change = item.quantity;
      }

      batch.update(pRef, {'totalQuantity': FieldValue.increment(change)});

      DocumentReference sRef = _db.collection('stocks').doc('${t.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'warehouseId': t.warehouseId,
        'productId': item.productId,
        'quantity': FieldValue.increment(change)
      }, SetOptions(merge: true));
    }

    // 2. Écritures Comptables
    final String journal = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'VEN' : 'ACH';

    // Comptes par défaut
    String tierAccount = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? '411100' : '401100';
    String tierLabel = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'Clients' : 'Fournisseurs';
    String htAccount = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? '701100' : '601100';
    String htLabel = (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) ? 'Ventes' : 'Achats';

    if (t.items.isNotEmpty) {
      final pDoc = await _db.collection('products').doc(t.items.first.productId).get();
      if (pDoc.exists) {
        final pData = pDoc.data()!;
        if (t.type == TransactionType.sale || t.type == TransactionType.saleReturn) {
          htAccount = pData['compteVente'] ?? '701100';
        } else {
          htAccount = pData['compteAchat'] ?? '601100';
        }
      }
    }

    double amount = (t.totalHT).abs(); // On utilise la valeur absolue car netToPay gère déjà le signe pour le solde

    // Logique Débit/Crédit selon le type
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
    ).toMap());

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${_getTypeLabel(t.type)} - ${t.tierName}',
      accountCode: htAccount, accountLabel: htLabel,
      debit: htDebit, credit: htCredit,
    ).toMap());

    // 3. Gestion de l'Acompte (seulement pour factures normales)
    if (t.amountPaid > 0 && (t.type == TransactionType.sale || t.type == TransactionType.purchase)) {
      batch.set(_db.collection('payments').doc(), {
        'tierId': t.tierId, 'tierName': t.tierName,
        'tierType': t.type == TransactionType.sale ? 'client' : 'supplier',
        'amount': t.amountPaid, 'date': Timestamp.fromDate(t.date),
        'method': t.paymentMethod, 'reference': 'Acompte ${t.invoiceNumber}',
        'invoiceNumber': t.invoiceNumber, 'createdBy': userName,
      });

      final String cashAccount = t.paymentMethod == 'Espèces' ? '571100' : '521100';
      final String cashLabel = t.paymentMethod == 'Espèces' ? 'Caisse' : 'Banque';

      batch.set(_db.collection('journal').doc(), JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Espèces' ? 'CAI' : 'BQ',
        label: 'Règlement Acompte - ${t.tierName}',
        accountCode: cashAccount, accountLabel: cashLabel,
        debit: t.type == TransactionType.sale ? t.amountPaid : 0,
        credit: t.type == TransactionType.sale ? 0 : t.amountPaid,
      ).toMap());

      batch.set(_db.collection('journal').doc(), JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Espèces' ? 'CAI' : 'BQ',
        label: 'Contrepartie Acompte - ${t.tierName}',
        accountCode: tierAccount, accountLabel: tierLabel,
        debit: t.type == TransactionType.sale ? 0 : t.amountPaid,
        credit: t.type == TransactionType.sale ? t.amountPaid : 0,
      ).toMap());
    }

    await batch.commit();
    await logAction(action: 'add_transaction', entity: 'transactions', entityId: ref.id, userName: userName, details: 'Facture ${t.invoiceNumber} (${t.type}) pour ${t.tierName}');
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

  Future<void> updateTransaction(AppTransaction newTx, AppTransaction oldTx) async {
    WriteBatch batch = _db.batch();
    // Annulation ancien stock
    for (var item in oldTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange;
      if (oldTx.type == TransactionType.sale || oldTx.type == TransactionType.purchaseReturn) {
        reverseChange = item.quantity;
      } else {
        reverseChange = -item.quantity;
      }
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});
      DocumentReference sRef = _db.collection('stocks').doc('${oldTx.warehouseId}_${item.productId}');
      batch.set(sRef, {'quantity': FieldValue.increment(reverseChange)}, SetOptions(merge: true));
    }
    // Application nouveau stock
    for (var item in newTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int change;
      if (newTx.type == TransactionType.sale || newTx.type == TransactionType.purchaseReturn) {
        change = -item.quantity;
      } else {
        change = item.quantity;
      }
      batch.update(pRef, {'totalQuantity': FieldValue.increment(change)});
      DocumentReference sRef = _db.collection('stocks').doc('${newTx.warehouseId}_${item.productId}');
      batch.set(sRef, {'warehouseId': newTx.warehouseId, 'productId': item.productId, 'quantity': FieldValue.increment(change)}, SetOptions(merge: true));
    }
    // Nettoyage compta et enregistrement
    final journals = await _db.collection('journal').where('reference', isEqualTo: oldTx.invoiceNumber).get();
    for (var doc in journals.docs) batch.delete(doc.reference);

    batch.update(_db.collection('transactions').doc(newTx.id), newTx.toMap());
    await batch.commit();
    await logAction(action: 'update_transaction', entity: 'transactions', entityId: newTx.id, userName: 'User', details: 'Modif. Facture ${newTx.invoiceNumber}');
  }

  Future<void> deleteTransaction(String id) async {
    final txDoc = await _db.collection('transactions').doc(id).get();
    if (!txDoc.exists) return;
    final txData = txDoc.data()!;
    if (txData['isPosted'] == true) throw Exception("Facture déjà comptabilisée.");
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
    batch.delete(_db.collection('transactions').doc(id));
    await batch.commit();
    await logAction(action: 'delete_transaction', entity: 'transactions', entityId: id, userName: 'User', details: 'Suppression Facture ${tx.invoiceNumber}');
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

  // --- RÈGLEMENTS ---
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
    await logAction(action: 'add_payment', entity: 'payments', entityId: ref.id, userName: userName, details: 'Règlement de ${p.amount} F pour ${p.tierName}');
  }
  Future<void> deletePayment(String id) async {
    final doc = await _db.collection('payments').doc(id).get();
    await _db.collection('payments').doc(id).delete();
    await logAction(action: 'delete_payment', entity: 'payments', entityId: id, userName: 'User', details: 'Suppression règlement ID: $id');
  }

  Future<void> updatePaymentJournal(String paymentId, String journalCode) {
    return _db.collection('payments').doc(paymentId).update({'journalCode': journalCode});
  }

  // --- DÉPÔTS ---
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
      paymentMethod: 'Espèces', warehouseId: quote.warehouseId,
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
      label: 'Vente (ex-Devis) - ${sale.tierName}', accountCode: '411100', accountLabel: 'Clients',
      debit: sale.totalHT, credit: 0, tierId: sale.tierId, tierName: sale.tierName,
    ).toMap());
    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: sale.date, reference: sale.invoiceNumber, journalCode: 'VEN',
      label: 'Vente (ex-Devis) - ${sale.tierName}', accountCode: '701100', accountLabel: 'Ventes',
      debit: 0, credit: sale.totalHT,
    ).toMap());
    await batch.commit();
  }
    
  Future<void> updatePaymentStatus(String id, bool isPosted) => _db.collection('payments').doc(id).update({'isPosted': isPosted});

  Future<void> syncManagementToAccounting() async {
    final txsSnap = await _db.collection('transactions').get();
    final paysSnap = await _db.collection('payments').get();
    final journalSnap = await _db.collection('journal').get();
    final List<AppTransaction> transactions = txsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    final List<Payment> payments = paysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    final List<String> existingRefs = journalSnap.docs.map((d) => (d.data()['reference'] as String)).toList();
    WriteBatch batch = _db.batch();
    for (var t in transactions) {
      if (!existingRefs.contains(t.invoiceNumber)) {
        batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.type == TransactionType.sale ? 'VEN' : 'ACH', label: 'Vente/Achat - ${t.tierName}', accountCode: t.type == TransactionType.sale ? '411100' : '401100', accountLabel: 'Tiers', debit: t.type == TransactionType.sale ? t.totalHT : 0, credit: t.type == TransactionType.sale ? 0 : t.totalHT, tierId: t.tierId, tierName: t.tierName).toMap());
        batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.type == TransactionType.sale ? 'VEN' : 'ACH', label: 'Vente/Achat - ${t.tierName}', accountCode: t.type == TransactionType.sale ? '701100' : '601100', accountLabel: 'HT', debit: t.type == TransactionType.sale ? 0 : t.totalHT, credit: t.type == TransactionType.sale ? t.totalHT : 0).toMap());
      }
    }
    for (var p in payments) {
      String payRef = p.reference.isEmpty ? 'PAY-${p.id.substring(0,5)}' : p.reference;
      if (!existingRefs.contains(payRef)) {
        String journal = p.journalCode ?? 'BQ';
        batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: p.date, reference: payRef, journalCode: journal, label: 'Règlement ${p.tierName}', accountCode: '521100', accountLabel: 'Banque', debit: p.tierType == TierType.client ? p.amount : 0, credit: p.tierType == TierType.client ? 0 : p.amount).toMap());
        batch.set(_db.collection('journal').doc(), JournalEntry(id: '', date: p.date, reference: payRef, journalCode: journal, label: 'Contrepartie ${p.tierName}', accountCode: p.tierType == TierType.client ? '411100' : '401100', accountLabel: 'Tiers', debit: p.tierType == TierType.client ? 0 : p.amount, credit: p.tierType == TierType.client ? p.amount : 0, tierId: p.tierId, tierName: p.tierName).toMap());
      }
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

  Stream<List<DailyClosing>> getClosings() {
    return _db.collection('closings').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => DailyClosing.fromMap(doc.data(), doc.id)).toList());
  }

  Future<List<Map<String, dynamic>>> getUnpaidReport({required TierType tierType, required DateTime start, required DateTime end}) async {
    final transType = tierType == TierType.client ? TransactionType.sale : TransactionType.purchase;
    final allTxsSnap = await _db.collection('transactions').where('type', isEqualTo: transType.toString().split('.').last).get();
    final allPaysSnap = await _db.collection('payments').where('tierType', isEqualTo: tierType == TierType.client ? 'client' : 'supplier').get();
    final allJournalSnap = await _db.collection('journal').where('accountCode', isEqualTo: tierType == TierType.client ? '411100' : '401100').get();
    List<AppTransaction> allTxs = allTxsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    List<Payment> allPays = allPaysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    List<JournalEntry> allJournal = allJournalSnap.docs.map((d) => JournalEntry.fromMap(d.data(), d.id)).toList();
    allTxs.sort((a, b) => a.date.compareTo(b.date));
    Map<String, double> creditsByTier = {};
    for (var p in allPays) creditsByTier[p.tierId] = (creditsByTier[p.tierId] ?? 0) + p.amount;
    for (var j in allJournal) {
      if (j.tierId != null) {
        double amount = tierType == TierType.client ? j.credit : j.debit;
        if (amount > 0) {
          bool alreadyCounted = allPays.any((p) => p.invoiceNumber == j.reference || p.reference.contains(j.reference));
          if (!alreadyCounted) creditsByTier[j.tierId!] = (creditsByTier[j.tierId!] ?? 0) + amount;
        }
      }
    }
    for (var t in allTxs) {
      if (t.amountPaid > 0) {
        bool dejaCompte = allPays.any((p) => p.invoiceNumber == t.invoiceNumber || p.reference.contains(t.invoiceNumber)) || allJournal.any((j) => j.reference == t.invoiceNumber);
        if (!dejaCompte) creditsByTier[t.tierId] = (creditsByTier[t.tierId] ?? 0) + t.amountPaid;
      }
    }
    List<Map<String, dynamic>> results = [];
    Map<String, double> remainingCredits = Map.from(creditsByTier);
    for (var t in allTxs) {
      double creditTier = remainingCredits[t.tierId] ?? 0;
      double amountApplied = creditTier >= t.netToPay ? t.netToPay : creditTier;
      double reste = t.netToPay - amountApplied;
      remainingCredits[t.tierId] = creditTier - amountApplied;
      if (reste > 10 && t.date.isAfter(start.subtract(const Duration(days: 1))) && t.date.isBefore(end.add(const Duration(days: 1)))) {
        results.add({'transaction': t, 'totalPaid': amountApplied, 'remaining': reste});
      }
    }
    return results;
  }
}
