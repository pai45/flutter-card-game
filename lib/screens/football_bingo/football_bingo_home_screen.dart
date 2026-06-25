import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../config/theme.dart';
import '../../models/football_bingo.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';

class FootballBingoHomeScreen extends StatelessWidget {
  const FootballBingoHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final FootballBingoState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final dayKeys = state.unlockedDayKeys.reversed.toList();
    final today = state.todayKey;
    final archive = dayKeys.where((key) => key != today).toList();
    final progress = state.archive.progressByDay[today]!;
    final heroAccent = progress.completed ? Cyber.lime : Cyber.amber;

    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: _HomeHeader(onBack: onBack),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _TodayHero(
                puzzle: state.puzzle,
                progress: progress,
                accent: heroAccent,
                onTap: () => _play(today),
              ),
              const SizedBox(height: 14),
              HudCtaButton(
                label: progress.completed
                    ? 'REVIEW GRID'
                    : progress.solvedCellIds.isNotEmpty
                    ? 'RESUME GRID'
                    : 'PLAY TODAY\'S GRID',
                icon: Icons.play_arrow,
                accent: heroAccent,
                onTap: () => onOpenDay(today),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'COMPLETED',
                      value: '${state.completedCount}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: 'UNLOCKED',
                      value: '${state.unlockedDayKeys.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel(label: 'Daily Archive'),
              const SizedBox(height: 10),
              if (archive.isEmpty)
                const _EmptyArchive()
              else
                for (final dayKey in archive) ...[
                  _ArchiveTile(
                    dayKey: dayKey,
                    progress: state.archive.progressByDay[dayKey]!,
                    onTap: () => onOpenDay(dayKey),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  void _play(String dayKey) {
    playSound(SoundEffect.uiTap);
    HapticFeedback.mediumImpact();
    onOpenDay(dayKey);
  }
}

class _HomeHeader extends StatelessWidget implements PreferredSizeWidget {
  const _HomeHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 66,
      backgroundColor: Cyber.bg,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.borderMuted)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back to matches',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onBack();
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BACK TO MATCHES',
                    style: Cyber.label(12, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'FOOTBALL BINGO',
                    style: Cyber.display(20, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
            const Icon(Icons.grid_view, color: Cyber.amber, size: 24),
          ],
        ),
      ),
    );
  }
}

/// The face-off hero — the one focal, glowing element on the page. Previews the
/// real 3x3 grid, lifelines as pips, and the solved meter.
class _TodayHero extends StatelessWidget {
  const _TodayHero({
    required this.puzzle,
    required this.progress,
    required this.accent,
    required this.onTap,
  });

  final FootballBingoPuzzle puzzle;
  final FootballBingoProgress progress;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final solved = progress.solvedCellIds.length;
    return CyberPanel(
      accent: accent,
      glow: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'TODAY\'S GRID',
                    style: Cyber.display(18, color: Colors.white),
                  ),
                ),
                CyberChip(label: 'DAILY', color: accent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              puzzle.title.toUpperCase(),
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
            ),
            const SizedBox(height: 14),
            _GridPreview(
              puzzle: puzzle,
              solvedIds: progress.solvedCellIds.toSet(),
              accent: accent,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _LifelinePips(remaining: progress.lifelines, accent: accent),
                const Spacer(),
                Text(
                  '$solved/9 CELLS',
                  style: Cyber.display(
                    13,
                    color: accent,
                  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CyberProgressBar(value: solved / 9, accent: accent, height: 8),
          ],
        ),
      ),
    );
  }
}

/// A compact 3x3 puzzle preview: top row of country tags, left column of club
/// tags, and 9 cells that read solved (lime) or locked (muted). Cells reveal
/// with a staggered slide-up.
class _GridPreview extends StatelessWidget {
  const _GridPreview({
    required this.puzzle,
    required this.solvedIds,
    required this.accent,
  });

  final FootballBingoPuzzle puzzle;
  final Set<String> solvedIds;
  final Color accent;

  static const double _labelExtent = 40;

  @override
  Widget build(BuildContext context) {
    // Cap the width so cells stay compact on wide screens (tablets / the test
    // surface); without this the square cells balloon to fill the panel.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: _grid(),
      ),
    );
  }

  Widget _grid() {
    return Column(
      children: [
        // Column header (countries).
        Row(
          children: [
            const SizedBox(width: _labelExtent, height: _labelExtent),
            for (final column in puzzle.columns)
              Expanded(child: _AxisTag(label: column.shortLabel)),
          ],
        ),
        for (var row = 0; row < kFootballBingoGridSize; row++)
          Row(
            children: [
              SizedBox(
                width: _labelExtent,
                child: _AxisTag(label: puzzle.rows[row].shortLabel),
              ),
              for (var col = 0; col < kFootballBingoGridSize; col++)
                Expanded(
                  child: CyberSlideUpFadeIn(
                    delay: Duration(milliseconds: 40 * (row * 3 + col)),
                    offset: 14,
                    child: _GridCell(
                      solved: solvedIds.contains(puzzle.cellAt(row, col).id),
                      accent: accent,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _AxisTag extends StatelessWidget {
  const _AxisTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Center(
        child: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Cyber.label(10, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.solved, required this.accent});

  final bool solved;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = solved ? Cyber.lime : Cyber.muted;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipPath(
          clipper: _SmallCyberClipper(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: Cyber.panelGradient(solved ? Cyber.lime : Cyber.panel),
              border: Border.all(color: color.withValues(alpha: 0.55)),
            ),
            child: Center(
              child: Icon(
                solved ? Icons.check : Icons.lock_outline,
                color: color.withValues(alpha: solved ? 0.95 : 0.4),
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tighter corner-cut for the small preview cells (the default 12px chamfer is
/// too large at this size).
class _SmallCyberClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => CyberClipper.buildPath(size, cut: 5);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LifelinePips extends StatelessWidget {
  const _LifelinePips({required this.remaining, required this.accent});

  final int remaining;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kFootballBingoStartingLifelines; i++)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Icon(
              i < remaining ? Icons.favorite : Icons.favorite_border,
              color: i < remaining
                  ? accent
                  : Cyber.muted.withValues(alpha: 0.5),
              size: 14,
            ),
          ),
      ],
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.dayKey,
    required this.progress,
    required this.onTap,
  });

  final String dayKey;
  final FootballBingoProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = progress.completed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CyberPanel(
        accent: done ? Cyber.lime : Cyber.cyan,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Cyber.cyan, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayKey,
                    style: Cyber.display(13, color: Colors.white).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 5),
                  CyberChip(
                    label: done ? 'COMPLETED' : 'ANSWER KEY',
                    color: done ? Cyber.lime : Cyber.cyan,
                  ),
                ],
              ),
            ),
            Text(
              done ? '9/9' : 'VIEW',
              style: Cyber.display(
                12,
                color: done ? Cyber.lime : Cyber.cyan,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            value,
            style: Cyber.display(20, color: Cyber.amber).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Cyber.label(9, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _EmptyArchive extends StatelessWidget {
  const _EmptyArchive();

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Text(
        'Previous daily grids will appear here after tomorrow unlocks.',
        style: Cyber.body(12, color: Cyber.muted),
      ),
    );
  }
}
