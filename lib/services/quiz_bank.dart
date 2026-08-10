import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/quiz_trivia.dart';
import '../models/sport_match.dart';

/// Loads the authored trivia database off the asset bundle and caches it.
///
/// One JSON file per sport+mode lives at `assets/quiz/<sport>_<mode>.json`.
/// Each file carries five **bands** of [kQuizBandSize] questions; band `k` owns
/// sets `10(k-1)+1 … 10k`, so flattening bands 1→5 reproduces the 500-question
/// pool the ladder indexes into. Bands exist so difficulty can ramp across the
/// 50 sets — band 1 is the gentlest rung of a mode, band 5 the hardest.
///
/// A file may ship with later bands empty (the database is authored one batch at
/// a time). A short pool is not an error: [authoredSetCount] reports how many of
/// the 50 sets actually exist so the lobby can render the rest as "SOON" rather
/// than fall back to filler questions.
abstract final class QuizBank {
  /// Questions per difficulty band — 10 sets × 10 questions.
  static const int kQuizBandSize = kQuizQuestionsPerSet * kSetsPerBand;

  /// Sets covered by one band. Five bands span the 50-set ladder.
  static const int kSetsPerBand = 10;

  /// Number of difficulty bands in every mode.
  static const int kBandCount = kQuizSetCount ~/ kSetsPerBand;

  static final Map<String, List<TriviaQuestion>> _pools = {};
  static final Map<String, Future<void>> _inFlight = {};

  static String _key(Sport sport, QuizMode mode) => '${sport.name}_${mode.name}';

  static String assetPath(Sport sport, QuizMode mode) =>
      'assets/quiz/${_key(sport, mode)}.json';

  /// True once [ensureLoaded] has resolved for this pool.
  static bool isLoaded(Sport sport, QuizMode mode) =>
      _pools.containsKey(_key(sport, mode));

  /// The flattened question pool, or an empty list when not yet loaded.
  static List<TriviaQuestion> pool(Sport sport, QuizMode mode) =>
      _pools[_key(sport, mode)] ?? const <TriviaQuestion>[];

  /// How many of the 50 sets have authored questions behind them. Partial sets
  /// don't count — a set needs all [kQuizQuestionsPerSet] questions to be
  /// playable.
  static int authoredSetCount(Sport sport, QuizMode mode) =>
      pool(sport, mode).length ~/ kQuizQuestionsPerSet;

  /// Parses `assets/quiz/<sport>_<mode>.json` into the cache. Idempotent, and
  /// concurrent calls share one decode. A missing or malformed file caches an
  /// empty pool rather than throwing — the ladder then shows every set as
  /// upcoming instead of crashing the screen.
  static Future<void> ensureLoaded(Sport sport, QuizMode mode) {
    final key = _key(sport, mode);
    if (_pools.containsKey(key)) return Future<void>.value();
    return _inFlight[key] ??= _load(sport, mode, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  static Future<void> _load(Sport sport, QuizMode mode, String key) async {
    try {
      final raw = await rootBundle.loadString(assetPath(sport, mode));
      _pools[key] = _parse(
        jsonDecode(raw) as Map<String, dynamic>,
        sport,
        mode,
      );
    } catch (_) {
      _pools[key] = const <TriviaQuestion>[];
    }
  }

  /// Flattens `bands` 1→5 into a single ordered pool. Stops at the first band
  /// that is missing or short, so a half-authored band can never shift the
  /// questions behind an already-published set.
  static List<TriviaQuestion> _parse(
    Map<String, dynamic> json,
    Sport sport,
    QuizMode mode,
  ) {
    final bands = json['bands'];
    if (bands is! Map) return const <TriviaQuestion>[];

    final questions = <TriviaQuestion>[];
    for (var band = 1; band <= kBandCount; band++) {
      final entries = bands['$band'];
      if (entries is! List || entries.length < kQuizBandSize) break;
      for (var index = 0; index < kQuizBandSize; index++) {
        final parsed = _question(
          entries[index],
          sport,
          mode,
          questions.length + 1,
        );
        if (parsed == null) return questions;
        questions.add(parsed);
      }
    }
    return List<TriviaQuestion>.unmodifiable(questions);
  }

  /// `{"p": prompt, "o": [4 options], "a": correctIndex}` → [TriviaQuestion].
  /// The id is positional so it stays stable regardless of file formatting, and
  /// keeps the `<mode>_q<NNN>` shape the rest of the app matches on.
  static TriviaQuestion? _question(
    Object? entry,
    Sport sport,
    QuizMode mode,
    int number,
  ) {
    if (entry is! Map) return null;
    final prompt = entry['p'];
    final rawOptions = entry['o'];
    final answer = entry['a'];
    if (prompt is! String || prompt.isEmpty) return null;
    if (rawOptions is! List || rawOptions.length < 2) return null;
    if (answer is! int || answer < 0 || answer >= rawOptions.length) return null;

    return TriviaQuestion(
      id: '${sport.name}_${mode.name}_q${number.toString().padLeft(3, '0')}',
      mode: mode,
      prompt: prompt,
      options: List<String>.unmodifiable(rawOptions.map((o) => '$o')),
      correctIndex: answer,
    );
  }

  /// Test seam — drops every cached pool.
  static void debugReset() {
    _pools.clear();
    _inFlight.clear();
  }
}
