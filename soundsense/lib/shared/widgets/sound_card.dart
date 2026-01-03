import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SoundCard extends StatelessWidget {
  final String soundName;
  final String priority;
  final double confidence;
  final VoidCallback onTap;

  const SoundCard({
    super.key,
    required this.soundName,
    required this.priority,
    required this.confidence,
    required this.onTap,
  });

  Color _getPriorityColor() {
    switch (priority) {
      case 'critical':
        return AppTheme.soundCritical;
      case 'important':
        return AppTheme.soundImportant;
      default:
        return AppTheme.soundNormal;
    }
  }

  IconData _getSoundIcon() {
    final name = soundName.toLowerCase();
    if (name.contains('car') || name.contains('horn')) return Icons.directions_car_rounded;
    if (name.contains('siren') || name.contains('alarm')) return Icons.emergency_rounded;
    if (name.contains('dog') || name.contains('cat') || name.contains('bird')) return Icons.pets_rounded;
    if (name.contains('doorbell') || name.contains('knock')) return Icons.doorbell_rounded;
    if (name.contains('baby') || name.contains('cry')) return Icons.child_care_rounded;
    if (name.contains('phone') || name.contains('ring')) return Icons.phone_android_rounded;
    if (name.contains('music') || name.contains('singing')) return Icons.music_note_rounded;
    if (name.contains('speech') || name.contains('talk')) return Icons.record_voice_over_rounded;
    if (name.contains('fire')) return Icons.local_fire_department_rounded;
    if (name.contains('water')) return Icons.water_drop_rounded;
    return Icons.hearing_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(_getSoundIcon(), color: color, size: 26),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soundName,
                    style: AppTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: AppTheme.bodySmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(confidence * 100).toInt()}%',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
