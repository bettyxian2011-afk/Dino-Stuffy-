/// Runtime configuration for Strata services.
///
/// Pass your Gemini API key at build/run time (never commit it):
/// ```bash
/// flutter run --dart-define=GEMINI_API_KEY=your_key_here
/// ```
class StrataConfig {
  StrataConfig._();

  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGeminiApiKey => geminiApiKey.isNotEmpty;

  /// Fast, low-cost vision model; good for constrained fossil ID.
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.0-flash',
  );
}
