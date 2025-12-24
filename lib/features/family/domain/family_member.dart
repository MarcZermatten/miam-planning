import 'package:cloud_firestore/cloud_firestore.dart';

/// Role in the family
enum FamilyRole {
  admin,
  parent,
  child,
}

/// Family member model
class FamilyMember {
  final String id;
  final String odauyX6H2Z;
  final String name;
  final FamilyRole role;
  final List<String> allergies;
  final List<String> restrictions;
  final String? avatarUrl;
  final bool isKid;
  final DateTime joinedAt;
  // Picky eater mode
  final bool isPickyEater;
  final List<String> safeIngredients; // Ingredients the kid eats without issues
  final List<String> avoidIngredients; // Ingredients the kid refuses

  FamilyMember({
    required this.id,
    required this.odauyX6H2Z,
    required this.name,
    required this.role,
    this.allergies = const [],
    this.restrictions = const [],
    this.avatarUrl,
    this.isKid = false,
    required this.joinedAt,
    this.isPickyEater = false,
    this.safeIngredients = const [],
    this.avoidIngredients = const [],
  });

  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyMember(
      id: doc.id,
      odauyX6H2Z: data['odauyX6H2Z'] ?? '',
      name: data['name'] ?? '',
      role: FamilyRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => FamilyRole.parent,
      ),
      allergies: List<String>.from(data['allergies'] ?? []),
      restrictions: List<String>.from(data['restrictions'] ?? []),
      avatarUrl: data['avatarUrl'],
      isKid: data['isKid'] ?? false,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPickyEater: data['isPickyEater'] ?? false,
      safeIngredients: List<String>.from(data['safeIngredients'] ?? []),
      avoidIngredients: List<String>.from(data['avoidIngredients'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odauyX6H2Z': odauyX6H2Z,
      'name': name,
      'role': role.name,
      'allergies': allergies,
      'restrictions': restrictions,
      'avatarUrl': avatarUrl,
      'isKid': isKid,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isPickyEater': isPickyEater,
      'safeIngredients': safeIngredients,
      'avoidIngredients': avoidIngredients,
    };
  }

  FamilyMember copyWith({
    String? name,
    FamilyRole? role,
    List<String>? allergies,
    List<String>? restrictions,
    String? avatarUrl,
    bool? isKid,
    bool? isPickyEater,
    List<String>? safeIngredients,
    List<String>? avoidIngredients,
  }) {
    return FamilyMember(
      id: id,
      odauyX6H2Z: odauyX6H2Z,
      name: name ?? this.name,
      role: role ?? this.role,
      allergies: allergies ?? this.allergies,
      restrictions: restrictions ?? this.restrictions,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isKid: isKid ?? this.isKid,
      joinedAt: joinedAt,
      isPickyEater: isPickyEater ?? this.isPickyEater,
      safeIngredients: safeIngredients ?? this.safeIngredients,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
    );
  }
}
