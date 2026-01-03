import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Emergency SOS Service
/// Handles emergency contacts, location, and automated alerts
class SOSService {
  // Singleton pattern
  static SOSService? _instance;
  static SOSService get instance {
    _instance ??= SOSService._();
    return _instance!;
  }
  SOSService._();

  // Emergency contacts storage
  List<EmergencyContact> _emergencyContacts = [];
  String _userName = 'User';
  bool _sosEnabled = true;
  int _countdownSeconds = 10;

  // Getters
  List<EmergencyContact> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  String get userName => _userName;
  bool get sosEnabled => _sosEnabled;
  int get countdownSeconds => _countdownSeconds;

  // Critical sound combinations that trigger SOS
  static const List<List<String>> criticalSoundCombinations = [
    ['Fire alarm', 'Scream'],
    ['Smoke detector', 'Scream'],
    ['Gunshot', 'Scream'],
    ['Explosion', 'Scream'],
    ['Car crash', 'Scream'],
    ['Glass breaking', 'Scream'],
  ];

  // Individual critical sounds that can trigger SOS
  static const List<String> criticalSounds = [
    'Fire alarm',
    'Smoke detector',
    'Gunshot',
    'Explosion',
    'Siren',
    'Scream',
    'Emergency vehicle',
    'Car alarm',
    'Glass breaking',
    'Car crash',
  ];

  /// Initialize the service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load user name
    _userName = prefs.getString('sos_user_name') ?? 'User';
    
    // Load SOS enabled state
    _sosEnabled = prefs.getBool('sos_enabled') ?? true;
    
    // Load countdown seconds
    _countdownSeconds = prefs.getInt('sos_countdown_seconds') ?? 10;
    
    // Load emergency contacts
    final contactsJson = prefs.getString('emergency_contacts');
    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      _emergencyContacts = decoded.map((e) => EmergencyContact.fromJson(e)).toList();
    }
    
    print('✅ SOS Service initialized with ${_emergencyContacts.length} contacts');
  }

  /// Save settings
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sos_user_name', _userName);
    await prefs.setBool('sos_enabled', _sosEnabled);
    await prefs.setInt('sos_countdown_seconds', _countdownSeconds);
    await prefs.setString('emergency_contacts', jsonEncode(_emergencyContacts.map((e) => e.toJson()).toList()));
  }

  /// Update user name
  Future<void> setUserName(String name) async {
    _userName = name;
    await _saveSettings();
  }

  /// Enable/disable SOS
  Future<void> setSosEnabled(bool enabled) async {
    _sosEnabled = enabled;
    await _saveSettings();
  }

  /// Set countdown duration
  Future<void> setCountdownSeconds(int seconds) async {
    _countdownSeconds = seconds.clamp(5, 30);
    await _saveSettings();
  }

  /// Add emergency contact
  Future<void> addContact(EmergencyContact contact) async {
    _emergencyContacts.add(contact);
    await _saveSettings();
  }

  /// Remove emergency contact
  Future<void> removeContact(String id) async {
    _emergencyContacts.removeWhere((c) => c.id == id);
    await _saveSettings();
  }

  /// Update emergency contact
  Future<void> updateContact(EmergencyContact contact) async {
    final index = _emergencyContacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _emergencyContacts[index] = contact;
      await _saveSettings();
    }
  }

  /// Check if detected sounds should trigger SOS
  bool shouldTriggerSOS(List<String> detectedSounds) {
    if (!_sosEnabled || _emergencyContacts.isEmpty) return false;
    
    final soundsLower = detectedSounds.map((s) => s.toLowerCase()).toList();
    
    // Check for critical sound combinations
    for (final combination in criticalSoundCombinations) {
      bool allFound = combination.every((sound) => 
        soundsLower.any((detected) => detected.contains(sound.toLowerCase()))
      );
      if (allFound) {
        print('🚨 SOS Triggered by combination: $combination');
        return true;
      }
    }
    
    // Check for single critical sounds with high priority
    int criticalCount = 0;
    for (final sound in criticalSounds) {
      if (soundsLower.any((detected) => detected.contains(sound.toLowerCase()))) {
        criticalCount++;
      }
    }
    
    // Trigger if 2+ critical sounds detected
    if (criticalCount >= 2) {
      print('🚨 SOS Triggered by multiple critical sounds: $criticalCount');
      return true;
    }
    
    return false;
  }

  /// Generate emergency message
  String generateEmergencyMessage(List<String> detectedSounds, String location) {
    final soundsList = detectedSounds.take(3).join(' and ');
    return 'SOUNDSENSE EMERGENCY ALERT: $_userName\'s phone detected [$soundsList] at $location. '
           'They may need immediate help. This is an automated alert.';
  }

  /// Check if a single sound is critical (for UI highlighting)
  static bool isCriticalSound(String soundName) {
    final lower = soundName.toLowerCase();
    return criticalSounds.any((s) => lower.contains(s.toLowerCase()));
  }
}


/// Emergency contact model
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String relationship;
  final bool isPrimary;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.relationship,
    this.isPrimary = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'relationship': relationship,
    'isPrimary': isPrimary,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'],
    name: json['name'],
    phoneNumber: json['phoneNumber'],
    relationship: json['relationship'],
    isPrimary: json['isPrimary'] ?? false,
  );

  EmergencyContact copyWith({
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
  }) => EmergencyContact(
    id: id,
    name: name ?? this.name,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    relationship: relationship ?? this.relationship,
    isPrimary: isPrimary ?? this.isPrimary,
  );
}
