import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../blocs/grand_prix/grand_prix_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/grand_prix_circuits.dart';
import '../../data/grand_prix_liveries.dart';
import '../../games/grand_prix/grand_prix_car_painter.dart';
import '../../models/grand_prix.dart';
import '../../models/progression.dart' show grandPrixXpMultiplier;
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/player_level_badge.dart';
import 'grand_prix_race_screen.dart';

/// Grand Prix Dash lobby: lifetime racing record, circuit picker, race
/// distance picker (1/3/5 laps), livery picker, and the START RACE CTA (the
/// screen's one glow). Circuit + distance + livery default to last used
/// (persisted on [GrandPrixStats]).
class GrandPrixLobbyScreen extends StatefulWidget {
  const GrandPrixLobbyScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<GrandPrixLobbyScreen> createState() => _GrandPrixLobbyScreenState();
}

class _GrandPrixLobbyScreenState extends State<GrandPrixLobbyScreen> {
  void _startRace() {
    final cubit = context.read<GrandPrixCubit>();
    final level = context.read<GameBloc>().state.progression.playerLevel;
    cubit.buildRace(level);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GrandPrixRaceScreen(
            onExit: navigator.pop,
            onRaceAgain: () {
              navigator.pop();
              _startRace();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      buildWhen: (p, c) => p.progression != c.progression,
      builder: (context, gameState) {
        return BlocBuilder<GrandPrixCubit, GrandPrixState>(
          builder: (context, state) {
            return Scaffold(
              backgroundColor: Cyber.bg,
              appBar: ReactHeaderBar(
                title: 'GRAND PRIX DASH',
                subtitle: '// LIGHTS OUT',
                onBack: () => widget.onNavigate(AppSection.predictions),
                showTitle: false,
                rightSlot: PlayerLevelBadge(progression: gameState.progression),
              ),
              body: CyberBackground(
                animated: true,
                child: SafeArea(
                  top: false,
                  child: state.loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Cyber.cyan),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const CyberSlideUpFadeIn(
                                    child: _PitLaneStatusBar(),
                                  ),
                                  const SizedBox(height: 16),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 80),
                                    offset: 24,
                                    child: _HeroRow(stats: state.stats),
                                  ),
                                  const SizedBox(height: 18),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 160),
                                    offset: 20,
                                    child: _RecordPanel(stats: state.stats),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'CIRCUIT'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 240),
                                    offset: 18,
                                    child: _CircuitPicker(
                                      selected: state.circuitId,
                                      stats: state.stats,
                                      laps: state.laps,
                                      onSelect: (id) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<GrandPrixCubit>()
                                            .selectCircuit(id);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'RACE DISTANCE'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 300),
                                    offset: 17,
                                    child: _LapPicker(
                                      selected: state.laps,
                                      onSelect: (laps) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<GrandPrixCubit>()
                                            .selectLaps(laps);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const SectionLabel(label: 'TEAM LIVERY'),
                                  const SizedBox(height: 10),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 360),
                                    offset: 16,
                                    child: _LiveryPicker(
                                      selected: state.livery,
                                      onSelect: (livery) {
                                        HapticFeedback.selectionClick();
                                        playSound(SoundEffect.uiTap);
                                        context
                                            .read<GrandPrixCubit>()
                                            .selectLivery(livery);
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  CyberSlideUpFadeIn(
                                    delay: const Duration(milliseconds: 420),
                                    offset: 22,
                                    child: HudCtaButton(
                                      label: 'START RACE',
                                      icon: Icons.sports_motorsports,
                                      accent: Cyber.magenta,
                                      tapSound: SoundEffect.playMatch,
                                      helper:
                                          '${grandPrixCircuit(state.circuitId).name} · '
                                          '${state.laps == 1 ? '1 LAP' : '${state.laps} LAPS'} · '
                                          '${grandPrixLiverySpec(state.livery).name}',
                                      onTap: _startRace,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _PitLaneStatusBar extends StatelessWidget {
  const _PitLaneStatusBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Cyber.success,
            shape: BoxShape.circle,
            boxShadow: Cyber.glow(Cyber.success, alpha: 0.6, blur: 8, spread: 0),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'PIT LANE OPEN',
          style: TextStyle(
            color: Cyber.success,
            fontFamily: Cyber.displayFont,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.magenta.withValues(alpha: 0.16)),
        ),
        const SizedBox(width: 10),
        const Text(
          'SYS://GP_DASH v1.0.0',
          style: TextStyle(
            color: Cyber.muted,
            fontFamily: Cyber.displayFont,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _HeroRow extends StatelessWidget {
  const _HeroRow({required this.stats});

  final GrandPrixStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _RaceEmblem(size: 84),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRAND PRIX DASH',
                style: Cyber.display(21, letterSpacing: 1.2).copyWith(
                  shadows: [
                    Shadow(
                      color: Cyber.magenta.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '1·3·5 LAPS · 20 CARS · LIGHTS OUT',
                style: TextStyle(
                  color: Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: CyberChip(
                  label: stats.wins > 0
                      ? '${stats.wins} RACE WINS'
                      : stats.races > 0
                          ? '${stats.races} RACES IN'
                          : 'ROOKIE SEASON',
                  color: stats.wins > 0 ? Cyber.gold : Cyber.magenta,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RaceEmblem extends StatefulWidget {
  const _RaceEmblem({this.size = 84});

  final double size;

  @override
  State<_RaceEmblem> createState() => _RaceEmblemState();
}

class _RaceEmblemState extends State<_RaceEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, _) {
          final phase = _spin.value * math.pi * 2;
          final pulse = 0.5 + 0.5 * math.sin(phase * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.9,
                height: size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Cyber.bg.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Cyber.magenta.withValues(alpha: 0.26 + pulse * 0.12),
                  ),
                  boxShadow: Cyber.glow(
                    Cyber.magenta,
                    alpha: 0.2 + pulse * 0.08,
                    blur: 18 + pulse * 4,
                    spread: -4,
                  ),
                ),
              ),
              Icon(
                Icons.sports_motorsports,
                size: size * 0.46,
                color: Cyber.magenta,
                shadows: [
                  Shadow(
                    color: Cyber.magenta.withValues(alpha: 0.62),
                    blurRadius: 16 + pulse * 4,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.stats});

  final GrandPrixStats stats;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.magenta,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          _RecordStat(label: 'RACES', value: '${stats.races}'),
          _RecordStat(
            label: 'WINS',
            value: '${stats.wins}',
            accent: Cyber.gold,
          ),
          _RecordStat(label: 'PODIUMS', value: '${stats.podiums}'),
          _RecordStat(
            label: 'BEST',
            value: stats.bestPosition > 0 ? 'P${stats.bestPosition}' : '—',
            accent: Cyber.cyan,
          ),
          _RecordStat(
            label: 'STREAK',
            value: '${stats.currentStreak}',
            accent: stats.currentStreak > 0 ? Cyber.success : Cyber.muted,
          ),
        ],
      ),
    );
  }
}

class _RecordStat extends StatelessWidget {
  const _RecordStat({
    required this.label,
    required this.value,
    this.accent = Colors.white,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontFamily: Cyber.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: Cyber.displayFont,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircuitPicker extends StatefulWidget {
  const _CircuitPicker({
    required this.selected,
    required this.stats,
    required this.laps,
    required this.onSelect,
  });

  final GrandPrixCircuitId selected;
  final GrandPrixStats stats;
  final int laps;
  final ValueChanged<GrandPrixCircuitId> onSelect;

  @override
  State<_CircuitPicker> createState() => _CircuitPickerState();
}

class _CircuitPickerState extends State<_CircuitPicker> {
  static const _cardExtent = 172.0 + 10.0; // card width + separator

  // Open with the remembered circuit in view, not always the list start.
  late final ScrollController _controller = ScrollController(
    initialScrollOffset:
        (grandPrixCircuits.indexWhere((c) => c.id == widget.selected) *
                _cardExtent -
            24)
            .clamp(0.0, _cardExtent * (grandPrixCircuits.length - 1)),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GrandPrixCircuitId get selected => widget.selected;
  GrandPrixStats get stats => widget.stats;
  ValueChanged<GrandPrixCircuitId> get onSelect => widget.onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: grandPrixCircuits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final circuit = grandPrixCircuits[index];
          final isSelected = circuit.id == selected;
          final bestLap = stats.bestLapMs(circuit.id, laps: widget.laps);
          return GestureDetector(
            onTap: () => onSelect(circuit.id),
            child: Container(
              width: 172,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color.alphaBlend(
                        Cyber.magenta.withValues(alpha: 0.1),
                        Cyber.panel,
                      )
                    : Cyber.panel,
                border: Border.all(
                  color: isSelected
                      ? Cyber.magenta
                      : Cyber.border.withValues(alpha: 0.6),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          circuit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(
                            11,
                            color: isSelected ? Cyber.magenta : Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CyberChip(
                        label: circuit.character,
                        color: isSelected ? Cyber.magenta : Cyber.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${'★' * circuit.difficultyStars}${'☆' * (4 - circuit.difficultyStars)}',
                    style: TextStyle(
                      color: Cyber.amber.withValues(alpha: 0.9),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'BEST ${formatLapTime(bestLap)}',
                    style: TextStyle(
                      color: bestLap != null ? Cyber.cyan : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Race-distance picker: 1 lap sprint, 3-lap grand prix, 5-lap endurance —
/// longer runs pay multiplied XP (chip reads [grandPrixXpMultiplier]).
class _LapPicker extends StatelessWidget {
  const _LapPicker({required this.selected, required this.onSelect});

  static const _options = [
    (laps: 1, title: 'SPRINT'),
    (laps: 3, title: 'GRAND PRIX'),
    (laps: 5, title: 'ENDURANCE'),
  ];

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in _options) ...[
          Expanded(
            child: _LapOption(
              laps: option.laps,
              title: option.title,
              isSelected: option.laps == selected,
              onTap: () => onSelect(option.laps),
            ),
          ),
          if (option != _options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _LapOption extends StatelessWidget {
  const _LapOption({
    required this.laps,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final int laps;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final multiplier = grandPrixXpMultiplier(laps);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.alphaBlend(
                  Cyber.magenta.withValues(alpha: 0.1),
                  Cyber.panel,
                )
              : Cyber.panel,
          border: Border.all(
            color: isSelected
                ? Cyber.magenta
                : Cyber.border.withValues(alpha: 0.6),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$laps',
                  style: Cyber.display(
                    22,
                    color: isSelected ? Cyber.magenta : Colors.white,
                  ).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  laps == 1 ? ' LAP' : ' LAPS',
                  style: Cyber.display(
                    9,
                    color: Cyber.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : Cyber.muted,
                fontFamily: Cyber.displayFont,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            CyberChip(
              label: 'XP ×$multiplier',
              color: multiplier > 1 ? Cyber.gold : Cyber.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Livery picker — each tile is the actual top-down F1 car you'll race
/// (shared [GrandPrixCarPreviewPainter]), not a flat colour swatch.
class _LiveryPicker extends StatelessWidget {
  const _LiveryPicker({required this.selected, required this.onSelect});

  final GrandPrixLivery selected;
  final ValueChanged<GrandPrixLivery> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final spec in grandPrixLiveries) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(spec.livery),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 68,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: spec.livery == selected
                          ? Color.alphaBlend(
                              spec.primary.withValues(alpha: 0.12),
                              Cyber.panel,
                            )
                          : Cyber.panel,
                      border: Border.all(
                        color: spec.livery == selected
                            ? Colors.white
                            : Cyber.border.withValues(alpha: 0.5),
                        width: spec.livery == selected ? 2 : 1,
                      ),
                    ),
                    child: CustomPaint(
                      painter: GrandPrixCarPreviewPainter(spec),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    spec.name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: spec.livery == selected
                          ? Colors.white
                          : Cyber.muted,
                      fontFamily: Cyber.displayFont,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (spec != grandPrixLiveries.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
