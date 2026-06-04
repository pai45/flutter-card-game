import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/theme.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';

/// The prediction quiz for one fixture: a team header with a split indicator
/// bar, then numbered multiple-choice questions with XP reward pills. Editable
/// until kickoff; read-only once live/finished, with a demo SETTLE action for
/// finished matches that credits the wallet (coins) for correct answers.
class MatchPredictionScreen extends StatefulWidget {
  const MatchPredictionScreen({required this.match, super.key});

  final SportMatch match;

  @override
  State<MatchPredictionScreen> createState() => _MatchPredictionScreenState();
}

class _MatchPredictionScreenState extends State<MatchPredictionScreen> {
  PredictionQuiz? _quiz;
  bool _loading = true;
  final Map<String, int> _answers = {};

  SportMatch get _match => widget.match;
  bool get _editable => _match.predictable;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cubit = context.read<PredictionCubit>();
    final quiz = await cubit.quizFor(_match.id);
    final existing = cubit.state.predictionFor(_match.id);
    if (existing != null) _answers.addAll(existing.answers);
    if (!mounted) return;
    setState(() {
      _quiz = quiz;
      _loading = false;
    });
  }

  bool get _allAnswered =>
      _quiz != null && _answers.length == _quiz!.questions.length;

  void _select(String questionId, int optionIndex) {
    if (!_editable) return;
    playSound(SoundEffect.uiTap);
    setState(() => _answers[questionId] = optionIndex);
  }

  Future<void> _submit() async {
    await context.read<PredictionCubit>().submit(_match.id, Map.of(_answers));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prediction submitted')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _settle() async {
    final reward = await context.read<PredictionCubit>().settle(_match.id);
    if (!mounted) return;
    if (reward > 0) {
      context.read<GameBloc>().add(CoinsAdded(reward));
      playSound(SoundEffect.coins);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reward > 0 ? 'Settled · +$reward coins' : 'Settled · no reward',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: AppBar(
        title: Text('PREDICTION', style: Cyber.label(15, letterSpacing: 1.5)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: CyberBackground(child: SizedBox.expand())),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Cyber.cyan))
                : BlocBuilder<PredictionCubit, PredictionState>(
                    builder: (context, state) {
                      final prediction = state.predictionFor(_match.id);
                      return _content(prediction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _content(UserPrediction? prediction) {
    final quiz = _quiz;
    return Column(
      children: [
        _MatchHeader(match: _match),
        Expanded(
          child: quiz == null
              ? Center(
                  child: Text(
                    'No quiz available for this match yet.',
                    style: Cyber.body(13, color: Cyber.muted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    for (var i = 0; i < quiz.questions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _QuestionCard(
                          index: i + 1,
                          question: quiz.questions[i],
                          selected: _answers[quiz.questions[i].id],
                          settled: prediction?.status == PredictionStatus.settled,
                          onSelect: (opt) =>
                              _select(quiz.questions[i].id, opt),
                        ),
                      ),
                  ],
                ),
        ),
        if (quiz != null) _bottomBar(prediction),
      ],
    );
  }

  Widget _bottomBar(UserPrediction? prediction) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: _buildAction(prediction),
      ),
    );
  }

  Widget _buildAction(UserPrediction? prediction) {
    // Finished + settleable + predicted-not-settled → SETTLE (demo).
    if (_match.status == MatchStatus.finished &&
        (_quiz?.settleable ?? false) &&
        prediction != null &&
        prediction.status != PredictionStatus.settled) {
      return CyberCtaButton(label: 'SETTLE & CLAIM', primary: true, onPressed: _settle);
    }
    if (prediction?.status == PredictionStatus.settled) {
      return _ResultBanner(prediction: prediction!);
    }
    if (!_editable) {
      return Text(
        'PREDICTIONS LOCKED — MATCH IN PROGRESS',
        textAlign: TextAlign.center,
        style: Cyber.label(11, color: Cyber.muted, letterSpacing: 1),
      );
    }
    return CyberCtaButton(
      label: prediction == null ? 'SUBMIT PREDICTION' : 'UPDATE PREDICTION',
      primary: true,
      onPressed: _allAnswered ? _submit : null,
    );
  }
}

// ── Match header with split indicator bar ─────────────────────────────────────
class _MatchHeader extends StatelessWidget {
  const _MatchHeader({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (match.status) {
      MatchStatus.upcoming =>
        '${match.kickoff.hour.toString().padLeft(2, '0')}:${match.kickoff.minute.toString().padLeft(2, '0')}',
      MatchStatus.live => match.liveMinute != null
          ? "LIVE ${match.liveMinute}'"
          : 'LIVE',
      MatchStatus.finished => 'FINISHED',
    };
    final statusColor = switch (match.status) {
      MatchStatus.upcoming => Cyber.gold,
      MatchStatus.live => Cyber.danger,
      MatchStatus.finished => Cyber.muted,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.55),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            statusLabel,
            style: Cyber.display(13, color: statusColor, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Badge(team: match.home),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  match.home.name,
                  style: Cyber.display(16, letterSpacing: 0.4),
                ),
              ),
              Text('-', style: Cyber.display(16, color: Cyber.muted)),
              Expanded(
                child: Text(
                  match.away.name,
                  textAlign: TextAlign.end,
                  style: Cyber.display(16, letterSpacing: 0.4),
                ),
              ),
              const SizedBox(width: 10),
              _Badge(team: match.away),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Container(height: 4, color: match.home.color)),
              Expanded(
                child: Container(
                  height: 4,
                  color: match.away.color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.team});
  final SportTeam team;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [team.color, Color.lerp(team.color, Colors.black, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        team.shortName,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: Cyber.displayFont,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ── Question card ─────────────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.settled,
    required this.onSelect,
  });

  final int index;
  final QuizQuestion question;
  final int? selected;
  final bool settled;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Numbered tab.
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                color: Cyber.cyan.withValues(alpha: 0.14),
                child: Text(
                  '$index',
                  style: Cyber.display(13, color: Cyber.cyan),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.text.toUpperCase(),
                  style: Cyber.display(15, letterSpacing: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reward pill (XP), per the design reference.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Cyber.violet.withValues(alpha: 0.18),
                border: Border.all(color: Cyber.violet.withValues(alpha: 0.6)),
              ),
              child: Text(
                '${question.reward} XP',
                style: Cyber.label(10, color: Cyber.violet, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Option(
                letter: String.fromCharCode(65 + i),
                label: question.options[i],
                state: _optionState(i),
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }

  _OptionVisual _optionState(int i) {
    if (settled) {
      if (i == question.settledOptionIndex) return _OptionVisual.correct;
      if (i == selected) return _OptionVisual.wrong;
      return _OptionVisual.idle;
    }
    return i == selected ? _OptionVisual.selected : _OptionVisual.idle;
  }
}

enum _OptionVisual { idle, selected, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.letter,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String label;
  final _OptionVisual state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (state) {
      _OptionVisual.selected => Cyber.cyan,
      _OptionVisual.correct => Cyber.success,
      _OptionVisual.wrong => Cyber.danger,
      _OptionVisual.idle => Cyber.muted,
    };
    final active = state != _OptionVisual.idle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.10) : Cyber.bg.withValues(alpha: 0.4),
          border: Border.all(
            color: active ? accent : Cyber.line,
            width: active ? 1.5 : 1,
          ),
          boxShadow: state == _OptionVisual.selected ? Cyber.glow(accent) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent.withValues(alpha: 0.18) : Cyber.panel,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: Text(
                letter,
                style: Cyber.display(12, color: active ? accent : Cyber.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Cyber.label(
                  12,
                  color: active ? Colors.white : Cyber.muted,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (state == _OptionVisual.correct)
              const Icon(Icons.check_circle, color: Cyber.success, size: 18),
            if (state == _OptionVisual.wrong)
              const Icon(Icons.cancel, color: Cyber.danger, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.prediction});
  final UserPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final correct = prediction.correctCount ?? 0;
    final reward = prediction.rewardEarned;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.success.withValues(alpha: 0.12),
        border: Border.all(color: Cyber.success.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$correct CORRECT · +$reward COINS',
        style: Cyber.label(13, color: Cyber.success, letterSpacing: 1),
      ),
    );
  }
}
