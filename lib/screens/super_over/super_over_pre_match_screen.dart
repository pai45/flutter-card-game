import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/super_over_batter_profiles.dart';
import '../../data/super_over_jerseys.dart';
import '../../models/cards.dart';
import '../../models/super_over.dart';
import '../../models/super_over_stats.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';

class SuperOverPreMatchScreen extends StatelessWidget {
  const SuperOverPreMatchScreen({
    required this.mode,
    required this.difficulty,
    required this.battingOrder,
    required this.jersey,
    required this.stats,
    required this.target,
    required this.objective,
    required this.onDifficultyChanged,
    required this.onStart,
    required this.onBack,
    super.key,
  });

  final SuperOverMode mode;
  final SuperOverDifficulty difficulty;
  final List<PlayerCard> battingOrder;
  final CricketJersey jersey;
  final SuperOverStats stats;
  final int? target;
  final SuperOverObjective objective;
  final ValueChanged<SuperOverDifficulty> onDifficultyChanged;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final profiles = SuperOverBatterProfiles.fromBattingOrder(battingOrder);
    final jerseySpec = cricketJerseySpec(jersey);
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'FINAL STAND',
        subtitle: '// PRE-MATCH BRIEFING',
        onBack: onBack,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _NightArenaBriefingPainter()),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TargetPanel(
                        mode: mode,
                        target: target,
                        scoreAttackRecord: stats.scoreAttackHighScore,
                      ),
                      const SizedBox(height: 14),
                      _InfoStrip(
                        items: const [
                          ('6', 'BALLS'),
                          ('2', 'WICKETS'),
                          ('3', 'BATTERS'),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'BATTING UNIT',
                        style: Cyber.label(9, color: Cyber.cyan),
                      ),
                      const SizedBox(height: 8),
                      for (final profile in profiles) ...[
                        _BatterRow(profile: profile, jerseySpec: jerseySpec),
                        const SizedBox(height: 7),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'DIFFICULTY',
                        style: Cyber.label(9, color: Cyber.cyan),
                      ),
                      const SizedBox(height: 8),
                      _DifficultySelector(
                        value: difficulty,
                        onChanged: onDifficultyChanged,
                      ),
                      const SizedBox(height: 14),
                      _BriefingCard(
                        icon: Icons.sports_cricket,
                        title: _bowlingPlan(difficulty),
                        body: _bowlingPlanBody(difficulty),
                      ),
                      const SizedBox(height: 8),
                      const _BriefingCard(
                        icon: Icons.stadium_outlined,
                        title: 'STATOZ NIGHT ARENA',
                        body:
                            'Floodlit batting-end camera // deep teal outfield',
                      ),
                      const SizedBox(height: 8),
                      _BriefingCard(
                        icon: Icons.track_changes,
                        title: objective.label,
                        body: 'OPTIONAL OBJECTIVE  //  +8 XP',
                      ),
                      const SizedBox(height: 8),
                      const _BriefingCard(
                        icon: Icons.bolt,
                        title: 'REWARD FORMULA',
                        body:
                            '+10 complete // +1 per run // +4 per six // +15 Chase win // +8 objective',
                      ),
                      const SizedBox(height: 22),
                      HudCtaButton(
                        label: 'START OVER',
                        icon: Icons.play_arrow_rounded,
                        onTap: onStart,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _bowlingPlan(SuperOverDifficulty difficulty) =>
      switch (difficulty) {
        SuperOverDifficulty.rookie => 'READABLE PACE PLAN',
        SuperOverDifficulty.pro => 'MIXED ATTACK PLAN',
        SuperOverDifficulty.allStar => 'DISGUISED FINISHER PLAN',
      };

  static String _bowlingPlanBody(SuperOverDifficulty difficulty) =>
      switch (difficulty) {
        SuperOverDifficulty.rookie =>
          'Early cues // strong marker // generous contact window',
        SuperOverDifficulty.pro =>
          'Varied pace // tactical fields // balanced cue timing',
        SuperOverDifficulty.allStar =>
          'Late cues // sequenced traps // advanced yorker threat',
      };
}

class _TargetPanel extends StatelessWidget {
  const _TargetPanel({
    required this.mode,
    required this.target,
    required this.scoreAttackRecord,
  });

  final SuperOverMode mode;
  final int? target;
  final int scoreAttackRecord;

  @override
  Widget build(BuildContext context) {
    final chase = mode == SuperOverMode.chase;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: .94),
        border: Border.all(color: chase ? Cyber.cyan : Cyber.violet),
        boxShadow: Cyber.glow(
          chase ? Cyber.cyan : Cyber.violet,
          alpha: .16,
          blur: 22,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          children: [
            Text(
              chase ? 'CHASE' : 'SCORE ATTACK',
              style: Cyber.label(
                9,
                color: chase ? Cyber.cyan : Cyber.violet,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              chase
                  ? 'YOU NEED ${(target ?? 0) + 1}'
                  : 'BEAT $scoreAttackRecord',
              style: Cyber.display(31, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Text(
              chase
                  ? 'Opponent posted ${target ?? 0}'
                  : 'Set the highest six-ball score',
              style: Cyber.body(11, color: Cyber.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, item) in items.indexed) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: .8),
              border: Border.all(color: Cyber.border),
            ),
            child: Column(
              children: [
                Text(item.$1, style: Cyber.display(18, color: Cyber.gold)),
                Text(item.$2, style: Cyber.label(8, color: Cyber.muted)),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _BatterRow extends StatelessWidget {
  const _BatterRow({required this.profile, required this.jerseySpec});

  final SuperOverBatterProfile profile;
  final CricketJerseySpec jerseySpec;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Cyber.panel.withValues(alpha: .9),
      border: Border.all(color: Cyber.border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: jerseySpec.primary,
            border: Border.all(color: jerseySpec.accent, width: 2),
            shape: BoxShape.circle,
          ),
          child: Text(
            '${profile.battingPosition}',
            style: Cyber.display(13, color: Colors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: Cyber.display(12)),
              const SizedBox(height: 2),
              Text(
                profile.archetypeLabel,
                style: Cyber.label(8, color: Cyber.muted),
              ),
            ],
          ),
        ),
        Text('${profile.rating}', style: Cyber.display(18, color: Cyber.gold)),
      ],
    ),
  );
}

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.value, required this.onChanged});
  final SuperOverDifficulty value;
  final ValueChanged<SuperOverDifficulty> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<SuperOverDifficulty>(
    segments: [
      for (final difficulty in SuperOverDifficulty.values)
        ButtonSegment(value: difficulty, label: Text(difficulty.label)),
    ],
    selected: {value},
    showSelectedIcon: false,
    style: ButtonStyle(
      visualDensity: VisualDensity.compact,
      textStyle: WidgetStatePropertyAll(Cyber.display(8)),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Cyber.bg : Cyber.muted,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Cyber.cyan : Cyber.panel,
      ),
    ),
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}

class _BriefingCard extends StatelessWidget {
  const _BriefingCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Cyber.panel.withValues(alpha: .86),
      border: Border.all(color: Cyber.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: Cyber.cyan, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Cyber.display(9, color: Colors.white)),
              const SizedBox(height: 3),
              Text(body, style: Cyber.body(9, color: Cyber.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NightArenaBriefingPainter extends CustomPainter {
  const _NightArenaBriefingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF111B30), Color(0xFF060A12)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    final grid = Paint()
      ..color = Cyber.cyan.withValues(alpha: .045)
      ..strokeWidth = 1;
    for (var y = 40.0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var x = 20.0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
