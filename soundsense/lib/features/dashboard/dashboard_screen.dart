import 'package:flutter/material.dart';
import '../../shared/widgets/sound_card.dart';
import '../../core/models/detected_sound.dart';
import '../../core/models/sound_category.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/sound_classifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AudioService _audioService = AudioService();
  final SoundClassifier _classifier = SoundClassifier();
  
  bool _isListening = false;
  bool _isModelLoaded = false;
  double _currentDecibel = 0;
  List<DetectedSound> _detectedSounds = [];
  List<double> _audioBuffer = [];

  @override
  void initState() {
    super.initState();
    _initializeClassifier();
    _setupAudioCallbacks();
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

    // Take 15600 samples for classification
    final samples = _audioBuffer.sublist(0, 15600);
    _audioBuffer = _audioBuffer.sublist(15600);

    // Run AI classification
    final results = await _classifier.classify(samples);

    if (results.isNotEmpty) {
      setState(() {
        // Add new detected sounds
        for (var result in results) {
          final priority = SoundCategory.getPriority(result.label);
          
          // Vibrate for important sounds
          if (priority == 'critical' || priority == 'important') {
            HapticService.vibrate(priority);
          }

          // Add to list (avoid duplicates)
          final exists = _detectedSounds.any((s) => s.name == result.label);
          if (!exists) {
            _detectedSounds.insert(0, DetectedSound(
              name: result.label,
              category: _getCategoryForSound(result.label),
              confidence: result.confidence,
              timestamp: DateTime.now(),
              priority: priority,
            ));
          }
        }

        // Keep only last 10 sounds
        if (_detectedSounds.length > 10) {
          _detectedSounds = _detectedSounds.sublist(0, 10);
        }
      });
    }
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

  @override
  Widget build(BuildContext context) {
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
          // AI Status indicator
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
          // Listening Status & Audio Level
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // AI Status
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
                
                // Status
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
                    ),
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
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_currentDecibel / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getDecibelColor(),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Toggle Button
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
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Detected Sounds Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Detected Sounds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_detectedSounds.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _detectedSounds.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
              ],
            ),
          ),
          
          // Sound Cards List
          Expanded(
            child: _detectedSounds.isEmpty
                ? Center(
                    child: Text(
                      _isListening 
                          ? 'Listening for sounds...' 
                          : 'Tap mic to start',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _detectedSounds.length,
                    itemBuilder: (context, index) {
                      final sound = _detectedSounds[index];
                      return SoundCard(
                        soundName: sound.name,
                        priority: sound.priority,
                        confidence: sound.confidence,
                        onTap: () => _onSoundTap(sound),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
