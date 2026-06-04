import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_segmented_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import 'widgets/match_prediction_card.dart';

/// The revamped HOME: a sports-prediction hub with three sections —
/// MATCHES (league-grouped fixtures with prediction quizzes), PICK (the user's
/// own predictions), and GAMES (the Pitch Duel card game + future modes).
class PredictionHomeScreen extends StatefulWidget {
  const PredictionHomeScreen({
    required this.onNavigate,
    required this.onOpenMatch,
    required this.onOpenGame,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final ValueChanged<SportMatch> onOpenMatch;
  final VoidCallback onOpenGame;

  @override
  State<PredictionHomeScreen> createState() => _PredictionHomeScreenState();
}

class _PredictionHomeScreenState extends State<PredictionHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PredictionBackground()),
          SafeArea(
            child: Column(
              children: [
                const _PredictionHeader(),
                CyberSegmentedTabs(
                  items: const ['MATCHES', 'PICK', 'GAMES'],
                  activeIndex: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_tab),
                      child: _buildTab(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 0,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  Widget _buildTab() {
    return switch (_tab) {
      0 => _MatchesTab(onOpenMatch: widget.onOpenMatch),
      1 => _PickTab(onOpenMatch: widget.onOpenMatch),
      _ => _GamesTab(onOpenGame: widget.onOpenGame),
    };
  }
}

// ── Background ────────────────────────────────────────────────────────────────
class _PredictionBackground extends StatelessWidget {
  const _PredictionBackground();

  @override
  Widget build(BuildContext context) {
    // Try the (optional) bespoke home image; fall back to the textured cyber
    // background so a missing asset never breaks the screen.
    return Image.asset(
      'assets/backgrounds/prediction_home.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.35),
      colorBlendMode: BlendMode.darken,
      errorBuilder: (_, _, _) => const CyberBackground(
        animated: true,
        child: SizedBox.expand(),
      ),
    );
  }
}

// ── Header: brand + currency ──────────────────────────────────────────────────
class _PredictionHeader extends StatelessWidget {
  const _PredictionHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Cyber.panel.withValues(alpha: 0.55), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(color: Cyber.cyan.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PREDICT',
                style: Cyber.display(24, letterSpacing: 1.8).copyWith(
                  shadows: Cyber.glow(Cyber.cyan, alpha: 0.6, blur: 14)
                      .map((s) => Shadow(color: s.color, blurRadius: s.blurRadius))
                      .toList(),
                ),
              ),
              Text(
                '// MATCH PROTOCOL',
                style: Cyber.label(
                  9,
                  color: Cyber.cyan.withValues(alpha: 0.55),
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          const _CurrencyPills(),
        ],
      ),
    );
  }
}

class _CurrencyPills extends StatelessWidget {
  const _CurrencyPills();

  @override
  Widget build(BuildContext context) {
    final coins = context.select<GameBloc, int>((b) => b.state.coins);
    return Row(
      children: [
        // Gems placeholder (0) — a second currency reserved for future use.
        _Pill(
          icon: const Icon(Icons.change_history, color: Cyber.violet, size: 16),
          value: '0',
        ),
        const SizedBox(width: 8),
        _Pill(icon: CoinIcon(size: 18), value: _formatInt(coins)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.value});
  final Widget icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.7),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: Cyber.displayFont,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MATCHES tab ───────────────────────────────────────────────────────────────
class _MatchesTab extends StatelessWidget {
  const _MatchesTab({required this.onOpenMatch});
  final ValueChanged<SportMatch> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, state) {
        if (state.loading) {
          return const Center(
            child: CircularProgressIndicator(color: Cyber.cyan),
          );
        }
        final grouped = state.fixturesByLeague;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(
              children: [
                Text(
                  'TODAY',
                  style: Cyber.display(15, letterSpacing: 1.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${state.fixtures.length})',
                  style: Cyber.label(13, color: Cyber.muted),
                ),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    color: Cyber.muted, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    SectionLabel(label: entry.key.shortCode),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: entry.key.accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
              for (final match in entry.value) ...[
                MatchPredictionCard(
                  match: match,
                  prediction: state.predictionFor(match.id),
                  onTap: (match.predictable ||
                          state.predictionFor(match.id) != null)
                      ? () => onOpenMatch(match)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

// ── PICK tab ──────────────────────────────────────────────────────────────────
class _PickTab extends StatelessWidget {
  const _PickTab({required this.onOpenMatch});
  final ValueChanged<SportMatch> onOpenMatch;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PredictionCubit, PredictionState>(
      builder: (context, state) {
        final picks = state.fixtures
            .where((m) => state.predictionFor(m.id) != null)
            .toList();
        if (picks.isEmpty) {
          return _EmptyState(
            icon: Icons.touch_app_outlined,
            title: 'NO PICKS YET',
            message: 'Predict a match in the MATCHES tab to see it here.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final match in picks) ...[
              MatchPredictionCard(
                match: match,
                prediction: state.predictionFor(match.id),
                onTap: () => onOpenMatch(match),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

// ── GAMES tab ─────────────────────────────────────────────────────────────────
class _GamesTab extends StatelessWidget {
  const _GamesTab({required this.onOpenGame});
  final VoidCallback onOpenGame;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _GameTile(
          title: 'PITCH DUEL',
          subtitle: 'TACTICAL CARD DUEL',
          icon: Icons.sports_esports,
          accent: Cyber.cyan,
          onTap: onOpenGame,
        ),
        const SizedBox(height: 12),
        _GameTile(
          title: 'QUIZ STREAK',
          subtitle: 'COMING SOON',
          icon: Icons.bolt,
          accent: Cyber.violet,
          locked: true,
        ),
        const SizedBox(height: 12),
        _GameTile(
          title: 'ACCURACY CHALLENGE',
          subtitle: 'COMING SOON',
          icon: Icons.track_changes,
          accent: Cyber.gold,
          locked: true,
        ),
      ],
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onTap,
        child: CyberPanel(
          accent: accent,
          glow: !locked,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Cyber.display(17, letterSpacing: 1),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Cyber.label(9, color: Cyber.muted,
                          letterSpacing: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: locked ? Cyber.muted : accent,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Cyber.muted, size: 48),
            const SizedBox(height: 16),
            Text(title, style: Cyber.display(18, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Cyber.body(13, color: Cyber.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
