import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/staggered_card_entrance.dart';
import 'widgets/standings_table.dart' show DetailTopBar;

const _gameCounts = <Sport, int>{
  Sport.football: 6,
  Sport.cricket: 3,
  Sport.basketball: 3,
  Sport.tennis: 3,
  Sport.motorsport: 3,
};

class AllSportsScreen extends StatefulWidget {
  const AllSportsScreen({
    required this.mode,
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final SportHubMode mode;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<AllSportsScreen> createState() => _AllSportsScreenState();
}

class _AllSportsScreenState extends State<AllSportsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.mode == SportHubMode.matches) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadMatchSports();
      });
    }
  }

  Future<void> _loadMatchSports() async {
    final cubit = context.read<PredictionCubit>();
    for (final sport in sportTabOrder) {
      await cubit.loadSport(sport);
    }
  }

  void _select(int index) {
    playSound(SoundEffect.uiTap);
    HapticFeedback.selectionClick();
    widget.onSelect(index);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              const DetailTopBar(title: 'SELECT SPORT'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SignalHeader(mode: widget.mode),
              ),
              Expanded(
                child: BlocBuilder<PredictionCubit, PredictionState>(
                  builder: (context, state) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        StaggeredCardEntrance(
                          index: 0,
                          animate: true,
                          child: _SportSignalRow(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Trending',
                            detail: 'CURATED // LIVE SIGNALS',
                            countLabel: 'HOT',
                            accent: Cyber.cyan,
                            selected:
                                widget.selectedIndex == hubTrendingTabIndex,
                            onTap: () => _select(hubTrendingTabIndex),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const HudLine(),
                        const SizedBox(height: 8),
                        for (
                          var index = 0;
                          index < sportTabOrder.length;
                          index++
                        ) ...[
                          _buildSportRow(
                            state,
                            sportTabOrder[index],
                            index + 1,
                          ),
                          if (index != sportTabOrder.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportRow(PredictionState state, Sport sport, int entranceIndex) {
    final module = sportModuleFor(sport);
    final selectedIndex = hubIndexForSport(sport);
    final fixtures = state.fixtures
        .where((fixture) => fixture.sport == sport)
        .toList(growable: false);
    final live = fixtures
        .where((fixture) => fixture.status == MatchStatus.live)
        .length;
    final loading = state.loadingSports.contains(sport);
    final countLabel = widget.mode == SportHubMode.games
        ? '${_gameCounts[sport] ?? 0}'
        : loading
        ? '...'
        : '$live / ${fixtures.length}';
    final detail = widget.mode == SportHubMode.games
        ? '${_gameCounts[sport] ?? 0} PLAYABLE MODES'
        : loading
        ? 'SCANNING LIVE FIXTURES'
        : '${fixtures.length} FIXTURES IN RANGE';

    return StaggeredCardEntrance(
      index: entranceIndex,
      animate: true,
      child: _SportSignalRow(
        icon: module.icon,
        label: sport == Sport.basketball ? 'Basketball' : module.label,
        detail: detail,
        countLabel: countLabel,
        accent: module.accent,
        selected: widget.selectedIndex == selectedIndex,
        onTap: () => _select(selectedIndex),
      ),
    );
  }
}

class _SignalHeader extends StatelessWidget {
  const _SignalHeader({required this.mode});

  final SportHubMode mode;

  @override
  Widget build(BuildContext context) {
    final modeLabel = mode == SportHubMode.matches ? 'MATCH FEED' : 'GAME DECK';
    return Row(
      children: [
        Text(
          'SPORT://ROUTER',
          style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1.2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Cyber.cyan.withValues(alpha: 0.22),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          modeLabel,
          style: Cyber.label(10, color: Cyber.muted, letterSpacing: 0.7),
        ),
      ],
    );
  }
}

class _SportSignalRow extends StatelessWidget {
  const _SportSignalRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.countLabel,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final String countLabel;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $detail',
      child: PressableScale(
        onTap: onTap,
        child: ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 3),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: selected
                  ? Color.alphaBlend(accent.withValues(alpha: 0.1), Cyber.panel)
                  : Cyber.panel,
              border: Border(
                left: BorderSide(
                  color: selected ? accent : Cyber.border,
                  width: selected ? 4 : 1,
                ),
                top: BorderSide(color: Cyber.border.withValues(alpha: 0.7)),
                right: BorderSide(color: Cyber.border.withValues(alpha: 0.7)),
                bottom: BorderSide(color: Cyber.border.withValues(alpha: 0.7)),
              ),
              boxShadow: selected
                  ? Cyber.glow(accent, alpha: 0.18, blur: 12, spread: -5)
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(icon, color: selected ? accent : Cyber.muted, size: 27),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: Cyber.display(
                          13,
                          color: selected ? Colors.white : Cyber.muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          10,
                          color: selected
                              ? accent.withValues(alpha: 0.8)
                              : Cyber.muted.withValues(alpha: 0.68),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  color: selected
                      ? accent.withValues(alpha: 0.14)
                      : Cyber.bg.withValues(alpha: 0.5),
                  alignment: Alignment.center,
                  child: Text(
                    countLabel,
                    style:
                        Cyber.display(
                          10,
                          color: selected ? accent : Cyber.muted,
                          letterSpacing: 0.5,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
