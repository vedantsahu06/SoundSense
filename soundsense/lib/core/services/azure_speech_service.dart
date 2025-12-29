import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AzureSpeechService {
  final String _apiKey;
  final String _region;
  
  bool _isListening = false;
  String _currentTranscription = '';
  
  final StreamController<String> _transcriptionController = 
      StreamController<String>.broadcast();
  final StreamController<String> _partialController = 
      StreamController<String>.broadcast();
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();
  
  // Audio buffer for batch processing
  List<int> _audioBuffer = [];
  Timer? _processTimer;
  
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<String> get partialStream => _partialController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  bool get isListening => _isListening;
  String get currentTranscription => _currentTranscription;
  
  AzureSpeechService({
    required String apiKey,
    String region = 'eastus',
  })  : _apiKey = apiKey,
        _region = region;
  
  /// Start transcription
  Future<bool> startTranscription({String language = 'en-US'}) async {
    if (_isListening) return true;
    
    _isListening = true;
    _audioBuffer = [];
    _connectionController.add(true);
    
    // Process audio every 3 seconds
    _processTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _processAudioBuffer(language);
    });
    
    return true;
  }
  
  /// Stop transcription
  Future<void> stopTranscription() async {
    _isListening = false;
    _processTimer?.cancel();
    _processTimer = null;
    _audioBuffer = [];
    _connectionController.add(false);
  }
  
  /// Add audio data to buffer
  void sendAudioData(Uint8List audioData) {
    if (!_isListening) return;
    _audioBuffer.addAll(audioData);
  }
  
  /// Process buffered audio
  Future<void> _processAudioBuffer(String language) async {
    if (_audioBuffer.isEmpty) return;
    
    // Get audio and clear buffer
    final audioData = Uint8List.fromList(_audioBuffer);
    _audioBuffer = [];
    
    // Send to Azure REST API
    final result = await _transcribeAudio(audioData, language);
    
    if (result != null && result.isNotEmpty) {
      _currentTranscription += ' $result';
      _currentTranscription = _currentTranscription.trim();
      _transcriptionController.add(_currentTranscription);
    }
  }
  
  /// Transcribe audio using REST API
  Future<String?> _transcribeAudio(Uint8List audioData, String language) async {
    final url = 'https://$_region.stt.speech.microsoft.com/'
        'speech/recognition/conversation/cognitiveservices/v1'
        '?language=$language';
    
    try {
      // Create WAV header for raw PCM data
      final wavData = _createWavFile(audioData);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': _apiKey,
          'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept': 'application/json',
        },
        body: wavData,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['RecognitionStatus'];
        
        if (status == 'Success') {
          return data['DisplayText'] ?? data['Text'];
        }
      } else {
        print('Azure Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Transcription error: $e');
      _errorController.add('Transcription failed: $e');
    }
    
    return null;
  }
  
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
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little);  // Audio format (PCM)
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
  
  /// Clear transcription
  void clearTranscription() {
    _currentTranscription = '';
    _transcriptionController.add('');
  }
  
  /// Dispose
  void dispose() {
    stopTranscription();
    _transcriptionController.close();
    _partialController.close();
    _connectionController.close();
    _errorController.close();
  }
}