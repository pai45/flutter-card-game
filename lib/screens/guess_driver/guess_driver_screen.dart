import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/guess_driver/guess_driver_cubit.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/game_scaffold.dart';
import '../guess_player/widgets/guess_result_overlay.dart';

class GuessDriverScreen extends StatefulWidget {
  const GuessDriverScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<GuessDriverScreen> createState() => _GuessDriverScreenState();
}

class _GuessDriverScreenState extends State<GuessDriverScreen> {
  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'GUESS THE DRIVER',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: widget.onBack,
      ),
      child: const CyberBackground(child: _GuessDriverBody()),
    );
  }
}

class _GuessDriverBody extends StatefulWidget {
  const _GuessDriverBody();

  @override
  State<_GuessDriverBody> createState() => _GuessDriverBodyState();
}

class _GuessDriverBodyState extends State<_GuessDriverBody> {
  String? _selectedDriver;
  final TextEditingController _searchController = TextEditingController();

  void _submit(BuildContext context) {
    final cubit = context.read<GuessDriverCubit>();
    if (_selectedDriver != null) {
      cubit.submitGuess(_selectedDriver!);
      _selectedDriver = null;
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
    return BlocBuilder<GuessDriverCubit, GuessDriverState>(
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

                // Race Details Panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _RaceDetailsPanel(
                    trackName: state.targetRace.trackName,
                    year: state.targetRace.year,
                    country: state.targetRace.country,
                  ),
                ),
                const SizedBox(height: 24),

                // Search Field
                if (state.gameState == GuessDriverGameState.playing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _DriverSearchField(
                      controller: _searchController,
                      onSelected: (d) => setState(() => _selectedDriver = d),
                      onCleared: () => setState(() => _selectedDriver = null),
                    ),
                  ),

                const Spacer(),

                // Hearts
                _buildHearts(state.remainingHearts),
                const SizedBox(height: 16),

                // Submit Button
                if (state.gameState == GuessDriverGameState.playing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: HudCtaButton(
                      label: _selectedDriver != null ? 'SUBMIT' : 'SKIP ROUND',
                      accent: _selectedDriver != null
                          ? AppTheme.activeButtonColor
                          : Cyber.danger,
                      onTap: () => _submit(context),
                    ),
                  ),
              ],
            ),

            // Overlays
            if (state.gameState != GuessDriverGameState.playing)
              GuessResultOverlay(
                won: state.gameState == GuessDriverGameState.won,
                playerName: state.targetRace.driverName,
                xpEarned: state.gameState == GuessDriverGameState.won ? 50 : 0,
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
            child: Icon(Icons.sports_motorsports_outlined, size: 56, color: Cyber.cyan),
          ),
        ),
      ),
    );
  }
}

class _RaceDetailsPanel extends StatelessWidget {
  const _RaceDetailsPanel({
    required this.trackName,
    required this.year,
    required this.country,
  });

  final String trackName;
  final String year;
  final String country;

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
                'RACE DETAILS',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'F1',
                style: const TextStyle(
                  color: Cyber.cyan,
                  fontFamily: 'Onest',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailCell(label: 'YEAR', value: year),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _DetailCell(label: 'TRACK', value: trackName),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailCell(label: 'COUNTRY', value: country),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Cyber.muted,
            fontFamily: 'Orbitron',
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Onest',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DriverSearchField extends StatelessWidget {
  const _DriverSearchField({
    required this.controller,
    required this.onSelected,
    required this.onCleared,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final allDrivers = context.read<GuessDriverCubit>().allDrivers;

    return Autocomplete<String>(
      displayStringForOption: (option) => option,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return allDrivers.where((String option) {
          return option.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          );
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (controller.text != textEditingController.text) {
              controller.text = textEditingController.text;
            }
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
                hintText: 'Search driver...',
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
                        option,
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
