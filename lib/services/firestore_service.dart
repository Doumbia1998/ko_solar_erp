import '../models/daily_closing.dart';
import '../models/task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... rest of the code ...

  // --- MODULE TECHNICIENS ---
  Stream<List<Task>> getTasks({String? technicianId}) {
    Query query = _db.collection('tasks').orderBy('assignedAt', descending: true);
    if (technicianId != null) {
      query = query.where('technicianId', isEqualTo: technicianId);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList());
  }

  Future<void> addTask(Task task) => _db.collection('tasks').add(task.toMap());

  Future<void> updateTaskStatus(String taskId, TaskStatus status, {Map<String, dynamic>? reportData}) {
    Map<String, dynamic> data = {'status': status.toString().split('.').last};
    if (reportData != null) {
      data.addAll(reportData);
      if (status == TaskStatus.completed) {
        data['completedAt'] = Timestamp.now();
      }
    }
    return _db.collection('tasks').doc(taskId).update(data);
  }

  Stream<List<AppUser>> getTechnicians() {
    return _db.collection('users').where('role', isEqualTo: 'technician').snapshots().map((snap) =>
        snap.docs.map((doc) => AppUser.fromMap(doc.data())).toList());
  }

  FirestoreService() {
    // Activer la persistance locale pour plus de rapidité (Offline First)
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // --- COMPTABILITÉ (JOURNAL) ---
  Stream<List<JournalEntry>> getJournalEntries() {
    return _db.collection('journal').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => JournalEntry.fromMap(doc.data(), doc.id)).toList());
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
    return _db.collection('journal').doc(entryId).update({
      'lettering': lettering,
    });
  }

  // --- TRANSFERTS DE STOCK ---
  Stream<List<StockTransfer>> getStockTransfers() {
    return _db.collection('stock_transfers').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => StockTransfer.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addStockTransfer(StockTransfer t) async {
    WriteBatch batch = _db.batch();
    
    // 1. Enregistrer l'historique du transfert
    DocumentReference ref = _db.collection('stock_transfers').doc();
    batch.set(ref, t.toMap());

    // 2. Mettre à jour le stock du dépôt SOURCE (Soustraction)
    DocumentReference sourceRef = _db.collection('stocks').doc('${t.fromWarehouseId}_${t.productId}');
    batch.set(sourceRef, {
      'warehouseId': t.fromWarehouseId,
      'productId': t.productId,
      'quantity': FieldValue.increment(-t.quantity)
    }, SetOptions(merge: true));

    // 3. Mettre à jour le stock du dépôt DESTINATION (Addition)
    DocumentReference targetRef = _db.collection('stocks').doc('${t.toWarehouseId}_${t.productId}');
    batch.set(targetRef, {
      'warehouseId': t.toWarehouseId,
      'productId': t.productId,
      'quantity': FieldValue.increment(t.quantity)
    }, SetOptions(merge: true));

    return batch.commit();
  }

  // Obtenir le stock d'un produit dans un dépôt spécifique (Répartition réelle et stricte)
  Future<int> getWarehouseStock(String productId, String warehouseId) async {
    // 1. On cherche l'entrée précise pour ce dépôt et ce produit
    final stockDoc = await _db.collection('stocks').doc('${warehouseId}_${productId}').get();
    
    if (stockDoc.exists) {
      return (stockDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
    }

    // 2. Si aucune entrée n'existe, on vérifie si c'est le "Dépôt Principal"
    final warehouseDoc = await _db.collection('warehouses').doc(warehouseId).get();
    String wName = warehouseDoc.data()?['name']?.toString().toLowerCase() ?? '';
    bool isPrincipal = wName.contains('principal');

    if (isPrincipal) {
      // Si rien n'est ventilé ailleurs, tout est au principal
      final allAllocated = await _db.collection('stocks').where('productId', isEqualTo: productId).get();
      if (allAllocated.docs.isEmpty) {
        final productDoc = await _db.collection('products').doc(productId).get();
        return (productDoc.data()?['totalQuantity'] as num?)?.toInt() ?? 0;
      }
    }

    return 0;
  }

  // Méthode utilitaire pour convertir les dates en toute sécurité
  DateTime _safeDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is Timestamp) return date.toDate();
    return DateTime.now();
  }

  // --- PRODUITS ---
  Stream<List<Product>> getProducts() {
    return _db.collection('products').snapshots().map((snap) =>
        snap.docs.map((doc) => Product.fromMap(doc.data(), doc.id)).toList());
  }
  Future<void> addProduct(Product p, {String? warehouseId}) async {
    DocumentReference ref = await _db.collection('products').add(p.toMap());
    
    // Si un dépôt est spécifié et qu'il y a un stock initial, on crée l'entrée de stock
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
    // Vérifier si le produit est utilisé dans des transactions
    final txSnap = await _db.collection('transactions').get();
    final hasTx = txSnap.docs.any((doc) {
      final items = (doc.data()['items'] as List?) ?? [];
      return items.any((item) => item['productId'] == id);
    });
    if (hasTx) throw Exception("Impossible de supprimer : cet article est présent dans des factures d'achat ou de vente.");

    // Vérifier si le produit est utilisé dans des transferts
    final transferSnap = await _db.collection('stock_transfers').where('productId', isEqualTo: id).get();
    if (transferSnap.docs.isNotEmpty) throw Exception("Impossible de supprimer : cet article a un historique de transferts.");

    return _db.collection('products').doc(id).delete();
  }

  // --- TIERS (Clients/Fournisseurs) ---
  Stream<List<Tier>> getTiers(TierType? type) {
    return _db.collection('tiers').snapshots().map((snap) {
      var list = snap.docs.map((doc) => Tier.fromMap(doc.data(), doc.id)).toList();
      if (type != null) list = list.where((t) => t.type == type).toList();
      return list;
    });
  }
  Future<void> addTier(Tier t) => _db.collection('tiers').add(t.toMap());
  Future<void> updateTier(Tier t) => _db.collection('tiers').doc(t.id).update(t.toMap());
  Future<void> deleteTier(String id) => _db.collection('tiers').doc(id).delete();

  // --- TRANSACTIONS (Ventes/Achats) ---
  Stream<List<AppTransaction>> getTransactions({TransactionType? type}) {
    return _db.collection('transactions').snapshots().map((snap) {
      var list = snap.docs.map((doc) => AppTransaction.fromMap(doc.data(), doc.id)).toList();
      if (type != null) list = list.where((t) => t.type == type).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
  Future<void> addTransaction(AppTransaction t, String userName) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('transactions').doc();
    
    // Ajouter le créateur au map avant l'enregistrement
    Map<String, dynamic> data = t.toMap();
    data['createdBy'] = userName;
    
    batch.set(ref, data);

    // Si c'est un DEVIS, on ne fait rien d'autre (ni stock, ni compta)
    if (t.type == TransactionType.quote) {
      return batch.commit();
    }

    // 1. Mise à jour du stock global et local (par dépôt)
    for (var item in t.items) {
      // Stock Global
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int change = t.type == TransactionType.sale ? -item.quantity : item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(change)});

      // Stock Local au Dépôt
      DocumentReference sRef = _db.collection('stocks').doc('${t.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'warehouseId': t.warehouseId,
        'productId': item.productId,
        'quantity': FieldValue.increment(change)
      }, SetOptions(merge: true));
    }

    // 2. Écritures Comptables Automatiques (SYSCOHADA)
    final String journal = t.type == TransactionType.sale ? 'VEN' : 'ACH';
    
    // Ligne Tiers (Client 411 ou Fournisseur 401)
    final String tierAccount = t.type == TransactionType.sale ? '411100' : '401100';
    final String tierLabel = t.type == TransactionType.sale ? 'Clients' : 'Fournisseurs';

    // Ligne HT : Récupération des comptes spécifiques aux articles
    // Note : Pour une facture multi-articles, on peut soit ventiler, 
    // soit utiliser le compte du premier article pour simplifier selon votre demande
    String htAccount = t.type == TransactionType.sale ? '701100' : '601100';
    String htLabel = t.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises';

    // Si on a des articles, on cherche le compte paramétré sur le premier article
    if (t.items.isNotEmpty) {
      final pDoc = await _db.collection('products').doc(t.items.first.productId).get();
      if (pDoc.exists) {
        final pData = pDoc.data()!;
        if (t.type == TransactionType.sale) {
          htAccount = pData['compteVente'] ?? '701100';
        } else {
          htAccount = pData['compteAchat'] ?? '601100';
        }
      }
    }

    // Écriture de la facture (Tiers)
    DocumentReference j1 = _db.collection('journal').doc();
    batch.set(j1, JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${t.type == TransactionType.sale ? "Vente" : "Achat"} - ${t.tierName}',
      accountCode: tierAccount, accountLabel: tierLabel,
      debit: t.type == TransactionType.sale ? t.totalHT : 0,
      credit: t.type == TransactionType.sale ? 0 : t.totalHT,
      tierId: t.tierId, tierName: t.tierName,
    ).toMap());

    // Écriture de la facture (Produit/Charge)
    DocumentReference j2 = _db.collection('journal').doc();
    batch.set(j2, JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${t.type == TransactionType.sale ? "Vente" : "Achat"} - ${t.tierName}',
      accountCode: htAccount, accountLabel: htLabel,
      debit: t.type == TransactionType.sale ? 0 : t.totalHT,
      credit: t.type == TransactionType.sale ? t.totalHT : 0,
    ).toMap());

    // 3. Gestion de l'Acompte (Règlement immédiat)
    if (t.amountPaid > 0) {
      // Enregistrer le paiement dans la collection payments
      DocumentReference pRef = _db.collection('payments').doc();
      batch.set(pRef, {
        'tierId': t.tierId,
        'tierName': t.tierName,
        'tierType': t.type == TransactionType.sale ? 'client' : 'supplier',
        'amount': t.amountPaid,
        'date': Timestamp.fromDate(t.date),
        'method': t.paymentMethod,
        'reference': 'Acompte ${t.invoiceNumber}',
        'invoiceNumber': t.invoiceNumber,
        'createdBy': userName,
      });

      // Écriture de l'acompte au journal (Caisse 571 contre Tiers 411/401)
      final String cashAccount = t.paymentMethod == 'Espèces' ? '571100' : '521100';
      final String cashLabel = t.paymentMethod == 'Espèces' ? 'Caisse' : 'Banque';

      DocumentReference j3 = _db.collection('journal').doc();
      batch.set(j3, JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Espèces' ? 'CAI' : 'BQ',
        label: 'Règlement Acompte - ${t.tierName}',
        accountCode: cashAccount, accountLabel: cashLabel,
        debit: t.type == TransactionType.sale ? t.amountPaid : 0,
        credit: t.type == TransactionType.sale ? 0 : t.amountPaid,
      ).toMap());

      DocumentReference j4 = _db.collection('journal').doc();
      batch.set(j4, JournalEntry(
        id: '', date: t.date, reference: t.invoiceNumber, journalCode: t.paymentMethod == 'Espèces' ? 'CAI' : 'BQ',
        label: 'Contrepartie Acompte - ${t.tierName}',
        accountCode: tierAccount, accountLabel: tierLabel,
        debit: t.type == TransactionType.sale ? 0 : t.amountPaid,
        credit: t.type == TransactionType.sale ? t.amountPaid : 0,
      ).toMap());
    }

    return batch.commit();
  }

  Future<void> updateTransaction(AppTransaction newTx, AppTransaction oldTx) async {
    WriteBatch batch = _db.batch();
    
    // 1. Annuler l'ancien impact sur le stock (Global + Local)
    for (var item in oldTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange = oldTx.type == TransactionType.sale ? item.quantity : -item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});

      DocumentReference sRef = _db.collection('stocks').doc('${oldTx.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'quantity': FieldValue.increment(reverseChange)
      }, SetOptions(merge: true));
    }

    // 2. Appliquer le nouvel impact sur le stock (Global + Local)
    for (var item in newTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int newChange = newTx.type == TransactionType.sale ? -item.quantity : item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(newChange)});

      DocumentReference sRef = _db.collection('stocks').doc('${newTx.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'warehouseId': newTx.warehouseId,
        'productId': item.productId,
        'quantity': FieldValue.increment(newChange)
      }, SetOptions(merge: true));
    }

    // 3. Supprimer les anciennes écritures comptables
    final journals = await _db.collection('journal').where('reference', isEqualTo: oldTx.invoiceNumber).get();
    for (var doc in journals.docs) {
      batch.delete(doc.reference);
    }

    // 4. Recréer les écritures comptables (Copie de la logique addTransaction)
    final String journal = newTx.type == TransactionType.sale ? 'VEN' : 'ACH';
    final String tierAccount = newTx.type == TransactionType.sale ? '411100' : '401100';
    final String tierLabel = newTx.type == TransactionType.sale ? 'Clients' : 'Fournisseurs';
    final String htAccount = newTx.type == TransactionType.sale ? '701100' : '601100';
    final String htLabel = newTx.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises';

    DocumentReference j1 = _db.collection('journal').doc();
    batch.set(j1, JournalEntry(
      id: '', date: newTx.date, reference: newTx.invoiceNumber, journalCode: journal,
      label: '${newTx.type == TransactionType.sale ? "Vente" : "Achat"} - ${newTx.tierName}',
      accountCode: tierAccount, accountLabel: tierLabel,
      debit: newTx.type == TransactionType.sale ? newTx.totalHT : 0,
      credit: newTx.type == TransactionType.sale ? 0 : newTx.totalHT,
    ).toMap());

    DocumentReference j2 = _db.collection('journal').doc();
    batch.set(j2, JournalEntry(
      id: '', date: newTx.date, reference: newTx.invoiceNumber, journalCode: journal,
      label: '${newTx.type == TransactionType.sale ? "Vente" : "Achat"} - ${newTx.tierName}',
      accountCode: htAccount, accountLabel: htLabel,
      debit: newTx.type == TransactionType.sale ? 0 : newTx.totalHT,
      credit: newTx.type == TransactionType.sale ? newTx.totalHT : 0,
    ).toMap());

    // 5. Mettre à jour la transaction
    batch.update(_db.collection('transactions').doc(newTx.id), newTx.toMap());
    
    return batch.commit();
  }
  Future<void> deleteTransaction(String id) async {
    // 1. Vérifier s'il y a des règlements liés à cette facture
    // Note: Dans notre système, les règlements sont liés via le tier et la date/référence si on veut être précis.
    // Pour simplifier selon votre demande : si le client a déjà fait des règlements globaux, on bloque ou on demande vérification.
    // Mais plus précisément, vérifions si un acompte a été saisi initialement (amountPaid > 0)
    final txDoc = await _db.collection('transactions').doc(id).get();
    if (!txDoc.exists) return;
    
    final txData = txDoc.data() as Map<String, dynamic>;
    if (txData['isPosted'] == true) {
      throw Exception("Impossible de supprimer une facture déjà comptabilisée (Validée).");
    }
    
    final double amountPaid = (txData['amountPaid'] as num?)?.toDouble() ?? 0;
    
    if (amountPaid > 0) {
      // Vérifier si un paiement correspondant existe réellement dans la collection payments
      final tx = AppTransaction.fromMap(txData, id);
      final paymentsSnap = await _db.collection('payments')
          .where('tierId', isEqualTo: tx.tierId)
          .where('invoiceNumber', isEqualTo: tx.invoiceNumber)
          .get();
      
      if (paymentsSnap.docs.isNotEmpty) {
        throw Exception("Cette facture contient un règlement. Veuillez d'abord supprimer le règlement associé dans l'historique du client.");
      }
    }

    // 2. Annuler l'impact sur le stock (Global + Local) avant de supprimer
    final tx = AppTransaction.fromMap(txData, id);
    WriteBatch batch = _db.batch();
    for (var item in tx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange = tx.type == TransactionType.sale ? item.quantity : -item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});

      DocumentReference sRef = _db.collection('stocks').doc('${tx.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'quantity': FieldValue.increment(reverseChange)
      }, SetOptions(merge: true));
    }

    // 3. Supprimer les écritures comptables liées
    final journals = await _db.collection('journal').where('reference', isEqualTo: tx.invoiceNumber).get();
    for (var doc in journals.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(_db.collection('transactions').doc(id));
    return batch.commit();
  }

  // --- TRANSPORT (Camions/Voyages) ---
  Stream<List<Truck>> getTrucks() {
    return _db.collection('trucks').snapshots().map((snap) =>
        snap.docs.map((doc) => Truck.fromMap(doc.data(), doc.id)).toList());
  }
  Future<void> addTruck(Truck t) => _db.collection('trucks').add(t.toMap());
  Future<void> updateTruck(Truck t) => _db.collection('trucks').doc(t.id).update(t.toMap());
  Future<void> deleteTruck(String id) => _db.collection('trucks').doc(id).delete();

  Stream<List<Trip>> getTrips({String? truckId}) {
    return _db.collection('trips').snapshots().map((snap) {
      var list = snap.docs.map((doc) => Trip.fromMap(doc.data(), doc.id)).toList();
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
      var list = snap.docs.map((doc) => Payment.fromMap(doc.data(), doc.id)).toList();
      if (tierId != null) list = list.where((p) => p.tierId == tierId).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }
  Future<void> addPayment(Payment p, String userName) async {
    Map<String, dynamic> data = p.toMap();
    data['createdBy'] = userName;
    await _db.collection('payments').add(data);
  }
  Future<void> deletePayment(String id) => _db.collection('payments').doc(id).delete();

  // --- DÉPÔTS ---
  Stream<List<Warehouse>> getWarehouses() {
    return _db.collection('warehouses').snapshots().map((snap) =>
        snap.docs.map((doc) => Warehouse.fromMap(doc.data(), doc.id)).toList());
  }
  Future<void> addWarehouse(Warehouse w) => _db.collection('warehouses').add(w.toMap());
  Future<void> deleteWarehouse(String id) => _db.collection('warehouses').doc(id).delete();

  // --- COMPTES COMPTABLES ---
  Stream<List<Account>> getAccounts() {
    return _db.collection('accounts').snapshots().map((snap) =>
        snap.docs.map((doc) => Account.fromMap(doc.data(), doc.id)).toList());
  }
  Future<void> addAccount(Account a) => _db.collection('accounts').add(a.toMap());
  Future<void> updateAccount(Account a) => _db.collection('accounts').doc(a.id).update(a.toMap());
  Future<void> deleteAccount(String id) => _db.collection('accounts').doc(id).delete();

  Future<void> updateTransactionStatus(String id, bool isPosted) => 
    _db.collection('transactions').doc(id).update({'isPosted': isPosted});

  Future<void> updateDeliveryStatus(String id, String status) => 
    _db.collection('transactions').doc(id).update({'deliveryStatus': status});

  Future<void> convertQuoteToSale(AppTransaction quote, String userName) async {
    WriteBatch batch = _db.batch();

    final newInvoiceNumber = 'FA${DateFormat('ddMMyyHHmm').format(DateTime.now())}';
    
    final sale = AppTransaction(
      id: _db.collection('transactions').doc().id,
      invoiceNumber: newInvoiceNumber,
      date: DateTime.now(),
      tierId: quote.tierId,
      tierName: quote.tierName,
      type: TransactionType.sale,
      items: quote.items,
      totalHT: quote.totalHT,
      amountPaid: 0,
      paymentMethod: 'Espèces',
      warehouseId: quote.warehouseId,
      destination: quote.destination,
      transportFees: quote.transportFees,
      addTransport: quote.addTransport,
      createdBy: userName,
    );

    // 1. Créer la vente
    batch.set(_db.collection('transactions').doc(sale.id), sale.toMap());
    
    // 2. Supprimer le devis
    batch.delete(_db.collection('transactions').doc(quote.id));

    // 3. Gérer les stocks
    for (var item in sale.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      batch.update(pRef, {'totalQuantity': FieldValue.increment(-item.quantity)});

      DocumentReference sRef = _db.collection('stocks').doc('${sale.warehouseId}_${item.productId}');
      batch.set(sRef, {
        'warehouseId': sale.warehouseId,
        'productId': item.productId,
        'quantity': FieldValue.increment(-item.quantity)
      }, SetOptions(merge: true));
    }

    // 4. Écritures comptables
    final String tierAccount = '411100';
    final String htAccount = '701100';

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: sale.date, reference: sale.invoiceNumber, journalCode: 'VEN',
      label: 'Vente (ex-Devis) - ${sale.tierName}',
      accountCode: tierAccount, accountLabel: 'Clients',
      debit: sale.totalHT, credit: 0,
      tierId: sale.tierId, tierName: sale.tierName,
    ).toMap());

    batch.set(_db.collection('journal').doc(), JournalEntry(
      id: '', date: sale.date, reference: sale.invoiceNumber, journalCode: 'VEN',
      label: 'Vente (ex-Devis) - ${sale.tierName}',
      accountCode: htAccount, accountLabel: 'Ventes de marchandises',
      debit: 0, credit: sale.totalHT,
    ).toMap());

    await batch.commit();
  }
    
  Future<void> updatePaymentStatus(String id, bool isPosted) => 
    _db.collection('payments').doc(id).update({'isPosted': isPosted});

  // --- SYNCHRONISATION GESTION -> COMPTABILITÉ ---
  Future<void> syncManagementToAccounting() async {
    final txsSnap = await _db.collection('transactions').get();
    final paysSnap = await _db.collection('payments').get();
    final journalSnap = await _db.collection('journal').get();

    final List<AppTransaction> transactions = txsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    final List<Payment> payments = paysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    final List<String> existingRefs = journalSnap.docs.map((d) => (d.data()['reference'] as String)).toList();

    WriteBatch batch = _db.batch();
    int count = 0;

    // 1. Synchroniser les Transactions (Factures)
    for (var t in transactions) {
      if (!existingRefs.contains(t.invoiceNumber)) {
        final String journal = t.type == TransactionType.sale ? 'VEN' : 'ACH';
        final String tierAccount = t.type == TransactionType.sale ? '411100' : '401100';
        final String tierLabel = t.type == TransactionType.sale ? 'Clients' : 'Fournisseurs';
        final String htAccount = t.type == TransactionType.sale ? '701100' : '601100';
        final String htLabel = t.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises';

        DocumentReference j1 = _db.collection('journal').doc();
        batch.set(j1, JournalEntry(
          id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
          label: '${t.type == TransactionType.sale ? "Vente" : "Achat"} - ${t.tierName}',
          accountCode: tierAccount, accountLabel: tierLabel,
          debit: t.type == TransactionType.sale ? t.totalHT : 0,
          credit: t.type == TransactionType.sale ? 0 : t.totalHT,
          tierId: t.tierId, tierName: t.tierName,
        ).toMap());

        DocumentReference j2 = _db.collection('journal').doc();
        batch.set(j2, JournalEntry(
          id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
          label: '${t.type == TransactionType.sale ? "Vente" : "Achat"} - ${t.tierName}',
          accountCode: htAccount, accountLabel: htLabel,
          debit: t.type == TransactionType.sale ? 0 : t.totalHT,
          credit: t.type == TransactionType.sale ? t.totalHT : 0,
        ).toMap());
        count += 2;
      }
    }

    // 2. Synchroniser les Règlements (Paiements)
    for (var p in payments) {
      String payRef = p.reference.isEmpty ? 'PAY-${p.id.substring(0,5)}' : p.reference;
      // Pour les acomptes liés aux factures, on évite les doublons si la ref est le numéro de facture
      if (!existingRefs.contains(payRef)) {
        // --- LOGIQUE DE MAPPING JOURNAL / COMPTE ---
        String journalCode = 'BQ';
        String cashAccount = '521100';
        String cashLabel = 'Banque';
        String m = p.method.toLowerCase();

        if (m.contains('sanogo')) {
          journalCode = 'CAS';
          cashAccount = '571200';
          cashLabel = 'Caisse Sanogo';
        } else if (m.contains('principal')) {
          journalCode = 'CAP';
          cashAccount = '571100';
          cashLabel = 'Caisse Principal';
        } else if (m.contains('dépendes') || m.contains('dépenses') || m.contains('depense')) {
          journalCode = 'CAD';
          cashAccount = '571300';
          cashLabel = 'Caisse Dépenses';
        } else if (m.contains('espèce') || m.contains('espece') || m.contains('cash')) {
          journalCode = 'CAP'; // Par défaut Principal pour les espèces
          cashAccount = '571100';
          cashLabel = 'Caisse Principal';
        } else if (m.contains('bim') || m.contains('banque') || m.contains('chèque') || m.contains('virement')) {
          journalCode = 'BQ';
          cashAccount = '521100';
          cashLabel = 'Banque BIM SA';
        }

        final String tierAccount = p.tierType == TierType.client ? '411100' : '401100';
        final String tierLabel = p.tierType == TierType.client ? 'Clients' : 'Fournisseurs';

        DocumentReference j1 = _db.collection('journal').doc();
        batch.set(j1, JournalEntry(
          id: '', date: p.date, reference: payRef, journalCode: journalCode,
          label: 'Règlement ${p.tierName}',
          accountCode: cashAccount, accountLabel: cashLabel,
          debit: p.tierType == TierType.client ? p.amount : 0,
          credit: p.tierType == TierType.client ? 0 : p.amount,
        ).toMap());

        DocumentReference j2 = _db.collection('journal').doc();
        batch.set(j2, JournalEntry(
          id: '', date: p.date, reference: payRef, journalCode: journalCode,
          label: 'Contrepartie règlement ${p.tierName}',
          accountCode: tierAccount, accountLabel: tierLabel,
          debit: p.tierType == TierType.client ? 0 : p.amount,
          credit: p.tierType == TierType.client ? p.amount : 0,
          tierId: p.tierId, tierName: p.tierName,
        ).toMap());
        count += 2;
      }
    }

    if (count > 0) await batch.commit();
  }

  // --- CLÔTURE DE JOURNÉE ---
  Future<void> performDailyClosing(DailyClosing closing) async {
    WriteBatch batch = _db.batch();
    
    // 1. Enregistrer la clôture
    DocumentReference ref = _db.collection('closings').doc();
    batch.set(ref, closing.toMap());

    // 2. Verrouiller toutes les transactions de la journée
    DateTime startOfDay = DateTime(closing.date.year, closing.date.month, closing.date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final txs = await _db.collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();
    
    for (var doc in txs.docs) {
      batch.update(doc.reference, {'isPosted': true});
    }

    // 3. Verrouiller tous les paiements de la journée
    final payments = await _db.collection('payments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (var doc in payments.docs) {
      batch.update(doc.reference, {'isPosted': true});
    }

    return batch.commit();
  }

  Stream<List<DailyClosing>> getClosings() {
    return _db.collection('closings').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => DailyClosing.fromMap(doc.data(), doc.id)).toList());
  }

  // --- LOGIQUE DE SOLDE UNIFIÉE (Source de vérité) ---
  Future<List<Map<String, dynamic>>> getUnpaidReport({
    required TierType tierType,
    required DateTime start,
    required DateTime end,
  }) async {
    final transType = tierType == TierType.client ? TransactionType.sale : TransactionType.purchase;
    
    // 1. Récupérer TOUT l'historique (Transactions + Règlements + Journal)
    final allTxsSnap = await _db.collection('transactions')
        .where('type', isEqualTo: transType.toString().split('.').last)
        .get();
    final allPaysSnap = await _db.collection('payments')
        .where('tierType', isEqualTo: tierType == TierType.client ? 'client' : 'supplier')
        .get();
    final allJournalSnap = await _db.collection('journal')
        .where('accountCode', isEqualTo: tierType == TierType.client ? '411100' : '401100')
        .get();

    List<AppTransaction> allTxs = allTxsSnap.docs.map((d) => AppTransaction.fromMap(d.data(), d.id)).toList();
    List<Payment> allPays = allPaysSnap.docs.map((d) => Payment.fromMap(d.data(), d.id)).toList();
    List<JournalEntry> allJournal = allJournalSnap.docs.map((d) => JournalEntry.fromMap(d.data(), d.id)).toList();

    allTxs.sort((a, b) => a.date.compareTo(b.date));

    // 2. Calculer le Crédit Total par Tiers
    Map<String, double> creditsByTier = {};

    // a. Crédit via le module Règlements
    for (var p in allPays) {
      creditsByTier[p.tierId] = (creditsByTier[p.tierId] ?? 0) + p.amount;
    }
    
    // b. Crédit via les écritures manuelles du Journal (Comptabilité auxiliaire)
    for (var j in allJournal) {
      if (j.tierId != null) {
        // Pour un client (411), un Crédit diminue sa dette
        // Pour un fournisseur (401), un Débit diminue notre dette
        double amount = tierType == TierType.client ? j.credit : j.debit;
        if (amount > 0) {
          // On vérifie que ce n'est pas une écriture automatique déjà comptée (via invoiceNumber)
          bool alreadyCounted = allPays.any((p) => p.invoiceNumber == j.reference || p.reference.contains(j.reference));
          if (!alreadyCounted) {
            creditsByTier[j.tierId!] = (creditsByTier[j.tierId!] ?? 0) + amount;
          }
        }
      }
    }

    // c. Crédit via les acomptes directs en facture
    for (var t in allTxs) {
      if (t.amountPaid > 0) {
        bool dejaCompte = allPays.any((p) => p.invoiceNumber == t.invoiceNumber || p.reference.contains(t.invoiceNumber)) ||
                          allJournal.any((j) => j.reference == t.invoiceNumber);
        if (!dejaCompte) {
          creditsByTier[t.tierId] = (creditsByTier[t.tierId] ?? 0) + t.amountPaid;
        }
      }
    }

    // 3. Imputer les crédits (FIFO)
    List<Map<String, dynamic>> results = [];
    Map<String, double> remainingCredits = Map.from(creditsByTier);

    for (var t in allTxs) {
      double creditTier = remainingCredits[t.tierId] ?? 0;
      double amountApplied = creditTier >= t.netToPay ? t.netToPay : creditTier;
      double reste = t.netToPay - amountApplied;
      
      remainingCredits[t.tierId] = creditTier - amountApplied;

      if (reste > 10 && t.date.isAfter(start.subtract(const Duration(days: 1))) && t.date.isBefore(end.add(const Duration(days: 1)))) {
        results.add({
          'transaction': t,
          'totalPaid': amountApplied,
          'remaining': reste,
        });
      }
    }
    return results;
  }
}
