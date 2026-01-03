import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/azure_speaker_service.dart';

/// Voice Training Screen for Azure Speaker Recognition
class AzureVoiceTrainingScreen extends StatefulWidget {
  const AzureVoiceTrainingScreen({super.key});

  @override
  State<AzureVoiceTrainingScreen> createState() =>
      _AzureVoiceTrainingScreenState();
}

class _AzureVoiceTrainingScreenState extends State<AzureVoiceTrainingScreen>
    with TickerProviderStateMixin {
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
  static const int _targetSeconds = 25;

  late AnimationController _pulseController;

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
    {'name': 'Doctor', 'emoji': '👨‍⚕️'},
    {'name': 'Other', 'emoji': '👤'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Voice Profiles', style: AppTheme.headlineMedium),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_currentProfileId == null) ...[
              _buildNameInput(),
              const SizedBox(height: 20),
              _buildRelationshipSelector(),
              const SizedBox(height: 24),
              _buildCreateProfileButton(),
            ] else
              _buildRecordingSection(),
            const SizedBox(height: 32),
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
          colors: [
            AppTheme.primary.withOpacity(0.2),
            AppTheme.accent.withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: AppTheme.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Azure Voice Recognition', style: AppTheme.headlineSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.verified,
                        color: AppTheme.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Microsoft AI • 95%+ Accuracy',
                      style:
                          AppTheme.bodySmall.copyWith(color: AppTheme.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Person\'s Name', style: AppTheme.labelLarge),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'e.g., Mom, Dad, John',
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.person_rounded,
                color: AppTheme.textTertiary),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildRelationshipSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Relationship', style: AppTheme.labelLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _relationships.map((rel) {
            final isSelected = _selectedRelationship == rel['name'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedRelationship = rel['name']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.borderMedium,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rel['emoji']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      rel['name']!,
                      style: AppTheme.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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
          height: 56,
          child: ElevatedButton(
            onPressed: canCreate && !_isProcessing ? _createProfile : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              disabledBackgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text('Create Voice Profile', style: AppTheme.buttonText),
          ),
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusMessage.contains('Error')
                  ? AppTheme.error.withOpacity(0.1)
                  : AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: _statusMessage.contains('Error')
                    ? AppTheme.error.withOpacity(0.3)
                    : AppTheme.success.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _statusMessage.contains('Error')
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  color: _statusMessage.contains('Error')
                      ? AppTheme.error
                      : AppTheme.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppTheme.bodySmall.copyWith(
                      color: _statusMessage.contains('Error')
                          ? AppTheme.error
                          : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Text(
                _relationships.firstWhere(
                    (r) => r['name'] == _selectedRelationship)['emoji']!,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Training', style: AppTheme.bodySmall),
                    Text(_nameController.text, style: AppTheme.headlineSmall),
                  ],
                ),
              ),
              if (_isEnrolled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.success, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Enrolled',
                        style: AppTheme.labelMedium
                            .copyWith(color: AppTheme.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress', style: AppTheme.labelMedium),
                  Text(
                    '${(_enrollmentProgress * 100).toInt()}%',
                    style: AppTheme.labelMedium.copyWith(
                      color: _isEnrolled ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _enrollmentProgress,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(
                    _isEnrolled ? AppTheme.success : AppTheme.primary,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),

          if (_isRecording) ...[
            const SizedBox(height: 24),
            Text(
              '$_recordingSeconds',
              style: AppTheme.displayLarge.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'seconds recorded of $_targetSeconds',
              style: AppTheme.bodySmall,
            ),
          ],

          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.info.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: AppTheme.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEnrolled
                        ? 'Voice profile saved! This person can now be identified during live captions.'
                        : 'Ask ${_nameController.text} to speak naturally for $_targetSeconds seconds in a quiet environment.',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.info),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Record Button
          if (!_isEnrolled)
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _isRecording
                      ? 1.0 + (_pulseController.value * 0.08)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _isRecording
                            ? AppTheme.dangerGradient
                            : AppTheme.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? AppTheme.error
                                    : AppTheme.primary)
                                .withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_isEnrolled) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentProfileId = null;
                    _isEnrolled = false;
                    _enrollmentProgress = 0;
                    _nameController.clear();
                    _statusMessage = '';
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Another Person'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          if (!_isEnrolled) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _cancelTraining,
              child: Text(
                'Cancel',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.error),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildExistingProfiles() {
    final profiles = _speakerService.profiles;
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saved Profiles', style: AppTheme.headlineSmall),
        const SizedBox(height: 16),
        ...profiles.asMap().entries.map((entry) {
          final index = entry.key;
          final profile = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(color: AppTheme.borderMedium),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(profile.emoji ?? '👤',
                        style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.personName, style: AppTheme.labelLarge),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: profile.isEnrolled
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.isEnrolled ? 'Ready' : 'Pending',
                            style: AppTheme.bodySmall.copyWith(
                              color: profile.isEnrolled
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteProfile(profile.profileId),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.error,
                ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: index * 100)).fadeIn().slideX(
              begin: 0.1);
        }),
      ],
    );
  }

  // ============================================================
  // Actions
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
        _statusMessage = 'Error: Failed to create profile. Check API key.';
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
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/voice_$timestamp.wav';

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
      setState(() => _isRecording = false);
      _showSnackbar('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path == null || _currentProfileId == null) {
      _showSnackbar('Recording failed');
      return;
    }

    setState(() {
      _statusMessage = 'Enrolling voice...';
      _isProcessing = true;
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
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
          _statusMessage = 'Voice enrolled successfully!';
          _showSnackbar('Voice profile saved! 🎉');
        } else if (result.success) {
          _statusMessage = 'Need ${result.remainingSeconds.round()}s more audio';
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
        backgroundColor: AppTheme.backgroundSecondary,
        title: Text('Delete Profile?', style: AppTheme.headlineSmall),
        content:
            Text('This cannot be undone.', style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.error)),
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
      SnackBar(
        content: Text(message, style: AppTheme.bodyMedium),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.backgroundTertiary,
      ),
    );
  }
}
