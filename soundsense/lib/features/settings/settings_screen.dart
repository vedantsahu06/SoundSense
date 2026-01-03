import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/settings_service.dart';
import '../sos/emergency_contacts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings', style: AppTheme.displaySmall),
                    const SizedBox(height: 4),
                    Text('Customize your experience',
                        style: AppTheme.bodyMedium),
                  ],
                ),
              ),
            ),

            // Sound Alerts Section
            SliverToBoxAdapter(child: _buildSectionHeader('Sound Alerts')),
            SliverToBoxAdapter(
              child: _buildSettingsCard([
                _buildSwitchTile(
                  title: 'Critical Sounds',
                  subtitle: 'Sirens, car horns, alarms',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.soundCritical,
                  value: _settings.criticalAlerts,
                  onChanged: (value) async {
                    await _settings.setCriticalAlerts(value);
                    setState(() {});
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: 'Important Sounds',
                  subtitle: 'Doorbell, dog bark, baby cry',
                  icon: Icons.notification_important_rounded,
                  color: AppTheme.soundImportant,
                  value: _settings.importantAlerts,
                  onChanged: (value) async {
                    await _settings.setImportantAlerts(value);
                    setState(() {});
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  title: 'Normal Sounds',
                  subtitle: 'Music, speech, background noise',
                  icon: Icons.volume_up_rounded,
                  color: AppTheme.soundNormal,
                  value: _settings.normalAlerts,
                  onChanged: (value) async {
                    await _settings.setNormalAlerts(value);
                    setState(() {});
                  },
                ),
              ]),
            ),

            // Vibration Section
            SliverToBoxAdapter(child: _buildSectionHeader('Vibration')),
            SliverToBoxAdapter(
              child: _buildSettingsCard([
                _buildSwitchTile(
                  title: 'Enable Vibration',
                  subtitle: 'Vibrate when sounds are detected',
                  icon: Icons.vibration_rounded,
                  color: AppTheme.primary,
                  value: _settings.vibrationEnabled,
                  onChanged: (value) async {
                    await _settings.setVibrationEnabled(value);
                    setState(() {});
                  },
                ),
                if (_settings.vibrationEnabled) ...[
                  _buildDivider(),
                  _buildIntensitySelector(),
                ],
              ]),
            ),

            // Sensitivity Section
            SliverToBoxAdapter(child: _buildSectionHeader('Detection')),
            SliverToBoxAdapter(
              child: _buildSettingsCard([
                _buildSensitivitySlider(),
              ]),
            ),

            // Emergency Section
            SliverToBoxAdapter(child: _buildSectionHeader('Emergency')),
            SliverToBoxAdapter(
              child: _buildSettingsCard([
                _buildNavigationTile(
                  title: 'Emergency Contacts',
                  subtitle: 'Manage SOS contacts',
                  icon: Icons.emergency_rounded,
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyContactsScreen(),
                      ),
                    );
                  },
                ),
              ]),
            ),

            // About Section
            SliverToBoxAdapter(child: _buildSectionHeader('About')),
            SliverToBoxAdapter(
              child: _buildSettingsCard([
                _buildInfoTile(
                  title: 'Version',
                  value: '1.0.0',
                  icon: Icons.info_outline_rounded,
                ),
                _buildDivider(),
                _buildInfoTile(
                  title: 'AI Model',
                  value: 'YAMNet',
                  icon: Icons.psychology_rounded,
                ),
                _buildDivider(),
                _buildInfoTile(
                  title: 'Speech Service',
                  value: 'Azure Cognitive',
                  icon: Icons.cloud_rounded,
                ),
              ]),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: AppTheme.labelLarge.copyWith(color: AppTheme.textTertiary),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.borderMedium,
      indent: 60,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.backgroundTertiary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: AppTheme.labelLarge),
          ),
          Text(value, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildIntensitySelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(Icons.speed_rounded,
                    color: AppTheme.textSecondary, size: 22),
              ),
              const SizedBox(width: 14),
              Text('Intensity', style: AppTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['Low', 'Medium', 'High'].map((intensity) {
              final isSelected = _settings.vibrationIntensity == intensity;
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    await _settings.setVibrationIntensity(intensity);
                    setState(() {});
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        right: intensity != 'High' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.backgroundTertiary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.borderMedium,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        intensity,
                        style: AppTheme.labelMedium.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivitySlider() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detection Sensitivity', style: AppTheme.labelLarge),
                    Text(
                      '${(_settings.sensitivity * 100).toInt()}%',
                      style:
                          AppTheme.bodySmall.copyWith(color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _settings.sensitivity,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              onChanged: (value) async {
                await _settings.setSensitivity(value);
                setState(() {});
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Less sensitive', style: AppTheme.bodySmall),
              Text('More sensitive', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
