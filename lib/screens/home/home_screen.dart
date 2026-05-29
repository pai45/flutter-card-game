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
                          CyberCtaButton(
                            label: 'Deck Builder',
                            onPressed: () => onNavigate(AppSection.deck),
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
                          CyberCtaButton(
                            label: 'Match History',
                            onPressed: () => showMatchHistoryArchive(
                              context,
                              state.matchHistory,
                            ),
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
          bottomNavigationBar: _LandingBottomNavigation(onNavigate: onNavigate),
        );
      },
    );
  }
}

class _LandingBottomNavigation extends StatelessWidget {
  const _LandingBottomNavigation({required this.onNavigate});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff10192b), Color(0xff070b14)],
          ),
          border: Border.all(color: Cyber.line),
          boxShadow: [
            BoxShadow(
              color: Cyber.cyan.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: -6,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: Cyber.cyan.withValues(alpha: 0.14),
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            if (index == 1) {
              onNavigate(AppSection.shop);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              selectedIcon: Icon(Icons.sports_esports),
              label: 'Game',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shop',
            ),
          ],
        ),
      ),
    );
  }
}
