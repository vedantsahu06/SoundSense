import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/services/azure_speech_service.dart';
import '../../core/services/azure_speaker_service.dart';
import '../../core/config/env_config.dart';

/// Enhanced Transcription Screen with REAL Azure Speaker Identification
class EnhancedTranscriptionScreen extends StatefulWidget {
  const EnhancedTranscriptionScreen({super.key});

  @override
  State<EnhancedTranscriptionScreen> createState() => _EnhancedTranscriptionScreenState();
}

class _EnhancedTranscriptionScreenState extends State<EnhancedTranscriptionScreen> {
  // Services
  late AzureSpeechService _speechService;
  final AzureSpeakerService _speakerService = AzureSpeakerService.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // State
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isConnected = false;
  String _selectedLanguage = 'en-US';
  
  // Transcription with speakers
  final List<TranscriptEntry> _transcriptEntries = [];
  String _partialText = '';
  IdentificationResult? _currentSpeaker;
  
  // Audio buffer for speaker identification
  List<int> _speakerAudioBuffer = [];
  Timer? _speakerIdentificationTimer;
  
  // Streams
  StreamSubscription? _transcriptionSub;
  StreamSubscription? _partialSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _audioSub;
  
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-IN', 'name': 'English (India)'},
    {'code': 'hi-IN', 'name': 'Hindi'},
    {'code': 'ta-IN', 'name': 'Tamil'},
    {'code': 'te-IN', 'name': 'Telugu'},
    {'code': 'ml-IN', 'name': 'Malayalam'},
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _speechService = AzureSpeechService(
      apiKey: EnvConfig.azureSpeechApiKey,
      region: EnvConfig.azureSpeechRegion,
    );
    
    // Subscribe to transcription
    _transcriptionSub = _speechService.transcriptionStream.listen(_onTranscription);
    _partialSub = _speechService.partialStream.listen(_onPartialResult);
    _connectionSub = _speechService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (!connected) _isListening = false;
      });
    });
    _errorSub = _speechService.errorStream.listen((error) {
      _showSnackbar(error, isError: true);
    });
    
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _transcriptionSub?.cancel();
    _partialSub?.cancel();
    _connectionSub?.cancel();
    _errorSub?.cancel();
    _audioSub?.cancel();
    _speakerIdentificationTimer?.cancel();
    _speechService.dispose();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // Transcription Handlers
  // ============================================================

  void _onTranscription(String fullText) {
    if (fullText.isEmpty) return;
    
    // Get the new text
    String newText = fullText;
    if (_transcriptEntries.isNotEmpty) {
      final lastFullText = _transcriptEntries.map((e) => e.text).join(' ');
      if (fullText.startsWith(lastFullText)) {
        newText = fullText.substring(lastFullText.length).trim();
      }
    }
    
    if (newText.isEmpty) return;
    
    setState(() {
      _transcriptEntries.add(TranscriptEntry(
        text: newText,
        speaker: _currentSpeaker,
        timestamp: DateTime.now(),
      ));
      _partialText = '';
    });
    
    _scrollToBottom();
  }

  void _onPartialResult(String partial) {
    setState(() => _partialText = partial);
  }

  // ============================================================
  // REAL Azure Speaker Identification
  // ============================================================

  void _startSpeakerIdentification() {
    _speakerAudioBuffer = [];
    
    // Identify speaker every 3 seconds
    _speakerIdentificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _identifyCurrentSpeaker(),
    );
  }

  void _stopSpeakerIdentification() {
    _speakerIdentificationTimer?.cancel();
    _speakerIdentificationTimer = null;
  }

  Future<void> _identifyCurrentSpeaker() async {
    if (_speakerAudioBuffer.length < 16000 * 2) return; // Need at least 1 second
    
    final audioData = Uint8List.fromList(_speakerAudioBuffer);
    _speakerAudioBuffer = []; // Clear buffer
    
    // Call REAL Azure Speaker Recognition
    final result = await _speakerService.identifySpeaker(audioData);
    
    setState(() {
      _currentSpeaker = result;
    });
    
    if (result.identified) {
      print('🎤 Identified: ${result.personName} (${result.confidencePercent}%)');
    }
  }

  void _addAudioForSpeakerIdentification(List<int> audioData) {
    _speakerAudioBuffer.addAll(audioData);
    
    // Keep only last 3 seconds of audio
    const maxBufferSize = 16000 * 2 * 3;
    if (_speakerAudioBuffer.length > maxBufferSize) {
      _speakerAudioBuffer = _speakerAudioBuffer.sublist(
        _speakerAudioBuffer.length - maxBufferSize,
      );
    }
  }

  // ============================================================
  // Recording Controls
  // ============================================================

  Future<void> _startListening() async {
    if (!await _audioRecorder.hasPermission()) {
      _showSnackbar('Microphone permission denied', isError: true);
      return;
    }
    
    final connected = await _speechService.startTranscription(
      language: _selectedLanguage,
    );
    
    if (!connected) {
      _showSnackbar('Failed to connect', isError: true);
      return;
    }
    
    try {
      final stream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      
      setState(() => _isListening = true);
      
      // Start REAL Azure speaker identification
      _startSpeakerIdentification();
      
      _audioSub = stream.listen((data) {
        // Send to Azure for transcription
        _speechService.sendAudioData(Uint8List.fromList(data));
        
        // Also buffer for speaker identification
        _addAudioForSpeakerIdentification(data);
      });
      
    } catch (e) {
      _showSnackbar('Failed to start: $e', isError: true);
      await _speechService.stopTranscription();
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    
    _stopSpeakerIdentification();
    await _audioSub?.cancel();
    await _audioRecorder.stop();
    await _speechService.stopTranscription();
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _clearTranscription() {
    setState(() {
      _transcriptEntries.clear();
      _partialText = '';
    });
    _speechService.clearTranscription();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: _buildAppBar(),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildLanguageSelector(),
                Expanded(child: _buildTranscriptArea()),
                _buildControlPanel(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.closed_caption, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          const Text(
            'Live Captions',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          if (_isListening) ...[
            const SizedBox(width: 12),
            _buildPulsingDot(),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white70),
          onPressed: _clearTranscription,
          tooltip: 'Clear',
        ),
        IconButton(
          icon: const Icon(Icons.person_add, color: Colors.white70),
          onPressed: () => Navigator.pushNamed(context, '/voice-training'),
          tooltip: 'Add Voice',
        ),
      ],
    );
  }

  Widget _buildPulsingDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat())
      .fadeIn(duration: 500.ms)
      .then()
      .fadeOut(duration: 500.ms);
  }

  Widget _buildHeader() {
    final profileCount = _speakerService.profiles.where((p) => p.isEnrolled).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isConnected 
                  ? Colors.green.withOpacity(0.2) 
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.greenAccent : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Azure Connected' : 'Offline',
                  style: TextStyle(
                    color: _isConnected ? Colors.greenAccent : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Voice profiles count
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/voice-training'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: profileCount > 0 
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.record_voice_over,
                    color: profileCount > 0 ? Colors.blue : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    profileCount > 0 ? '$profileCount voices' : 'Add voices',
                    style: TextStyle(
                      color: profileCount > 0 ? Colors.blue : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.language, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C2136),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.white),
                items: _languages.map((lang) {
                  return DropdownMenuItem(
                    value: lang['code'],
                    child: Text(lang['name']!),
                  );
                }).toList(),
                onChanged: _isListening ? null : (value) {
                  setState(() => _selectedLanguage = value!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening
              ? Colors.cyanAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: _transcriptEntries.isEmpty && _partialText.isEmpty
          ? _buildEmptyState()
          : _buildTranscriptList(),
    );
  }

  Widget _buildEmptyState() {
    final hasProfiles = _speakerService.profiles.any((p) => p.isEnrolled);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _isListening
                ? 'Listening...\nSpeak now'
                : 'Tap the microphone to start\nSpeaker names will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          if (!hasProfiles) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(height: 8),
                  const Text(
                    'No voice profiles yet',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add family voices to see who is speaking',
                    style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/voice-training'),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Voice Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _transcriptEntries.length + (_partialText.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _transcriptEntries.length) {
          return _buildTranscriptBubble(
            text: _partialText,
            speaker: _currentSpeaker,
            isPartial: true,
          );
        }
        
        final entry = _transcriptEntries[index];
        return _buildTranscriptBubble(
          text: entry.text,
          speaker: entry.speaker,
          timestamp: entry.timestamp,
        );
      },
    );
  }

  Widget _buildTranscriptBubble({
    required String text,
    IdentificationResult? speaker,
    DateTime? timestamp,
    bool isPartial = false,
  }) {
    final isKnown = speaker?.identified ?? false;
    final name = speaker?.personName ?? 'Unknown';
    final confidence = speaker?.confidence ?? 0.0;
    
    // Get emoji for speaker
    String emoji = '❓';
    if (isKnown) {
      final profile = _speakerService.profiles.firstWhere(
        (p) => p.personName == name,
        orElse: () => AzureVoiceProfile(profileId: '', personName: name),
      );
      emoji = profile.emoji ?? '👤';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isKnown
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Speaker name and confidence
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isKnown ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isKnown && confidence > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(confidence).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(confidence * 100).round()}%',
                          style: TextStyle(
                            color: _getConfidenceColor(confidence),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (timestamp != null)
                      Text(
                        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                // Text content
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPartial
                        ? Colors.white.withOpacity(0.03)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isPartial
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                      fontSize: 16,
                      fontStyle: isPartial ? FontStyle.italic : FontStyle.normal,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05);
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return Colors.greenAccent;
    if (confidence >= 0.70) return Colors.blue;
    return Colors.orange;
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Sound training button
            _buildControlButton(
              icon: Icons.music_note,
              label: 'Sounds',
              onTap: () => Navigator.pushNamed(context, '/sound-training'),
            ),
            
            // Main mic button
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [Colors.redAccent, Colors.red.shade700]
                        : [Colors.cyanAccent, Colors.blue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.redAccent : Colors.cyanAccent)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            
            // Voice training button
            _buildControlButton(
              icon: Icons.person_add,
              label: 'Voices',
              onTap: () => Navigator.pushNamed(context, '/voice-training'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}


/// Transcript entry with speaker info
class TranscriptEntry {
  final String text;
  final IdentificationResult? speaker;
  final DateTime timestamp;

  TranscriptEntry({
    required this.text,
    this.speaker,
    required this.timestamp,
  });
}