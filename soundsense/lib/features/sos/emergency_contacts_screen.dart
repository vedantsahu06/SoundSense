import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/sos_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/sms_service.dart';
import 'sos_countdown_screen.dart';

/// Emergency Contacts Management Screen
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SOSService _sosService = SOSService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _sosService.initialize();
    await LocationService.instance.initialize();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundPrimary,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final contacts = _sosService.emergencyContacts;

    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Emergency SOS', style: AppTheme.headlineMedium),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSOSCard(),
            const SizedBox(height: 24),
            _buildContactsHeader(contacts.length),
            const SizedBox(height: 16),
            if (contacts.isEmpty)
              _buildEmptyState()
            else
              ...contacts.asMap().entries.map((entry) =>
                  _buildContactCard(entry.value, entry.key)),
            const SizedBox(height: 24),
            _buildInfoCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _buildSOSCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.dangerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.error.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emergency_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            'Emergency SOS',
            style: AppTheme.headlineLarge.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Press the button below to send an emergency alert to all your contacts with your location.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _triggerManualSOS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  icon: const Icon(Icons.sos_rounded),
                  label: Text('SEND SOS NOW',
                      style: AppTheme.buttonText
                          .copyWith(color: AppTheme.error)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _testSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
                child: const Icon(Icons.science_rounded),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildContactsHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Emergency Contacts', style: AppTheme.headlineSmall),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Text(
            '$count / 5',
            style: AppTheme.labelMedium.copyWith(
              color: count >= 5 ? AppTheme.warning : AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.borderMedium),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_off_rounded,
                color: AppTheme.warning, size: 48),
          ),
          const SizedBox(height: 20),
          Text('No Contacts Added', style: AppTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Add emergency contacts to enable SOS alerts. They will receive your location when you trigger an emergency.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact, int index) {
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
              child: Text(
                _getEmoji(contact.relationship),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: AppTheme.labelLarge),
                const SizedBox(height: 2),
                Text(contact.phoneNumber, style: AppTheme.bodySmall),
                Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundTertiary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        contact.relationship,
                        style:
                            AppTheme.bodySmall.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteContact(contact),
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppTheme.error,
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 100)).fadeIn().slideX(
        begin: 0.1);
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.info, size: 20),
              const SizedBox(width: 10),
              Text('How SOS Works',
                  style: AppTheme.labelLarge.copyWith(color: AppTheme.info)),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('🔊', 'Automatic trigger on critical sounds (siren, alarm)'),
          _buildInfoItem('📍', 'Sends your GPS location'),
          _buildInfoItem('📱', 'SMS sent to all emergency contacts'),
          _buildInfoItem('⏱️', '10 second countdown to cancel'),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String _getEmoji(String relationship) {
    final emojis = {
      'Mom': '👩',
      'Dad': '👨',
      'Sister': '👧',
      'Brother': '👦',
      'Spouse': '💑',
      'Child': '👶',
      'Friend': '🧑‍🤝‍🧑',
      'Colleague': '💼',
      'Doctor': '👨‍⚕️',
      'Neighbor': '🏠',
    };
    return emojis[relationship] ?? '👤';
  }

  void _triggerManualSOS() {
    final contacts = _sosService.emergencyContacts;
    if (contacts.isEmpty) {
      _showSnackbar('Please add emergency contacts first', isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SOSCountdownScreen(
          detectedSounds: ['Manual SOS Trigger'],
          location: 'Getting location...',
          onCancel: () => Navigator.pop(context),
          onSendSOS: () async {
            await SMSService.instance.sendSOSToContacts(['Manual SOS']);
            if (mounted) {
              Navigator.pop(context);
              _showSnackbar('SOS sent to ${contacts.length} contacts!');
            }
          },
        ),
      ),
    );
  }

  void _testSOS() async {
    final contacts = _sosService.emergencyContacts;
    if (contacts.isEmpty) {
      _showSnackbar('Please add emergency contacts first', isError: true);
      return;
    }

    // Get location for test
    final locationString = await LocationService.instance.getLocationString();
    final message = _sosService.generateEmergencyMessage(['Test Alert'], locationString);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        title: Row(
          children: [
            const Icon(Icons.science_rounded, color: AppTheme.info),
            const SizedBox(width: 10),
            Text('Test SOS', style: AppTheme.headlineSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This is a test. The following message would be sent:',
                style: AppTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundTertiary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Text(message, style: AppTheme.bodySmall),
            ),
            const SizedBox(height: 12),
            Text(
              'Recipients: ${contacts.map((c) => c.name).join(", ")}',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRelationship = 'Friend';

    final relationships = [
      'Mom', 'Dad', 'Sister', 'Brother', 'Spouse',
      'Child', 'Friend', 'Colleague', 'Doctor', 'Neighbor'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add Emergency Contact', style: AppTheme.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: AppTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: AppTheme.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Text('Relationship', style: AppTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: relationships.map((rel) {
                  final isSelected = selectedRelationship == rel;
                  return GestureDetector(
                    onTap: () =>
                        setModalState(() => selectedRelationship = rel),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.backgroundTertiary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXL),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.borderMedium,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getEmoji(rel),
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            rel,
                            style: AppTheme.labelMedium.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty || phone.isEmpty) {
                      _showSnackbar('Please fill all fields', isError: true);
                      return;
                    }

                    await _sosService.addContact(
                      EmergencyContact(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        phoneNumber: phone,
                        relationship: selectedRelationship,
                      ),
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      _showSnackbar('Contact added!');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Contact'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteContact(EmergencyContact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        title: Text('Remove Contact?', style: AppTheme.headlineSmall),
        content: Text('Remove ${contact.name} from emergency contacts?',
            style: AppTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove',
                style: AppTheme.labelMedium.copyWith(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sosService.removeContact(contact.id);
      setState(() {});
      _showSnackbar('Contact removed');
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.bodyMedium),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
