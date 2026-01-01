import 'dart:typed_data';
import '../models/custom_sound_model.dart';
import 'embedding_service.dart';
import 'training_database.dart';

/// Service for training and detecting custom sounds
class CustomSoundService {
  final EmbeddingService _embeddingService = EmbeddingService.instance;
  final TrainingDatabase _database = TrainingDatabase.instance;
  
  List<CustomSound> _customSounds = [];
  bool _isInitialized = false;

  // Singleton
  static CustomSoundService? _instance;
  static CustomSoundService get instance {
    _instance ??= CustomSoundService._();
    return _instance!;
  }
  CustomSoundService._();

  /// Initialize service and load saved sounds
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _embeddingService.initialize();
    await _database.initialize();
    _customSounds = await _database.getAllCustomSounds();
    _isInitialized = true;
    
    print('✅ Custom sound service initialized with ${_customSounds.length} sounds');
  }

  /// Get all custom sounds
  List<CustomSound> get customSounds => List.unmodifiable(_customSounds);

  /// Start training a new custom sound
  /// Returns a TrainingSession to collect samples
  TrainingSession startTraining({
    required String name,
    required String category,
    String? icon,
    int requiredSamples = 5,
  }) {
    return TrainingSession(
      name: name,
      category: category,
      icon: icon ?? SoundCategory.getIcon(category),
      requiredSamples: requiredSamples,
      embeddingService: _embeddingService,
      onComplete: _saveCustomSound,
    );
  }

  /// Save a trained custom sound
  Future<void> _saveCustomSound(CustomSound sound) async {
    await _database.saveCustomSound(sound);
    _customSounds.add(sound);
    print('✅ Saved custom sound: ${sound.name}');
  }

  /// Delete a custom sound
  Future<void> deleteCustomSound(String id) async {
    await _database.deleteCustomSound(id);
    _customSounds.removeWhere((s) => s.id == id);
  }

  /// Detect if audio matches any custom sound
  /// Returns the best match if confidence is above threshold
 Future<CustomSoundMatch?> detectCustomSound(
  Uint8List audioData, {
  double threshold = 0.5,
}) async {
  if (_customSounds.isEmpty) {
    print('🔊 No custom sounds to detect');
    return null;
  }

  print('🔊 Checking against ${_customSounds.length} custom sounds...');

  final queryEmbedding = await _embeddingService.generateEmbedding(audioData);
  
  CustomSound? bestMatch;
  double bestScore = 0.0;

  for (final sound in _customSounds) {
    if (!sound.isActive) continue;
    
    for (final storedEmbedding in sound.embeddings) {
      final similarity = _embeddingService.cosineSimilarity(
        queryEmbedding,
        storedEmbedding,
      );
      
      print('  - ${sound.name}: similarity = ${(similarity * 100).toStringAsFixed(1)}%');
      
      if (similarity > bestScore) {
        bestScore = similarity;
        bestMatch = sound;
      }
    }
  }

  print('🔊 Best match: ${bestMatch?.name ?? 'none'} (${(bestScore * 100).toStringAsFixed(1)}%)');

  if (bestMatch != null && bestScore >= threshold) {
    return CustomSoundMatch(
      sound: bestMatch,
      confidence: bestScore,
    );
  }

  return null;
}

  /// Update a custom sound's settings
  Future<void> updateCustomSound(CustomSound updated) async {
    await _database.saveCustomSound(updated);
    final index = _customSounds.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _customSounds[index] = updated;
    }
  }

  /// Add more training samples to existing sound
  Future<void> addTrainingSample(String soundId, Uint8List audioData) async {
    final index = _customSounds.indexWhere((s) => s.id == soundId);
    if (index == -1) return;

    final embedding = await _embeddingService.generateEmbedding(audioData);
    final sound = _customSounds[index];
    
    final updatedSound = sound.copyWith(
      embeddings: [...sound.embeddings, embedding],
      sampleCount: sound.sampleCount + 1,
    );
    
    await updateCustomSound(updatedSound);
  }
}


/// Result of custom sound detection
class CustomSoundMatch {
  final CustomSound sound;
  final double confidence;

  CustomSoundMatch({
    required this.sound,
    required this.confidence,
  });

  String get displayName => sound.name;
  String get displayIcon => sound.icon;
  int get confidencePercent => (confidence * 100).round();
}


/// Training session for collecting sound samples
class TrainingSession {
  final String name;
  final String category;
  final String icon;
  final int requiredSamples;
  final EmbeddingService _embeddingService;
  final Function(CustomSound) _onComplete;

  final List<List<double>> _collectedEmbeddings = [];
  bool _isComplete = false;

  TrainingSession({
    required this.name,
    required this.category,
    required this.icon,
    required this.requiredSamples,
    required EmbeddingService embeddingService,
    required Function(CustomSound) onComplete,
  })  : _embeddingService = embeddingService,
        _onComplete = onComplete;

  /// Number of samples collected
  int get samplesCollected => _collectedEmbeddings.length;

  /// Number of samples remaining
  int get samplesRemaining => requiredSamples - samplesCollected;

  /// Whether training is complete
  bool get isComplete => _isComplete;

  /// Progress percentage (0-100)
  int get progressPercent => ((samplesCollected / requiredSamples) * 100).round();

  /// Add a training sample
 /// Add a training sample
Future<bool> addSample(Uint8List audioData) async {
  if (_isComplete) return false;

  final embedding = await _embeddingService.generateEmbedding(audioData);
  
  // Skip energy check - accept all samples
  print('✅ Sample accepted (energy check bypassed)');

  _collectedEmbeddings.add(embedding);
  print('✅ Sample ${samplesCollected}/$requiredSamples collected');

  // Check if training is complete
  if (samplesCollected >= requiredSamples) {
    await _finishTraining();
  }

  return true;
}

  /// Finish training and save the sound
  Future<void> _finishTraining() async {
    if (_isComplete) return;
    _isComplete = true;

    final sound = CustomSound(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      category: category,
      icon: icon,
      embeddings: _collectedEmbeddings,
      createdAt: DateTime.now(),
      sampleCount: _collectedEmbeddings.length,
    );

    await _onComplete(sound);
    print('✅ Training complete for: $name');
  }

  /// Cancel training
  void cancel() {
    _collectedEmbeddings.clear();
    _isComplete = true;
  }

  double _calculateEnergy(List<double> embedding) {
    double sum = 0;
    for (final value in embedding) {
      sum += value * value;
    }
    return sum / embedding.length;
  }
}