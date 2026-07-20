import 'dart:async';
import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../models/guess_player.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

class GuessPlayerHomeScreen extends StatefulWidget {
  const GuessPlayerHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenToday,
    required this.onOpenLogs,
    required this.onRetry,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;
  final VoidCallback onRetry;

  @override
  State<GuessPlayerHomeScreen> createState() => _GuessPlayerHomeScreenState();
}

class _GuessPlayerHomeScreenState extends State<GuessPlayerHomeScreen> {
  Timer? _ticker;
  Duration _untilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!mounted) return;
    setState(() => _untilReset = tomorrow.difference(now));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'DAILY CAREER INTEL',
      subtitle: 'GUESS THE PLAYER',
      leading: IconButton(
        tooltip: 'Back to games',
        onPressed: () {
          playSound(SoundEffect.uiTap);
          widget.onBack();
        },
        icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
      ),
      rightSlot: const Icon(
        Icons.person_search_rounded,
        color: Cyber.magenta,
        size: 22,
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (widget.state.loadStatus == GuessPlayerLoadStatus.loading) {
      return const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: Cyber.magenta,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (widget.state.loadStatus == GuessPlayerLoadStatus.error) {
      return CyberNoDataState(
        icon: Icons.sync_problem_rounded,
        title: 'INTEL LINK FAILED',
        message:
            widget.state.errorMessage ??
            'The daily mystery could not be loaded.',
        accent: Cyber.danger,
        actionLabel: 'RETRY LINK',
        actionIcon: Icons.refresh,
        onAction: widget.onRetry,
      );
    }

    final record =
        widget.state.archive.resultsByDay[widget.state.currentDayKey];
    final archive = widget.state.archive;
    final streak = archive.solveStreak(widget.state.currentDayKey);
    final winRate = (archive.winRate * 100).round();
    final averageAttempts = archive.averageAttempts;
    final ctaLabel = switch (record?.status) {
      GuessPlayerResultStatus.inProgress
          when (record?.startedAtEpochMs ?? 0) > 0 =>
        'RESUME',
      GuessPlayerResultStatus.inProgress => 'PLAY',
      _ => 'REVIEW',
    };

    return CyberArenaBackground(
      assetPath: 'assets/backgrounds/home_stadium.png',
      accent: Cyber.magenta,
      secondaryAccent: Cyber.cyan,
      assetOpacity: 0.2,
      horizonColor: Cyber.violet,
      topShadeAlpha: 0.22,
      middleShadeAlpha: 0.38,
      bottomShadeAlpha: 0.86,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CyberSlideUpFadeIn(
                    child: HudCornerFrame(
                      accent: Cyber.magenta,
                      padding: const EdgeInsets.all(16),
                      child: _Hero(
                        dayKey: widget.state.currentDayKey,
                        resetLabel: _formatCountdown(_untilReset),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CyberSlideUpFadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'SOLVE STREAK',
                            value: '$streak',
                            accent: streak > 0 ? Cyber.success : Cyber.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'WIN RATE',
                            value: '$winRate%',
                            accent: Cyber.cyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            label: 'AVG TRIES',
                            value: averageAttempts == 0
                                ? '—'
                                : averageAttempts.toStringAsFixed(1),
                            accent: Cyber.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CyberSlideUpFadeIn(
                    delay: const Duration(milliseconds: 170),
                    child: _AllTimeStrip(
                      solved: archive.solvedCount,
                      played: archive.completedCount,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CyberSlideUpFadeIn(
                    delay: const Duration(milliseconds: 240),
                    child: HudCtaButton(
                      label: ctaLabel,
                      icon: Icons.radar_rounded,
                      accent: Cyber.magenta,
                      tapSound: SoundEffect.playMatch,
                      onTap: widget.onOpenToday,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CyberSlideUpFadeIn(
                    delay: const Duration(milliseconds: 320),
                    child: _ArchiveLink(onTap: widget.onOpenLogs),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.dayKey, required this.resetLabel});

  final String dayKey;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.magenta.withValues(alpha: 0.55)),
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            color: Cyber.magenta,
            size: 34,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CLASSIFIED PLAYER',
                style: Cyber.display(
                  18,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Decode six career signals. Earlier solves earn more XP.',
                style: Cyber.body(12, color: Cyber.muted, height: 1.3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  CyberChip(label: dayKey, color: Cyber.cyan),
                  CyberChip(label: 'RESET $resetLabel', color: Cyber.magenta),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.border,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: Cyber.display(
              17,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.7),
          ),
        ],
      ),
    );
  }
}

class _AllTimeStrip extends StatelessWidget {
  const _AllTimeStrip({required this.solved, required this.played});

  final int solved;
  final int played;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.88),
        border: Border.all(color: Cyber.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: Cyber.muted, size: 15),
          const SizedBox(width: 8),
          Text('CAREER ARCHIVE', style: Cyber.label(9, color: Cyber.muted)),
          const Spacer(),
          Text(
            '$solved SOLVED  //  $played PLAYED',
            style: Cyber.display(
              9,
              color: Cyber.cyan,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _ArchiveLink extends StatelessWidget {
  const _ArchiveLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open 30 day mystery archive',
      child: InkWell(
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Cyber.magenta, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OPEN 30-DAY INTEL ARCHIVE',
                  style: Cyber.display(11, color: Cyber.magenta),
                ),
              ),
              const Icon(Icons.chevron_right, color: Cyber.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatCountdown(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
