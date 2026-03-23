import 'package:cloud_functions/cloud_functions.dart';

class AiChatException implements Exception {
  const AiChatException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) {
      return message;
    }
    return '$code: $message';
  }
}

class AiChatService {
  AiChatService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<String> sendMessage({
    required String message,
    required List<Map<String, String>> history,
    Map<String, dynamic>? patientProfile,
    Map<String, dynamic>? ecgReport,
    String? patientQuery,
  }) async {
    final HttpsCallable callable = _functions.httpsCallable(
      'aiAvatarChat',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    HttpsCallableResult<dynamic> result;
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'message': message,
        'history': history,
        'provider': 'groq',
      };
      if (patientProfile != null) {
        payload['patientProfile'] = patientProfile;
      }
      if (ecgReport != null) {
        payload['ecgReport'] = ecgReport;
      }
      if (patientQuery != null && patientQuery.trim().isNotEmpty) {
        payload['patientQuery'] = patientQuery.trim();
      }
      result = await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      final String cleanMessage =
          (error.message ?? 'AI service unavailable. Please try again.').trim();
      throw AiChatException(
        cleanMessage,
        code: error.code,
      );
    } catch (_) {
      throw const AiChatException('Network/server error while contacting AI service.');
    }

    final dynamic data = result.data;
    if (data is Map && data['reply'] is String) {
      return (data['reply'] as String).trim();
    }
    throw const AiChatException('Invalid AI response format.');
  }
}
