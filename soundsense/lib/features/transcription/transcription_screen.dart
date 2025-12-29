import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/services/azure_speech_service.dart';
import '../../core/config/env_config.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  late AzureSpeechService _speechService;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isListening = false;
  bool _isConnected = false;
  String _transcription = '';
  String _partialText = '';
  String _selectedLanguage = 'en-US';
  
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
    {'code': 'mr-IN', 'name': 'Marathi'},
    {'code': 'bn-IN', 'name': 'Bengali'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeSpeechService();
  }
  
  void _initializeSpeechService() {
    _speechService = AzureSpeechService(
      apiKey: EnvConfig.azureSpeechApiKey,
      region: EnvConfig.azureSpeechRegion,
    );
    
    _transcriptionSub = _speechService.transcriptionStream.listen((text) {
      setState(() {
        _transcription = text;
        _partialText = '';
      });
      _scrollToBottom();
    });
    
    _partialSub = _speechService.partialStream.listen((text) {
      setState(() {
        _partialText = text;
      });
    });
    
    _connectionSub = _speechService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (!connected) _isListening = false;
      });
    });
    
    _errorSub = _speechService.errorStream.listen((error) {
      _showSnackbar(error, isError: true);
    });
  }

  @override
  void dispose() {
    _transcriptionSub?.cancel();
    _partialSub?.cancel();
    _connectionSub?.cancel();
    _errorSub?.cancel();
    _audioSub?.cancel();
    _speechService.dispose();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _startListening() async {
    if (!await _audioRecorder.hasPermission()) {
      _showSnackbar('Microphone permission denied', isError: true);
      return;
    }
    
    final connected = await _speechService.startTranscription(
      language: _selectedLanguage,
    );
    
    if (!connected) {
      _showSnackbar('Failed to connect to Azure', isError: true);
      return;
    }
    
    try {
     final stream = await _audioRecorder.startStream(
  const RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: 16000,
    numChannels: 1,
  ),
);
      
      setState(() => _isListening = true);
      
      _audioSub = stream.listen((data) {
        _speechService.sendAudioData(Uint8List.fromList(data));
      });
      
    } catch (e) {
      _showSnackbar('Failed to start recording: $e', isError: true);
      await _speechService.stopTranscription();
    }
  }
  
  Future<void> _stopListening() async {
    setState(() => _isListening = false);
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
      _transcription = '';
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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.closed_caption, color: Colors.cyanAccent),
            const SizedBox(width: 8),
            const Text('Live Captions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLanguageSelector(),
          _buildConnectionStatus(),
          Expanded(child: _buildTranscriptionArea()),
          _buildControlPanel(),
        ],
      ),
    );
  }
  
  Widget _buildPulsingDot() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (c) => c.repeat())
      .fadeIn(duration: 500.ms)
      .then()
      .fadeOut(duration: 500.ms);
  }
  
  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
  
  Widget _buildConnectionStatus() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isConnected ? Colors.greenAccent : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isConnected ? 'Connected to Azure' : 'Not connected',
            style: TextStyle(
              color: _isConnected ? Colors.greenAccent : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTranscriptionArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isListening 
              ? Colors.cyanAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: _transcription.isEmpty && _partialText.isEmpty
          ? _buildEmptyState()
          : _buildTranscriptionContent(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _isListening ? 'Listening...\nSpeak now' : 'Tap the microphone to start\nlive captions',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTranscriptionContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_transcription.isNotEmpty)
            Text(
              _transcription,
              style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.6),
            ),
          if (_partialText.isNotEmpty)
            Text(
              _partialText,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 20,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: GestureDetector(
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
                color: (_isListening ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.4),
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
    );
  }
}