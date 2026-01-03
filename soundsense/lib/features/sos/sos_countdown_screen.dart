import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/sos_service.dart';

/// Full-screen SOS countdown with cancel option
class SOSCountdownScreen extends StatefulWidget {
  final List<String> detectedSounds;
  final String location;
  final VoidCallback onCancel;
  final VoidCallback onSendSOS;

  const SOSCountdownScreen({
    super.key,
    required this.detectedSounds,
    required this.location,
    required this.onCancel,
    required this.onSendSOS,
  });

  @override
  State<SOSCountdownScreen> createState() => _SOSCountdownScreenState();
}

class _SOSCountdownScreenState extends State<SOSCountdownScreen>
    with TickerProviderStateMixin {
  late int _countdown;
  Timer? _timer;
  bool _isCancelled = false;
  bool _isSending = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _countdown = SOSService.instance.countdownSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _startCountdown();
    _vibrateUrgent();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isCancelled) {
        timer.cancel();
        return;
      }

      setState(() => _countdown--);
      HapticFeedback.heavyImpact();

      if (_countdown <= 0) {
        timer.cancel();
        _sendSOS();
      }
    });
  }

  void _vibrateUrgent() async {
    while (!_isCancelled && mounted) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      if (_isCancelled || !mounted) break;
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _cancelSOS() {
    setState(() => _isCancelled = true);
    _timer?.cancel();
    HapticFeedback.lightImpact();
    widget.onCancel();
  }

  void _sendSOS() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    widget.onSendSOS();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Warning Icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120 + (_pulseController.value * 20),
                    height: 120 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.error.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: AppTheme.error,
                      size: 64,
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'EMERGENCY SOS',
                style: AppTheme.displaySmall.copyWith(
                  color: AppTheme.error,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Countdown
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Text(
                    '$_countdown',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                      color: Color.lerp(
                        Colors.white,
                        AppTheme.error,
                        _pulseController.value,
                      ),
                    ),
                  );
                },
              ),

              Text(
                'seconds until SOS is sent',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 40),

              // Detected Sounds
              if (widget.detectedSounds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hearing_rounded,
                              color: AppTheme.error, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Detected Sounds',
                            style: AppTheme.labelLarge
                                .copyWith(color: AppTheme.error),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.detectedSounds.join(' • '),
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

              const Spacer(),

              // Cancel Button
              GestureDetector(
                onTap: _cancelSOS,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(color: AppTheme.borderLight, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.close_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'TAP TO CANCEL',
                        style: AppTheme.labelLarge.copyWith(
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        "I'm okay, cancel the alert",
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// SOS Sent Confirmation Screen
class SOSSentScreen extends StatelessWidget {
  final int contactsNotified;
  final VoidCallback onDismiss;

  const SOSSentScreen({
    super.key,
    required this.contactsNotified,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.success,
                  size: 64,
                ),
              ).animate().scale(begin: const Offset(0.5, 0.5)),

              const SizedBox(height: 32),

              Text(
                'SOS SENT',
                style: AppTheme.displaySmall.copyWith(
                  color: AppTheme.success,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 16),

              Text(
                '$contactsNotified contact${contactsNotified != 1 ? 's' : ''} notified',
                style: AppTheme.headlineSmall,
              ).animate().fadeIn(delay: 500.ms),

              const SizedBox(height: 12),

              Text(
                'Your emergency contacts have been sent your location. Help is on the way.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium,
              ).animate().fadeIn(delay: 700.ms),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('I AM SAFE'),
                ),
              ).animate().fadeIn(delay: 900.ms),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: () {
                  // Could add call emergency services
                },
                icon: const Icon(Icons.phone_rounded, color: AppTheme.error),
                label: Text(
                  'Call Emergency Services (112)',
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.error),
                ),
              ).animate().fadeIn(delay: 1100.ms),
            ],
          ),
        ),
      ),
    );
  }
}
