import 'package:permission_handler/permission_handler.dart';

class AudioService {
  bool _isListening = false;

  bool get isListening => _isListening;

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
    _isListening = true;
  }

  // Stop listening
  void stopListening() {
    _isListening = false;
  }
}