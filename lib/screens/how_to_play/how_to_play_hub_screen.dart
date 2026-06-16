import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

/// The four playable modes that have a How To Play guide. Order matches the
/// [_guides] table so a mode maps straight to its guide by index.
enum HowToPlayMode { predict, pick, pitchDuel, penaltyShootout }

/// Opens the standalone How To Play guide for a single [mode]. Used by the in-
/// context help affordances inside the Predict and Pick surfaces.
void showHowToPlayGuide(BuildContext context, HowToPlayMode mode) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _HowToPlayGuideScreen(guide: _guides[mode.index]),
    ),
  );
}

/// A compact, flat help affordance that drops a player straight into the guide
/// for [mode]. Secondary chrome — flat fill + accent border, never glows.
class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({
    required this.mode,
    this.accent = Cyber.cyan,
    super.key,
  });

  final HowToPlayMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        showHowToPlayGuide(context, mode);
      },
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        child: Icon(Icons.help_outline, color: accent, size: 18),
      ),
    );
  }
}

/// How To Play hub: one card per playable mode (Predict, Pick, Pitch Duel,
/// Penalty Shootout). Each card opens a flat reference guide built from the
/// product docs. Per the request this surface is gradient-free and glow-free —
/// depth comes from flat fills, the chamfer silhouette and accent borders.
class HowToPlayHubScreen extends StatelessWidget {
  const HowToPlayHubScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'How to Play',
      subtitle: '// Pick a Mode to Learn',
      leading: IconButton(
        onPressed: () => onNavigate(AppSection.profile),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(
            'FOUR WAYS TO PLAY STATOZ',
            style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            'Predict fixtures, take market picks, duel with cards, or trade spot '
            'kicks. Tap a mode for its quick guide.',
            style: Cyber.body(12.5, color: AppTheme.text2, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _guides.length; i++) ...[
            _ModeCard(guide: _guides[i]),
            if (i < _guides.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ── Mode card ────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.guide});

  final _ModeGuide guide;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _HowToPlayGuideScreen(guide: guide),
        ),
      ),
      child: CyberPanel(
        accent: guide.accent,
        solidBackground: true,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _IconTile(icon: guide.icon, accent: guide.accent, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.title,
                    style: Cyber.display(15, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    guide.tagline,
                    style: Cyber.body(12, color: AppTheme.text2, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  _MetaTag(
                    label: '${guide.steps.length} STEPS',
                    accent: guide.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: guide.accent.withValues(alpha: 0.8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Cyber.label(8, color: accent, letterSpacing: 1.2),
      ),
    );
  }
}

// ── Guide detail screen ──────────────────────────────────────────────────────

class _HowToPlayGuideScreen extends StatelessWidget {
  const _HowToPlayGuideScreen({required this.guide});

  final _ModeGuide guide;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: guide.title,
      subtitle: guide.subtitle,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _GuideHeader(guide: guide),
          const SizedBox(height: 14),
          _OverviewStrip(stats: guide.stats),
          const SizedBox(height: 18),
          _StepsPanel(steps: guide.steps, accent: guide.accent),
          const SizedBox(height: 14),
          _FactsPanel(facts: guide.facts, accent: guide.accent),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.guide});

  final _ModeGuide guide;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: guide.accent,
      solidBackground: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon: guide.icon, accent: guide.accent, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.title,
                  style: Cyber.display(16, letterSpacing: 0.6),
                ),
                const SizedBox(height: 7),
                Text(
                  guide.purpose,
                  style: Cyber.body(12.5, color: AppTheme.text2, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview strip ───────────────────────────────────────────────────────────

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.stats});

  final List<_GuideStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(child: _GuideStatCell(stat: stats[i])),
          if (i < stats.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _GuideStatCell extends StatelessWidget {
  const _GuideStatCell({required this.stat});

  final _GuideStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.07),
        border: Border.all(color: stat.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(stat.icon, color: stat.color, size: 22),
          const SizedBox(height: 7),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: Cyber.label(9, letterSpacing: 0.8),
          ),
          const SizedBox(height: 3),
          Text(
            stat.sub,
            textAlign: TextAlign.center,
            style: Cyber.body(9, color: Cyber.muted, height: 1.2),
          ),
        ],
      ),
    );
  }
}

// ── Steps panel ──────────────────────────────────────────────────────────────

class _StepsPanel extends StatelessWidget {
  const _StepsPanel({required this.steps, required this.accent});

  final List<_GuideStep> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      solidBackground: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'How It Works'),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++) ...[
            _StepTile(index: i + 1, step: steps[i], accent: accent),
            if (i < steps.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.accent,
  });

  final int index;
  final _GuideStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
          ),
          child: Text(
            '$index',
            style: Cyber.label(
              12,
              color: accent,
              letterSpacing: 0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  step.title,
                  style: Cyber.label(12.5, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                step.body,
                style: Cyber.body(12, color: AppTheme.text2, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Facts panel ──────────────────────────────────────────────────────────────

class _FactsPanel extends StatelessWidget {
  const _FactsPanel({required this.facts, required this.accent});

  final List<_GuideFact> facts;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      solidBackground: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'Good to Know'),
          const SizedBox(height: 12),
          for (var i = 0; i < facts.length; i++) ...[
            _FactTile(fact: facts[i], accent: accent),
            if (i < facts.length - 1) ...[
              const SizedBox(height: 10),
              const HudLine(),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.fact, required this.accent});

  final _GuideFact fact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(fact.icon, color: accent, size: 16),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fact.label, style: Cyber.label(11.5, letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(
                fact.body,
                style: Cyber.body(11.5, color: Cyber.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared icon tile ─────────────────────────────────────────────────────────

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.accent,
    required this.size,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _ModeGuide {
  const _ModeGuide({
    required this.title,
    required this.tagline,
    required this.subtitle,
    required this.purpose,
    required this.icon,
    required this.accent,
    required this.stats,
    required this.steps,
    required this.facts,
  });

  final String title;
  final String tagline;
  final String subtitle;
  final String purpose;
  final IconData icon;
  final Color accent;
  final List<_GuideStat> stats;
  final List<_GuideStep> steps;
  final List<_GuideFact> facts;
}

class _GuideStat {
  const _GuideStat({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
}

class _GuideStep {
  const _GuideStep({required this.title, required this.body});

  final String title;
  final String body;
}

class _GuideFact {
  const _GuideFact({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;
}

const _guides = <_ModeGuide>[
  // ── Predict ────────────────────────────────────────────────────────────────
  _ModeGuide(
    title: 'PREDICT',
    tagline: 'Answer the match quiz, earn XP',
    subtitle: '// Match Quiz · XP Only',
    purpose:
        'Study a real fixture, answer a short quiz before kickoff, and earn XP '
        'when the match settles.',
    icon: Icons.quiz,
    accent: Cyber.cyan,
    stats: [
      _GuideStat(
        icon: Icons.view_carousel,
        label: 'ONE AT A TIME',
        sub: 'question per page',
        color: Cyber.cyan,
      ),
      _GuideStat(
        icon: Icons.bolt,
        label: 'BOOSTERS',
        sub: '2× and 1.5×',
        color: Cyber.amber,
      ),
      _GuideStat(
        icon: Icons.military_tech,
        label: 'XP ONLY',
        sub: 'never coins',
        color: Cyber.violet,
      ),
    ],
    steps: [
      _GuideStep(
        title: 'Open Matches',
        body:
            'Fixtures are grouped by league. Tap a predictable upcoming match '
            'to start its quiz.',
      ),
      _GuideStep(
        title: 'Answer the quiz',
        body:
            'One question per page — exact score or multiple choice. NEXT '
            'unlocks once you answer the current question.',
      ),
      _GuideStep(
        title: 'Boost your best calls',
        body:
            'Place one 2× and one 1.5× booster on answered questions to '
            'multiply their XP. Move or remove them until predictions lock.',
      ),
      _GuideStep(
        title: 'Lock at kickoff',
        body:
            'Answers stay editable until the match starts, then the screen '
            'turns read-only and shows crowd vote results.',
      ),
      _GuideStep(
        title: 'Reveal the results',
        body:
            'When the match finishes, tap REVEAL RESULTS for the settlement '
            'cinematic. Correct answers credit XP to your progression.',
      ),
    ],
    facts: [
      _GuideFact(
        icon: Icons.military_tech,
        label: 'XP, never coins',
        body: 'Predictions only ever pay XP into your shared level track.',
      ),
      _GuideFact(
        icon: Icons.edit,
        label: 'Edit until kickoff',
        body: 'Re-open a prediction any time before the match starts to change answers.',
      ),
      _GuideFact(
        icon: Icons.history,
        label: 'Review, not replay',
        body: 'A match you already predicted opens as a review list, not a fresh quiz.',
      ),
    ],
  ),

  // ── Pick ──────────────────────────────────────────────────────────────────
  _ModeGuide(
    title: 'PICK',
    tagline: 'Take a position on outcome markets',
    subtitle: '// Outcome Markets · Oz Coins',
    purpose:
        'Browse outcome markets, choose a price, and confirm an Oz Coin amount '
        'on your call.',
    icon: Icons.show_chart,
    accent: Cyber.lime,
    stats: [
      _GuideStat(
        icon: Icons.tune,
        label: 'FILTERS',
        sub: 'sport + market',
        color: Cyber.lime,
      ),
      _GuideStat(
        icon: Icons.sell,
        label: 'PRICED',
        sub: 'per outcome',
        color: Cyber.cyan,
      ),
      _GuideStat(
        icon: Icons.monetization_on,
        label: 'OZ COINS',
        sub: 'your stake',
        color: Cyber.gold,
      ),
    ],
    steps: [
      _GuideStep(
        title: 'Browse markets',
        body:
            'Filter by sport (IPL, EPL, NBA…) and by market type — All Picks, '
            'Matches, Event, or Futures.',
      ),
      _GuideStep(
        title: 'Read the card',
        body:
            'Each market shows the league, the question, close time, volume, '
            'and a price for every outcome.',
      ),
      _GuideStep(
        title: 'Tap an outcome price',
        body:
            'A confirmation sheet opens with your pick, its price, and your '
            'available balance.',
      ),
      _GuideStep(
        title: 'Set your amount',
        body:
            'Adjust the stake in price-step increments — it always stays inside '
            'your balance.',
      ),
      _GuideStep(
        title: 'Confirm the pick',
        body: 'Lock it in. A short success message confirms your position.',
      ),
    ],
    facts: [
      _GuideFact(
        icon: Icons.sports_soccer,
        label: 'Match market',
        body: 'Pick the result of a live or upcoming match.',
      ),
      _GuideFact(
        icon: Icons.help_outline,
        label: 'Binary event',
        body: 'A yes/no question — qualification, a player playing, and so on.',
      ),
      _GuideFact(
        icon: Icons.timeline,
        label: 'Futures',
        body: 'A longer-range outcome with several possible winners.',
      ),
    ],
  ),

  // ── Pitch Duel ─────────────────────────────────────────────────────────────
  _ModeGuide(
    title: 'PITCH DUEL',
    tagline: 'Tactical 4-round card duel',
    subtitle: '// Tactical 4-Round Duel',
    purpose:
        'Turn your card collection into a four-round tactical match — outscore '
        'the CPU for XP and coins.',
    icon: Icons.sports_soccer,
    accent: Cyber.violet,
    stats: [
      _GuideStat(
        icon: Icons.repeat,
        label: '4 ROUNDS',
        sub: 'attack ×2 · defend ×2',
        color: Cyber.violet,
      ),
      _GuideStat(
        icon: Icons.style,
        label: 'PLAYER + ACTION',
        sub: 'each round',
        color: Cyber.cyan,
      ),
      _GuideStat(
        icon: Icons.emoji_events,
        label: 'XP & COINS',
        sub: 'on a win',
        color: Cyber.gold,
      ),
    ],
    steps: [
      _GuideStep(
        title: 'Build a legal deck',
        body: '2 attackers, 2 defenders, 1 goalkeeper, and 6 action cards.',
      ),
      _GuideStep(
        title: 'Toss for role',
        body:
            'A coin flip sets who attacks first; roles alternate, so you attack '
            'twice and defend twice across the match.',
      ),
      _GuideStep(
        title: 'Read the scenario',
        body:
            'Each round drops a football scenario — counter, set piece, box '
            'defense — that tilts the attack vs defense power.',
      ),
      _GuideStep(
        title: 'Pick player + action',
        body:
            'Choose a role-appropriate player card and one action card for the '
            'round.',
      ),
      _GuideStep(
        title: 'Strike the Shot Meter',
        body:
            'Tap to stop the sweeping marker. Perfect timing adds up to +20 '
            'power to your side.',
      ),
      _GuideStep(
        title: 'Resolve and repeat',
        body:
            'The power gap becomes a goal, save, block, miss, foul, or red '
            'card. Highest score after 4 rounds wins.',
      ),
    ],
    facts: [
      _GuideFact(
        icon: Icons.functions,
        label: 'Power formula',
        body: 'Card rating + action power + scenario bonus + a 0–20 swing.',
      ),
      _GuideFact(
        icon: Icons.warning_amber,
        label: 'Risky actions',
        body: 'Carry a 12% chance of a foul (attack) or a red card (defense).',
      ),
      _GuideFact(
        icon: Icons.sports_soccer,
        label: 'Tied at full time',
        body: 'A level match after 4 rounds goes to a penalty shootout.',
      ),
    ],
  ),

  // ── Penalty Shootout ───────────────────────────────────────────────────────
  _ModeGuide(
    title: 'PENALTY SHOOTOUT',
    tagline: 'Sudden-death spot kicks',
    subtitle: '// Sudden-Death Spot Kicks',
    purpose:
        'Your five-man lineup trades spot kicks with the CPU — outsmart the '
        'keeper to win.',
    icon: Icons.gps_fixed,
    accent: Cyber.amber,
    stats: [
      _GuideStat(
        icon: Icons.format_list_numbered,
        label: '5 KICKS EACH',
        sub: 'then sudden death',
        color: Cyber.amber,
      ),
      _GuideStat(
        icon: Icons.open_with,
        label: 'L · C · R',
        sub: 'aim your shot',
        color: Cyber.cyan,
      ),
      _GuideStat(
        icon: Icons.shield,
        label: 'RATINGS MATTER',
        sub: 'tip each duel',
        color: Cyber.lime,
      ),
    ],
    steps: [
      _GuideStep(
        title: 'Set your lineup',
        body:
            'Your five squad players line up in kick order — higher ratings '
            'convert their kicks more often.',
      ),
      _GuideStep(
        title: 'Pick a direction',
        body:
            'Aim left, center, or right by tapping a goal zone. The keeper '
            'dives at the same moment.',
      ),
      _GuideStep(
        title: 'Beat the keeper',
        body: 'You score when your direction differs from the keeper\'s dive.',
      ),
      _GuideStep(
        title: 'Trade kicks',
        body:
            'You and the CPU alternate kicks. Your keeper guards the net on the '
            'CPU\'s turn.',
      ),
      _GuideStep(
        title: 'Sudden death',
        body: 'Level after five kicks each? Sudden-death pairs decide it.',
      ),
    ],
    facts: [
      _GuideFact(
        icon: Icons.shield,
        label: 'Ratings tip the duel',
        body: 'A stronger kicker beats the keeper more reliably.',
      ),
      _GuideFact(
        icon: Icons.flash_on,
        label: 'Early finish',
        body: 'The round can end as soon as one side can no longer catch up.',
      ),
      _GuideFact(
        icon: Icons.sports_soccer,
        label: 'Standalone mode',
        body: 'Played on its own from the Games tab — not tied to a card match.',
      ),
    ],
  ),
];
