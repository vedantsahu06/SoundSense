import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import '../../core/services/azure_speaker_service.dart';
import 'package:path_provider/path_provider.dart';

/// Real Azure Voice Training Screen
class AzureVoiceTrainingScreen extends StatefulWidget {
  const AzureVoiceTrainingScreen({super.key});

  @override
  State<AzureVoiceTrainingScreen> createState() => _AzureVoiceTrainingScreenState();
}

class _AzureVoiceTrainingScreenState extends State<AzureVoiceTrainingScreen> {
  final AzureSpeakerService _speakerService = AzureSpeakerService.instance;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final _nameController = TextEditingController();

  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _currentProfileId;
  String _statusMessage = '';
  double _enrollmentProgress = 0;
  bool _isEnrolled = false;

  // Recording
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _targetSeconds = 25; // Azure needs 20+ seconds

  // Relationships
  String _selectedRelationship = 'Friend';
  final List<Map<String, String>> _relationships = [
    {'name': 'Mom', 'emoji': '👩'},
    {'name': 'Dad', 'emoji': '👨'},
    {'name': 'Sister', 'emoji': '👧'},
    {'name': 'Brother', 'emoji': '👦'},
    {'name': 'Spouse', 'emoji': '💑'},
    {'name': 'Child', 'emoji': '👶'},
    {'name': 'Friend', 'emoji': '🧑‍🤝‍🧑'},
    {'name': 'Colleague', 'emoji': '💼'},
  ];

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
          'Train Voice (Azure AI)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildNameInput(),
            const SizedBox(height: 20),
            _buildRelationshipSelector(),
            const SizedBox(height: 24),
            if (_currentProfileId == null)
              _buildCreateProfileButton()
            else
              _buildRecordingSection(),
            const SizedBox(height: 24),
            _buildExistingProfiles(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.3), Colors.purple.withOpacity(0.3)],
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
            child: const Icon(Icons.record_voice_over, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Azure Speaker Recognition',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Microsoft AI • 95%+ Accuracy',
                  style: TextStyle(
                    color: Colors.greenAccent.withOpacity(0.9),
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

  Widget _buildRelationshipSelector() {
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
          children: _relationships.map((rel) {
            final isSelected = _selectedRelationship == rel['name'];
            return GestureDetector(
              onTap: () => setState(() => _selectedRelationship = rel['name']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rel['emoji']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      rel['name']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
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

  Widget _buildCreateProfileButton() {
    final canCreate = _nameController.text.trim().isNotEmpty;
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canCreate && !_isProcessing ? _createProfile : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Create Voice Profile',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: TextStyle(
              color: _statusMessage.contains('Error') ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingSection() {
    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Training: ${_nameController.text}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              LinearProgressIndicator(
                value: _enrollmentProgress,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isEnrolled ? Colors.greenAccent : Colors.blue,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              
              Text(
                _isEnrolled
                    ? '✅ Voice Enrolled Successfully!'
                    : 'Record ${_targetSeconds} seconds of speech',
                style: TextStyle(
                  color: _isEnrolled ? Colors.greenAccent : Colors.white70,
                ),
              ),
              
              if (_isRecording) ...[
                const SizedBox(height: 16),
                Text(
                  '$_recordingSeconds / $_targetSeconds sec',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.tips_and_updates, color: Colors.blue, size: 24),
              const SizedBox(height: 8),
              Text(
                _isEnrolled
                    ? 'Voice profile is ready! You can now identify this person.'
                    : 'Ask ${_nameController.text} to speak naturally for $_targetSeconds seconds.\n\nTips:\n• Normal speaking volume\n• Quiet environment\n• Natural conversation',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Record button
        if (!_isEnrolled)
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [Colors.red, Colors.redAccent]
                      : [Colors.blue, Colors.blueAccent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ).animate(target: _isRecording ? 1 : 0)
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          ),
        
        if (_isEnrolled) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentProfileId = null;
                _isEnrolled = false;
                _enrollmentProgress = 0;
                _nameController.clear();
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add Another Person'),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Cancel button
        if (!_isEnrolled)
          TextButton(
            onPressed: _cancelTraining,
            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
      ],
    );
  }

  Widget _buildExistingProfiles() {
    final profiles = _speakerService.profiles;
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enrolled Voices',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...profiles.map((profile) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text(profile.emoji ?? '👤', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.personName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      profile.isEnrolled ? '✅ Enrolled' : '⏳ Pending',
                      style: TextStyle(
                        color: profile.isEnrolled ? Colors.greenAccent : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => _deleteProfile(profile.profileId),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _createProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Creating profile...';
    });

    final profileId = await _speakerService.createVoiceProfile(name);

    setState(() {
      _isProcessing = false;
      if (profileId != null) {
        _currentProfileId = profileId;
        _statusMessage = 'Profile created! Now record voice.';
      } else {
        _statusMessage = 'Error: Failed to create profile';
      }
    });
  }
Future<void> _startRecording() async {
  if (_isRecording || _currentProfileId == null) return;

  if (!await _audioRecorder.hasPermission()) {
    _showSnackbar('Microphone permission denied');
    return;
  }

  try {
    // Get proper temp directory using path_provider
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${tempDir.path}/voice_$timestamp.wav';
    
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
      setState(() {
        _recordingSeconds++;
        _enrollmentProgress = _recordingSeconds / _targetSeconds;
      });

      if (_recordingSeconds >= _targetSeconds) {
        _stopRecording();
      }
    });
  } catch (e) {
    print('❌ Recording error: $e');
    setState(() => _isRecording = false);
    _showSnackbar('Failed to start recording: $e');
  }
}

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path == null || _currentProfileId == null) {
      print('❌ Path is null or no profile ID');
      _showSnackbar('Recording failed');
      return;
    }

    setState(() {
      _statusMessage = 'Enrolling voice with Azure...';
      _isProcessing = true;
    });

    try {
      final file = File(path);
      final exists = await file.exists();
    print('📁 File exists: $exists');

    if (!exists) {
      print('❌ File does not exist!');
      _showSnackbar('Recording file not found');
      return;
    }
      final audioData = await file.readAsBytes();

      final result = await _speakerService.enrollVoiceProfile(
        _currentProfileId!,
        audioData,
      );

      setState(() {
        _isProcessing = false;
        if (result.isEnrolled) {
          _isEnrolled = true;
          _enrollmentProgress = 1.0;
          _statusMessage = '✅ Voice enrolled successfully!';
          _showSnackbar('Voice profile saved! 🎉');
        } else if (result.success) {
          _statusMessage = 'Need ${result.remainingSeconds.round()}s more audio';
          _showSnackbar('Record more audio');
        } else {
          _statusMessage = 'Error: ${result.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _cancelTraining() async {
    if (_currentProfileId != null) {
      await _speakerService.deleteVoiceProfile(_currentProfileId!);
    }
    setState(() {
      _currentProfileId = null;
      _isEnrolled = false;
      _enrollmentProgress = 0;
      _statusMessage = '';
    });
  }

  Future<void> _deleteProfile(String profileId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2136),
        title: const Text('Delete Profile?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white70)),
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
      await _speakerService.deleteVoiceProfile(profileId);
      setState(() {});
      _showSnackbar('Profile deleted');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}