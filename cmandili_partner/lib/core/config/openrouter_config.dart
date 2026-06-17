import 'package:flutter_dotenv/flutter_dotenv.dart';

/// OpenRouter settings for the AI menu scanner.
///
/// SECURITY NOTE: the API key is read from `.env`, which ships bundled inside
/// the released APK/IPA. Treat [apiKey] as extractable by anyone with the app
/// binary — set a hard credit limit on the key at openrouter.ai and rotate it
/// before a production release. The secure alternative is keeping the key in a
/// Supabase Edge Function and calling that instead.
class OpenRouterConfig {
  static String get apiKey =>
      const String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '')
              .isNotEmpty
          ? const String.fromEnvironment('OPENROUTER_API_KEY')
          : (dotenv.env['OPENROUTER_API_KEY'] ?? '');

  /// Vision model id. Defaults to a fast, cheap model good at OCR-style tasks.
  static String get model {
    final fromEnv = dotenv.env['OPENROUTER_MODEL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return 'google/gemini-2.0-flash-001';
  }

  static const String endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  static bool get isConfigured => apiKey.isNotEmpty;
}
