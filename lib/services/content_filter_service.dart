import 'content_filter_terms.dart';

/// Basic profanity/offensive content filter for chat messages.
///
/// Checks against keyword lists in both English and Spanish (see
/// `content_filter_terms.dart`). Matching is on whole words after
/// normalization (case, accents, common symbol/digit substitutions), so
/// ordinary words that merely contain a blocked substring ("computadora",
/// "reputación", "retardo") are not flagged. Deliberate obfuscation is still
/// caught: single letters split by spaces or punctuation ("p u t a",
/// "p.u.t.a"), symbol/digit substitution ("put@", "mi3rda") and stretched
/// letters ("putaaaa").
///
/// This is a first-pass filter — not a replacement for user reporting.
class ContentFilterService {
  ContentFilterService._();
  static final ContentFilterService instance = ContentFilterService._();

  static final Set<String> _words = {
    ...offensiveWords,
    ...offPlatformPaymentWords,
  };

  static final List<List<String>> _phrases = [
    for (final phrase in [...offensivePhrases, ...offPlatformPaymentPhrases])
      phrase.split(' '),
  ];

  /// Words keyed by their form with repeated letters collapsed, to catch
  /// stretched spellings such as "putaaaa" or "mierdaaa".
  static final Map<String, String> _collapsedWords = {
    for (final word in _words) _collapseRepeats(word): word,
  };

  /// No blocked word is longer than this, so a spelled-out run never needs
  /// to be joined beyond it (keeps long runs of single letters linear).
  static final int _maxWordLength =
      _words.fold(0, (max, word) => word.length > max ? word.length : max);

  static final RegExp _stretchedLetter = RegExp(r'([a-z])\1\1');
  static final RegExp _repeatedLetters = RegExp(r'([a-z])\1+');

  /// Check if a message contains offensive content.
  /// Returns the matched keyword if found, null if clean.
  String? checkMessage(String message) {
    final matches = _matchesIn(message);
    return matches.isEmpty ? null : matches.first.keyword;
  }

  /// Returns true if the message passes the filter (is clean).
  bool isClean(String message) => checkMessage(message) == null;

  /// Filter a message by replacing offensive words with asterisks.
  /// Every occurrence is masked; the rest of the message is unchanged.
  String filterMessage(String message) {
    final matches = _matchesIn(message);
    if (matches.isEmpty) return message;

    final chars = message.split('');
    for (final match in matches) {
      for (var i = match.start; i < match.end; i++) {
        chars[i] = '*';
      }
    }
    return chars.join();
  }

  /// Matches from two readings of [message], ordered by position:
  /// - symbols/digits folded into letters, which catches "put@" and "mi3rda";
  /// - symbols/digits as separators, which catches an insult glued to one
  ///   ("puta1", "@puta").
  static List<_Match> _matchesIn(String message) {
    if (message.isEmpty) return const [];
    return [
      ..._findMatches(_tokenize(message, foldSymbols: true)),
      ..._findMatches(_tokenize(message, foldSymbols: false)),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<_Match> _findMatches(List<_Token> tokens) {
    final matches = <_Match>[];
    var i = 0;
    while (i < tokens.length) {
      final match = _matchAt(tokens, i);
      if (match == null) {
        i++;
        continue;
      }
      matches.add(match.match);
      i += match.length;
    }
    return matches;
  }

  /// Tries a phrase, then a single word, then a run of spelled-out single
  /// letters starting at [index].
  static ({_Match match, int length})? _matchAt(
      List<_Token> tokens, int index) {
    for (final phrase in _phrases) {
      if (_phraseMatches(tokens, index, phrase)) {
        final last = tokens[index + phrase.length - 1];
        return (
          match: _Match(phrase.join(' '), tokens[index].start, last.end),
          length: phrase.length,
        );
      }
    }

    final token = tokens[index];
    final word = _wordFor(token.text);
    if (word != null) {
      return (match: _Match(word, token.start, token.end), length: 1);
    }

    return _spelledOutAt(tokens, index);
  }

  static bool _phraseMatches(
    List<_Token> tokens,
    int index,
    List<String> phrase,
  ) {
    if (index + phrase.length > tokens.length) return false;
    for (var j = 0; j < phrase.length; j++) {
      if (tokens[index + j].text != phrase[j]) return false;
    }
    return true;
  }

  static String? _wordFor(String text) {
    if (_words.contains(text)) return text;
    if (!_hasStretchedLetter(text)) return null;
    return _collapsedWords[_collapseRepeats(text)];
  }

  /// "p u t a" / "p.u.t.a": the longest run of single-letter tokens starting
  /// at [index] that spells a blocked word.
  static ({_Match match, int length})? _spelledOutAt(
    List<_Token> tokens,
    int index,
  ) {
    var end = index;
    while (end < tokens.length &&
        end - index < _maxWordLength &&
        tokens[end].text.length == 1) {
      end++;
    }
    for (var last = end - 1; last > index; last--) {
      final spelled = tokens.sublist(index, last + 1).map((t) => t.text).join();
      final word = _wordFor(spelled);
      if (word != null) {
        return (
          match: _Match(word, tokens[index].start, tokens[last].end),
          length: last - index + 1,
        );
      }
    }
    return null;
  }

  /// Splits [message] into normalized lowercase ASCII words, keeping each
  /// word's start/end offsets in the original string.
  static List<_Token> _tokenize(String message, {required bool foldSymbols}) {
    final tokens = <_Token>[];
    final buffer = StringBuffer();
    var start = -1;

    void flush(int end) {
      if (buffer.isNotEmpty) tokens.add(_Token(buffer.toString(), start, end));
      buffer.clear();
      start = -1;
    }

    for (var i = 0; i < message.length; i++) {
      final unit = message.codeUnitAt(i);
      if (_isCombiningMark(unit) && start != -1) continue;
      final letter = _normalizeChar(message[i], foldSymbols: foldSymbols);
      if (letter == null) {
        flush(i);
        continue;
      }
      if (start == -1) start = i;
      buffer.write(letter);
    }
    flush(message.length);
    return tokens;
  }

  /// Maps one character to a lowercase ASCII letter, or null for a separator.
  static String? _normalizeChar(String char, {required bool foldSymbols}) {
    final lower = char.toLowerCase();
    final code = lower.codeUnitAt(0);
    if (lower.length == 1 && code >= 0x61 && code <= 0x7a) return lower;
    return _accentFolds[lower] ?? (foldSymbols ? _symbolFolds[lower] : null);
  }

  /// Accents / diacritics.
  static const Map<String, String> _accentFolds = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Deliberate symbol/digit substitutions ("put@", "mi3rda", "$hit").
  static const Map<String, String> _symbolFolds = {
    '@': 'a',
    '4': 'a',
    '3': 'e',
    '1': 'i',
    '0': 'o',
    r'$': 's',
    '5': 's',
    '7': 't',
  };

  /// Unicode combining diacritical marks (decomposed accents such as
  /// "e" + U+0301); they stay part of the current word.
  static bool _isCombiningMark(int unit) => unit >= 0x0300 && unit <= 0x036f;

  static bool _hasStretchedLetter(String text) =>
      _stretchedLetter.hasMatch(text);

  static String _collapseRepeats(String text) =>
      text.replaceAllMapped(_repeatedLetters, (m) => m[1]!);
}

class _Token {
  const _Token(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

class _Match {
  const _Match(this.keyword, this.start, this.end);
  final String keyword;
  final int start;
  final int end;
}
