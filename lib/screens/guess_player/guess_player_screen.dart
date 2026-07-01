import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_player/guess_player_cubit.dart';
import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../models/cards.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_tooltip.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/team_logo.dart';
import 'widgets/guess_result_overlay.dart';

class GuessPlayerScreen extends StatefulWidget {
  const GuessPlayerScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessPlayerScreen> createState() => _GuessPlayerScreenState();
}

class _GuessPlayerScreenState extends State<GuessPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'GUESS THE PLAYER',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack,
      ),
      child: const CyberBackground(child: _GuessPlayerBody()),
    );
  }
}

class _GuessPlayerBody extends StatefulWidget {
  const _GuessPlayerBody();

  @override
  State<_GuessPlayerBody> createState() => _GuessPlayerBodyState();
}

class _GuessPlayerBodyState extends State<_GuessPlayerBody> {
  PlayerCard? _selectedPlayer;
  final TextEditingController _searchController = TextEditingController();

  void _submit(BuildContext context) {
    final cubit = context.read<GuessPlayerCubit>();
    if (_selectedPlayer != null) {
      cubit.submitGuess(_selectedPlayer!);
      _selectedPlayer = null;
      _searchController.clear();
    } else {
      cubit.skip();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GuessPlayerCubit, GuessPlayerState>(
      builder: (context, state) {
        return Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 24),

                // Mystery Avatar Panel
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _MysteryAvatarPanel(),
                ),
                const SizedBox(height: 16),

                // Career Timeline Panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _CareerTimelinePanel(timeline: state.timeline),
                ),
                const SizedBox(height: 24),

                // Search Field
                if (state.gameState == GuessPlayerGameState.playing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _PlayerSearchField(
                      controller: _searchController,
                      onSelected: (p) => setState(() => _selectedPlayer = p),
                      onCleared: () => setState(() => _selectedPlayer = null),
                    ),
                  ),

                const Spacer(),

                // Hearts
                _buildHearts(state.remainingHearts),
                const SizedBox(height: 16),

                // Submit Button
                if (state.gameState == GuessPlayerGameState.playing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: HudCtaButton(
                      label: _selectedPlayer != null ? 'SUBMIT' : 'SKIP ROUND',
                      accent: _selectedPlayer != null
                          ? AppTheme.activeButtonColor
                          : Cyber.danger,
                      onTap: () => _submit(context),
                    ),
                  ),
              ],
            ),

            // Overlays
            if (state.gameState != GuessPlayerGameState.playing)
              GuessResultOverlay(
                won: state.gameState == GuessPlayerGameState.won,
                playerName: state.targetPlayer.name,
                xpEarned: state.gameState == GuessPlayerGameState.won ? 50 : 0,
                onContinue: () {
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildHearts(int remainingHearts) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(10, (index) {
        final active = index < remainingHearts;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            active ? Icons.favorite : Icons.favorite_border,
            color: active ? Cyber.danger : Colors.white70,
            size: 22,
            shadows: active ? Cyber.glow(Cyber.danger, alpha: 0.5) : null,
          ),
        );
      }),
    );
  }
}

class _MysteryAvatarPanel extends StatelessWidget {
  const _MysteryAvatarPanel();

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.panel,
      solidBackground: true,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xff1A2433),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Cyber.gold, width: 2),
            boxShadow: Cyber.glow(Cyber.gold, alpha: 0.3),
          ),
          child: const Center(
            child: Icon(Icons.help_outline, size: 56, color: Cyber.cyan),
          ),
        ),
      ),
    );
  }
}

class _CareerTimelinePanel extends StatelessWidget {
  const _CareerTimelinePanel({required this.timeline});

  final dynamic timeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff0B1220),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: Cyber.borderSubtle),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CAREER TIMELINE',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${timeline.career.length} TEAMS',
                style: const TextStyle(
                  color: Cyber.muted,
                  fontFamily: 'Onest',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: timeline.career.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final spell = timeline.career[index];
                // We'll show standard abbreviations.
                final clubAbbr = spell.clubName.length >= 3
                    ? spell.clubName.substring(0, 3).toUpperCase()
                    : spell.clubName.toUpperCase();

                // Try to find the team in followableLeagues to get accurate colors/shortNames.
                SportTeam? realTeam;
                for (final l in followableLeagues) {
                  for (final t in l.teams) {
                    if (t.name.toLowerCase() == spell.clubName.toLowerCase() ||
                        t.id.toLowerCase() == spell.clubName.toLowerCase()) {
                      realTeam = t;
                      break;
                    }
                  }
                  if (realTeam != null) break;
                }

                final team = realTeam ?? SportTeam(
                  id: spell.clubName,
                  name: spell.clubName,
                  shortName: clubAbbr,
                  color: const Color(0xff1A2433), // dark cyber panel color
                );
                final isLast = index == timeline.career.length - 1;
                final endYearStr = isLast
                    ? 'Present'
                    : '${timeline.career[index + 1].startYear}';
                final dateRange = '${spell.startYear}-$endYearStr';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CyberTooltip(
                      message: spell.clubName,
                      child: TeamLogo(team: team, width: 54, height: 54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateRange,
                      style: const TextStyle(
                        color: Cyber.muted,
                        fontFamily: 'Onest',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSearchField extends StatelessWidget {
  const _PlayerSearchField({
    required this.controller,
    required this.onSelected,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<PlayerCard> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final allPlayers = context.read<GuessPlayerCubit>().allPlayers;

    return Autocomplete<PlayerCard>(
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<PlayerCard>.empty();
        }
        return allPlayers.where((PlayerCard option) {
          return option.name.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Sync local controller with Autocomplete's controller
            if (controller.text != textEditingController.text) {
              controller.text = textEditingController.text;
            }
            // Listen to changes to sync back
            textEditingController.addListener(() {
              if (controller.text != textEditingController.text) {
                controller.text = textEditingController.text;
              }
            });

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Onest',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search player...',
                hintStyle: const TextStyle(color: Cyber.muted),
                filled: true,
                fillColor: const Color(0xff0A101C),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    textEditingController.clear();
                    controller.clear();
                    onCleared();
                    focusNode.unfocus();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(color: Cyber.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(color: Cyber.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: const BorderSide(color: Cyber.cyan, width: 2),
                ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 48,
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xff0B1220),
                borderRadius: BorderRadius.zero,
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.5)),
                boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.2),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        option.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Onest',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
