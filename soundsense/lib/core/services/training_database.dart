import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_sound_model.dart';
import '../models/voice_profile_model.dart';

/// Database for storing custom sounds and voice profiles
/// Uses SharedPreferences for simple local storage
/// For production, consider using Hive or SQLite
class TrainingDatabase {
  static TrainingDatabase? _instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Storage keys
  static const String _customSoundsKey = 'dhwani_custom_sounds';
  static const String _voiceProfilesKey = 'dhwani_voice_profiles';

  // Singleton
  static TrainingDatabase get instance {
    _instance ??= TrainingDatabase._();
    return _instance!;
  }
  TrainingDatabase._();

  /// Initialize database
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    print('✅ Training database initialized');
  }

  // ============================================================
  // Custom Sounds
  // ============================================================

  /// Get all custom sounds
  Future<List<CustomSound>> getAllCustomSounds() async {
    await _ensureInitialized();
    
    final jsonString = _prefs!.getString(_customSoundsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => CustomSound.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error loading custom sounds: $e');
      return [];
    }
  }

  /// Save a custom sound
  Future<void> saveCustomSound(CustomSound sound) async {
    await _ensureInitialized();
    
    final sounds = await getAllCustomSounds();
    
    // Update if exists, otherwise add
    final index = sounds.indexWhere((s) => s.id == sound.id);
    if (index != -1) {
      sounds[index] = sound;
    } else {
      sounds.add(sound);
    }

    await _saveCustomSounds(sounds);
  }

  /// Delete a custom sound
  Future<void> deleteCustomSound(String id) async {
    await _ensureInitialized();
    
    final sounds = await getAllCustomSounds();
    sounds.removeWhere((s) => s.id == id);
    await _saveCustomSounds(sounds);
  }

  /// Save all custom sounds
  Future<void> _saveCustomSounds(List<CustomSound> sounds) async {
    final jsonList = sounds.map((s) => s.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs!.setString(_customSoundsKey, jsonString);
  }

  // ============================================================
  // Voice Profiles
  // ============================================================

  /// Get all voice profiles
  Future<List<VoiceProfile>> getAllVoiceProfiles() async {
    await _ensureInitialized();
    
    final jsonString = _prefs!.getString(_voiceProfilesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => VoiceProfile.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error loading voice profiles: $e');
      return [];
    }
  }

  /// Save a voice profile
  Future<void> saveVoiceProfile(VoiceProfile profile) async {
    await _ensureInitialized();
    
    final profiles = await getAllVoiceProfiles();
    
    // Update if exists, otherwise add
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await _saveVoiceProfiles(profiles);
  }

  /// Delete a voice profile
  Future<void> deleteVoiceProfile(String id) async {
    await _ensureInitialized();
    
    final profiles = await getAllVoiceProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveVoiceProfiles(profiles);
  }

  /// Save all voice profiles
  Future<void> _saveVoiceProfiles(List<VoiceProfile> profiles) async {
    final jsonList = profiles.map((p) => p.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs!.setString(_voiceProfilesKey, jsonString);
  }

  // ============================================================
  // Utilities
  // ============================================================

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _ensureInitialized();
    await _prefs!.remove(_customSoundsKey);
    await _prefs!.remove(_voiceProfilesKey);
    print('🗑️ All training data cleared');
  }

  /// Get storage statistics
  Future<Map<String, int>> getStatistics() async {
    final sounds = await getAllCustomSounds();
    final profiles = await getAllVoiceProfiles();
    
    return {
      'customSounds': sounds.length,
      'voiceProfiles': profiles.length,
      'totalSoundSamples': sounds.fold(0, (sum, s) => sum + s.sampleCount),
      'totalVoiceSamples': profiles.fold(0, (sum, p) => sum + p.sampleCount),
    };
  }

  /// Export all data as JSON
  Future<String> exportData() async {
    final sounds = await getAllCustomSounds();
    final profiles = await getAllVoiceProfiles();
    
    return jsonEncode({
      'customSounds': sounds.map((s) => s.toJson()).toList(),
      'voiceProfiles': profiles.map((p) => p.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Import data from JSON
  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      
      if (data['customSounds'] != null) {
        final sounds = (data['customSounds'] as List)
            .map((json) => CustomSound.fromJson(json))
            .toList();
        await _saveCustomSounds(sounds);
      }
      
      if (data['voiceProfiles'] != null) {
        final profiles = (data['voiceProfiles'] as List)
            .map((json) => VoiceProfile.fromJson(json))
            .toList();
        await _saveVoiceProfiles(profiles);
      }
      
      print('✅ Data imported successfully');
    } catch (e) {
      print('❌ Error importing data: $e');
      throw Exception('Failed to import data: $e');
    }
  }
}