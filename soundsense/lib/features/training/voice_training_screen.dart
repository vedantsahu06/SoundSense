import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/models/voice_profile_model.dart';
import '../../core/services/speaker_identification_service.dart';

class VoiceTrainingScreen extends StatefulWidget {
  const VoiceTrainingScreen({super.key});

  @override
  State<VoiceTrainingScreen> createState() => _VoiceTrainingScreenState();
}

class _VoiceTrainingScreenState extends State<VoiceTrainingScreen> {
  final SpeakerIdentificationService _speakerService = SpeakerIdentificationService.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // State
  bool _isInitialized = false;
  bool _isRecording = false;
  VoiceTrainingSession? _currentSession;
  
  // Form
  final _nameController = TextEditingController();
  String _selectedRelationship = Relationship.friend;
  
  // Recording
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 8;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _speakerService.initialize();
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
          'Train Voice Profile',
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
  // Setup View
  // ============================================================

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildNameInput(),
          const SizedBox(height: 24),
          _buildRelationshipSelection(),
          const SizedBox(height: 32),
          _buildExistingProfiles(),
          const SizedBox(height: 32),
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
          colors: [Colors.orange.withOpacity(0.3), Colors.pink.withOpacity(0.3)],
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
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Voice Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dhwani will identify who is speaking',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
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
          'Person\'s Name',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Mom, Dad, Priya',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.person, color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildRelationshipSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relationship',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Relationship.all.map((rel) {
            final isSelected = _selectedRelationship == rel;
            return GestureDetector(
              onTap: () => setState(() => _selectedRelationship = rel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orangeAccent : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Relationship.getEmoji(rel)),
                    const SizedBox(width: 6),
                    Text(
                      rel,
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

  Widget _buildExistingProfiles() {
    final profiles = _speakerService.voiceProfiles;
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Voice Profiles',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              '${profiles.length} profiles',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...profiles.map((profile) => _buildProfileTile(profile)),
      ],
    );
  }

  Widget _buildProfileTile(VoiceProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(profile.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${profile.relationship} • ${profile.sampleCount} samples',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              profile.isActive ? Icons.check_circle : Icons.cancel,
              color: profile.isActive ? Colors.greenAccent : Colors.grey,
            ),
            onPressed: () => _toggleProfile(profile),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _deleteProfile(profile),
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
          backgroundColor: Colors.orangeAccent,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          'Start Voice Training',
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ============================================================
  // Training View
  // ============================================================

  Widget _buildTrainingView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildProgress(),
          const SizedBox(height: 24),
          _buildPhraseCard(),
          const Spacer(),
          _buildRecordingUI(),
          const Spacer(),
          _buildTips(),
          const SizedBox(height: 24),
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
        const SizedBox(height: 8),
        Text(
          session.relationship,
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: session.progressPercent / 100,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          '${session.samplesCollected} of ${session.requiredSamples} recordings',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildPhraseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Ask them to say:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            '"${_currentSession?.currentPhrase}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildRecordingUI() {
    return Column(
      children: [
        if (_isRecording)
          Text(
            '$_recordingSeconds / $_maxRecordingSeconds sec',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut(),
        
        const SizedBox(height: 24),
        
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
                    : [Colors.orangeAccent, Colors.deepOrange],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.redAccent : Colors.orangeAccent)
                      .withOpacity(0.4),
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
          _isRecording ? 'Recording...' : 'Tap when they\'re ready',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.tips_and_updates, color: Colors.amber, size: 24),
          const SizedBox(height: 8),
          Text(
            'Tips:\n• Normal speaking volume\n• Quiet environment\n• Natural speaking pace',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
      _currentSession = _speakerService.startTraining(
        name: name,
        relationship: _selectedRelationship,
      );
    });
  }

  Future<void> _recordSample() async {
    if (_isRecording || _currentSession == null) return;

    if (!await _audioRecorder.hasPermission()) {
      _showSnackbar('Microphone permission denied', isError: true);
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    await _audioRecorder.start(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',
    );

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      
      if (_recordingSeconds >= _maxRecordingSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path == null) {
      _showSnackbar('Recording failed', isError: true);
      return;
    }

    // Create sample audio data
    final audioData = Uint8List(16000 * 2 * _maxRecordingSeconds);
    
    final success = await _currentSession!.addSample(audioData);
    
    if (success) {
      _showSnackbar('Sample ${_currentSession!.samplesCollected} recorded! ✓');
      
      if (_currentSession!.isComplete) {
        _showSnackbar('Voice profile saved! 🎉');
        setState(() {
          _currentSession = null;
          _nameController.clear();
        });
      }
    } else {
      _showSnackbar('No voice detected - try again', isError: true);
    }
  }

  void _cancelTraining() {
    _currentSession?.cancel();
    setState(() => _currentSession = null);
  }

  Future<void> _toggleProfile(VoiceProfile profile) async {
    final updated = profile.copyWith(isActive: !profile.isActive);
    await _speakerService.updateVoiceProfile(updated);
    setState(() {});
  }

  Future<void> _deleteProfile(VoiceProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2136),
        title: const Text('Delete Profile?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${profile.name}"\'s voice profile?',
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
      await _speakerService.deleteVoiceProfile(profile.id);
      setState(() {});
      _showSnackbar('Profile deleted');
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