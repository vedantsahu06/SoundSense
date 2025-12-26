import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:audio_streamer/audio_streamer.dart';

class AudioService {
  bool _isListening = false;
  NoiseMeter? _noiseMeter;
  AudioStreamer? _audioStreamer;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  StreamSubscription<List<double>>? _audioSubscription;
  
  // Callbacks
  Function(double decibel)? onNoiseLevel;
  Function(List<double> audioData)? onAudioData;
  
  bool get isListening => _isListening;

  AudioService() {
    _noiseMeter = NoiseMeter();
    _audioStreamer = AudioStreamer();
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

    // Start noise meter (for decibel display)
    _noiseSubscription = _noiseMeter?.noise.listen(
      (NoiseReading reading) {
        if (onNoiseLevel != null) {
          onNoiseLevel!(reading.meanDecibel);
        }
      },
      onError: (error) {
        print('Noise meter error: $error');
      },
    );

    // Start audio streamer (for AI classification)
    _audioSubscription = _audioStreamer?.audioStream.listen(
      (List<double> audioData) {
        if (onAudioData != null) {
          onAudioData!(audioData);
        }
      },
      onError: (error) {
        print('Audio streamer error: $error');
      },
    );

    _isListening = true;
  }

  // Stop listening
  void stopListening() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _isListening = false;
  }

  // Dispose
  void dispose() {
    stopListening();
  }
}