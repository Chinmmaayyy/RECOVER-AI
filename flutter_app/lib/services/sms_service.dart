// TWILIO SETUP INSTRUCTIONS:
// 1. Go to twilio.com → sign up free
// 2. Get a free trial phone number
// 3. Copy Account SID, Auth Token, and your Twilio number
// 4. Paste them into the constants below
// 5. Verify your personal phone number in Twilio console
//    (free trial only sends to verified numbers)

import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  // Replace these with your real Twilio credentials
  static const accountSid = 'YOUR_TWILIO_ACCOUNT_SID';
  static const authToken = 'YOUR_TWILIO_AUTH_TOKEN';
  static const twilioNumber = 'YOUR_TWILIO_NUMBER';
  static const demoCaregiverPhone = '+91YOUR_TEST_PHONE';

  /// Send a RED alert SMS via Twilio API.
  /// Falls back to device SMS (url_launcher) if Twilio fails.
  static Future<void> sendRedAlert({
    required String patientName,
    required String caregiverPhone,
    required String reason,
  }) async {
    final message =
        'URGENT: $patientName has flagged a critical symptom: $reason. Please check in immediately.';

    try {
      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
      );

      final credentials = base64Encode(utf8.encode('$accountSid:$authToken'));

      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.set('Authorization', 'Basic $credentials');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

      final body = Uri(queryParameters: {
        'To': caregiverPhone,
        'From': twilioNumber,
        'Body': message,
      }).query;

      request.write(body);
      final response = await request.close();
      client.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return; // Twilio sent successfully
      }

      // Twilio failed — fall through to SMS fallback
      await _fallbackSms(caregiverPhone, patientName);
    } catch (_) {
      // Network error or Twilio misconfigured — fall back to device SMS
      await _fallbackSms(caregiverPhone, patientName);
    }
  }

  /// Opens the device SMS app as a fallback when Twilio is unavailable
  static Future<void> _fallbackSms(String phone, String patientName) async {
    final fallbackMessage = 'URGENT: $patientName needs your attention now.';
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': fallbackMessage},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
