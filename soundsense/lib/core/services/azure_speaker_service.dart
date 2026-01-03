import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Azure Speaker Recognition Service
/// Uses Microsoft's real AI for speaker identification
class AzureSpeakerService {
  final String _apiKey;
  final String _region;
  final String _baseUrl;

  // Stored voice profiles (Azure profile IDs)
  final Map<String, AzureVoiceProfile> _profiles = {};

  // Singleton
  static AzureSpeakerService? _instance;
  static AzureSpeakerService get instance {
    _instance ??= AzureSpeakerService._();
    return _instance!;
  }

  AzureSpeakerService._()
      : _apiKey = EnvConfig.azureSpeechApiKey,
        _region = EnvConfig.azureSpeechRegion,
        _baseUrl = 'https://${EnvConfig.azureSpeechRegion}.api.cognitive.microsoft.com';

  /// Get the configured Azure region
  String get region => _region;

  // ============================================================
  // SPEAKER IDENTIFICATION (Who is speaking?)
  // ============================================================

  /// Create a new voice profile for identification
  /// Returns the Azure profile ID
  Future<String?> createVoiceProfile(String personName) async {
    final url = '$_baseUrl/speaker-recognition/identification/text-independent/profiles?api-version=2021-09-05';
  print('🔍 Creating profile for: $personName');
  print('🔍 URL: $url');
  print('🔍 API Key: ${_apiKey.substring(0, 5)}...');
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'locale': 'en-us',
        }),
      );
print('🔍 Response Status: ${response.statusCode}');
    print('🔍 Response Body: ${response.body}');
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final profileId = data['profileId'];
        
        // Store locally
        _profiles[profileId] = AzureVoiceProfile(
          profileId: profileId,
          personName: personName,
          isEnrolled: false,
        );
        
        print('✅ Created voice profile: $profileId for $personName');
        return profileId;
      } else {
        print('❌ Failed to create profile: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error creating profile: $e');
      return null;
    }
  }

  /// Enroll audio for a voice profile (train the voice)
  /// Needs 20+ seconds of audio for best results
  Future<EnrollmentResult> enrollVoiceProfile(String profileId, Uint8List audioData) async {
    final url = '$_baseUrl/speaker-recognition/identification/text-independent/profiles/$profileId/enrollments?api-version=2021-09-05';

    try {
      // Convert to WAV format
      final wavData = _createWavFile(audioData);

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'audio/wav',
        },
        body: wavData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final remainingSeconds = data['remainingEnrollmentsSpeechLength'] ?? 0;
        final enrollmentStatus = data['enrollmentStatus'] ?? 'unknown';
        
        // Update local profile
        if (_profiles.containsKey(profileId)) {
          _profiles[profileId] = _profiles[profileId]!.copyWith(
            isEnrolled: enrollmentStatus == 'Enrolled',
          );
        }

        print('✅ Enrollment status: $enrollmentStatus, Remaining: ${remainingSeconds}s');
        
        return EnrollmentResult(
          success: true,
          isEnrolled: enrollmentStatus == 'Enrolled',
          remainingSeconds: (remainingSeconds as num).toDouble(),
          message: enrollmentStatus,
        );
      } else {
        print('❌ Enrollment failed: ${response.statusCode} - ${response.body}');
        return EnrollmentResult(
          success: false,
          isEnrolled: false,
          remainingSeconds: 0,
          message: 'Failed: ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error enrolling: $e');
      return EnrollmentResult(
        success: false,
        isEnrolled: false,
        remainingSeconds: 0,
        message: 'Error: $e',
      );
    }
  }

  /// Identify who is speaking from enrolled profiles
  Future<IdentificationResult> identifySpeaker(Uint8List audioData) async {
    // Get all enrolled profile IDs
    final enrolledProfiles = _profiles.values
        .where((p) => p.isEnrolled)
        .map((p) => p.profileId)
        .toList();

    if (enrolledProfiles.isEmpty) {
      return IdentificationResult(
        identified: false,
        profileId: null,
        personName: 'Unknown',
        confidence: 0,
        message: 'No enrolled profiles',
      );
    }

    final profileIds = enrolledProfiles.join(',');
    final url = '$_baseUrl/speaker-recognition/identification/text-independent/profiles:identifySingleSpeaker?api-version=2021-09-05&profileIds=$profileIds';

    try {
      final wavData = _createWavFile(audioData);

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'audio/wav',
        },
        body: wavData,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final identifiedProfile = data['identifiedProfile'];
        final profileId = identifiedProfile?['profileId'];
        final score = identifiedProfile?['score'] ?? 0.0;

        if (profileId != null && profileId != '00000000-0000-0000-0000-000000000000') {
          final profile = _profiles[profileId];
          
          print('✅ Identified: ${profile?.personName} (${(score * 100).round()}%)');
          
          return IdentificationResult(
            identified: true,
            profileId: profileId,
            personName: profile?.personName ?? 'Unknown',
            confidence: (score as num).toDouble(),
            message: 'Success',
          );
        } else {
          return IdentificationResult(
            identified: false,
            profileId: null,
            personName: 'Unknown',
            confidence: 0,
            message: 'No match found',
          );
        }
      } else {
        print('❌ Identification failed: ${response.statusCode} - ${response.body}');
        return IdentificationResult(
          identified: false,
          profileId: null,
          personName: 'Unknown',
          confidence: 0,
          message: 'Failed: ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error identifying: $e');
      return IdentificationResult(
        identified: false,
        profileId: null,
        personName: 'Unknown',
        confidence: 0,
        message: 'Error: $e',
      );
    }
  }

  /// Delete a voice profile
  Future<bool> deleteVoiceProfile(String profileId) async {
    final url = '$_baseUrl/speaker-recognition/identification/text-independent/profiles/$profileId?api-version=2021-09-05';

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _profiles.remove(profileId);
        print('✅ Deleted profile: $profileId');
        return true;
      } else {
        print('❌ Failed to delete: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting: $e');
      return false;
    }
  }

  /// Get all profiles
  List<AzureVoiceProfile> get profiles => _profiles.values.toList();

  /// Get profile by name
  AzureVoiceProfile? getProfileByName(String name) {
    try {
      return _profiles.values.firstWhere((p) => p.personName == name);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Create WAV file from raw PCM data
  Uint8List _createWavFile(Uint8List pcmData) {
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;

    final header = ByteData(44);

    // "RIFF" chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // "fmt " chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // "data" chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and data
    final wavFile = Uint8List(44 + pcmData.length);
    wavFile.setAll(0, header.buffer.asUint8List());
    wavFile.setAll(44, pcmData);

    return wavFile;
  }

  /// Save profiles to local storage
  Future<void> saveProfilesToStorage() async {
    // TODO: Implement with SharedPreferences
  }

  /// Load profiles from local storage
  Future<void> loadProfilesFromStorage() async {
    // TODO: Implement with SharedPreferences
  }
}


// ============================================================
// DATA MODELS
// ============================================================

/// Azure Voice Profile
class AzureVoiceProfile {
  final String profileId;
  final String personName;
  final bool isEnrolled;
  final String? relationship;
  final String? emoji;

  AzureVoiceProfile({
    required this.profileId,
    required this.personName,
    this.isEnrolled = false,
    this.relationship,
    this.emoji,
  });

  AzureVoiceProfile copyWith({
    String? personName,
    bool? isEnrolled,
    String? relationship,
    String? emoji,
  }) {
    return AzureVoiceProfile(
      profileId: profileId,
      personName: personName ?? this.personName,
      isEnrolled: isEnrolled ?? this.isEnrolled,
      relationship: relationship ?? this.relationship,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'personName': personName,
    'isEnrolled': isEnrolled,
    'relationship': relationship,
    'emoji': emoji,
  };

  factory AzureVoiceProfile.fromJson(Map<String, dynamic> json) {
    return AzureVoiceProfile(
      profileId: json['profileId'],
      personName: json['personName'],
      isEnrolled: json['isEnrolled'] ?? false,
      relationship: json['relationship'],
      emoji: json['emoji'],
    );
  }
}

/// Enrollment Result
class EnrollmentResult {
  final bool success;
  final bool isEnrolled;
  final double remainingSeconds;
  final String message;

  EnrollmentResult({
    required this.success,
    required this.isEnrolled,
    required this.remainingSeconds,
    required this.message,
  });
}

/// Identification Result
class IdentificationResult {
  final bool identified;
  final String? profileId;
  final String personName;
  final double confidence;
  final String message;

  IdentificationResult({
    required this.identified,
    this.profileId,
    required this.personName,
    required this.confidence,
    required this.message,
  });

  int get confidencePercent => (confidence * 100).round();
}