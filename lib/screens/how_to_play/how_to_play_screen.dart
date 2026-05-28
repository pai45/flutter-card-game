import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'How to Play',
      subtitle: '// Master the 4-Round Duel',
      leading: IconButton(
        onPressed: () => widget.onNavigate(AppSection.home),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _OverviewStrip(),
          ),
          const SizedBox(height: 20),
          _StepCarousel(
            controller: _controller,
            page: _page,
            onPageChanged: (i) => setState(() => _page = i),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PowerFormula(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const _QuickRules(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Data ────────────────────────────────────────────────────────────────────

class _Step {
  const _Step({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.hint,
  });

  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String hint;
}

const _steps = [
  _Step(
    index: 1,
    icon: Icons.style,
    color: Cyber.violet,
    title: 'Build Your Deck',
    body: 'Choose 2 attackers, 2 defenders, and 6 action cards to form your squad.',
    hint: '2 ATK   ·   2 DEF   ·   6 ACT',
  ),
  _Step(
    index: 2,
    icon: Icons.toll,
    color: Cyber.amber,
    title: 'Toss for Role',
    body: 'Coin flip decides who attacks first. Roles alternate every round after.',
    hint: 'HEADS = ATTACK   ·   TAILS = DEFEND',
  ),
  _Step(
    index: 3,
    icon: Icons.flag,
    color: Cyber.lime,
    title: 'Reveal Scenario',
    body: 'A bonus scenario drops each round. Read it — it changes everything.',
    hint: 'QUICK COUNTER   ·   SET PIECE   ·   1V1 DUEL',
  ),
  _Step(
    index: 4,
    icon: Icons.bolt,
    color: Cyber.cyan,
    title: 'Lock Your Move',
    body: 'Play 1 player card + 1 action card before the round resolves.',
    hint: 'PLAYER  +  ACTION  =  POWER',
  ),
  _Step(
    index: 5,
    icon: Icons.sports_soccer,
    color: Cyber.success,
    title: 'Resolve the Round',
    body: 'Rating, action boost, scenario bonus, and a luck roll decide the outcome.',
    hint: 'GOAL   ·   SAVED   ·   BLOCKED   ·   FOUL',
  ),
  _Step(
    index: 6,
    icon: Icons.emoji_events,
    color: Cyber.magenta,
    title: 'Penalty Shootout',
    body: 'Still tied after 4 rounds? Best of 5 kicks, then sudden death.',
    hint: 'BEST OF 5   →   SUDDEN DEATH',
  ),
];

class _Faq {
  const _Faq({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final IconData icon;
  final String question;
  final String answer;
}

const _faqs = [
  _Faq(
    icon: Icons.replay,
    question: 'Can I reuse cards?',
    answer: 'Yes. Cards can be reused unless a player gets a red card.',
  ),
  _Faq(
    icon: Icons.dangerous,
    question: 'What does a red card do?',
    answer: 'That player card is blocked for all remaining rounds.',
  ),
  _Faq(
    icon: Icons.swap_horiz,
    question: 'When do roles change?',
    answer: 'After Round 1, Attack and Defense alternate automatically.',
  ),
  _Faq(
    icon: Icons.sports_soccer,
    question: 'When do penalties happen?',
    answer: 'Only when the match is tied after 4 rounds.',
  ),
];

// ── Overview strip ───────────────────────────────────────────────────────────

class _OverviewStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OverviewStat(
          icon: Icons.people,
          label: '4 ROUNDS',
          sub: '1 move each',
          color: Cyber.cyan,
        ),
        const SizedBox(width: 8),
        _OverviewStat(
          icon: Icons.style,
          label: 'PICK CARDS',
          sub: 'Player + Action',
          color: Cyber.violet,
        ),
        const SizedBox(width: 8),
        _OverviewStat(
          icon: Icons.emoji_events,
          label: 'OUTSCORE',
          sub: 'Win the duel',
          color: Cyber.gold,
        ),
      ],
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Cyber.muted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step carousel ────────────────────────────────────────────────────────────

class _StepCarousel extends StatelessWidget {
  const _StepCarousel({
    required this.controller,
    required this.page,
    required this.onPageChanged,
  });

  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'Orbitron',
                ),
              ),
              const Spacer(),
              Text(
                '${page + 1} / ${_steps.length}',
                style: const TextStyle(
                  color: Cyber.muted,
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 228,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: _steps.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StepCard(step: _steps[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_steps.length, (i) {
            final active = i == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? _steps[page].color
                    : Cyber.muted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: step.color,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.12),
                  border: Border.all(color: step.color.withValues(alpha: 0.45)),
                ),
                child: Icon(step.icon, color: step.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      color: step.color.withValues(alpha: 0.18),
                      child: Text(
                        'STEP ${step.index.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: step.color,
                          fontFamily: 'Orbitron',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      step.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            step.body,
            style: const TextStyle(
              color: Color(0xffd1d5db),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            color: step.color.withValues(alpha: 0.08),
            child: Text(
              step.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: step.color.withValues(alpha: 0.9),
                fontFamily: 'Orbitron',
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Power formula ────────────────────────────────────────────────────────────

class _PowerFormula extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'Power Check'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _FormulaChip(
                label: 'RATING',
                color: Cyber.cyan,
                icon: Icons.person,
              ),
              const _Op('+'),
              _FormulaChip(
                label: 'ACTION',
                color: Cyber.amber,
                icon: Icons.bolt,
              ),
              const _Op('+'),
              _FormulaChip(
                label: 'BONUS',
                color: Cyber.lime,
                icon: Icons.star,
              ),
              const _Op('+'),
              _FormulaChip(
                label: 'LUCK',
                color: Cyber.magenta,
                icon: Icons.casino,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const HudLine(),
          const SizedBox(height: 10),
          const Text(
            'Smart picks improve your odds. Risky cards can win big — or punish you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Cyber.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaChip extends StatelessWidget {
  const _FormulaChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontFamily: 'Orbitron',
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _Op extends StatelessWidget {
  const _Op(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Cyber.muted,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

// ── Quick rules ──────────────────────────────────────────────────────────────

class _QuickRules extends StatelessWidget {
  const _QuickRules();

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'Quick Rules'),
          const SizedBox(height: 12),
          for (var i = 0; i < _faqs.length; i++) ...[
            _FaqTile(faq: _faqs[i]),
            if (i < _faqs.length - 1)
              Divider(
                color: Cyber.violet.withValues(alpha: 0.2),
                height: 16,
              ),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.faq.icon, color: Cyber.violet, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.faq.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Onest',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Cyber.muted,
                size: 18,
              ),
            ],
          ),
          AnimatedCrossFade(
            alignment: Alignment.topLeft,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 26, top: 6),
              child: Text(
                widget.faq.answer,
                style: const TextStyle(
                  color: Cyber.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
