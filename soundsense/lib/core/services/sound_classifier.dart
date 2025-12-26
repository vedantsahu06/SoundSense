import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SoundClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isReady = false;

  bool get isReady => _isReady;
  List<String> get labels => _labels;

  Future<void> initialize() async {
    try {
      print('Loading AI model...');
      
      // Load labels first
      final labelsData = await rootBundle.loadString('assets/models/yamnet_labels.txt');
      _labels = _parseLabels(labelsData);
      print('Loaded ${_labels.length} labels');

      // Load TFLite model
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yamnet.tflite',
        options: options,
      );
      
      print('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      _isReady = true;
      print('AI Model loaded successfully!');
    } catch (e) {
      print('Failed to load AI model: $e');
      _isReady = false;
    }
  }

  List<String> _parseLabels(String csvData) {
    final lines = csvData.split('\n');
    final labels = <String>[];
    
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final parts = line.split(',');
      if (parts.length >= 3) {
        labels.add(parts[2].replaceAll('"', ''));
      }
    }
    return labels;
  }

  List<SoundResult> classify(List<double> audioData) {
    if (!_isReady || _interpreter == null) {
      print('Classifier not ready');
      return [];
    }

    try {
      // YAMNet expects 15600 samples
      if (audioData.length < 15600) {
        print('Audio data too short: ${audioData.length}');
        return [];
      }

      // Prepare input - normalize to [-1, 1]
      final input = Float32List(15600);
      for (int i = 0; i < 15600; i++) {
        input[i] = audioData[i].clamp(-1.0, 1.0);
      }
      final inputTensor = input.reshape([15600]);

      // Prepare output
      final outputTensor = List<double>.filled(521, 0).reshape([1, 521]);

      // Run model
      _interpreter!.run(inputTensor, outputTensor);

      // Get results
      final scores = outputTensor[0] as List<double>;
      final results = <SoundResult>[];

      // Find top 5 sounds with confidence > 0.1
      final indexed = <MapEntry<int, double>>[];
      for (int i = 0; i < scores.length; i++) {
        indexed.add(MapEntry(i, scores[i]));
      }
      indexed.sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < 5 && i < indexed.length; i++) {
        final idx = indexed[i].key;
        final score = indexed[i].value;
        if (score > 0.1 && idx < _labels.length) {
          results.add(SoundResult(
            label: _labels[idx],
            confidence: score,
          ));
          print('Detected: ${_labels[idx]} (${(score * 100).toInt()}%)');
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
