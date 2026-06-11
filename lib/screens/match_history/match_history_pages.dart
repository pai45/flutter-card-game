import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/match_widgets.dart';

void showMatchHistoryArchive(
  BuildContext context,
  List<MatchHistoryEntry> history,
) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => _MatchHistoryArchivePage(history: history),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

void showMatchHistoryDetail(BuildContext context, MatchHistoryEntry entry) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, a, b) => _MatchHistoryDetailPage(entry: entry),
      transitionsBuilder: (ctx, animation, b, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

// ─── Archive list ─────────────────────────────────────────────────────────────

class _MatchHistoryArchivePage extends StatelessWidget {
  const _MatchHistoryArchivePage({required this.history});

  final List<MatchHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    final wins   = history.where((e) => e.resultLabel == 'Victory').length;
    final draws  = history.where((e) => e.resultLabel == 'Draw').length;
    final losses = history.length - wins - draws;
    final winPct = history.isEmpty ? 0 : (wins / history.length * 100).round();

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
                child: Row(
                  children: [
                    Container(width: 3, height: 22, color: Cyber.cyan),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'MATCH ARCHIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Cyber.cyan),
                    ),
                  ],
                ),
              ),
              // ── stats bar ───────────────────────────────────────────────────
              if (history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      _StatBox('W', '$wins',   Cyber.success),
                      const SizedBox(width: 8),
                      _StatBox('D', '$draws',  Cyber.amber),
                      const SizedBox(width: 8),
                      _StatBox('L', '$losses', Cyber.danger),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$winPct%',
                            style: Cyber.display(
                              24,
                              color: wins > losses ? Cyber.success : Cyber.muted,
                            ),
                          ),
                          const Text(
                            'WIN RATE',
                            style: TextStyle(
                              color: Cyber.muted,
                              fontFamily: 'Orbitron',
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // ── win/loss bar ─────────────────────────────────────────────
              if (history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: ClipRRect(
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: [
                          if (wins > 0)
                            Expanded(
                              flex: wins,
                              child: Container(color: Cyber.success),
                            ),
                          if (draws > 0)
                            Expanded(
                              flex: draws,
                              child: Container(color: Cyber.amber),
                            ),
                          if (losses > 0)
                            Expanded(
                              flex: losses,
                              child: Container(color: Cyber.danger),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
                  child: Text(
                    'No archived matches yet.',
                    style: TextStyle(color: Cyber.muted, fontSize: 12),
                  ),
                ),
              // ── list ────────────────────────────────────────────────────────
              Expanded(
                child: history.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: history.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = history[index];
                          return MatchHistoryTile(
                            entry: entry,
                            onTap: () => showMatchHistoryDetail(context, entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Match detail ─────────────────────────────────────────────────────────────

class _MatchHistoryDetailPage extends StatelessWidget {
  const _MatchHistoryDetailPage({required this.entry});

  final MatchHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final resultColor = switch (entry.resultLabel) {
      'Victory' => Cyber.success,
      'Defeat'  => Cyber.danger,
      _          => Cyber.amber,
    };
    final resultIcon = switch (entry.resultLabel) {
      'Victory' => Icons.emoji_events,
      'Defeat'  => Icons.sentiment_dissatisfied,
      _          => Icons.balance,
    };

    // Pre-compute running score after each round.
    final List<({int p, int c})> running = [];
    var pGoals = 0, cGoals = 0;
    for (final r in entry.rounds) {
      if (r.outcomeLabel.toLowerCase() == 'goal') {
        if (r.playerAttacking) { pGoals++; } else { cGoals++; }
      }
      running.add((p: pGoals, c: cGoals));
    }

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
                child: Row(
                  children: [
                    Container(width: 3, height: 22, color: resultColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.deckName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Cyber.cyan),
                    ),
                  ],
                ),
              ),

              // ── hero scoreline ───────────────────────────────────────────
              _HeroScoreline(entry: entry, resultColor: resultColor, resultIcon: resultIcon),

              // ── goal trail ───────────────────────────────────────────────
              if (entry.rounds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _GoalTrail(rounds: entry.rounds),
                ),

              // ── round log header ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Container(width: 3, height: 14, color: Cyber.cyan),
                    const SizedBox(width: 8),
                    const Text(
                      'ROUND LOG',
                      style: TextStyle(
                        color: Cyber.cyan,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.rounds.length} ROUNDS',
                      style: const TextStyle(
                        color: Cyber.muted,
                        fontSize: 10,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
              ),

              // ── round items ──────────────────────────────────────────────
              Expanded(
                child: entry.rounds.isEmpty
                    ? const Center(
                        child: Text(
                          'No round data.',
                          style: TextStyle(color: Cyber.muted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        itemCount: entry.rounds.length,
                        itemBuilder: (context, index) {
                          final round = entry.rounds[index];
                          final score = running[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < entry.rounds.length - 1 ? 6 : 0,
                            ),
                            child: _RoundLogItem(
                              round: round,
                              playerGoals: score.p,
                              cpuGoals: score.c,
                              index: index,
                              isLast: index == entry.rounds.length - 1,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero scoreline widget ─────────────────────────────────────────────────────

class _HeroScoreline extends StatelessWidget {
  const _HeroScoreline({
    required this.entry,
    required this.resultColor,
    required this.resultIcon,
  });

  final MatchHistoryEntry entry;
  final Color resultColor;
  final IconData resultIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            resultColor.withValues(alpha: 0.12),
            Cyber.panel2,
          ],
        ),
        border: Border.all(color: resultColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: resultColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      child: Row(
        children: [
          // Result label + icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(resultIcon, color: resultColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    entry.resultLabel.toUpperCase(),
                    style: TextStyle(
                      color: resultColor,
                      fontFamily: 'Orbitron',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                historyTimestampLabel(entry.timestampIso),
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.isShootout) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Cyber.violet.withValues(alpha: 0.15),
                    border: Border.all(color: Cyber.violet.withValues(alpha: 0.6)),
                  ),
                  child: const Text(
                    'PENALTY SHOOTOUT',
                    style: TextStyle(
                      color: Cyber.violet,
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
              if (entry.penaltyPlayerScore != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Cyber.violet.withValues(alpha: 0.15),
                    border: Border.all(color: Cyber.violet.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    'PEN  ${entry.penaltyPlayerScore} – ${entry.penaltyOpponentScore}',
                    style: const TextStyle(
                      color: Cyber.violet,
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          // Score
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    '${entry.playerScore}',
                    style: Cyber.display(52, color: Cyber.cyan),
                  ),
                  Text(
                    'YOU',
                    style: TextStyle(
                      color: Cyber.cyan.withValues(alpha: 0.6),
                      fontFamily: 'Orbitron',
                      fontSize: 9,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '–',
                  style: Cyber.display(28, color: Cyber.muted),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${entry.opponentScore}',
                    style: Cyber.display(52, color: Cyber.danger),
                  ),
                  Text(
                    'CPU',
                    style: TextStyle(
                      color: Cyber.danger.withValues(alpha: 0.6),
                      fontFamily: 'Orbitron',
                      fontSize: 9,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Goal trail (mini dot timeline) ───────────────────────────────────────────

class _GoalTrail extends StatelessWidget {
  const _GoalTrail({required this.rounds});

  final List<MatchHistoryRound> rounds;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'GOALS',
          style: TextStyle(
            color: Cyber.muted.withValues(alpha: 0.6),
            fontFamily: 'Orbitron',
            fontSize: 9,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < rounds.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 12,
                      height: 1,
                      color: Cyber.line.withValues(alpha: 0.35),
                    ),
                  _GoalDot(round: rounds[i], index: i),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalDot extends StatelessWidget {
  const _GoalDot({required this.round, required this.index});

  final MatchHistoryRound round;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isGoal = round.outcomeLabel.toLowerCase() == 'goal';
    final color = isGoal
        ? (round.playerAttacking ? Cyber.success : Cyber.danger)
        : Cyber.line.withValues(alpha: 0.5);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t.clamp(0.0, 1.3),
        child: child,
      ),
      child: Tooltip(
        message: 'R${round.round}: ${round.outcomeLabel}',
        child: Container(
          width: isGoal ? 11 : 8,
          height: isGoal ? 11 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: isGoal
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
        ),
      ),
    );
  }
}

// ── Round log item ────────────────────────────────────────────────────────────

class _RoundLogItem extends StatelessWidget {
  const _RoundLogItem({
    required this.round,
    required this.playerGoals,
    required this.cpuGoals,
    required this.index,
    required this.isLast,
  });

  final MatchHistoryRound round;
  final int playerGoals;
  final int cpuGoals;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final oColor = _outcomeColor(round.outcomeLabel);
    final oIcon  = _outcomeIcon(round.outcomeLabel);
    final roleColor = round.playerAttacking ? Cyber.lime : Cyber.cyan;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(28 * (1 - t), 0),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Column(
        children: [
          // ── card ──────────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: oColor.withValues(alpha: 0.05),
              border: Border(
                left: BorderSide(color: oColor, width: 3),
                top: BorderSide(color: oColor.withValues(alpha: 0.22)),
                right: BorderSide(color: oColor.withValues(alpha: 0.22)),
                bottom: BorderSide(color: oColor.withValues(alpha: 0.22)),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Round badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: oColor.withValues(alpha: 0.15),
                    border: Border.all(color: oColor.withValues(alpha: 0.55)),
                  ),
                  child: Center(
                    child: Text(
                      '${round.round}',
                      style: TextStyle(
                        color: oColor,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scenario + outcome stamp
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              round.scenarioTitle.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Orbitron',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Outcome stamp
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: oColor.withValues(alpha: 0.15),
                              border: Border.all(
                                color: oColor.withValues(alpha: 0.75),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(oIcon, color: oColor, size: 11),
                                const SizedBox(width: 4),
                                Text(
                                  round.outcomeLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: oColor,
                                    fontSize: 9,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Role chip + running score
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  round.playerAttacking
                                      ? Icons.sports_soccer
                                      : Icons.shield,
                                  color: roleColor,
                                  size: 9,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  round.playerAttacking ? 'ATK' : 'DEF',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontSize: 9,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Running score
                          Text(
                            'YOU ',
                            style: TextStyle(
                              color: Cyber.cyan.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '$playerGoals',
                            style: Cyber.display(14, color: Cyber.cyan),
                          ),
                          Text(
                            ' : ',
                            style: const TextStyle(
                              color: Cyber.muted,
                              fontFamily: 'Orbitron',
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$cpuGoals',
                            style: Cyber.display(14, color: Cyber.danger),
                          ),
                          Text(
                            ' CPU',
                            style: TextStyle(
                              color: Cyber.danger.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── connector to next round ────────────────────────────────────────
          if (!isLast)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Container(
                  width: 2,
                  height: 6,
                  color: oColor.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Color _outcomeColor(String label) => switch (label.toLowerCase()) {
  'goal'     => Cyber.success,
  'saved'    => Cyber.cyan,
  'blocked'  => Cyber.violet,
  'missed'   => Cyber.muted,
  'foul'     => Cyber.amber,
  'red card' => Cyber.danger,
  _          => Cyber.muted,
};

IconData _outcomeIcon(String label) => switch (label.toLowerCase()) {
  'goal'     => Icons.sports_soccer,
  'saved'    => Icons.back_hand,
  'blocked'  => Icons.shield,
  'missed'   => Icons.close,
  'foul'     => Icons.warning_amber_rounded,
  'red card' => Icons.style,
  _          => Icons.help_outline,
};

// ── Archive stat box ──────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: Cyber.display(22, color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timestamp label ──────────────────────────────────────────────────────────

String historyTimestampLabel(String timestampIso) {
  final stamp = DateTime.tryParse(timestampIso)?.toLocal();
  if (stamp == null) return 'Unknown time';
  final month = switch (stamp.month) {
    1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr',
    5 => 'May', 6 => 'Jun', 7 => 'Jul', 8 => 'Aug',
    9 => 'Sep', 10 => 'Oct', 11 => 'Nov', _ => 'Dec',
  };
  final hour = stamp.hour % 12 == 0 ? 12 : stamp.hour % 12;
  final minute = stamp.minute.toString().padLeft(2, '0');
  final meridiem = stamp.hour >= 12 ? 'PM' : 'AM';
  return '$month ${stamp.day}, ${stamp.year}  $hour:$minute $meridiem';
}
