import 'package:url_launcher/url_launcher.dart';
import 'sos_service.dart';
import 'location_service.dart';

/// SMS Service for sending emergency alerts
class SMSService {
  // Singleton
  static SMSService? _instance;
  static SMSService get instance {
    _instance ??= SMSService._();
    return _instance!;
  }
  SMSService._();

  final LocationService _locationService = LocationService.instance;

  /// Send SOS SMS to all emergency contacts
  Future<SOSResult> sendSOSToContacts(List<String> detectedSounds) async {
    final sosService = SOSService.instance;
    final contacts = sosService.emergencyContacts;

    if (contacts.isEmpty) {
      return SOSResult(
        success: false,
        contactsNotified: 0,
        message: 'No emergency contacts configured',
      );
    }

    // Get location
    final location = await _locationService.getReadableLocation();
    
    // Generate message
    final message = sosService.generateEmergencyMessage(detectedSounds, location);

    int successCount = 0;
    List<String> failedContacts = [];

    // Send SMS to each contact
    for (final contact in contacts) {
      final success = await _sendSMS(contact.phoneNumber, message);
      if (success) {
        successCount++;
        print('✅ SMS sent to ${contact.name}');
      } else {
        failedContacts.add(contact.name);
        print('❌ Failed to send SMS to ${contact.name}');
      }
    }

    return SOSResult(
      success: successCount > 0,
      contactsNotified: successCount,
      message: successCount == contacts.length
          ? 'All contacts notified'
          : 'Sent to $successCount/${contacts.length} contacts',
      failedContacts: failedContacts,
    );
  }

  /// Send SMS using URL launcher (opens SMS app with pre-filled message)
  Future<bool> _sendSMS(String phoneNumber, String message) async {
    try {
      // Clean phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Encode message for URL
      final encodedMessage = Uri.encodeComponent(message);
      
      // Create SMS URI
      final smsUri = Uri.parse('sms:$cleanNumber?body=$encodedMessage');
      
      // Launch SMS app
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        print('❌ Cannot launch SMS for $phoneNumber');
        return false;
      }
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  /// Send SMS to multiple numbers at once (if supported)
  Future<bool> sendBulkSMS(List<String> phoneNumbers, String message) async {
    try {
      // Join numbers with comma (some devices support this)
      final numbers = phoneNumbers.map((p) => p.replaceAll(RegExp(r'[^\d+]'), '')).join(',');
      final encodedMessage = Uri.encodeComponent(message);
      
      final smsUri = Uri.parse('sms:$numbers?body=$encodedMessage');
      
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      }
      
      // Fallback: send to first number if bulk not supported
      if (phoneNumbers.isNotEmpty) {
        return await _sendSMS(phoneNumbers.first, message);
      }
      
      return false;
    } catch (e) {
      print('❌ Error sending bulk SMS: $e');
      return false;
    }
  }

  /// Make emergency call
  Future<bool> makeEmergencyCall(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      final phoneUri = Uri.parse('tel:$cleanNumber');
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error making call: $e');
      return false;
    }
  }

  /// Call emergency services (911, 112, etc.)
  Future<bool> callEmergencyServices() async {
    // Try common emergency numbers
    final emergencyNumbers = ['911', '112', '100', '101', '102'];
    
    for (final number in emergencyNumbers) {
      final phoneUri = Uri.parse('tel:$number');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        return true;
      }
    }
    
    return false;
  }
}


/// Result of SOS operation
class SOSResult {
  final bool success;
  final int contactsNotified;
  final String message;
  final List<String> failedContacts;

  SOSResult({
    required this.success,
    required this.contactsNotified,
    required this.message,
    this.failedContacts = const [],
  });
}
