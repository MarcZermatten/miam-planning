import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../domain/family.dart';
import '../domain/family_member.dart';

/// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Family repository provider
final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

/// Current user's families stream
final userFamiliesProvider = StreamProvider<List<Family>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(familyRepositoryProvider).getUserFamilies(user.uid);
});

/// Current selected family ID - persisted with SharedPreferences
final currentFamilyIdProvider = StateNotifierProvider<CurrentFamilyNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CurrentFamilyNotifier(prefs);
});

/// Notifier for current family ID with persistence
class CurrentFamilyNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'current_family_id';

  CurrentFamilyNotifier(this._prefs) : super(_prefs.getString(_key));

  void setFamilyId(String? familyId) {
    state = familyId;
    if (familyId != null) {
      _prefs.setString(_key, familyId);
    } else {
      _prefs.remove(_key);
    }
  }

  void clearFamilyId() {
    state = null;
    _prefs.remove(_key);
  }
}

/// Current family stream
final currentFamilyProvider = StreamProvider<Family?>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchFamily(familyId);
});

/// Family members stream
final familyMembersProvider = StreamProvider<List<FamilyMember>>((ref) {
  final familyId = ref.watch(currentFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  return ref.watch(familyRepositoryProvider).watchMembers(familyId);
});

/// All allergies in the family (combined from all members)
final familyAllergiesProvider = Provider<Set<String>>((ref) {
  final membersAsync = ref.watch(familyMembersProvider);
  return membersAsync.when(
    data: (members) {
      final allergies = <String>{};
      for (final member in members) {
        allergies.addAll(member.allergies);
      }
      return allergies;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Ingredients to avoid from picky eaters in the family
final pickyEaterAvoidProvider = Provider<Set<String>>((ref) {
  final membersAsync = ref.watch(familyMembersProvider);
  return membersAsync.when(
    data: (members) {
      final avoid = <String>{};
      for (final member in members) {
        if (member.isPickyEater) {
          avoid.addAll(member.avoidIngredients);
        }
      }
      return avoid;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});

/// Toggle for picky eater filter
final filterPickyEaterProvider = StateProvider<bool>((ref) => false);

/// Family repository for Firestore operations
class FamilyRepository {
  final FirebaseFirestore _firestore;
  final dynamic _auth;

  FamilyRepository(this._firestore, this._auth);

  CollectionReference<Map<String, dynamic>> get _familiesRef =>
      _firestore.collection('families');

  CollectionReference<Map<String, dynamic>> _membersRef(String familyId) =>
      _familiesRef.doc(familyId).collection('members');

  /// Create a new family
  Future<Family> createFamily({
    required String name,
    required String odauyX6H2Z,
    required String userName,
  }) async {
    final inviteCode = _generateInviteCode();

    final docRef = _familiesRef.doc();
    final family = Family(
      id: docRef.id,
      name: name,
      createdBy: odauyX6H2Z,
      createdAt: DateTime.now(),
      settings: FamilySettings(),
      inviteCode: inviteCode,
    );

    await docRef.set(family.toFirestore());

    // Add creator as admin member
    await addMember(
      familyId: docRef.id,
      odauyX6H2Z: odauyX6H2Z,
      name: userName,
      role: FamilyRole.admin,
      isKid: false,
    );

    // Update user's familyIds
    await _updateUserFamilies(odauyX6H2Z, docRef.id, add: true);

    return family;
  }

  /// Join a family with invite code
  Future<Family?> joinFamily({
    required String inviteCode,
    required String odauyX6H2Z,
    required String userName,
  }) async {
    final query = await _familiesRef
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final family = Family.fromFirestore(query.docs.first);

    // Check if already a member
    final existingMember = await _membersRef(family.id)
        .where('odauyX6H2Z', isEqualTo: odauyX6H2Z)
        .limit(1)
        .get();

    if (existingMember.docs.isNotEmpty) {
      return family; // Already a member
    }

    // Add as parent by default
    await addMember(
      familyId: family.id,
      odauyX6H2Z: odauyX6H2Z,
      name: userName,
      role: FamilyRole.parent,
      isKid: false,
    );

    await _updateUserFamilies(odauyX6H2Z, family.id, add: true);

    return family;
  }

  /// Add a member to family
  Future<FamilyMember> addMember({
    required String familyId,
    required String odauyX6H2Z,
    required String name,
    required FamilyRole role,
    bool isKid = false,
    List<String>? allergies,
    List<String>? restrictions,
  }) async {
    final docRef = _membersRef(familyId).doc();
    final member = FamilyMember(
      id: docRef.id,
      odauyX6H2Z: odauyX6H2Z,
      name: name,
      role: role,
      isKid: isKid,
      allergies: allergies ?? [],
      restrictions: restrictions ?? [],
      joinedAt: DateTime.now(),
    );

    await docRef.set(member.toFirestore());
    return member;
  }

  /// Update family settings
  Future<void> updateFamily(String familyId, {
    String? name,
    FamilySettings? settings,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (settings != null) updates['settings'] = settings.toMap();

    await _familiesRef.doc(familyId).update(updates);
  }

  /// Update member
  Future<void> updateMember(String familyId, FamilyMember member) async {
    await _membersRef(familyId).doc(member.id).update(member.toFirestore());
  }

  /// Remove member from family
  Future<void> removeMember(String familyId, String memberId, String odauyX6H2Z) async {
    await _membersRef(familyId).doc(memberId).delete();
    await _updateUserFamilies(odauyX6H2Z, familyId, add: false);
  }

  /// Watch a family
  Stream<Family?> watchFamily(String familyId) {
    return _familiesRef.doc(familyId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Family.fromFirestore(doc);
    });
  }

  /// Watch family members
  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _membersRef(familyId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList();
    });
  }

  /// Get user's families
  Stream<List<Family>> getUserFamilies(String odauyX6H2Z) {
    return _firestore
        .collection('users')
        .doc(odauyX6H2Z)
        .snapshots()
        .asyncMap((userDoc) async {
      final familyIds = List<String>.from(userDoc.data()?['familyIds'] ?? []);
      if (familyIds.isEmpty) return <Family>[];

      final families = <Family>[];
      for (final id in familyIds) {
        final doc = await _familiesRef.doc(id).get();
        if (doc.exists) {
          families.add(Family.fromFirestore(doc));
        }
      }
      return families;
    });
  }

  /// Regenerate invite code
  Future<String> regenerateInviteCode(String familyId) async {
    final newCode = _generateInviteCode();
    await _familiesRef.doc(familyId).update({'inviteCode': newCode});
    return newCode;
  }

  /// Update user's family list
  Future<void> _updateUserFamilies(String odauyX6H2Z, String familyId, {required bool add}) async {
    final userRef = _firestore.collection('users').doc(odauyX6H2Z);

    if (add) {
      await userRef.set({
        'familyIds': FieldValue.arrayUnion([familyId]),
      }, SetOptions(merge: true));
    } else {
      await userRef.update({
        'familyIds': FieldValue.arrayRemove([familyId]),
      });
    }
  }

  /// Generate random invite code (6 characters)
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
