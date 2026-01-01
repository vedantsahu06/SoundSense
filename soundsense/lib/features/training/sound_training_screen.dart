import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/models/custom_sound_model.dart';
import '../../core/services/custom_sound_service.dart';
import 'package:path_provider/path_provider.dart';
class SoundTrainingScreen extends StatefulWidget {
  const SoundTrainingScreen({super.key});

  @override
  State<SoundTrainingScreen> createState() => _SoundTrainingScreenState();
}

class _SoundTrainingScreenState extends State<SoundTrainingScreen> {
  final CustomSoundService _soundService = CustomSoundService.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // State
  bool _isInitialized = false;
  bool _isRecording = false;
  TrainingSession? _currentSession;
  
  // Form
  final _nameController = TextEditingController();
  String _selectedCategory = SoundCategory.home;
  
  // Recording
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 5;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _soundService.initialize();
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Train Custom Sound',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isInitialized
          ? _currentSession == null
              ? _buildSetupView()
              : _buildTrainingView()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  // ============================================================
  // Setup View - Enter name and category
  // ============================================================

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 32),
          
          // Sound Name
          _buildNameInput(),
          const SizedBox(height: 24),
          
          // Category Selection
          _buildCategorySelection(),
          const SizedBox(height: 32),
          
          // Existing Sounds
          _buildExistingSounds(),
          const SizedBox(height: 32),
          
          // Start Button
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teach Dhwani New Sounds',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record a sound 5 times to train',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sound Name',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Pressure Cooker, My Doorbell',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.label, color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SoundCategory.all.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(SoundCategory.getIcon(category)),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExistingSounds() {
    final sounds = _soundService.customSounds;
    if (sounds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Custom Sounds',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${sounds.length} sounds',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sounds.map((sound) => _buildSoundTile(sound)),
      ],
    );
  }

  Widget _buildSoundTile(CustomSound sound) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(sound.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${sound.category} • ${sound.sampleCount} samples',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              sound.isActive ? Icons.check_circle : Icons.cancel,
              color: sound.isActive ? Colors.greenAccent : Colors.grey,
            ),
            onPressed: () => _toggleSound(sound),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _deleteSound(sound),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    final canStart = _nameController.text.trim().isNotEmpty;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canStart ? _startTraining : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Start Training',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ============================================================
  // Training View - Record samples
  // ============================================================

  Widget _buildTrainingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress
          _buildProgress(),
          const Spacer(),
          
          // Recording UI
          _buildRecordingUI(),
          const Spacer(),
          
          // Instructions
          _buildInstructions(),
          const SizedBox(height: 24),
          
          // Cancel Button
          TextButton(
            onPressed: _cancelTraining,
            child: const Text('Cancel Training', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final session = _currentSession!;
    return Column(
      children: [
        Text(
          'Training: ${session.name}',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(session.requiredSamples, (index) {
            final isCompleted = index < session.samplesCollected;
            final isCurrent = index == session.samplesCollected;
            return Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.greenAccent
                    : isCurrent
                        ? Colors.cyanAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: Colors.cyanAccent, width: 2)
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.black, size: 20)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.cyanAccent : Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          '${session.samplesCollected} of ${session.requiredSamples} samples',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        // Recording indicator
        if (_isRecording)
          Text(
            '$_recordingSeconds / $_maxRecordingSeconds sec',
            style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut(),
        
        const SizedBox(height: 24),
        
        // Record button
        GestureDetector(
          onTap: _isRecording ? null : _recordSample,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isRecording
                    ? [Colors.redAccent, Colors.red.shade700]
                    : [Colors.cyanAccent, Colors.blue],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 48,
            ),
          ),
        ).animate(target: _isRecording ? 1 : 0)
          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
        
        const SizedBox(height: 24),
        
        Text(
          _isRecording ? 'Recording...' : 'Tap to Record',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.lightbulb, color: Colors.amber, size: 24),
          const SizedBox(height: 8),
          Text(
            'Play the sound "${_currentSession?.name}" clearly.\nRecord it from different distances for better accuracy.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Actions
  // ============================================================

  void _startTraining() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _currentSession = _soundService.startTraining(
        name: name,
        category: _selectedCategory,
      );
    });
  }
Future<void> _recordSample() async {
  if (_isRecording || _currentSession == null) return;

  if (!await _audioRecorder.hasPermission()) {
    _showSnackbar('Microphone permission denied', isError: true);
    return;
  }

  try {
    // Get proper temp directory using path_provider
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/sound_$timestamp.wav';
    
    print('🎤 Recording to: $filePath');

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    await _audioRecorder.start(
       RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      
      if (_recordingSeconds >= _maxRecordingSeconds) {
        _stopRecording();
      }
    });
  } catch (e) {
    print('❌ Recording error: $e');
    setState(() => _isRecording = false);
    _showSnackbar('Failed to start recording: $e', isError: true);
  }
}

Future<void> _stopRecording() async {
  _recordingTimer?.cancel();
  
  final path = await _audioRecorder.stop();
  setState(() => _isRecording = false);

  if (path == null) {
    _showSnackbar('Recording failed', isError: true);
    return;
  }

  try {
    final file = File(path);
    var audioData = await file.readAsBytes();
    
    print('📁 Raw file size: ${audioData.length} bytes');
    
    // Strip WAV header (44 bytes) to get raw PCM data
    if (audioData.length > 44) {
      // Check if it's a WAV file (starts with "RIFF")
      if (audioData[0] == 0x52 && audioData[1] == 0x49 && 
          audioData[2] == 0x46 && audioData[3] == 0x46) {
        audioData = audioData.sublist(44); // Remove 44-byte WAV header
        print('📁 Stripped WAV header, PCM size: ${audioData.length} bytes');
      }
    }
    
    // Take only 31200 bytes (same as detection: 15600 samples * 2 bytes)
    if (audioData.length > 31200) {
      // Take from middle of recording for better quality
      final start = (audioData.length - 31200) ~/ 2;
      audioData = audioData.sublist(start, start + 31200);
      print('📁 Trimmed to ${audioData.length} bytes');
    }
    
    final success = await _currentSession!.addSample(audioData);
    
    if (success) {
      _showSnackbar('Sample ${_currentSession!.samplesCollected} recorded! ✓');
      
      if (_currentSession!.isComplete) {
        _showSnackbar('Training complete! 🎉');
        setState(() {
          _currentSession = null;
          _nameController.clear();
        });
      }
    } else {
      _showSnackbar('Sample rejected - try again', isError: true);
    }
  } catch (e) {
    print('❌ Error reading audio: $e');
    _showSnackbar('Error: $e', isError: true);
  }
}
  void _cancelTraining() {
    _currentSession?.cancel();
    setState(() => _currentSession = null);
  }

  Future<void> _toggleSound(CustomSound sound) async {
    final updated = sound.copyWith(isActive: !sound.isActive);
    await _soundService.updateCustomSound(updated);
    setState(() {});
  }

  Future<void> _deleteSound(CustomSound sound) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2136),
        title: const Text('Delete Sound?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${sound.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _soundService.deleteCustomSound(sound.id);
      setState(() {});
      _showSnackbar('Sound deleted');
    }
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
}