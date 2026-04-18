import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/tier.dart';
import '../models/transaction.dart';
import '../models/warehouse.dart';
import '../models/transport.dart';
import '../models/payment.dart';
import '../models/account.dart';
import '../models/stock_transfer.dart';
import '../models/journal_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  // --- TRANSFERTS DE STOCK ---
  Stream<List<StockTransfer>> getStockTransfers() {
    return _db.collection('stock_transfers').orderBy('date', descending: true).snapshots().map((snap) =>
        snap.docs.map((doc) => StockTransfer.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addStockTransfer(StockTransfer t) async {
    WriteBatch batch = _db.batch();
    DocumentReference ref = _db.collection('stock_transfers').doc();
    batch.set(ref, t.toMap());
    return batch.commit();
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
  Future<void> addProduct(Product p) => _db.collection('products').add(p.toMap());
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

    // 1. Mise à jour du stock
    for (var item in t.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int change = t.type == TransactionType.sale ? -item.quantity : item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(change)});
    }

    // 2. Écritures Comptables Automatiques (SYSCOHADA)
    final String journal = t.type == TransactionType.sale ? 'VEN' : 'ACH';
    
    // Ligne Tiers (Client 411 ou Fournisseur 401)
    final String tierAccount = t.type == TransactionType.sale ? '411100' : '401100';
    final String tierLabel = t.type == TransactionType.sale ? 'Clients' : 'Fournisseurs';
    
    // Ligne HT (Vente 701 ou Achat 601)
    final String htAccount = t.type == TransactionType.sale ? '701100' : '601100';
    final String htLabel = t.type == TransactionType.sale ? 'Ventes de marchandises' : 'Achats de marchandises';

    // Écriture de la facture (Total HT)
    DocumentReference j1 = _db.collection('journal').doc();
    batch.set(j1, JournalEntry(
      id: '', date: t.date, reference: t.invoiceNumber, journalCode: journal,
      label: '${t.type == TransactionType.sale ? "Vente" : "Achat"} - ${t.tierName}',
      accountCode: tierAccount, accountLabel: tierLabel,
      debit: t.type == TransactionType.sale ? t.totalHT : 0,
      credit: t.type == TransactionType.sale ? 0 : t.totalHT,
    ).toMap());

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
    
    // 1. Annuler l'ancien impact sur le stock
    for (var item in oldTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange = oldTx.type == TransactionType.sale ? item.quantity : -item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});
    }

    // 2. Appliquer le nouvel impact sur le stock
    for (var item in newTx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int newChange = newTx.type == TransactionType.sale ? -item.quantity : item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(newChange)});
    }

    // 3. Mettre à jour la transaction
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
    final double amountPaid = (txData['amountPaid'] as num?)?.toDouble() ?? 0;
    
    if (amountPaid > 0) {
      throw Exception("Cette facture contient un acompte. Veuillez d'abord supprimer le règlement associé dans le module Règlements.");
    }

    // 2. Annuler l'impact sur le stock avant de supprimer
    final tx = AppTransaction.fromMap(txData, id);
    WriteBatch batch = _db.batch();
    for (var item in tx.items) {
      DocumentReference pRef = _db.collection('products').doc(item.productId);
      int reverseChange = tx.type == TransactionType.sale ? item.quantity : -item.quantity;
      batch.update(pRef, {'totalQuantity': FieldValue.increment(reverseChange)});
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
    
  Future<void> updatePaymentStatus(String id, bool isPosted) => 
    _db.collection('payments').doc(id).update({'isPosted': isPosted});
}
