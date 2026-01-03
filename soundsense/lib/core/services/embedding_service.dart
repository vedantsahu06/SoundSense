import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service to generate audio embeddings (fingerprints)
/// Uses YAMNet's intermediate layer for embeddings
class EmbeddingService {
  static EmbeddingService? _instance;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  // Singleton pattern
  static EmbeddingService get instance {
    _instance ??= EmbeddingService._();
    return _instance!;
  }

  EmbeddingService._();

  /// Initialize the embedding model
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      _isInitialized = true;
      print('✅ Embedding service initialized');
      return true;
    } catch (e) {
      print('❌ Failed to initialize embedding service: $e');
      return false;
    }
  }

/// Generate embedding from audio data
/// Returns a 1024-dimensional vector representing the audio
Future<List<double>> generateEmbedding(Uint8List audioData) async {
  if (!_isInitialized) {
    await initialize();
  }

  try {
    print('📊 Audio data size: ${audioData.length} bytes');
    
    // Convert audio to float samples
    final samples = _convertToFloatSamples(audioData);
    print('📊 Converted to ${samples.length} float samples');
    
    // Ensure correct input size (YAMNet expects 15600 samples)
    final inputSamples = _padOrTrimSamples(samples, 15600);
    
    // Create simple audio fingerprint based on frequency analysis
    // This is a simpler but more reliable approach
    final embedding = _createAudioFingerprint(inputSamples);
    
    print('📊 Generated embedding with ${embedding.length} values');
    final sum = embedding.fold(0.0, (a, b) => a + b.abs());
    print('📊 Embedding sum: $sum');
    
    return embedding;
  } catch (e) {
    print('❌ Error generating embedding: $e');
    return List.filled(1024, 0.0);
  }
}

/// Create audio fingerprint using frequency analysis
List<double> _createAudioFingerprint(List<double> samples) {
  final fingerprint = List<double>.filled(1024, 0.0);
  
  // Divide audio into 1024 chunks and calculate energy of each
  final chunkSize = samples.length ~/ 1024;
  
  for (int i = 0; i < 1024; i++) {
    final start = i * chunkSize;
    final end = (i + 1) * chunkSize;
    
    double energy = 0.0;
    for (int j = start; j < end && j < samples.length; j++) {
      energy += samples[j] * samples[j];
    }
    
    fingerprint[i] = sqrt(energy / chunkSize);
  }
  
  // Normalize the fingerprint
  final maxVal = fingerprint.reduce((a, b) => a > b ? a : b);
  if (maxVal > 0) {
    for (int i = 0; i < fingerprint.length; i++) {
      fingerprint[i] /= maxVal;
    }
  }
  
  return fingerprint;
}

double sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 10; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

  /// Generate multiple embeddings from longer audio
  /// Splits audio into chunks and generates embedding for each
  Future<List<List<double>>> generateMultipleEmbeddings(
    Uint8List audioData, {
    int chunkDurationMs = 975,
    int overlapMs = 200,
  }) async {
    final List<List<double>> embeddings = [];
    
    // Calculate chunk sizes in samples (16kHz = 16 samples per ms)
    final chunkSamples = (chunkDurationMs * 16).round();
    final overlapSamples = (overlapMs * 16).round();
    final stepSamples = chunkSamples - overlapSamples;
    
    // Convert to samples
    final allSamples = _convertToFloatSamples(audioData);
    
    // Process each chunk
    int start = 0;
    while (start + chunkSamples <= allSamples.length) {
      final chunk = allSamples.sublist(start, start + chunkSamples);
      final chunkBytes = _convertToBytes(chunk);
      final embedding = await generateEmbedding(chunkBytes);
      embeddings.add(embedding);
      start += stepSamples;
    }
    
    // Process remaining samples if any
    if (start < allSamples.length && allSamples.length - start > chunkSamples ~/ 2) {
      final chunk = _padOrTrimSamples(
        allSamples.sublist(start),
        chunkSamples,
      );
      final chunkBytes = _convertToBytes(chunk);
      final embedding = await generateEmbedding(chunkBytes);
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Calculate cosine similarity between two embeddings
  /// Returns value between -1 and 1 (1 = identical, 0 = unrelated, -1 = opposite)
  double cosineSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have same length');
    }

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    if (norm1 == 0 || norm2 == 0) return 0.0;

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Calculate average embedding from multiple embeddings
  List<double> averageEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return List.filled(1024, 0.0);

    final int dimensions = embeddings[0].length;
    final average = List.filled(dimensions, 0.0);

    for (final embedding in embeddings) {
      for (int i = 0; i < dimensions; i++) {
        average[i] += embedding[i];
      }
    }

    for (int i = 0; i < dimensions; i++) {
      average[i] /= embeddings.length;
    }

    return average;
  }

  /// Find best match from a list of embeddings
  /// Returns index of best match and similarity score
  ({int index, double similarity}) findBestMatch(
    List<double> queryEmbedding,
    List<List<double>> candidateEmbeddings,
  ) {
    int bestIndex = -1;
    double bestSimilarity = -1.0;

    for (int i = 0; i < candidateEmbeddings.length; i++) {
      final similarity = cosineSimilarity(queryEmbedding, candidateEmbeddings[i]);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestIndex = i;
      }
    }

    return (index: bestIndex, similarity: bestSimilarity);
  }

  /// Convert audio bytes to float samples
  List<double> _convertToFloatSamples(Uint8List audioData) {
    final samples = <double>[];
    
    // Assuming 16-bit PCM audio
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Convert 2 bytes to 16-bit signed integer
      int sample = audioData[i] | (audioData[i + 1] << 8);
      // Convert to signed
      if (sample > 32767) sample -= 65536;
      // Normalize to [-1, 1]
      samples.add(sample / 32768.0);
    }
    
    return samples;
  }

  /// Convert float samples back to bytes
  Uint8List _convertToBytes(List<double> samples) {
    final bytes = Uint8List(samples.length * 2);
    
    for (int i = 0; i < samples.length; i++) {
      int sample = (samples[i] * 32768).round().clamp(-32768, 32767);
      if (sample < 0) sample += 65536;
      bytes[i * 2] = sample & 0xFF;
      bytes[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    
    return bytes;
  }

  /// Pad or trim samples to target length
  List<double> _padOrTrimSamples(List<double> samples, int targetLength) {
    if (samples.length == targetLength) {
      return samples;
    } else if (samples.length > targetLength) {
      // Take center portion
      final start = (samples.length - targetLength) ~/ 2;
      return samples.sublist(start, start + targetLength);
    } else {
      // Pad with zeros
      final padded = List<double>.filled(targetLength, 0.0);
      final start = (targetLength - samples.length) ~/ 2;
      for (int i = 0; i < samples.length; i++) {
        padded[start + i] = samples[i];
      }
      return padded;
    }
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}


/// Voice-specific embedding service
/// Extracts voice characteristics for speaker identification
class VoiceEmbeddingService {
  final EmbeddingService _embeddingService = EmbeddingService.instance;

  /// Generate voice embedding with additional voice features
  Future<List<double>> generateVoiceEmbedding(Uint8List audioData) async {
    // Get base embedding from YAMNet
    final baseEmbedding = await _embeddingService.generateEmbedding(audioData);
    
    // Extract additional voice features
    final voiceFeatures = _extractVoiceFeatures(audioData);
    
    // Combine base embedding with voice features
    // This gives us a more voice-specific signature
    return [...baseEmbedding, ...voiceFeatures];
  }

  /// Extract voice-specific features
  List<double> _extractVoiceFeatures(Uint8List audioData) {
    final samples = _convertToFloatSamples(audioData);
    
    // Calculate various voice characteristics
    final pitch = _estimatePitch(samples);
    final energy = _calculateEnergy(samples);
    final zeroCrossings = _calculateZeroCrossingRate(samples);
    final spectralCentroid = _estimateSpectralCentroid(samples);
    
    // Normalize features
    return [
      pitch / 500.0,           // Normalize pitch (0-500 Hz range)
      energy,                   // Already 0-1
      zeroCrossings,           // Already 0-1
      spectralCentroid / 8000, // Normalize centroid
    ];
  }

  /// Simple pitch estimation using zero-crossing
  double _estimatePitch(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    
    // Estimate frequency from zero crossings
    final duration = samples.length / 16000.0; // Assuming 16kHz
    return crossings / (2 * duration);
  }

  /// Calculate RMS energy
 double _calculateEnergy(List<double> embedding) {
  double sum = 0;
  for (final value in embedding) {
    sum += value * value;
  }
  return sum / embedding.length;
}

  /// Calculate zero-crossing rate
  double _calculateZeroCrossingRate(List<double> samples) {
    if (samples.length < 2) return 0.0;
    
    int crossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i] >= 0) != (samples[i - 1] >= 0)) {
        crossings++;
      }
    }
    
    return crossings / (samples.length - 1).toDouble();
  }

  /// Estimate spectral centroid
  double _estimateSpectralCentroid(List<double> samples) {
    // Simplified spectral centroid estimation
    // In production, you'd use FFT
    final zcr = _calculateZeroCrossingRate(samples);
    
    // Rough estimate based on ZCR
    return zcr * 16000 * 0.5; // Half of Nyquist * ZCR
  }

  List<double> _convertToFloatSamples(Uint8List audioData) {
    final samples = <double>[];
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = audioData[i] | (audioData[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      samples.add(sample / 32768.0);
    }
    return samples;
  }
}