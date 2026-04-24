import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url =>
      const String.fromEnvironment('SUPABASE_URL', defaultValue: '')
          .isNotEmpty
          ? const String.fromEnvironment('SUPABASE_URL')
          : (dotenv.env['SUPABASE_URL'] ?? '');

  static String get anonKey =>
      const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '')
          .isNotEmpty
          ? const String.fromEnvironment('SUPABASE_ANON_KEY')
          : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
}
