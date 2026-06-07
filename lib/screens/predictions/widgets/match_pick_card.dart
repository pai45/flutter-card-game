import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/sport_match.dart';
import '../../../models/team_standing.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';
import '../../shop/shop_screen.dart' show CoinIcon;

/// A fixture rendered as a quick market: HOME / DRAW / AWAY (football) or
/// HOME / AWAY (cricket). The split is derived from the league standings —
/// the stronger side carries the higher share — so the prices stay consistent
/// with the table without any extra seed data. Used in the league + team detail
/// "PICKS CENTER".
class MatchPickCard extends StatefulWidget {
  const MatchPickCard({
    required this.match,
    required this.standings,
    super.key,
  });

  final SportMatch match;
  final List<TeamStanding> standings;

  @override
  State<MatchPickCard> createState() => _MatchPickCardState();
}

class _MatchPickCardState extends State<MatchPickCard> {
  String? _selectedKey;

  void _openSheet({
    required String key,
    required String pick,
    required int price,
    required Color color,
  }) {
    playSound(SoundEffect.uiTap);
    setState(() => _selectedKey = key);
    final m = widget.match;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _PickConfirmSheet(
        question: '${m.home.name} vs ${m.away.name}',
        selectedPick: pick,
        price: price,
        color: color,
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedKey = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final split = _pickSplit(m, widget.standings);
    final isFootball = m.sport == Sport.football;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 15, smallCut: 2),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff121b30), Color(0xff0e1628)],
          ),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TeamLine(team: m.home, score: m.homeScore),
                        const SizedBox(height: 9),
                        _TeamLine(team: m.away, score: m.awayScore),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(match: m),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _PickButton(
                    label: m.home.shortName,
                    price: split.home,
                    color: m.home.color,
                    selected: _selectedKey == 'home',
                    onTap: () => _openSheet(
                      key: 'home',
                      pick: m.home.name,
                      price: split.home,
                      color: m.home.color,
                    ),
                  ),
                ),
                if (isFootball)
                  Expanded(
                    child: _PickButton(
                      label: 'DRAW',
                      price: split.draw ?? 0,
                      color: const Color(0xff334155),
                      selected: _selectedKey == 'draw',
                      onTap: () => _openSheet(
                        key: 'draw',
                        pick: 'Draw',
                        price: split.draw ?? 0,
                        color: const Color(0xff334155),
                      ),
                    ),
                  ),
                Expanded(
                  child: _PickButton(
                    label: m.away.shortName,
                    price: split.away,
                    color: m.away.color,
                    selected: _selectedKey == 'away',
                    onTap: () => _openSheet(
                      key: 'away',
                      pick: m.away.name,
                      price: split.away,
                      color: m.away.color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Win-share split derived from standings points (stronger side → higher share).
/// Football reserves a fixed draw share; cricket is two-way. Values sum to 100.
({int home, int? draw, int away}) _pickSplit(
  SportMatch match,
  List<TeamStanding> standings,
) {
  double pointsOf(String teamId) {
    for (final s in standings) {
      if (s.team.id == teamId) return s.points.toDouble();
    }
    return 20; // neutral fallback when a side isn't in the table
  }

  final home = pointsOf(match.home.id);
  final away = pointsOf(match.away.id);
  final total = home + away == 0 ? 1 : home + away;

  if (match.sport == Sport.cricket) {
    final h = ((home / total) * 100).round().clamp(5, 95);
    return (home: h, draw: null, away: 100 - h);
  }
  const draw = 26;
  const rest = 100 - draw;
  final h = ((home / total) * rest).round().clamp(5, rest - 5);
  return (home: h, draw: draw, away: rest - h);
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, this.score});

  final SportTeam team;
  final String? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Badge(team: team),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(13, weight: FontWeight.w800, height: 1),
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          Text(
            score!,
            style: Cyber.label(
              10,
              color: Colors.white,
              letterSpacing: 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.team});

  final SportTeam team;

  @override
  Widget build(BuildContext context) {
    return TeamLogo(team: team, width: 30, height: 24);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return switch (match.status) {
      MatchStatus.live => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffff2f35),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            match.liveMinute != null ? "LIVE ${match.liveMinute}'" : 'LIVE',
            style: Cyber.label(
              9,
              color: const Color(0xffff2f35),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      MatchStatus.finished => Text(
        'FT',
        style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1),
      ),
      MatchStatus.upcoming => Text(
        _formatTime(match.kickoff),
        style: Cyber.label(
          11,
          color: const Color(0xffc8a45a),
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    };
  }
}

class _PickButton extends StatefulWidget {
  const _PickButton({
    required this.label,
    required this.price,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int price;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PickButton> createState() => _PickButtonState();
}

class _PickButtonState extends State<_PickButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final light = widget.color.computeLuminance() > 0.55;
    final ink = light ? const Color(0xff15202e) : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        height: 42,
        transform: Matrix4.translationValues(0, _pressed ? 1 : 0, 0),
        decoration: BoxDecoration(
          color: _pressed
              ? Color.lerp(widget.color, Colors.black, 0.18)
              : widget.color,
          border: Border.all(
            color: widget.selected ? Cyber.cyan : Colors.transparent,
            width: widget.selected ? 1.5 : 0,
          ),
          boxShadow: widget.selected
              ? Cyber.glow(Cyber.cyan, alpha: 0.4, blur: 14, spread: -3)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: Cyber.label(11, color: ink, letterSpacing: 0.6),
            ),
            const SizedBox(width: 5),
            CoinIcon(size: 14),
            const SizedBox(width: 3),
            Text(
              '${widget.price}',
              style: Cyber.label(
                12,
                color: ink,
                letterSpacing: 0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm sheet ─────────────────────────────────────────────────────────────
class _PickConfirmSheet extends StatefulWidget {
  const _PickConfirmSheet({
    required this.question,
    required this.selectedPick,
    required this.price,
    required this.color,
  });

  final String question;
  final String selectedPick;
  final int price;
  final Color color;

  @override
  State<_PickConfirmSheet> createState() => _PickConfirmSheetState();
}

class _PickConfirmSheetState extends State<_PickConfirmSheet> {
  late int _amount = widget.price;

  @override
  Widget build(BuildContext context) {
    final balance = context.select<GameBloc, int>((b) => b.state.coins);
    final safeBalance = balance == 0 ? 100 : balance;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 18, smallCut: 4),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff152139), Color(0xff0b101c)],
            ),
            border: Border.all(color: Cyber.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HudLine(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONFIRM PICK',
                      style: Cyber.label(
                        12,
                        color: Cyber.cyan,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.question,
                      style: Cyber.body(
                        16,
                        weight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SummaryTile(
                          label: 'PICK',
                          child: Text(
                            widget.selectedPick,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.label(13, color: widget.color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SummaryTile(
                          label: 'STAKE',
                          child: _CoinValue(value: _amount),
                        ),
                        const SizedBox(width: 8),
                        _SummaryTile(
                          label: 'BALANCE',
                          child: _CoinValue(value: safeBalance),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AmountStepper(
                      value: _amount,
                      step: widget.price == 0 ? 10 : widget.price,
                      max: safeBalance,
                      onChanged: (v) => setState(() => _amount = v),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetAction(
                        label: 'CANCEL',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff243654)),
                    Expanded(
                      child: _SheetAction(
                        label: 'CONFIRM PICK',
                        color: Cyber.cyan,
                        onTap: () {
                          playSound(SoundEffect.uiTap);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xff121b30),
                              content: Text(
                                'Pick confirmed with $_amount Oz Coins',
                                style: Cyber.body(12),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          border: Border.all(color: const Color(0xff243654)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _CoinValue extends StatelessWidget {
  const _CoinValue({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: 14),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: Cyber.label(
            13,
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _AmountStepper extends StatelessWidget {
  const _AmountStepper({
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: () => onChanged((value - step).clamp(step, max)),
        ),
        Expanded(
          child: Container(
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              border: Border.all(color: const Color(0xff243654)),
            ),
            child: _CoinValue(value: value),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: () => onChanged((value + step).clamp(step, max)),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xff16223a),
          border: Border.all(color: Cyber.border),
        ),
        child: Icon(icon, color: Cyber.cyan, size: 18),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          style: Cyber.label(12, color: color, letterSpacing: 1.2),
        ),
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
