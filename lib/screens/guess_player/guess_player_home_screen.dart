import 'package:flutter/material.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';

class GuessPlayerHomeScreen extends StatelessWidget {
  const GuessPlayerHomeScreen({
    required this.state,
    required this.onBack,
    required this.onOpenDay,
    required this.onOpenLogs,
    super.key,
  });

  final GuessPlayerState state;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;
  final VoidCallback onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final today = state.todayKey;
    final todayResult = state.archive.resultsByDay[today];
    final ctaLabel = todayResult != null
        ? (todayResult.won ? 'REVIEW SOLUTION' : 'REVIEW RESULTS')
        : 'PLAY TODAY\'S MYSTERY';

    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: _HomeHeader(onBack: onBack),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topGap = (constraints.maxHeight * 0.25)
                  .clamp(80.0, 200.0)
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
                          const _LandingHero(),
                          const SizedBox(height: 32),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 200),
                            offset: 22,
                            child: HudCtaButton(
                              label: ctaLabel,
                              icon: Icons.person_search,
                              accent: Cyber.magenta,
                              tapSound: SoundEffect.playMatch,
                              onTap: () => onOpenDay(today),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CyberSlideUpFadeIn(
                            delay: const Duration(milliseconds: 300),
                            offset: 22,
                            child: _DailyLogsHeader(onTap: onOpenLogs),
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

class _LandingHero extends StatelessWidget {
  const _LandingHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.person_search,
          size: 72,
          color: Cyber.magenta,
          shadows: Cyber.glow(Cyber.magenta),
        ),
        const SizedBox(height: 16),
        const Text(
          'GUESS THE PLAYER',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Identify the mystery footballer from their career timeline.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: 'Onest',
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
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
            const Icon(Icons.person_search, color: Cyber.magenta, size: 24),
          ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        borderRadius: BorderRadius.zero,
        splashColor: Cyber.magenta.withValues(alpha: 0.1),
        highlightColor: Cyber.magenta.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xff0a0d18),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Cyber.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.history, color: Cyber.magenta, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'DAILY LOGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
