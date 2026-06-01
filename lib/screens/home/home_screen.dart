import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../config/tutorial_steps.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../../widgets/tutorial.dart';
import '../../screens/match_history/match_history_pages.dart';
import 'widgets/daily_drop.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Pitch Duel',
            subtitle: '// Main Terminal',
            rightSlot: PlayerLevelBadge(progression: state.progression),
          ),
          body: CyberBackground(
            animated: true,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 144),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            size: 58,
                            color: Cyber.cyan,
                            shadows: [
                              Shadow(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          CyberChip(
                            label: state.deckReady
                                ? 'DECK ONLINE'
                                : 'DEFAULT LOADOUT',
                            color: state.deckReady ? Cyber.lime : Cyber.amber,
                          ),
                          const SizedBox(height: 28),
                          state.deckReady
                              ? HudCtaButton(
                                  label: 'PLAY MATCH',
                                  onTap: () {
                                    context.read<GameBloc>().add(
                                      MatchStarted(),
                                    );
                                    onNavigate(AppSection.match);
                                  },
                                )
                              : Opacity(
                                  opacity: 0.45,
                                  child: IgnorePointer(
                                    child: HudCtaButton(
                                      label: 'PLAY MATCH',
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => onNavigate(AppSection.howToPlay),
                            child: const Text(
                              'HOW TO PLAY',
                              style: TextStyle(
                                color: Cyber.cyan,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {
                              context.read<GameBloc>().add(TutorialReset());
                              showTutorialNow(
                                context,
                                keyName: 'home',
                                steps: homeTutorialSteps,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tutorial reset')),
                              );
                            },
                            child: Text(
                              'REPLAY WALKTHROUGH',
                              style: TextStyle(
                                color: Cyber.cyan.withValues(alpha: 0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Deck Builder',
                                  clip: false,
                                  onPressed: () =>
                                      onNavigate(AppSection.deck),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CyberCtaButton(
                                  label: 'Match History',
                                  clip: false,
                                  onPressed: () => showMatchHistoryArchive(
                                    context,
                                    state.matchHistory,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DailyDropButton(),
                ),
                const TutorialTip(keyName: 'home', steps: homeTutorialSteps),
              ],
            ),
          ),
          bottomNavigationBar: LandingBottomNavigation(
            selectedIndex: 0,
            onNavigate: onNavigate,
          ),
        );
      },
    );
  }
}

