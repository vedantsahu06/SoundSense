import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SoundClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isReady = false;

  bool get isReady => _isReady;
  List<String> get labels => _labels;

  // Load model and labels
  Future<void> initialize() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('models/yamnet.tflite');
      
      // Load labels
      final labelsData = await rootBundle.loadString('assets/models/yamnet_labels.txt');
      _labels = _parseLabels(labelsData);
      
      _isReady = true;
      print('SoundClassifier initialized with ${_labels.length} labels');
    } catch (e) {
      print('Failed to initialize SoundClassifier: $e');
      _isReady = false;
    }
  }

  // Parse CSV labels file
  List<String> _parseLabels(String csvData) {
    final lines = csvData.split('\n');
    final labels = <String>[];
    
    for (int i = 1; i < lines.length; i++) { // Skip header
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final parts = line.split(',');
      if (parts.length >= 3) {
        labels.add(parts[2].replaceAll('"', '')); // Get display_name
      }
    }
    return labels;
  }

  // Classify audio data
  Future<List<SoundResult>> classify(List<double> audioData) async {
    if (!_isReady || _interpreter == null) {
      return [];
    }

    try {
      // Prepare input (YAMNet expects 15600 samples at 16kHz = ~1 second)
      final input = Float32List.fromList(audioData);
      
      // Prepare output
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.filled(outputShape[0] * outputShape[1], 0.0)
          .reshape([outputShape[0], outputShape[1]]);

      // Run inference
      _interpreter!.run(input, output);

      // Get top results
      final results = <SoundResult>[];
      final scores = output[0] as List<double>;
      
      // Find top 5 sounds
      final indexed = scores.asMap().entries.toList();
      indexed.sort((a, b) => b.value.compareTo(a.value));
      
      for (int i = 0; i < 5 && i < indexed.length; i++) {
        final idx = indexed[i].key;
        final score = indexed[i].value;
        if (score > 0.1 && idx < _labels.length) {
          results.add(SoundResult(
            label: _labels[idx],
            confidence: score,
          ));
        }
      }

      return results;
    } catch (e) {
      print('Classification error: $e');
      return [];
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}

class SoundResult {
  final String label;
  final double confidence;

  SoundResult({
    required this.label,
    required this.confidence,
  });
}