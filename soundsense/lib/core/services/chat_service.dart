import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Replace with your API key
  static const String _apiKey = 'AIzaSyA9E5q63mvxDPCVCIuaYQL3HRMudz34Knc';
  static const String _baseUrl =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';


  // Store recent sounds for context
  List<String> _recentSounds = [];

  void updateRecentSounds(List<String> sounds) {
    _recentSounds = sounds.take(5).toList();
  }

  Future<String> sendMessage(String userMessage) async {
    try {
      // Build context about recent sounds
      String soundContext = '';
      if (_recentSounds.isNotEmpty) {
        soundContext = 'Recent sounds detected nearby: ${_recentSounds.join(", ")}. ';
      }

      // System prompt for SoundSense assistant
      final systemPrompt = '''
You are SoundSense Assistant, an AI helper for deaf and hard-of-hearing users.
Your role is to:
- Help users understand sounds in their environment
- Provide safety advice about detected sounds
- Answer questions about sound-related topics
- Be supportive and helpful

$soundContext

Keep responses short and clear (2-3 sentences max).
''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$systemPrompt\n\nUser: $userMessage'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 200,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        return text;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return 'Sorry, I could not process your request. Please try again.';
      }
    } catch (e) {
      print('Chat error: $e');
      return 'Sorry, something went wrong. Please check your internet connection.';
    }
  }
}