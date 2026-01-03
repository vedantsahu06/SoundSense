import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import '../../core/theme/app_theme.dart';
import '../../core/models/detected_sound.dart';
import '../../core/models/sound_category.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/sound_classifier.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/animation_service.dart';
import '../../core/services/custom_sound_service.dart';
import '../../core/services/sos_service.dart';
import '../../core/services/sms_service.dart';
import '../../core/services/location_service.dart';
import '../training/sound_training_screen.dart';
import '../training/azure_voice_training_screen.dart';
import '../sos/emergency_contacts_screen.dart';
import '../sos/sos_countdown_screen.dart';
import '../../shared/widgets/critical_alerts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final SoundClassifier _classifier = SoundClassifier();
  final SettingsService _settings = SettingsService();
  final SOSService _sosService = SOSService.instance;

  bool _isListening = false;
  bool _isModelLoaded = false;
  double _currentDecibel = 0;
  List<DetectedSound> _detectedSounds = [];
  List<double> _audioBuffer = [];
  DetectedSound? _currentSound;
  bool _showCriticalAlert = false;
  bool _showSOSCountdown = false;
  bool _showSOSSent = false;
  int _sosContactsNotified = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeClassifier();
    _setupAudioCallbacks();
    _initializeSOS();
  }

  Future<void> _initializeSOS() async {
    await _sosService.initialize();
    await LocationService.instance.initialize();
  }

  Future<void> _initializeClassifier() async {
    await _classifier.initialize();
    await CustomSoundService.instance.initialize();
    setState(() {
      _isModelLoaded = _classifier.isReady;
    });
  }

  void _setupAudioCallbacks() {
    _audioService.onNoiseLevel = (double decibel) {
      setState(() => _currentDecibel = decibel);
    };

    _audioService.onAudioData = (List<double> audioData) {
      _audioBuffer.addAll(audioData);
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

    // Check custom sounds first
    final customMatch =
        await CustomSoundService.instance.detectCustomSound(audioBytes);
    if (customMatch != null) {
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
      return;
    }

    final results = await _classifier.classify(samples);
    if (results.isNotEmpty) {
      for (var result in results) {
        final priority = SoundCategory.getPriority(result.label);
        if (!_settings.shouldShowSound(priority)) continue;

        if (_settings.vibrationEnabled &&
            (priority == 'critical' || priority == 'important')) {
          HapticService.vibrate(priority);
        }

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

          if (AnimationService.isCriticalAlert(result.label)) {
            _showCriticalAlert = true;
          }

          _checkForSOSTrigger();

          if (_detectedSounds.length > 10) {
            _detectedSounds = _detectedSounds.sublist(0, 10);
          }
        });
      }
    }
  }

  void _checkForSOSTrigger() {
    if (_showSOSCountdown || _showSOSSent) return;

    final recentSounds = _detectedSounds
        .where((s) => DateTime.now().difference(s.timestamp).inSeconds < 30)
        .map((s) => s.name)
        .toList();

    if (_sosService.shouldTriggerSOS(recentSounds)) {
      setState(() => _showSOSCountdown = true);
    }
  }

  Future<void> _sendSOS() async {
    final recentSounds = _detectedSounds.take(5).map((s) => s.name).toList();
    final result = await SMSService.instance.sendSOSToContacts(recentSounds);

    setState(() {
      _showSOSCountdown = false;
      _showSOSSent = true;
      _sosContactsNotified = result.contactsNotified;
    });
  }

  void _triggerManualSOS() {
    setState(() => _showSOSCountdown = true);
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
    if (lower.contains('car') ||
        lower.contains('horn') ||
        lower.contains('siren')) {
      return 'Traffic';
    } else if (lower.contains('dog') ||
        lower.contains('cat') ||
        lower.contains('bird')) {
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
    _pulseController.dispose();
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
        setState(() => _isListening = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Microphone permission denied',
                  style: AppTheme.bodyMedium),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return AppTheme.soundCritical;
      case 'important':
        return AppTheme.soundImportant;
      default:
        return AppTheme.soundNormal;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show SOS countdown screen
    if (_showSOSCountdown) {
      return SOSCountdownScreen(
        detectedSounds: _detectedSounds.take(5).map((s) => s.name).toList(),
        location: 'Getting location...',
        onCancel: () => setState(() => _showSOSCountdown = false),
        onSendSOS: _sendSOS,
      );
    }

    // Show SOS sent confirmation
    if (_showSOSSent) {
      return SOSSentScreen(
        contactsNotified: _sosContactsNotified,
        onDismiss: () => setState(() => _showSOSSent = false),
      );
    }

    // Show critical alert if needed
    if (_showCriticalAlert && _currentSound != null) {
      return CriticalSoundAlert(
        soundName: _currentSound!.name,
        confidence: _currentSound!.confidence,
        onDismiss: () => setState(() => _showCriticalAlert = false),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            SliverToBoxAdapter(
              child: _buildHeader(),
            ),

            // Sound Listening Section
            SliverToBoxAdapter(
              child: _buildListeningSection(),
            ),

            // Quick Actions
            SliverToBoxAdapter(
              child: _buildQuickActions(),
            ),

            // Current Detection Card
            if (_currentSound != null && _isListening)
              SliverToBoxAdapter(
                child: _buildCurrentSoundCard(),
              ),

            // Recent Sounds Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Sounds', style: AppTheme.headlineSmall),
                    if (_detectedSounds.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _detectedSounds.clear();
                            _currentSound = null;
                          });
                        },
                        child: Text(
                          'Clear All',
                          style: AppTheme.labelMedium
                              .copyWith(color: AppTheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Sound List
            _detectedSounds.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final sound = _detectedSounds[index];
                          return _buildSoundCard(sound, index)
                              .animate()
                              .fadeIn(
                                  delay: Duration(milliseconds: index * 50))
                              .slideX(begin: 0.1);
                        },
                        childCount: _detectedSounds.length,
                      ),
                    ),
                  ),
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
          // App Logo & Title
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(Icons.hearing, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SoundSense', style: AppTheme.headlineLarge),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isModelLoaded
                            ? AppTheme.success
                            : AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isModelLoaded ? 'AI Ready' : 'Loading AI...',
                      style: AppTheme.bodySmall.copyWith(
                        color: _isModelLoaded
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Emergency SOS Button
          _buildSOSButton(),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const EmergencyContactsScreen()),
        );
      },
      onLongPress: _triggerManualSOS,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppTheme.dangerGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: [
            BoxShadow(
              color: AppTheme.error.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emergency, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              'SOS',
              style: AppTheme.labelLarge.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: _isListening
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.borderMedium,
        ),
      ),
      child: Column(
        children: [
          // Status Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isListening ? AppTheme.success : AppTheme.textTertiary,
                  shape: BoxShape.circle,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: AppTheme.success.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isListening ? 'Listening...' : 'Tap to Start',
                style: AppTheme.headlineSmall.copyWith(
                  color: _isListening
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Decibel Display
          if (_isListening) ...[
            Text(
              '${_currentDecibel.toStringAsFixed(0)} dB',
              style: AppTheme.displayMedium.copyWith(
                color: _getDecibelColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Decibel Bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: constraints.maxWidth *
                            (_currentDecibel / 100).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getDecibelColor().withOpacity(0.7),
                              _getDecibelColor(),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Mic Button
          GestureDetector(
            onTap: _toggleListening,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = _isListening
                    ? 1.0 + (_pulseController.value * 0.08)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _isListening
                          ? AppTheme.dangerGradient
                          : AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening
                                  ? AppTheme.error
                                  : AppTheme.primary)
                              .withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getDecibelColor() {
    if (_currentDecibel > 80) return AppTheme.error;
    if (_currentDecibel > 60) return AppTheme.warning;
    return AppTheme.success;
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.music_note_rounded,
                  title: 'Train Sound',
                  subtitle: 'Custom sounds',
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SoundTrainingScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.person_add_rounded,
                  title: 'Voice Profile',
                  subtitle: 'Recognize people',
                  color: AppTheme.accentOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AzureVoiceTrainingScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSoundCard() {
    if (_currentSound == null) return const SizedBox.shrink();

    final color = _getPriorityColor(_currentSound!.priority);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getSoundIcon(_currentSound!.category),
              color: color,
              size: 30,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Now Detecting',
                  style: AppTheme.labelMedium.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentSound!.name,
                  style: AppTheme.headlineMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(_currentSound!.confidence * 100).toInt()}% confidence',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildSoundCard(DetectedSound sound, int index) {
    final color = _getPriorityColor(sound.priority);

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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(_getSoundIcon(sound.category), color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.name,
                  style: AppTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sound.priority.toUpperCase(),
                        style: AppTheme.bodySmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(sound.confidence * 100).toInt()}%',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatTime(sound.timestamp),
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _getSoundIcon(String category) {
    switch (category.toLowerCase()) {
      case 'traffic':
        return Icons.directions_car_rounded;
      case 'animal':
        return Icons.pets_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'speech':
        return Icons.record_voice_over_rounded;
      case 'home':
        return Icons.home_rounded;
      default:
        return Icons.hearing_rounded;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hearing_disabled_rounded,
              size: 48,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isListening ? 'Listening for sounds...' : 'No sounds detected',
            style: AppTheme.headlineSmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening
                ? 'Sounds will appear here when detected'
                : 'Tap the mic button to start listening',
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
