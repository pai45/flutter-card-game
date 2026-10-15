import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_widgets.dart';

enum _MatchLeaderboardMode {
  notEntered,
  editable,
  locked,
  revealReady,
  settled,
  closed,
}

const double _matchLeaderboardCardHeight = 70;

class MatchLeaderboardScreen extends StatelessWidget {
  const MatchLeaderboardScreen({
    required this.match,
    required this.quiz,
    required this.prediction,
    required this.entries,
    super.key,
  });

  final SportMatch match;
  final PredictionQuiz? quiz;
  final UserPrediction? prediction;
  final List<MatchPredictionLeaderboardEntry> entries;

  _MatchLeaderboardMode get _mode {
    if (prediction?.status == PredictionStatus.settled) {
      return _MatchLeaderboardMode.settled;
    }
    if (match.status == MatchStatus.finished) {
      if (prediction != null && (quiz?.settleable ?? false)) {
        return _MatchLeaderboardMode.revealReady;
      }
      return _MatchLeaderboardMode.closed;
    }
    if (match.status == MatchStatus.live ||
        prediction?.status == PredictionStatus.locked) {
      return _MatchLeaderboardMode.locked;
    }
    if (prediction != null) return _MatchLeaderboardMode.editable;
    return _MatchLeaderboardMode.notEntered;
  }

  MatchPredictionLeaderboardEntry? get _userEntry {
    for (final entry in entries) {
      if (entry.name.toLowerCase() == 'you') return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = quiz?.questions.length ?? 0;
    final user = _userEntry;

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: Column(
              children: [
                _MatchLeaderboardTopBar(
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                    children: [
                      _MatchLeaderboardStats(
                        user: user,
                        prediction: prediction,
                        entries: entries,
                        totalQuestions: totalQuestions,
                      ),
                      const SizedBox(height: 16),
                      _RankSectionHeader(mode: _mode, count: entries.length),
                      const SizedBox(height: 10),
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _MatchRankRow(entry: entry),
                        ),
                      if (entries.isEmpty)
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.42,
                          child: _EmptyLeaderboard(mode: _mode),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchLeaderboardTopBar extends StatelessWidget {
  const _MatchLeaderboardTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xff11182a).withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Cyber.cyan.withValues(alpha: 0.34)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Color(0xffd9e5f6)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.emoji_events_outlined, color: Cyber.gold, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'MATCH LEADERBOARD',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(15, color: Colors.white, letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchLeaderboardStats extends StatelessWidget {
  const _MatchLeaderboardStats({
    required this.user,
    required this.prediction,
    required this.entries,
    required this.totalQuestions,
  });

  final MatchPredictionLeaderboardEntry? user;
  final UserPrediction? prediction;
  final List<MatchPredictionLeaderboardEntry> entries;
  final int totalQuestions;

  @override
  Widget build(BuildContext context) {
    final predictions = prediction?.answers.length ?? user?.correct ?? 0;
    return Row(
      children: [
        Expanded(
          child: _LeaderboardStatCard(
            label: 'YOUR RANK',
            value: user == null ? '--' : '#${user!.rank}',
            color: Cyber.cyan,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LeaderboardStatCard(
            label: 'PREDICTIONS',
            value: totalQuestions == 0
                ? '$predictions'
                : '$predictions/$totalQuestions',
            color: Cyber.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LeaderboardStatCard(
            label: 'PLAYERS',
            value: '${entries.length}',
            color: Cyber.lime,
          ),
        ),
      ],
    );
  }
}

class _RankSectionHeader extends StatelessWidget {
  const _RankSectionHeader({required this.mode, required this.count});

  final _MatchLeaderboardMode mode;
  final int count;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      _MatchLeaderboardMode.notEntered => 'JOIN BEFORE LOCK',
      _MatchLeaderboardMode.editable => 'LIVE STANDINGS PREVIEW',
      _MatchLeaderboardMode.locked => 'LOCKED PICKS',
      _MatchLeaderboardMode.revealReady => 'FINAL RANKS READY',
      _MatchLeaderboardMode.settled => 'FINAL RESULTS',
      _MatchLeaderboardMode.closed => 'MATCH CLOSED',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.0),
          ),
        ),
        Text(
          '$count PLAYERS',
          style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 0.8),
        ),
      ],
    );
  }
}

class _MatchRankRow extends StatelessWidget {
  const _MatchRankRow({required this.entry});

  final MatchPredictionLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final isUser = entry.name.toLowerCase() == 'you';
    final rankColor = entry.rank <= 3 ? Cyber.gold : Cyber.cyan;
    final accent = isUser ? Cyber.cyan : rankColor;
    return SizedBox(
      height: _matchLeaderboardCardHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Cyber.cyan.withValues(alpha: 0.10)
              : Cyber.panel.withValues(alpha: 0.34),
          border: Border.all(
            color: isUser
                ? Cyber.cyan.withValues(alpha: 0.55)
                : Cyber.line.withValues(alpha: entry.rank <= 3 ? 0.24 : 0.0),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '#${entry.rank}',
                style: Cyber.display(
                  13,
                  color: rankColor,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(width: 10),
            _MatchPlayerAvatar(
              name: entry.name,
              size: 44,
              highlight: isUser,
              ring: entry.rank <= 3 ? rankColor : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(
                            14,
                            weight: isUser ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 7),
                        const _StatusPill(
                          label: 'YOU',
                          color: Cyber.cyan,
                          small: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.correct} correct',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      8.5,
                      color: Cyber.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${entry.points}',
                      maxLines: 1,
                      style: Cyber.display(16, color: accent).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    'XP',
                    style: Cyber.label(
                      8,
                      color: Cyber.muted.withValues(alpha: 0.82),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchPlayerAvatar extends StatelessWidget {
  const _MatchPlayerAvatar({
    required this.name,
    required this.size,
    required this.highlight,
    this.ring,
  });

  final String name;
  final double size;
  final bool highlight;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final color = ring ?? (highlight ? Cyber.cyan : Cyber.line);
    final fill = _avatarFill(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(fill, Cyber.panel, 0.42),
        border: Border.all(
          color: color.withValues(alpha: highlight ? 0.9 : 0.42),
          width: highlight ? 2 : 1.2,
        ),
      ),
      child: Text(
        _initials(name),
        style: Cyber.display(
          size >= 44 ? 13 : 11,
          color: Colors.white,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

Color _avatarFill(String name) {
  const palette = [
    Cyber.cyan,
    Cyber.violet,
    Cyber.gold,
    Cyber.lime,
    Cyber.danger,
  ];
  final seed = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return palette[seed % palette.length];
}

class _LeaderboardStatCard extends StatelessWidget {
  const _LeaderboardStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.58),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.7),
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(
                17,
                color: color,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.small = false,
  });

  final String label;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 9,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Cyber.label(
          small ? 7 : 8.5,
          color: color,
          letterSpacing: small ? 0.5 : 0.8,
        ),
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard({required this.mode});

  final _MatchLeaderboardMode mode;

  @override
  Widget build(BuildContext context) {
    final canJoin =
        mode == _MatchLeaderboardMode.notEntered ||
        mode == _MatchLeaderboardMode.editable;
    return CyberNoDataState(
      icon: canJoin ? Icons.sports_esports : Icons.emoji_events_outlined,
      title: canJoin ? 'Be the 1st to play' : 'No players yet',
      message: canJoin
          ? 'No one has submitted this prediction quiz yet. Play first and set the rank to beat.'
          : 'No prediction quiz results were submitted before this board closed.',
      accent: canJoin ? Cyber.cyan : Cyber.gold,
      spark: canJoin ? Icons.bolt : Icons.lock_clock,
    );
  }
}
