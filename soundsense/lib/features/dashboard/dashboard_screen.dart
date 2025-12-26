import 'package:flutter/material.dart';
import '../../shared/widgets/sound_card.dart';
import '../../core/models/detected_sound.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/audio_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AudioService _audioService = AudioService();
  bool _isListening = false;

  // Demo sounds for testing UI
  final List<DetectedSound> _detectedSounds = [
    DetectedSound(
      name: 'Car Horn',
      category: 'Traffic',
      confidence: 0.92,
      timestamp: DateTime.now(),
      priority: 'critical',
    ),
    DetectedSound(
      name: 'Dog Bark',
      category: 'Animal',
      confidence: 0.85,
      timestamp: DateTime.now(),
      priority: 'important',
    ),
    DetectedSound(
      name: 'Music',
      category: 'Entertainment',
      confidence: 0.78,
      timestamp: DateTime.now(),
      priority: 'normal',
    ),
  ];

  void _toggleListening() async {
    if (_isListening) {
      _audioService.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      try {
        await _audioService.startListening();
        setState(() {
          _isListening = true;
        });
      } catch (e) {
        // Show error if permission denied
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Listening Status & Toggle Button
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
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
          // Sound Cards List
          Expanded(
            child: _detectedSounds.isEmpty
                ? const Center(
                    child: Text(
                      'No sounds detected',
                      style: TextStyle(color: Colors.grey),
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
