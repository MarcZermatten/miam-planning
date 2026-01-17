import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../family/data/family_repository.dart';
import '../domain/wine_bottle.dart';

final wineRepositoryProvider = Provider<WineRepository>((ref) {
  return WineRepository(FirebaseFirestore.instance);
});

final wineBottlesProvider = StreamProvider<List<WineBottle>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(wineRepositoryProvider).watchWineBottles(familyId);
});

class WineRepository {
  final FirebaseFirestore _firestore;

  WineRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _wineCollection(String familyId) {
    return _firestore.collection('families').doc(familyId).collection('wine');
  }

  Stream<List<WineBottle>> watchWineBottles(String familyId) {
    return _wineCollection(familyId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => WineBottle.fromFirestore(doc)).toList());
  }

  Future<void> addWineBottle({
    required String familyId,
    required String name,
    required WineType type,
    String? grape,
    int? year,
    int quantity = 1,
  }) async {
    await _wineCollection(familyId).add({
      'name': name,
      'type': type.name,
      'grape': grape,
      'year': year,
      'quantity': quantity,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateQuantity(String familyId, String wineId, int newQuantity) async {
    if (newQuantity <= 0) {
      await _wineCollection(familyId).doc(wineId).delete();
    } else {
      await _wineCollection(familyId).doc(wineId).update({'quantity': newQuantity});
    }
  }

  Future<void> deleteWineBottle(String familyId, String wineId) async {
    await _wineCollection(familyId).doc(wineId).delete();
  }

  Future<void> updateWineBottle({
    required String familyId,
    required String wineId,
    required String name,
    required WineType type,
    String? grape,
    int? year,
    required int quantity,
  }) async {
    await _wineCollection(familyId).doc(wineId).update({
      'name': name,
      'type': type.name,
      'grape': grape,
      'year': year,
      'quantity': quantity,
    });
  }
}
