import 'package:flutter/material.dart';
import '../../shared/widgets/sound_card.dart';
import '../../core/models/detected_sound.dart';
import '../../core/models/sound_category.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/sound_classifier.dart';
import '../chat/chat_screen.dart';
import '../transcription/transcription_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/services/settings_service.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../shared/widgets/sound_animation.dart';
import '../../shared/widgets/critical_alerts.dart';
import '../../core/services/animation_service.dart';
import '../../shared/widgets/sound_grid.dart';
import '../training/sound_training_screen.dart';
import '../training/voice_training_screen.dart';
import '../transcription/enhanced_transcription_screen.dart';
import '../../core/services/custom_sound_service.dart';
import 'dart:typed_data';
import '../../core/services/training_database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AudioService _audioService = AudioService();
  final SoundClassifier _classifier = SoundClassifier();
  final SettingsService _settings = SettingsService();
  
  bool _isListening = false;
  bool _isModelLoaded = false;
  double _currentDecibel = 0;
  List<DetectedSound> _detectedSounds = [];
  List<double> _audioBuffer = [];
  DetectedSound? _currentSound;  // Currently displayed sound
bool _showCriticalAlert = false;

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
    _setupAudioCallbacks();
    _checkCustomSounds();
  }

Future<void> _checkCustomSounds() async {
  final customSoundService = CustomSoundService.instance;
  await customSoundService.initialize();
  
  // Clear old bad data - REMOVE AFTER ONE RUN
  await TrainingDatabase.instance.clearAllData();
  print('🗑️ Cleared old data!');
  
  print('🔊 Custom sounds saved: ${customSoundService.customSounds.length}');
}
  Future<void> _initializeClassifier() async {
    await _classifier.initialize();
    setState(() {
      _isModelLoaded = _classifier.isReady;
    });
    if (_isModelLoaded) {
      print('AI Model loaded successfully!');
    } else {
      print('Failed to load AI model');
    }
  }

  void _setupAudioCallbacks() {
    // Listen to decibel levels
    _audioService.onNoiseLevel = (double decibel) {
      setState(() {
        _currentDecibel = decibel;
      });
    };

    // Listen to raw audio data
    _audioService.onAudioData = (List<double> audioData) {
      _audioBuffer.addAll(audioData);
      
      // YAMNet needs ~15600 samples (about 1 second at 16kHz)
      if (_audioBuffer.length >= 15600) {
        _classifyAudio();
      }
    };
  }
Future<void> _classifyAudio() async {
  if (!_isModelLoaded || _audioBuffer.length < 15600) return;

  final samples = _audioBuffer.sublist(0, 15600);
  _audioBuffer = _audioBuffer.sublist(15600);
  final audioBytes = _samplesToBytes(samples);

  
   final customMatch = await CustomSoundService.instance.detectCustomSound(audioBytes);
  if (customMatch != null) {
    print('🎯 Custom sound detected: ${customMatch.displayName} (${customMatch.confidencePercent}%)');
    
    final customDetected = DetectedSound(
      name: '⭐ ${customMatch.displayName}',
      category: customMatch.sound.category,
      confidence: customMatch.confidence,
      timestamp: DateTime.now(),
      priority: 'important',
    );
    
    setState(() {
      _detectedSounds.insert(0, customDetected);
      _currentSound = customDetected;
      if (_detectedSounds.length > 10) {
        _detectedSounds = _detectedSounds.sublist(0, 10);
      }
    });
    
    HapticService.vibrate('important');
    return; // Skip YAMNet if custom sound found
  }
final results = await _classifier.classify(samples);
  if (results.isNotEmpty) {
    for (var result in results) {
      final priority = SoundCategory.getPriority(result.label);

      // Skip if disabled in settings
      if (!_settings.shouldShowSound(priority)) continue;

      // Vibrate if enabled
      if (_settings.vibrationEnabled &&
          (priority == 'critical' || priority == 'important')) {
        HapticService.vibrate(priority);
      }

      // Check for duplicates
      final exists = _detectedSounds.any((s) => s.name == result.label);
      if (exists) continue;

      final newSound = DetectedSound(
        name: result.label,
        category: _getCategoryForSound(result.label),
        confidence: result.confidence,
        timestamp: DateTime.now(),
        priority: priority,
      );

      setState(() {
        _detectedSounds.insert(0, newSound);
        _currentSound = newSound;

        // Show critical alert for dangerous sounds
        if (AnimationService.isCriticalAlert(result.label)) {
          _showCriticalAlert = true;
        }

        if (_detectedSounds.length > 10) {
          _detectedSounds = _detectedSounds.sublist(0, 10);
        }
      });
    }
  }
}
Uint8List _samplesToBytes(List<double> samples) {
  final bytes = Uint8List(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    int sample = (samples[i] * 32768).round().clamp(-32768, 32767);
    if (sample < 0) sample += 65536;
    bytes[i * 2] = sample & 0xFF;
    bytes[i * 2 + 1] = (sample >> 8) & 0xFF;
  }
  return bytes;
}
  String _getCategoryForSound(String soundName) {
    final lower = soundName.toLowerCase();
    if (lower.contains('car') || lower.contains('horn') || lower.contains('siren')) {
      return 'Traffic';
    } else if (lower.contains('dog') || lower.contains('cat') || lower.contains('bird')) {
      return 'Animal';
    } else if (lower.contains('music') || lower.contains('singing')) {
      return 'Music';
    } else if (lower.contains('speech') || lower.contains('talk')) {
      return 'Speech';
    } else if (lower.contains('door') || lower.contains('knock')) {
      return 'Home';
    }
    return 'Other';
  }

  @override
  void dispose() {
    _audioService.dispose();
    _classifier.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      _audioService.stopListening();
      setState(() {
        _isListening = false;
        _currentDecibel = 0;
      });
    } else {
      try {
        await _audioService.startListening();
        setState(() {
          _isListening = true;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSoundTap(DetectedSound sound) {
    HapticService.vibrate(sound.priority);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sound.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Category', sound.category),
            _buildInfoRow('Confidence', '${(sound.confidence * 100).toInt()}%'),
            _buildInfoRow('Priority', sound.priority.toUpperCase()),
            _buildInfoRow('Time', _formatTime(sound.timestamp)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Color _getDecibelColor() {
    if (_currentDecibel > 80) return const Color(0xFFFF4757);
    if (_currentDecibel > 60) return const Color(0xFFFFA502);
    return const Color(0xFF2ED573);
  }
  Widget _buildFeatureCard({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
Widget build(BuildContext context) {
  // Show critical alert if needed
  if (_showCriticalAlert && _currentSound != null) {
    return CriticalAlert(
      soundName: _currentSound!.name,
      confidence: _currentSound!.confidence,
      onDismiss: () {
        setState(() {
          _showCriticalAlert = false;
        });
      },
    );
  }

  return Scaffold(
    backgroundColor: const Color(0xFF1A1A2E),
    appBar: AppBar(
      title: const Text(
        'SoundSense',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF16213E),
      centerTitle: true,
      actions: [
         IconButton(
    icon: const Icon(Icons.music_note, color: Colors.white),
    tooltip: 'Train Sounds',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SoundTrainingScreen(),
        ),
      );
    },
  ),
  // NEW: Voice Training
  IconButton(
    icon: const Icon(Icons.person_add, color: Colors.white),
    tooltip: 'Voice Profiles',
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VoiceTrainingScreen(),
        ),
      );
    },
  ),
        IconButton(
          
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
      IconButton(
  icon: const Icon(Icons.subtitles, color: Colors.white),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedTranscriptionScreen(),
      ),
    );
  },
),
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  recentSounds: _detectedSounds.map((s) => s.name).toList(),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Icon(
            _isModelLoaded ? Icons.psychology : Icons.psychology_outlined,
            color: _isModelLoaded ? const Color(0xFF2ED573) : Colors.grey,
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        // Status & Controls
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // AI Loading indicator
              if (!_isModelLoaded)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading AI Model...',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),

              // Listening Status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? const Color(0xFF2ED573)
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ).animate(target: _isListening ? 1 : 0)
                      .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
                      .then()
                      .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening...' : 'Not Listening',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Decibel Display
              if (_isListening) ...[
                Text(
                  '${_currentDecibel.toStringAsFixed(1)} dB',
                  style: TextStyle(
                    color: _getDecibelColor(),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_currentDecibel / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getDecibelColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Mic Button with animation
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? const Color(0xFFFF4757)
                        : const Color(0xFF2ED573),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening
                                ? const Color(0xFFFF4757)
                                : const Color(0xFF2ED573))
                            .withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ).animate(target: _isListening ? 1 : 0)
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1))
                    .then()
                    .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
              ),
              const SizedBox(height: 24),

// Feature Cards Row
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    // Train Sounds Card
    _buildFeatureCard(
      icon: Icons.music_note,
      label: 'Train\nSounds',
      color: Colors.purple,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SoundTrainingScreen(),
          ),
        );
      },
    ),
    const SizedBox(width: 16),
    // Voice Profiles Card
    _buildFeatureCard(
      icon: Icons.person_add,
      label: 'Voice\nProfiles',
      color: Colors.orange,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const VoiceTrainingScreen(),
          ),
        );
      },
    ),
    const SizedBox(width: 16),
    // Enhanced Captions Card
    _buildFeatureCard(
      icon: Icons.closed_caption,
      label: 'Live\nCaptions',
      color: Colors.cyan,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EnhancedTranscriptionScreen(),
          ),
        );
      },
    ),
  ],
),
            ],
          ),
        ),

        // Current Sound Animation (if any)
      // Current Sound Animation (if any)
if (_detectedSounds.isNotEmpty && _isListening)
  SoundGrid(
    sounds: _detectedSounds,
    onSoundTap: _onSoundTap,
  ),

        // Sound History Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Recent Sounds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_detectedSounds.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _detectedSounds.clear();
                      _currentSound = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),

        // Sound Cards List
        Expanded(
          child: _detectedSounds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hearing,
                        size: 48,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isListening
                            ? 'Listening for sounds...'
                            : 'Tap mic to start',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _detectedSounds.length,
                  itemBuilder: (context, index) {
                    final sound = _detectedSounds[index];
                    return SoundCard(
                      soundName: sound.name,
                      priority: sound.priority,
                      confidence: sound.confidence,
                      onTap: () => _onSoundTap(sound),
                    ).animate().fadeIn(delay: Duration(milliseconds: index * 100))
                        .slideX(begin: 0.2);
                  },
                ),
        ),
      ],
    ),
  );
}
}
