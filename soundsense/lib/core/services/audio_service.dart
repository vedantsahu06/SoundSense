import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';

class AudioService {
  bool _isListening = false;
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  
  // Callback for when noise level changes
  Function(double decibel)? onNoiseLevel;
  
  bool get isListening => _isListening;

  AudioService() {
    _noiseMeter = NoiseMeter();
  }

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Check if permission granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  // Start listening
  Future<void> startListening() async {
    bool hasAccess = await requestPermission();
    if (!hasAccess) {
      throw Exception('Microphone permission denied');
    }

    _noiseSubscription = _noiseMeter?.noise.listen(
      (NoiseReading reading) {
        // Send decibel level to callback
        if (onNoiseLevel != null) {
          onNoiseLevel!(reading.meanDecibel);
        }
      },
      onError: (error) {
        print('Noise meter error: $error');
      },
    );

    _isListening = true;
  }

  // Stop listening
  void stopListening() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _isListening = false;
  }

  // Dispose
  void dispose() {
    stopListening();
  }
}