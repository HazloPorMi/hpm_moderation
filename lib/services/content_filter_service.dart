/// Basic profanity/offensive content filter for chat messages.
///
/// Checks against a keyword list in both English and Spanish.
/// Returns true if content is flagged as potentially offensive.
/// This is a first-pass filter — not a replacement for user reporting.
class ContentFilterService {
  ContentFilterService._();
  static final ContentFilterService instance = ContentFilterService._();

  // Basic offensive keywords (English + Spanish)
  // Kept minimal and focused on clearly offensive terms
  static const List<String> _offensiveKeywords = [
    // English
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'damn',
    'nigger', 'faggot', 'retard',
    'kill yourself', 'kys',
    // Spanish
    'puta', 'mierda', 'cabron', 'pendejo', 'verga',
    'marica', 'joto', 'zorra', 'culero', 'chingar',
    'hijo de puta', 'malparido',
    // Scam/fraud indicators
    'send money', 'wire transfer', 'western union',
    'envia dinero', 'transferencia',
  ];

  /// Check if a message contains offensive content.
  /// Returns the matched keyword if found, null if clean.
  String? checkMessage(String message) {
    if (message.isEmpty) return null;

    final lowered = message.toLowerCase().trim();

    for (final keyword in _offensiveKeywords) {
      if (lowered.contains(keyword)) {
        return keyword;
      }
    }

    return null;
  }

  /// Returns true if the message passes the filter (is clean).
  bool isClean(String message) => checkMessage(message) == null;

  /// Filter a message by replacing offensive words with asterisks.
  /// Returns the filtered message.
  String filterMessage(String message) {
    if (message.isEmpty) return message;

    String filtered = message;
    final lowered = message.toLowerCase();

    for (final keyword in _offensiveKeywords) {
      final index = lowered.indexOf(keyword);
      if (index != -1) {
        final replacement = '*' * keyword.length;
        filtered = filtered.replaceRange(
          index,
          index + keyword.length,
          replacement,
        );
      }
    }

    return filtered;
  }
}
