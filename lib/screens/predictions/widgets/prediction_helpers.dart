import 'package:flutter/material.dart';

import '../../../models/prediction.dart';

// ── Question / option / panel palette ─────────────────────────────────────────
const Color panelTop = Color(0xff1b2336);
const Color panelBottom = Color(0xff131b2a);
const Color panelBorder = Color(0xff2a3550);
const double quizSurfaceOpacity = 0.90;
const Color optionFill = Color(0xff0f1826);
const Color optionBorder = Color(0xff283448);
const Color letterFill = Color(0xff1a2434);

// ── Score helpers ─────────────────────────────────────────────────────────────
({int home, int away}) decodeScore(int encoded) {
  final (home, away) = ScoreAnswer.decode(encoded);
  return (home: home, away: away);
}

// ── Answer labelling / correctness ────────────────────────────────────────────
String answerLabel(QuizQuestion question, int? answer) {
  if (answer == null) return 'Not answered';
  if (question.isScorePrediction) {
    final (home, away) = ScoreAnswer.decode(answer);
    return '$home - $away';
  }
  if (answer < 0 || answer >= question.options.length) return 'Unknown';
  return question.options[answer];
}

int? correctAnswer(QuizQuestion question) => question.isScorePrediction
    ? question.settledScoreEncoded
    : question.settledOptionIndex;

List<int> pollAnswers(
  QuizQuestion question,
  PredictionVoteBreakdown? votes,
  int? selected,
) {
  if (!question.isScorePrediction) {
    return [for (var i = 0; i < question.options.length; i++) i];
  }
  final answers = <int>{...votes?.totals.keys ?? const <int>[]};
  if (selected != null) answers.add(selected);
  final correct = question.settledScoreEncoded;
  if (correct != null) answers.add(correct);
  final sorted = answers.toList()
    ..sort(
      (a, b) => (votes?.votesFor(b) ?? 0).compareTo(votes?.votesFor(a) ?? 0),
    );
  return sorted.take(5).toList();
}

// ── Draft diff helpers ────────────────────────────────────────────────────────
bool sameAnswers(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool sameMultipliers(
  Map<String, PredictionMultiplier> a,
  Map<String, PredictionMultiplier> b,
) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

// ── Formatting ────────────────────────────────────────────────────────────────
String formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
  return '$m:$s';
}
