import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/match.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../match_history/match_history_pages.dart';
import '../predictions/prediction_match_history_screen.dart';

/// PROFILE tab — player identity over two record cards: MY MATCHES (the
/// prediction quiz) and MY PICKS (the Pitch Duel card game), followed by the
/// card-game utilities (deck builder, all cards, how to play) and settings.
///
/// The layout mirrors the shared design: a banner-headed identity card, two
/// accent-coded stat sections each with a "View History" footer, and a stack of
/// HUD navigation rows. All chrome is built from the shared `Cyber.*` tokens and
/// components so it stays on-brand with the rest of the app.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  // Mirrors the player's standing in the (mock) leaderboard, where the current
  // user sits at rank #12. Surfaced here as MY PICKS · CURRENT RANK.
  static const int _leaderboardRank = 12;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: CyberPlainBackground(child: SizedBox.expand()),
          ),
          SafeArea(
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, game) {
                return BlocBuilder<PredictionCubit, PredictionState>(
                  builder: (context, pred) {
                    final totalPicks = pred.predictions.values.fold<int>(
                      0,
                      (sum, p) => sum + p.answers.length,
                    );
                    final correct = pred.correctPredictions;
                    final predAccuracy = totalPicks == 0
                        ? 0
                        : (correct / totalPicks * 100).round();

                    final duelsPlayed = game.matchHistory.length;
                    final duelWins = game.matchHistory.where(_isWin).length;
                    final winRate = duelsPlayed == 0
                        ? 0
                        : (duelWins / duelsPlayed * 100).round();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _IdentityHeader(game: game),
                        const SizedBox(height: 14),
                        _StatSection(
                          title: 'MY MATCHES',
                          accent: Cyber.violet,
                          icon: const _CrossedSwords(size: 22),
                          stats: [
                            _Stat('MATCHES', '${pred.predictionsMade}'),
                            _Stat('ACCURACY', '$predAccuracy%'),
                            _Stat('PREDICTIONS', '$totalPicks'),
                          ],
                          onViewHistory: () =>
                              showPredictionMatchHistory(context),
                        ),
                        const SizedBox(height: 14),
                        _StatSection(
                          title: 'MY PICKS',
                          accent: Cyber.success,
                          icon: const Icon(
                            Icons.keyboard_double_arrow_up,
                            color: Cyber.success,
                            size: 22,
                          ),
                          stats: [
                            _Stat('MATCHES', '$duelsPlayed'),
                            _Stat('ACCURACY', '$winRate%'),
                            _Stat('CURRENT RANK', '$_leaderboardRank'),
                          ],
                          onViewHistory: () => showMatchHistoryArchive(
                            context,
                            game.matchHistory,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _NavRow(
                          icon: Icons.dashboard_customize,
                          label: 'Deck Builder',
                          onTap: () => _push(
                            context,
                            (nav) => DeckBuilderScreen(onNavigate: nav),
                          ),
                        ),
                        _NavRow(
                          icon: Icons.style,
                          label: 'All Cards',
                          onTap: () => _push(
                            context,
                            (nav) => AllCardsScreen(onNavigate: nav),
                          ),
                        ),
                        _NavRow(
                          icon: Icons.menu_book,
                          label: 'How To Play',
                          onTap: () => _push(
                            context,
                            (nav) => HowToPlayScreen(onNavigate: nav),
                          ),
                        ),
                        _NavRow(
                          icon: Icons.bug_report,
                          label: 'Report a Bug / Mismatch',
                          onTap: () => _showBugReportDialog(context),
                        ),
                        _NavRow(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Settings coming soon'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 3,
        onNavigate: onNavigate,
        includeShop: false,
      ),
    );
  }

  Future<void> _showBugReportDialog(BuildContext context) async {
    final report = await showDialog<_BugReport>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const _BugReportDialog(),
    );

    if (!context.mounted || report == null) return;

    final hasContent = report.content.isNotEmpty;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hasContent
                ? 'Report submitted: ${report.description}'
                : 'Report submitted',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  static bool _isWin(MatchHistoryEntry e) {
    if (e.playerScore != e.opponentScore) {
      return e.playerScore > e.opponentScore;
    }
    return (e.penaltyPlayerScore ?? 0) > (e.penaltyOpponentScore ?? 0);
  }

  void _push(
    BuildContext context,
    Widget Function(ValueChanged<AppSection>) builder,
  ) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => builder((_) => navigator.pop())),
    );
  }
}

class _BugReport {
  const _BugReport({required this.description, required this.content});

  final String description;
  final String content;
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _description = TextEditingController();
  final _content = TextEditingController();

  bool _submittedEmpty = false;

  @override
  void dispose() {
    _description.dispose();
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _description.text.trim();
    final content = _content.text.trim();

    if (description.isEmpty || content.isEmpty) {
      setState(() => _submittedEmpty = true);
      return;
    }

    Navigator.of(
      context,
    ).pop(_BugReport(description: description, content: content));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: CyberPanel(
          accent: Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bug_report,
                          color: Cyber.cyan,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REPORT',
                          style: Cyber.label(
                            11,
                            color: Cyber.cyan,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'BUG / MISMATCH',
                      style: Cyber.display(16, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 14),
                    _BugReportField(
                      controller: _description,
                      label: 'Description',
                      hint: 'Short summary',
                      error:
                          _submittedEmpty && _description.text.trim().isEmpty,
                    ),
                    const SizedBox(height: 12),
                    _BugReportField(
                      controller: _content,
                      label: 'Content',
                      hint: 'What happened?',
                      maxLines: 5,
                      error: _submittedEmpty && _content.text.trim().isEmpty,
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _BugReportAction(
                        label: 'Cancel',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff2a303c)),
                    Expanded(
                      child: _BugReportAction(
                        label: 'Submit >',
                        color: Cyber.cyan,
                        onTap: _submit,
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

class _BugReportField extends StatelessWidget {
  const _BugReportField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.error,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool error;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final borderColor = error ? Cyber.red : const Color(0xff343b49);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.3),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Cyber.body(13),
          cursorColor: Cyber.cyan,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Cyber.body(13, color: Cyber.muted),
            filled: true,
            fillColor: Cyber.bg.withValues(alpha: 0.45),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: borderColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _BugReportAction extends StatelessWidget {
  const _BugReportAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Cyber.label(11, color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}

// ─── Identity header ──────────────────────────────────────────────────────────

/// The banner-headed identity card: a glowing emblem strip that fades into the
/// panel, the player avatar + level badge, and the player name. This is the one
/// focal (glowing) surface on the screen, per the design glow rule.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(Cyber.cyan),
          border: Border.all(color: Cyber.border),
          boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.16, blur: 20, spread: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _EmblemBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Avatar(),
                      const Spacer(),
                      PlayerLevelBadge(progression: game.progression),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PLAYER ONE',
                    style: Cyber.display(24, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LVL ${game.progression.playerLevel} · ${game.progression.totalXP} XP',
                    style: Cyber.label(
                      11,
                      color: Cyber.muted,
                      letterSpacing: 1,
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

/// Decorative banner: a textured cyan→violet glow strip with a centred crest,
/// fading into the card surface at the bottom.
class _EmblemBanner extends StatelessWidget {
  const _EmblemBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Cyber.violet.withValues(alpha: 0.28),
                  Cyber.cyan.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay(vignette: false)),
          // Crest emblem, floated to the right like the reference.
          const Align(alignment: Alignment(0.55, 0.0), child: _Crest()),
          // Fade the banner into the card surface below it.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Cyber.panel2],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: Cyber.border),
        boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.3, blur: 18, spread: -4),
      ),
      child: const Icon(Icons.shield_moon, color: Cyber.cyan, size: 32),
    );
  }
}

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Cyber.cyan, Cyber.violet],
        ),
        border: Border.all(color: Cyber.border, width: 2),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 40),
    );
  }
}

// ─── Stat section (MY MATCHES / MY PICKS) ─────────────────────────────────────

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatSection extends StatelessWidget {
  const _StatSection({
    required this.title,
    required this.accent,
    required this.icon,
    required this.stats,
    required this.onViewHistory,
  });

  final String title;
  final Color accent;
  final Widget icon;
  final List<_Stat> stats;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: Cyber.panelGradient(accent),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: 24, height: 24, child: Center(child: icon)),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Cyber.display(20, color: accent, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            // Stat tiles.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(stat: stats[i], accent: accent),
                    ),
                  ],
                ],
              ),
            ),
            // View History footer.
            _ViewHistoryRow(accent: accent, onTap: onViewHistory),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, required this.accent});

  final _Stat stat;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.16),
            Cyber.bg.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Cyber.body(
              10,
              color: Colors.white.withValues(alpha: 0.8),
              weight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              style: Cyber.display(
                24,
                letterSpacing: 0.5,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewHistoryRow extends StatelessWidget {
  const _ViewHistoryRow({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: accent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'View History',
                  style: Cyber.body(15, weight: FontWeight.w600),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Cyber.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── HUD navigation rows ──────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  static const _borderColor = Cyber.border;

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.5),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Cyber.cyan, size: 20),
                  const SizedBox(width: 12),
                  Text(label, style: Cyber.body(15, weight: FontWeight.w600)),
                ],
              ),
              const Icon(Icons.chevron_right, color: Cyber.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Crossed-swords glyph (MY MATCHES) ────────────────────────────────────────

/// The crossed-swords glyph used for the MATCHES tab on the prediction hub,
/// reused here so MY MATCHES carries the same icon language as the design.
class _CrossedSwords extends StatelessWidget {
  const _CrossedSwords({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CrossedSwordsPainter(Cyber.violet)),
    );
  }
}

class _CrossedSwordsPainter extends CustomPainter {
  const _CrossedSwordsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final blade = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guard = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.22, h * 0.84),
      Offset(w * 0.82, h * 0.18),
      blade,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.84),
      Offset(w * 0.18, h * 0.18),
      blade,
    );
    canvas.drawLine(
      Offset(w * 0.12, h * 0.66),
      Offset(w * 0.34, h * 0.84),
      guard,
    );
    canvas.drawLine(
      Offset(w * 0.66, h * 0.84),
      Offset(w * 0.88, h * 0.66),
      guard,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossedSwordsPainter old) => old.color != color;
}
