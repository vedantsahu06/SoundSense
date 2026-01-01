/// Model for voice profiles (speaker identification)
class VoiceProfile {
  final String id;
  final String name;
  final String relationship; // Mom, Dad, Sister, Friend, etc.
  final String emoji;
  final List<List<double>> voiceEmbeddings; // Voice signature
  final DateTime createdAt;
  final int sampleCount;
  final bool isActive;
  final double? averagePitch; // Optional voice characteristics
  final double? averageEnergy;

  VoiceProfile({
    required this.id,
    required this.name,
    required this.relationship,
    this.emoji = '👤',
    required this.voiceEmbeddings,
    required this.createdAt,
    this.sampleCount = 0,
    this.isActive = true,
    this.averagePitch,
    this.averageEnergy,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'emoji': emoji,
      'voiceEmbeddings': voiceEmbeddings.map((e) => e.toList()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'sampleCount': sampleCount,
      'isActive': isActive,
      'averagePitch': averagePitch,
      'averageEnergy': averageEnergy,
    };
  }

  /// Create from JSON
  factory VoiceProfile.fromJson(Map<String, dynamic> json) {
    return VoiceProfile(
      id: json['id'],
      name: json['name'],
      relationship: json['relationship'],
      emoji: json['emoji'] ?? '👤',
      voiceEmbeddings: (json['voiceEmbeddings'] as List)
          .map((e) => (e as List).map((v) => v as double).toList())
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      sampleCount: json['sampleCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      averagePitch: json['averagePitch'],
      averageEnergy: json['averageEnergy'],
    );
  }

  /// Create a copy with updated fields
  VoiceProfile copyWith({
    String? name,
    String? relationship,
    String? emoji,
    List<List<double>>? voiceEmbeddings,
    int? sampleCount,
    bool? isActive,
    double? averagePitch,
    double? averageEnergy,
  }) {
    return VoiceProfile(
      id: id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      emoji: emoji ?? this.emoji,
      voiceEmbeddings: voiceEmbeddings ?? this.voiceEmbeddings,
      createdAt: createdAt,
      sampleCount: sampleCount ?? this.sampleCount,
      isActive: isActive ?? this.isActive,
      averagePitch: averagePitch ?? this.averagePitch,
      averageEnergy: averageEnergy ?? this.averageEnergy,
    );
  }
}

/// Predefined relationships
class Relationship {
  static const String mom = 'Mom';
  static const String dad = 'Dad';
  static const String sister = 'Sister';
  static const String brother = 'Brother';
  static const String spouse = 'Spouse';
  static const String child = 'Child';
  static const String friend = 'Friend';
  static const String colleague = 'Colleague';
  static const String other = 'Other';

  static List<String> get all => [
    mom, dad, sister, brother, spouse, child, friend, colleague, other
  ];

  static String getEmoji(String relationship) {
    switch (relationship) {
      case mom: return '👩';
      case dad: return '👨';
      case sister: return '👧';
      case brother: return '👦';
      case spouse: return '💑';
      case child: return '👶';
      case friend: return '🧑‍🤝‍🧑';
      case colleague: return '💼';
      default: return '👤';
    }
  }
}

/// Result of speaker identification
class SpeakerIdentificationResult {
  final VoiceProfile? speaker;
  final double confidence;
  final bool isUnknown;

  SpeakerIdentificationResult({
    this.speaker,
    required this.confidence,
    this.isUnknown = false,
  });

  String get displayName {
    if (isUnknown || speaker == null) {
      return 'Unknown';
    }
    return speaker!.name;
  }

  String get displayEmoji {
    if (isUnknown || speaker == null) {
      return '❓';
    }
    return speaker!.emoji;
  }
}