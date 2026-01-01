import 'dart:typed_data';
import '../models/voice_profile_model.dart';
import 'embedding_service.dart';
import 'training_database.dart';

/// Service for training and identifying speakers
class SpeakerIdentificationService {
  final VoiceEmbeddingService _voiceEmbeddingService = VoiceEmbeddingService();
  final EmbeddingService _embeddingService = EmbeddingService.instance;
  final TrainingDatabase _database = TrainingDatabase.instance;
  
  List<VoiceProfile> _voiceProfiles = [];
  bool _isInitialized = false;

  // Singleton
  static SpeakerIdentificationService? _instance;
  static SpeakerIdentificationService get instance {
    _instance ??= SpeakerIdentificationService._();
    return _instance!;
  }
  SpeakerIdentificationService._();

  /// Initialize service and load saved profiles
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _embeddingService.initialize();
    await _database.initialize();
    _voiceProfiles = await _database.getAllVoiceProfiles();
    _isInitialized = true;
    
    print('✅ Speaker ID service initialized with ${_voiceProfiles.length} profiles');
  }

  /// Get all voice profiles
  List<VoiceProfile> get voiceProfiles => List.unmodifiable(_voiceProfiles);

  /// Start training a new voice profile
  VoiceTrainingSession startTraining({
    required String name,
    required String relationship,
    String? emoji,
    int requiredSamples = 5,
  }) {
    return VoiceTrainingSession(
      name: name,
      relationship: relationship,
      emoji: emoji ?? Relationship.getEmoji(relationship),
      requiredSamples: requiredSamples,
      voiceEmbeddingService: _voiceEmbeddingService,
      onComplete: _saveVoiceProfile,
    );
  }

  /// Save a trained voice profile
  Future<void> _saveVoiceProfile(VoiceProfile profile) async {
    await _database.saveVoiceProfile(profile);
    _voiceProfiles.add(profile);
    print('✅ Saved voice profile: ${profile.name}');
  }

  /// Delete a voice profile
  Future<void> deleteVoiceProfile(String id) async {
    await _database.deleteVoiceProfile(id);
    _voiceProfiles.removeWhere((p) => p.id == id);
  }

  /// Identify speaker from audio
  /// Returns the best matching profile if confidence is above threshold
  Future<SpeakerIdentificationResult> identifySpeaker(
    Uint8List audioData, {
    double threshold = 0.70,
  }) async {
    if (_voiceProfiles.isEmpty) {
      return SpeakerIdentificationResult(
        speaker: null,
        confidence: 0.0,
        isUnknown: true,
      );
    }

    // Generate voice embedding for query audio
    final queryEmbedding = await _voiceEmbeddingService.generateVoiceEmbedding(audioData);
    
    VoiceProfile? bestMatch;
    double bestScore = 0.0;

    for (final profile in _voiceProfiles) {
      if (!profile.isActive) continue;
      
      // Compare with all stored embeddings
      for (final storedEmbedding in profile.voiceEmbeddings) {
        final similarity = _cosineSimilarity(queryEmbedding, storedEmbedding);
        
        if (similarity > bestScore) {
          bestScore = similarity;
          bestMatch = profile;
        }
      }
    }

    if (bestMatch != null && bestScore >= threshold) {
      return SpeakerIdentificationResult(
        speaker: bestMatch,
        confidence: bestScore,
        isUnknown: false,
      );
    }

    return SpeakerIdentificationResult(
      speaker: null,
      confidence: bestScore,
      isUnknown: true,
    );
  }

  /// Identify speaker with multiple audio chunks for better accuracy
  Future<SpeakerIdentificationResult> identifySpeakerFromChunks(
    List<Uint8List> audioChunks, {
    double threshold = 0.70,
  }) async {
    if (audioChunks.isEmpty) {
      return SpeakerIdentificationResult(
        speaker: null,
        confidence: 0.0,
        isUnknown: true,
      );
    }

    // Get identification result for each chunk
    final results = <SpeakerIdentificationResult>[];
    for (final chunk in audioChunks) {
      final result = await identifySpeaker(chunk, threshold: threshold);
      results.add(result);
    }

    // Vote for best speaker
    final votes = <String, int>{};
    final scores = <String, List<double>>{};
    
    for (final result in results) {
      if (!result.isUnknown && result.speaker != null) {
        final id = result.speaker!.id;
        votes[id] = (votes[id] ?? 0) + 1;
        scores[id] = [...(scores[id] ?? []), result.confidence];
      }
    }

    if (votes.isEmpty) {
      return SpeakerIdentificationResult(
        speaker: null,
        confidence: 0.0,
        isUnknown: true,
      );
    }

    // Find speaker with most votes
    String? winnerId;
    int maxVotes = 0;
    for (final entry in votes.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        winnerId = entry.key;
      }
    }

    if (winnerId != null) {
      final winner = _voiceProfiles.firstWhere((p) => p.id == winnerId);
      final avgConfidence = scores[winnerId]!.reduce((a, b) => a + b) / scores[winnerId]!.length;
      
      return SpeakerIdentificationResult(
        speaker: winner,
        confidence: avgConfidence,
        isUnknown: false,
      );
    }

    return SpeakerIdentificationResult(
      speaker: null,
      confidence: 0.0,
      isUnknown: true,
    );
  }

  /// Update a voice profile
  Future<void> updateVoiceProfile(VoiceProfile updated) async {
    await _database.saveVoiceProfile(updated);
    final index = _voiceProfiles.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _voiceProfiles[index] = updated;
    }
  }

  /// Add more training samples to existing profile
  Future<void> addTrainingSample(String profileId, Uint8List audioData) async {
    final index = _voiceProfiles.indexWhere((p) => p.id == profileId);
    if (index == -1) return;

    final embedding = await _voiceEmbeddingService.generateVoiceEmbedding(audioData);
    final profile = _voiceProfiles[index];
    
    final updatedProfile = profile.copyWith(
      voiceEmbeddings: [...profile.voiceEmbeddings, embedding],
      sampleCount: profile.sampleCount + 1,
    );
    
    await updateVoiceProfile(updatedProfile);
  }

  /// Cosine similarity calculation
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    
    return dot / (sqrt(normA) * sqrt(normB));
  }

  double sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}


/// Training session for voice profiles
class VoiceTrainingSession {
  final String name;
  final String relationship;
  final String emoji;
  final int requiredSamples;
  final VoiceEmbeddingService _voiceEmbeddingService;
  final Function(VoiceProfile) _onComplete;

  final List<List<double>> _collectedEmbeddings = [];
  final List<double> _pitchSamples = [];
  final List<double> _energySamples = [];
  bool _isComplete = false;

  VoiceTrainingSession({
    required this.name,
    required this.relationship,
    required this.emoji,
    required this.requiredSamples,
    required VoiceEmbeddingService voiceEmbeddingService,
    required Function(VoiceProfile) onComplete,
  })  : _voiceEmbeddingService = voiceEmbeddingService,
        _onComplete = onComplete;

  /// Number of samples collected
  int get samplesCollected => _collectedEmbeddings.length;

  /// Number of samples remaining
  int get samplesRemaining => requiredSamples - samplesCollected;

  /// Whether training is complete
  bool get isComplete => _isComplete;

  /// Progress percentage
  int get progressPercent => ((samplesCollected / requiredSamples) * 100).round();

  /// Phrases to read during training
  static List<String> get trainingPhrases => [
    "Hello, my name is ${DateTime.now().second}",
    "The quick brown fox jumps over the lazy dog",
    "I am recording my voice for Dhwani",
    "This app will help identify who is speaking",
    "Thank you for using this accessibility app",
    "Voice recognition makes communication easier",
    "I want to help people who cannot hear",
  ];

  /// Get current phrase to read
  String get currentPhrase {
    if (samplesCollected < trainingPhrases.length) {
      return trainingPhrases[samplesCollected];
    }
    return "Please continue speaking naturally";
  }

  /// Add a training sample
  Future<bool> addSample(Uint8List audioData) async {
    if (_isComplete) return false;

    // Check audio has sufficient energy (not silence)
    if (!_hasVoiceActivity(audioData)) {
      print('⚠️ Sample rejected: no voice detected');
      return false;
    }

    final embedding = await _voiceEmbeddingService.generateVoiceEmbedding(audioData);
    
    _collectedEmbeddings.add(embedding);
    
    // Extract voice characteristics
    final features = _extractFeatures(audioData);
    _pitchSamples.add(features['pitch'] ?? 0);
    _energySamples.add(features['energy'] ?? 0);
    
    print('✅ Voice sample ${samplesCollected}/$requiredSamples collected');

    if (samplesCollected >= requiredSamples) {
      await _finishTraining();
    }

    return true;
  }

  /// Check if audio contains voice activity
  bool _hasVoiceActivity(Uint8List audioData) {
    double energy = 0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = audioData[i] | (audioData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      energy += (sample / 32768.0) * (sample / 32768.0);
    }
    energy = energy / (audioData.length / 2);
    return energy > 0.001; // Threshold for voice activity
  }

  /// Extract voice features
  Map<String, double> _extractFeatures(Uint8List audioData) {
    final samples = <double>[];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = audioData[i] | (audioData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      samples.add(sample / 32768.0);
    }

    // Calculate energy
    double energy = 0;
    for (final s in samples) {
      energy += s * s;
    }
    energy = energy / samples.length;

    // Estimate pitch via zero crossings
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    double pitch = crossings / (2 * samples.length / 16000.0);

    return {
      'pitch': pitch,
      'energy': energy,
    };
  }

  /// Finish training and save profile
  Future<void> _finishTraining() async {
    if (_isComplete) return;
    _isComplete = true;

    // Calculate average pitch and energy
    double avgPitch = 0;
    double avgEnergy = 0;
    if (_pitchSamples.isNotEmpty) {
      avgPitch = _pitchSamples.reduce((a, b) => a + b) / _pitchSamples.length;
      avgEnergy = _energySamples.reduce((a, b) => a + b) / _energySamples.length;
    }

    final profile = VoiceProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      relationship: relationship,
      emoji: emoji,
      voiceEmbeddings: _collectedEmbeddings,
      createdAt: DateTime.now(),
      sampleCount: _collectedEmbeddings.length,
      averagePitch: avgPitch,
      averageEnergy: avgEnergy,
    );

    await _onComplete(profile);
    print('✅ Voice training complete for: $name');
  }

  /// Cancel training
  void cancel() {
    _collectedEmbeddings.clear();
    _pitchSamples.clear();
    _energySamples.clear();
    _isComplete = true;
  }
}