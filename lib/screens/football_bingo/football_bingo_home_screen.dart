import 'package:flutter/material.dart';

import '../../blocs/football_bingo/football_bingo_state.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../how_to_play/how_to_play_hub_screen.dart';

class FootballBingoHomeScreen extends StatelessWidget {
  const FootballBingoHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    required this.onOpenLogs,
    super.key,
  });

  final FootballBingoState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final progress = state.archive.progressByDay[today] ?? state.progress;
    final ctaLabel = progress.completed
        ? 'REVIEW GRID'
        : progress.solvedCellIds.isNotEmpty
        ? 'RESUME GRID'
        : 'PLAY TODAY\'S GRID';

    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: _HomeHeader(onBack: onBack),
      body: CyberArenaBackground(
        assetPath: 'assets/backgrounds/football_bingo_stadium.png',
        accent: Cyber.amber,
        topShadeAlpha: 0.18,
        middleShadeAlpha: 0.28,
        bottomShadeAlpha: 0.76,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topGap = (constraints.maxHeight * 0.27)
                  .clamp(120.0, 238.0)
                  .toDouble();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  SizedBox(height: topGap),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LandingHero(
                            completedCount: state.completedCount,
                            unlockedCount: state.unlockedDayKeys.length,
                          ),
                          const SizedBox(height: 20),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 390),
                            offset: 22,
                            child: HudCtaButton(
                              label: ctaLabel,
                              icon: Icons.play_arrow,
                              accent: Cyber.amber,
                              tapSound: SoundEffect.playMatch,
                              onTap: () => onOpenDay(today),
                            ),
                          ),
                          const SizedBox(height: 14),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 470),
                            offset: 22,
                            child: _DailyLogsHeader(onTap: onOpenLogs),
                          ),
                          const SizedBox(height: 16),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 650),
                            offset: 14,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 14,
                              runSpacing: 6,
                              children: [
                                _HudLink(
                                  label: 'HOW TO PLAY',
                                  onTap: () => showHowToPlayGuide(
                                    context,
                                    HowToPlayMode.bingoGrid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
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
      backgroundColor: const Color(0xff070a14),
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
            const Spacer(),
            const Icon(Icons.grid_view, color: Cyber.amber, size: 24),
          ],
        ),
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.completedCount,
    required this.unlockedCount,
  });

  final int completedCount;
  final int unlockedCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSlideUpFadeIn(child: _TelemetryStrip()),
        const SizedBox(height: 12),
        CyberSlideUpFadeIn(
          delay: const Duration(milliseconds: 80),
          offset: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _BingoIconBay(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'FOOTBALL BINGO',
                        maxLines: 1,
                        style: Cyber.display(22, color: Colors.white).copyWith(
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: Cyber.cyan.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '3X3 BINGO GAME',
                      style: Cyber.label(10, color: Cyber.muted),
                    ),
                    const SizedBox(height: 8),
                    const CyberChip(label: 'BINGO ONLINE', color: Cyber.lime),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CyberDealtCard(
                key: const ValueKey('home-stat-complete'),
                index: 0,
                initialDelay: const Duration(milliseconds: 180),
                flyDistance: 130,
                child: _StatTile(label: 'COMPLETE', value: '$completedCount'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: CyberDealtCard(
                key: const ValueKey('home-stat-unlocked'),
                index: 1,
                initialDelay: const Duration(milliseconds: 180),
                flyDistance: 130,
                child: _StatTile(label: 'UNLOCKED', value: '$unlockedCount'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TelemetryStrip extends StatelessWidget {
  const _TelemetryStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xff071321).withValues(alpha: 0.82),
        border: Border(
          left: BorderSide(color: Cyber.cyan.withValues(alpha: 0.35)),
          right: BorderSide(color: Cyber.cyan.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Cyber.lime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Cyber.lime.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('ONLINE', style: Cyber.display(9, color: Cyber.lime)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Cyber.cyan.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'SYS://3X3 BINGO GAME | 1.0.0',
                style: Cyber.label(8, color: Cyber.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BingoIconBay extends StatelessWidget {
  const _BingoIconBay();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: _HudCorner(top: true, left: true),
          ),
          const Positioned(
            right: 0,
            top: 0,
            child: _HudCorner(top: true, left: false),
          ),
          const Positioned(
            left: 0,
            bottom: 0,
            child: _HudCorner(top: false, left: true),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: _HudCorner(top: false, left: false),
          ),
          Center(
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xff102036).withValues(alpha: 0.95),
                shape: BoxShape.circle,
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.cyan.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.grid_view, color: Cyber.amber, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCorner extends StatelessWidget {
  const _HudCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(color: Cyber.amber.withValues(alpha: 0.75))
              : BorderSide.none,
          bottom: top
              ? BorderSide.none
              : BorderSide(color: Cyber.amber.withValues(alpha: 0.75)),
          left: left
              ? BorderSide(color: Cyber.amber.withValues(alpha: 0.75))
              : BorderSide.none,
          right: left
              ? BorderSide.none
              : BorderSide(color: Cyber.amber.withValues(alpha: 0.75)),
        ),
      ),
    );
  }
}

class _DailyLogsHeader extends StatelessWidget {
  const _DailyLogsHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        playSound(SoundEffect.uiTap);
        onTap();
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xff102036).withValues(alpha: 0.92),
          border: Border.all(color: Cyber.border.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Cyber.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'DAILY LOGS',
                style: Cyber.display(
                  14,
                  color: Cyber.amber,
                ).copyWith(letterSpacing: 1.4),
              ),
            ),
            const Icon(Icons.chevron_right, color: Cyber.cyan, size: 22),
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
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff102036).withValues(alpha: 0.86),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Cyber.display(
              16,
              color: Cyber.amber,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _HudLink extends StatelessWidget {
  const _HudLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: Cyber.amber,
          fontFamily: Cyber.displayFont,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
