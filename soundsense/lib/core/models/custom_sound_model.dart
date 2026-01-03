/// Model for custom trained sounds
class CustomSound {
  final String id;
  final String name;
  final String category;
  final String icon;
  final List<List<double>> embeddings; // Multiple samples for accuracy
  final DateTime createdAt;
  final int sampleCount;
  final bool isActive;

  CustomSound({
    required this.id,
    required this.name,
    required this.category,
    this.icon = '🔊',
    required this.embeddings,
    required this.createdAt,
    this.sampleCount = 0,
    this.isActive = true,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'icon': icon,
      'embeddings': embeddings.map((e) => e.toList()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'sampleCount': sampleCount,
      'isActive': isActive,
    };
  }

  /// Create from JSON
  factory CustomSound.fromJson(Map<String, dynamic> json) {
    return CustomSound(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      icon: json['icon'] ?? '🔊',
      embeddings: (json['embeddings'] as List)
          .map((e) => (e as List).map((v) => v as double).toList())
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      sampleCount: json['sampleCount'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  /// Create a copy with updated fields
  CustomSound copyWith({
    String? name,
    String? category,
    String? icon,
    List<List<double>>? embeddings,
    int? sampleCount,
    bool? isActive,
  }) {
    return CustomSound(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      embeddings: embeddings ?? this.embeddings,
      createdAt: createdAt,
      sampleCount: sampleCount ?? this.sampleCount,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Predefined categories for custom sounds
class SoundCategory {
  static const String home = 'Home';
  static const String kitchen = 'Kitchen';
  static const String outdoor = 'Outdoor';
  static const String alert = 'Alert';
  static const String vehicle = 'Vehicle';
  static const String people = 'People';
  static const String pet = 'Pet';
  static const String other = 'Other';

  static List<String> get all => [
    home, kitchen, outdoor, alert, vehicle, people, pet, other
  ];

  static String getIcon(String category) {
    switch (category) {
      case home: return '🏠';
      case kitchen: return '🍳';
      case outdoor: return '🌳';
      case alert: return '🚨';
      case vehicle: return '🚗';
      case people: return '👤';
      case pet: return '🐾';
      default: return '🔊';
    }
  }
}