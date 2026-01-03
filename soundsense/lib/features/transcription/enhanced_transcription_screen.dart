import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/azure_speech_service.dart';
import '../../core/services/azure_speaker_service.dart';
import '../../core/config/env_config.dart';

/// Live Captions Screen with Real-time Speech-to-Text
class EnhancedTranscriptionScreen extends StatefulWidget {
  const EnhancedTranscriptionScreen({super.key});

  @override
  State<EnhancedTranscriptionScreen> createState() =>
      _EnhancedTranscriptionScreenState();
}

class _EnhancedTranscriptionScreenState extends State<EnhancedTranscriptionScreen>
    with TickerProviderStateMixin {
  // Services
  late AzureSpeechService _speechService;
  final AzureSpeakerService _speakerService = AzureSpeakerService.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // State
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isConnected = false;
  String _selectedLanguage = 'en-US';

  // Transcription
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
  late AnimationController _pulseController;

  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)', 'flag': '🇺🇸'},
    {'code': 'en-IN', 'name': 'English (India)', 'flag': '🇮🇳'},
    {'code': 'hi-IN', 'name': 'Hindi', 'flag': '🇮🇳'},
    {'code': 'es-ES', 'name': 'Spanish', 'flag': '🇪🇸'},
    {'code': 'fr-FR', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'de-DE', 'name': 'German', 'flag': '🇩🇪'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initialize();
  }

  Future<void> _initialize() async {
    _speechService = AzureSpeechService(
      apiKey: EnvConfig.azureSpeechApiKey,
      region: EnvConfig.azureSpeechRegion,
    );

    _transcriptionSub =
        _speechService.transcriptionStream.listen(_onTranscription);
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
    _pulseController.dispose();
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
  // Speaker Identification
  // ============================================================

  void _startSpeakerIdentification() {
    _speakerAudioBuffer = [];
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
    if (_speakerAudioBuffer.length < 16000 * 2) return;

    final audioData = Uint8List.fromList(_speakerAudioBuffer);
    _speakerAudioBuffer = [];

    final result = await _speakerService.identifySpeaker(audioData);

    setState(() {
      _currentSpeaker = result;
    });
  }

  void _addAudioForSpeakerIdentification(List<int> audioData) {
    _speakerAudioBuffer.addAll(audioData);

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
      _showSnackbar('Failed to connect to Azure', isError: true);
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

      _startSpeakerIdentification();

      _audioSub = stream.listen((data) {
        _speechService.sendAudioData(Uint8List.fromList(data));
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
        content: Text(message, style: AppTheme.bodyMedium),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
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
      backgroundColor: AppTheme.backgroundPrimary,
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStatusBar(),
                  Expanded(child: _buildTranscriptArea()),
                  _buildControlPanel(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child:
                const Icon(Icons.closed_caption_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Live Captions', style: AppTheme.headlineLarge),
                    if (_isListening) ...[
                      const SizedBox(width: 10),
                      _buildPulsingDot(),
                    ],
                  ],
                ),
                Text(
                  'Real-time speech to text',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearTranscription,
            icon: const Icon(Icons.delete_outline_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.backgroundSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.6 + (_pulseController.value * 0.4)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.error.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2 * _pulseController.value,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBar() {
    final profileCount =
        _speakerService.profiles.where((p) => p.isEnrolled).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Language Selector
          Expanded(
            child: GestureDetector(
              onTap: _isListening ? null : _showLanguageSelector,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.borderMedium),
                ),
                child: Row(
                  children: [
                    Text(
                      _languages.firstWhere(
                              (l) => l['code'] == _selectedLanguage)['flag'] ??
                          '🌐',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _languages.firstWhere(
                                (l) => l['code'] == _selectedLanguage)['name'] ??
                            'English',
                        style: AppTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _isListening
                          ? AppTheme.textDisabled
                          : AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Voice Profiles Badge
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/voice-training'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: profileCount > 0
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: profileCount > 0
                      ? AppTheme.primary.withOpacity(0.3)
                      : AppTheme.warning.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_rounded,
                    size: 18,
                    color:
                        profileCount > 0 ? AppTheme.primary : AppTheme.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profileCount > 0 ? '$profileCount' : '+',
                    style: AppTheme.labelLarge.copyWith(
                      color: profileCount > 0
                          ? AppTheme.primary
                          : AppTheme.warning,
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

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Select Language', style: AppTheme.headlineMedium),
              const SizedBox(height: 16),
              ..._languages.map((lang) => ListTile(
                    onTap: () {
                      setState(() => _selectedLanguage = lang['code']!);
                      Navigator.pop(context);
                    },
                    leading: Text(lang['flag']!,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(lang['name']!, style: AppTheme.labelLarge),
                    trailing: _selectedLanguage == lang['code']
                        ? const Icon(Icons.check_circle,
                            color: AppTheme.primary)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptArea() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: _isListening
              ? AppTheme.accent.withOpacity(0.3)
              : AppTheme.borderMedium,
        ),
      ),
      child: _transcriptEntries.isEmpty && _partialText.isEmpty
          ? _buildEmptyState()
          : _buildTranscriptList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.backgroundTertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening
                    ? Icons.hearing_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isListening ? 'Listening...' : 'Start Recording',
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _isListening
                  ? 'Speak now and your words will appear here'
                  : 'Tap the microphone button to begin transcription',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium,
            ),
            if (!_isListening) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.info.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: AppTheme.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add voice profiles to identify who is speaking',
                        style:
                            AppTheme.bodySmall.copyWith(color: AppTheme.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
    final name = speaker?.personName ?? 'Speaker';
    final confidence = speaker?.confidence ?? 0.0;

    String emoji = '👤';
    if (isKnown) {
      final profile = _speakerService.profiles.firstWhere(
        (p) => p.personName == name,
        orElse: () => AzureVoiceProfile(profileId: '', personName: name),
      );
      emoji = profile.emoji ?? '👤';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isKnown
                  ? AppTheme.primary.withOpacity(0.15)
                  : AppTheme.backgroundTertiary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isKnown
                    ? AppTheme.primary.withOpacity(0.3)
                    : AppTheme.borderMedium,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: AppTheme.labelLarge.copyWith(
                        color: isKnown ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    if (isKnown && confidence > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getConfidenceColor(confidence).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(confidence * 100).round()}%',
                          style: AppTheme.bodySmall.copyWith(
                            color: _getConfidenceColor(confidence),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (timestamp != null)
                      Text(
                        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                        style: AppTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isPartial
                        ? AppTheme.backgroundTertiary.withOpacity(0.5)
                        : AppTheme.backgroundTertiary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Text(
                    text,
                    style: AppTheme.bodyLarge.copyWith(
                      color: isPartial
                          ? AppTheme.textTertiary
                          : AppTheme.textPrimary,
                      fontStyle:
                          isPartial ? FontStyle.italic : FontStyle.normal,
                      height: 1.5,
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
    if (confidence >= 0.85) return AppTheme.success;
    if (confidence >= 0.70) return AppTheme.info;
    return AppTheme.warning;
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mic Button
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale =
                      _isListening ? 1.0 + (_pulseController.value * 0.05) : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isListening
                            ? AppTheme.dangerGradient
                            : AppTheme.accentGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
                                    ? AppTheme.error
                                    : AppTheme.accent)
                                .withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening ? 'Tap to stop' : 'Tap to start',
              style: AppTheme.bodySmall,
            ),
          ],
        ),
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
