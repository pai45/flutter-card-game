import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/tennis/tennis_cubit.dart';
import '../../blocs/tennis/tennis_state.dart';
import '../../config/theme.dart';
import '../../models/tennis.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import 'tennis_match_screen.dart';

class TennisRallyHub extends StatefulWidget {
  const TennisRallyHub({required this.onExit, super.key});

  /// Returns to the Games tab that launched this standalone flow.
  final VoidCallback onExit;

  @override
  State<TennisRallyHub> createState() => _TennisRallyHubState();
}

class _TennisRallyHubState extends State<TennisRallyHub> {
  bool _preparingPreview = false;

  TennisCubit get _cubit => context.read<TennisCubit>();

  @override
  void initState() {
    super.initState();
    // The starter pack is granted by GameBloc before this hub is ever pushed
    // (see _enterTennisGameFlow in app.dart), so the deck is the source of
    // truth for which athletes the player owns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final deck = context.read<GameBloc>().state;
      unawaited(
        _cubit.syncFromDeck(
          deck.deckTennisPlayers.map((card) => card.id).toList(),
          deck.deckTennisStarter?.id,
        ),
      );
    });
  }

  void _preparePreviewOnce(TennisState state) {
    if (_preparingPreview ||
        state.loading ||
        !state.profile.starterPackClaimed ||
        state.profile.ownedPlayerIds.isEmpty ||
        state.phase == TennisFlowPhase.preview ||
        state.phase == TennisFlowPhase.match) {
      return;
    }
    _preparingPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cubit.prepareQuickMatchPreview();
      _preparingPreview = false;
    });
  }

  void _launch() {
    final config = _cubit.buildMatch(mode: TennisMode.quickMatch);
    _pushMatch(config);
  }

  void _resume() {
    final config = _cubit.resumeMatch();
    _pushMatch(config);
  }

  void _pushMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: TennisMatchScreen(
            config: config,
            onExit: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
            onRestart: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
            onContinueTournament: () {
              navigator.pop();
              _cubit.prepareQuickMatchPreview();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TennisCubit, TennisState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        if (!state.profile.starterPackClaimed ||
            state.profile.ownedPlayerIds.isEmpty) {
          // syncFromDeck lands on the frame after mount; hold the loader
          // rather than flashing an empty preview.
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        _preparePreviewOnce(state);
        return _PreviewScreen(
          state: state,
          onBack: widget.onExit,
          onStart: state.canResume ? _resume : _launch,
        );
      },
    );
  }
}

enum _TennisHubView {
  landing,
  selection,
  preview,
  training,
  tournament,
  career,
  settings,
}

class TennisRallyV2Hub extends StatefulWidget {
  const TennisRallyV2Hub({required this.onExit, super.key});

  /// Returns to the Games tab that launched this standalone flow.
  final VoidCallback onExit;

  @override
  State<TennisRallyV2Hub> createState() => _TennisRallyV2HubState();
}

class _TennisRallyV2HubState extends State<TennisRallyV2Hub> {
  _TennisHubView _view = _TennisHubView.landing;

  TennisCubit get _cubit => context.read<TennisCubit>();

  void _openMode(TennisMode mode) {
    playSound(SoundEffect.uiTap);
    _cubit.selectMode(mode);
    setState(() {
      _view = switch (mode) {
        TennisMode.training => _TennisHubView.training,
        TennisMode.tournament => _TennisHubView.tournament,
        _ => _TennisHubView.selection,
      };
    });
    if (mode == TennisMode.tournament) _cubit.prepareTournament();
  }

  void _showPreview() {
    _cubit.showPreview();
    setState(() => _view = _TennisHubView.preview);
  }

  void _launch({TennisMode? mode, int? trainingLesson}) {
    final config = _cubit.buildMatch(
      mode: mode,
      trainingLesson: trainingLesson,
    );
    _pushMatch(config);
  }

  void _resume() {
    final config = _cubit.resumeMatch();
    _pushMatch(config);
  }

  void _pushMatch(TennisMatchConfig config) {
    playSound(SoundEffect.playMatch);
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: TennisMatchScreen(
            config: config,
            onExit: () {
              navigator.pop();
              _cubit.returnToHub();
              if (mounted) setState(() => _view = _TennisHubView.landing);
            },
            onRestart: () {
              navigator.pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _launch(
                  mode: config.mode,
                  trainingLesson: config.trainingLesson,
                );
              });
            },
            onContinueTournament: () {
              navigator.pop();
              _cubit.returnToHub();
              if (mounted) setState(() => _view = _TennisHubView.tournament);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TennisCubit, TennisState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            backgroundColor: Cyber.bg,
            body: Center(child: CircularProgressIndicator(color: Cyber.cyan)),
          );
        }
        return switch (_view) {
          _TennisHubView.landing => _LandingScreen(
            state: state,
            onExit: widget.onExit,
            onOpenMode: _openMode,
            onResume: _resume,
            onCareer: () => setState(() => _view = _TennisHubView.career),
            onSettings: () => setState(() => _view = _TennisHubView.settings),
          ),
          _TennisHubView.selection => _SelectionScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onPreview: _showPreview,
          ),
          _TennisHubView.preview => _PreviewScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.selection),
            onStart: () => _launch(),
          ),
          _TennisHubView.training => _TrainingScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onSelectPlayer: () {
              _cubit.selectMode(TennisMode.training);
              setState(() => _view = _TennisHubView.selection);
            },
            onStart: (lesson) =>
                _launch(mode: TennisMode.training, trainingLesson: lesson),
          ),
          _TennisHubView.tournament => _TournamentScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
            onStart: () => _launch(mode: TennisMode.tournament),
            onNewDraw: () => _cubit.prepareTournament(),
          ),
          _TennisHubView.career => _CareerScreen(
            state: state,
            onBack: () => setState(() => _view = _TennisHubView.landing),
          ),
          _TennisHubView.settings => _HubSettingsScreen(
            settings: state.profile.settings,
            onBack: () => setState(() => _view = _TennisHubView.landing),
          ),
        };
      },
    );
  }
}

class _LandingScreen extends StatelessWidget {
  const _LandingScreen({
    required this.state,
    required this.onExit,
    required this.onOpenMode,
    required this.onResume,
    required this.onCareer,
    required this.onSettings,
  });

  final TennisState state;
  final VoidCallback onExit;
  final ValueChanged<TennisMode> onOpenMode;
  final VoidCallback onResume;
  final VoidCallback onCareer;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'Tennis Rally',
        subtitle: '// COURT ONLINE',
        onBack: onExit,
      ),
      body: Column(
        children: [
          Expanded(
            child: CyberBackground(
              animated: !profile.settings.reducedMotion,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LandingSystemBar(
                          player: state.selectedPlayer,
                          onSettings: onSettings,
                        ),
                        const SizedBox(height: 13),
                        _TennisHero(
                          onPlay: () => onOpenMode(TennisMode.quickMatch),
                        ),
                        if (state.canResume) ...[
                          const SizedBox(height: 13),
                          _ResumeCard(
                            snapshot: state.resumeSnapshot!,
                            onResume: onResume,
                          ),
                        ],
                        const SizedBox(height: 18),
                        const SectionLabel(label: 'PLAY MODES'),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final width = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.tournament,
                                  icon: Icons.emoji_events_outlined,
                                  subtitle: '8 PLAYERS / 3 ROUNDS',
                                  accent: Cyber.gold,
                                  onTap: () =>
                                      onOpenMode(TennisMode.tournament),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.training,
                                  icon: Icons.school_outlined,
                                  subtitle: '8 SKILL LESSONS',
                                  accent: Cyber.cyan,
                                  onTap: () => onOpenMode(TennisMode.training),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.endlessRally,
                                  icon: Icons.all_inclusive,
                                  subtitle: 'FIRST MISS ENDS IT',
                                  accent: Cyber.lime,
                                  onTap: () =>
                                      onOpenMode(TennisMode.endlessRally),
                                ),
                                _ModeCard(
                                  width: width,
                                  mode: TennisMode.targetPractice,
                                  icon: Icons.gps_fixed,
                                  subtitle: '20 BALLS / 90 SEC',
                                  accent: Cyber.amber,
                                  onTap: () =>
                                      onOpenMode(TennisMode.targetPractice),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _CareerStrip(profile: profile, onTap: onCareer),
                        const SizedBox(height: 13),
                        _MasteryStrip(profile: profile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingSystemBar extends StatelessWidget {
  const _LandingSystemBar({required this.player, required this.onSettings});

  final TennisPlayer player;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Cyber.lime,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'COURT ONLINE // ${player.name.toUpperCase()}',
            style: Cyber.display(9, color: Cyber.muted),
          ),
        ),
        IconButton(
          tooltip: 'Tennis settings',
          onPressed: onSettings,
          icon: const Icon(Icons.tune, color: Cyber.cyan, size: 21),
        ),
      ],
    );
  }
}

class _TennisHero extends StatelessWidget {
  const _TennisHero({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 254,
      child: ClipPath(
        clipper: const HudChamferClipper(bigCut: 22, smallCut: 8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: const _HeroCourtPainter()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    color: Cyber.lime.withValues(alpha: 0.16),
                    child: Text(
                      'FEATURED // 2D ARCADE',
                      style: Cyber.display(8, color: Cyber.lime),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'TENNIS',
                    style: Cyber.display(
                      34,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'RALLY',
                    style: Cyber.display(
                      38,
                      color: Cyber.lime,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'READ THE BOUNCE. OWN THE LINE.',
                    style: Cyber.body(
                      11,
                      color: Colors.white.withValues(alpha: 0.72),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: min(330, MediaQuery.sizeOf(context).width - 72),
                    child: HudCtaButton(
                      label: 'QUICK MATCH',
                      icon: Icons.sports_tennis,
                      accent: Cyber.lime,
                      helper: 'FULL SET // PRO DEFAULT',
                      onTap: onPlay,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCourtPainter extends CustomPainter {
  const _HeroCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff183341), Color(0xff07111d)],
        ).createShader(Offset.zero & size),
    );
    final court = Path()
      ..moveTo(size.width * 0.63, size.height * 0.14)
      ..lineTo(size.width * 0.94, size.height * 0.14)
      ..lineTo(size.width * 1.08, size.height * 0.98)
      ..lineTo(size.width * 0.47, size.height * 0.98)
      ..close();
    canvas.drawPath(court, Paint()..color = const Color(0xff12606a));
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.59),
      Offset(size.width, size.height * 0.59),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.705, size.height * 0.14),
      Offset(size.width * 0.64, size.height * 0.98),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.855, size.height * 0.14),
      Offset(size.width * 0.91, size.height * 0.98),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.42),
      9,
      Paint()..color = Cyber.lime,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.42),
      18,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.snapshot, required this.onResume});

  final TennisMatchSnapshot snapshot;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const Icon(Icons.restore, color: Cyber.amber, size: 28),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCH SUSPENDED',
                  style: Cyber.display(11, color: Cyber.amber),
                ),
                const SizedBox(height: 4),
                Text(
                  '${snapshot.config.mode.label} // ${tennisPlayerById(snapshot.config.opponentId).name.toUpperCase()}',
                  style: Cyber.body(10, color: Cyber.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onResume,
            child: Text('RESUME', style: Cyber.display(10, color: Cyber.amber)),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.width,
    required this.mode,
    required this.icon,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final double width;
  final TennisMode mode;
  final IconData icon;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(13),
          child: SizedBox(
            height: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 23),
                const Spacer(),
                Text(
                  mode.label,
                  maxLines: 1,
                  style: Cyber.display(10, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  style: Cyber.display(7, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerStrip extends StatelessWidget {
  const _CareerStrip({required this.profile, required this.onTap});

  final TennisProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rate = profile.setsPlayed == 0
        ? 0
        : profile.setsWon / profile.setsPlayed;
    return InkWell(
      onTap: onTap,
      child: CyberPanel(
        accent: Cyber.gold,
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              color: Cyber.gold,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TENNIS CAREER',
                    style: Cyber.display(12, color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${profile.setsWon} WINS // ${(rate * 100).round()}% RATE // ${profile.achievements.length}/10 ACHIEVEMENTS',
                    style: Cyber.display(8, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Cyber.gold),
          ],
        ),
      ),
    );
  }
}

class _MasteryStrip extends StatelessWidget {
  const _MasteryStrip({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final player = tennisPlayerById(profile.selectedPlayerId);
    final level = profile.masteryLevel(player.id);
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${player.name.toUpperCase()} MASTERY',
                  style: Cyber.display(10),
                ),
              ),
              Text('LV $level', style: Cyber.display(11, color: Cyber.cyan)),
            ],
          ),
          const SizedBox(height: 9),
          CyberProgressBar(
            value: profile.masteryProgress(player.id),
            accent: Cyber.cyan,
            animate: false,
          ),
          const SizedBox(height: 7),
          Text(
            _nextCosmetic(level),
            style: Cyber.display(8, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

String _nextCosmetic(int level) => switch (level) {
  < 2 => 'NEXT // ALTERNATE OUTFIT AT LEVEL 2',
  < 3 => 'NEXT // RACKET DESIGN AT LEVEL 3',
  < 5 => 'NEXT // PLAYER FRAME AT LEVEL 5',
  < 7 => 'NEXT // VICTORY POSE AT LEVEL 7',
  < 10 => 'NEXT // SERVE EFFECT AT LEVEL 10',
  _ => 'MASTERY PATH COMPLETE',
};

class _SelectionScreen extends StatelessWidget {
  const _SelectionScreen({
    required this.state,
    required this.onBack,
    required this.onPreview,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final selected = state.selectedPlayer;
    final competitive =
        state.selectedMode == TennisMode.quickMatch ||
        state.selectedMode == TennisMode.tournament;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'PLAYER SELECT',
        subtitle: '// ${state.selectedMode.label}',
        onBack: onBack,
      ),
      body: CyberBackground(
        animated: !profile.settings.reducedMotion,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionLabel(label: 'CHOOSE ATHLETE'),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final player in tennisPlayers)
                              SizedBox(
                                width: width,
                                child: _AthleteCard(
                                  player: player,
                                  selected: player.id == selected.id,
                                  unlocked: profile.isPlayerUnlocked(player.id),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _AthleteDetail(player: selected, profile: profile),
                    const SizedBox(height: 18),
                    const SectionLabel(label: 'DIFFICULTY'),
                    const SizedBox(height: 9),
                    _DifficultyPicker(selected: profile.difficulty),
                    if (competitive) ...[
                      const SizedBox(height: 18),
                      const SectionLabel(label: 'RIVAL'),
                      const SizedBox(height: 9),
                      _OpponentPicker(
                        playerId: selected.id,
                        selectedId: profile.lastOpponentId,
                      ),
                    ],
                    const SizedBox(height: 20),
                    HudCtaButton(
                      label: competitive ? 'SCOUT RIVAL' : 'SESSION PREVIEW',
                      icon: competitive
                          ? Icons.visibility_outlined
                          : Icons.sports_tennis,
                      accent: Cyber.lime,
                      helper:
                          '${selected.name.toUpperCase()} // ${profile.difficulty.label}',
                      onTap: onPreview,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AthleteCard extends StatelessWidget {
  const _AthleteCard({
    required this.player,
    required this.selected,
    required this.unlocked,
  });

  final TennisPlayer player;
  final bool selected;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.lime : Cyber.cyan;
    return Opacity(
      opacity: unlocked ? 1 : 0.54,
      child: InkWell(
        onTap: unlocked
            ? () {
                HapticFeedback.selectionClick();
                context.read<TennisCubit>().selectPlayer(player.id);
              }
            : null,
        child: CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 116,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PlayerMonogram(player: player, size: 38),
                    const Spacer(),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: Cyber.lime,
                        size: 19,
                      )
                    else if (!unlocked)
                      const Icon(
                        Icons.lock_outline,
                        color: Cyber.muted,
                        size: 18,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  player.name.toUpperCase(),
                  maxLines: 1,
                  style: Cyber.display(10),
                ),
                const SizedBox(height: 4),
                Text(
                  player.archetype.label,
                  maxLines: 1,
                  style: Cyber.display(7, color: accent),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked
                      ? 'OVR ${player.ratings.overall}'
                      : _unlockLabel(player.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(7, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _unlockLabel(String id) => switch (id) {
  'sora-malik' => 'COMPLETE ALL TRAINING',
  'kaia-brooks' => 'WIN ROOKIE TITLE',
  'theo-laurent' => 'WIN PRO TITLE',
  'riven-cole' => 'WIN ALL-STAR TITLE',
  _ => 'STARTER',
};

class _PlayerMonogram extends StatelessWidget {
  const _PlayerMonogram({required this.player, required this.size});

  final TennisPlayer player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = player.name.split(' ').map((part) => part[0]).join();
    final color = _playerAccent(player.id);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(initials, style: Cyber.display(size * 0.28, color: color)),
    );
  }
}

Color _playerAccent(String id) => switch (id) {
  'jett-okafor' => Cyber.amber,
  'mira-chen' => Cyber.lime,
  'luca-vale' => Cyber.gold,
  'sora-malik' => Cyber.lime,
  'kaia-brooks' => Cyber.pink,
  'theo-laurent' => Cyber.blue,
  'riven-cole' => Cyber.violet,
  _ => Cyber.cyan,
};

class _AthleteDetail extends StatelessWidget {
  const _AthleteDetail({required this.player, required this.profile});

  final TennisPlayer player;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final ratings = player.ratings;
    return CyberPanel(
      accent: _playerAccent(player.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.signature,
                  style: Cyber.body(12, color: Cyber.muted),
                ),
              ),
              Text(
                'LV ${profile.masteryLevel(player.id)}',
                style: Cyber.display(11, color: Cyber.cyan),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RatingChip('SPD', ratings.speed),
              _RatingChip('PWR', ratings.power),
              _RatingChip('CTL', ratings.control),
              _RatingChip('SRV', ratings.serve),
              _RatingChip('STA', ratings.stamina),
              _RatingChip('VOL', ratings.volley),
              _RatingChip('SPN', ratings.spin),
              _RatingChip('RCH', ratings.reach),
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 67,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      color: Cyber.bg.withValues(alpha: 0.62),
      child: Row(
        children: [
          Text(label, style: Cyber.display(7, color: Cyber.muted)),
          const Spacer(),
          Text('$value', style: Cyber.display(9, color: Cyber.cyan)),
        ],
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected});

  final TennisDifficulty selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final difficulty in TennisDifficulty.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: difficulty == TennisDifficulty.allStar ? 0 : 7,
              ),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<TennisCubit>().selectDifficulty(difficulty);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 13,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: difficulty == selected
                        ? Cyber.cyan.withValues(alpha: 0.2)
                        : Cyber.panel,
                    border: Border.all(
                      color: difficulty == selected ? Cyber.cyan : Cyber.border,
                    ),
                  ),
                  child: Text(
                    difficulty.label,
                    textAlign: TextAlign.center,
                    style: Cyber.display(
                      8,
                      color: difficulty == selected ? Cyber.cyan : Cyber.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OpponentPicker extends StatelessWidget {
  const _OpponentPicker({required this.playerId, required this.selectedId});

  final String playerId;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tennisPlayers
            .where((player) => player.id != playerId)
            .length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final rivals = tennisPlayers
              .where((player) => player.id != playerId)
              .toList();
          final rival = rivals[index];
          final selected = rival.id == selectedId;
          return InkWell(
            onTap: () => context.read<TennisCubit>().selectOpponent(rival.id),
            child: Container(
              width: 145,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: selected
                    ? Cyber.amber.withValues(alpha: 0.15)
                    : Cyber.panel,
                border: Border.all(
                  color: selected ? Cyber.amber : Cyber.border,
                ),
              ),
              child: Row(
                children: [
                  _PlayerMonogram(player: rival, size: 38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rival.name.toUpperCase(),
                          maxLines: 1,
                          style: Cyber.display(8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'OVR ${rival.ratings.overall}',
                          style: Cyber.display(7, color: Cyber.muted),
                        ),
                      ],
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

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final player = state.selectedPlayer;
    final opponent = state.selectedOpponent;
    final profile = state.profile;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'Tennis Rally',
        subtitle: '// MATCH LOBBY',
        onBack: onBack,
      ),
      body: CyberBackground(
        animated: !profile.settings.reducedMotion,
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _TennisLobbyCourtPainter()),
              ),
            ),
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CyberSlideUpFadeIn(
                          child: CyberLobbyStatusBar(
                            systemLabel: 'SYS://TENNIS_RALLY v1.0.0',
                            lineColor: Cyber.lime,
                          ),
                        ),
                        const SizedBox(height: 18),
                        CyberSlideUpFadeIn(
                          delay: const Duration(milliseconds: 80),
                          offset: 24,
                          child: Row(
                            children: [
                              const _TennisLobbyEmblem(size: 92),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'TENNIS RALLY',
                                        style: Cyber.display(
                                          24,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'FAST COURT SHOWDOWN',
                                      style: Cyber.display(
                                        9,
                                        color: Cyber.muted,
                                        letterSpacing: 2.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    CyberChip(
                                      label: state.canResume
                                          ? 'MATCH SAVED'
                                          : 'ATHLETE READY',
                                      color: state.canResume
                                          ? Cyber.amber
                                          : Cyber.lime,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: CyberDealtCard(
                                key: const ValueKey(
                                  'tennis-lobby-stat-mastery',
                                ),
                                index: 0,
                                initialDelay: const Duration(milliseconds: 180),
                                flyDistance: 130,
                                child: CyberHudStat(
                                  label: 'MASTERY',
                                  value:
                                      'LV ${profile.masteryLevel(player.id)}',
                                  accent: Cyber.lime,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CyberDealtCard(
                                key: const ValueKey('tennis-lobby-stat-wins'),
                                index: 1,
                                initialDelay: const Duration(milliseconds: 180),
                                flyDistance: 130,
                                child: CyberHudStat(
                                  label: 'SET WINS',
                                  value: '${profile.setsWon}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CyberDealtCard(
                                key: const ValueKey('tennis-lobby-stat-streak'),
                                index: 2,
                                initialDelay: const Duration(milliseconds: 180),
                                flyDistance: 130,
                                child: CyberHudStat(
                                  label: 'STREAK',
                                  value: '${profile.currentWinStreak}',
                                  accent: profile.currentWinStreak > 0
                                      ? Cyber.success
                                      : Cyber.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        CyberSlideUpFadeIn(
                          delay: const Duration(milliseconds: 390),
                          offset: 22,
                          child: HudCtaButton(
                            label: state.canResume
                                ? 'RESUME MATCH'
                                : 'PLAY MATCH',
                            icon: Icons.sports_tennis,
                            accent: Cyber.lime,
                            helper:
                                '${profile.difficulty.label} // SEEDED FAIR PLAY',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onStart();
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SectionLabel(label: 'NEXT MATCH'),
                        const SizedBox(height: 10),
                        CyberSlideUpFadeIn(
                          delay: const Duration(milliseconds: 500),
                          offset: 18,
                          child: _VersusPanel(
                            player: player,
                            opponent: opponent,
                            difficulty: profile.difficulty,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CyberSlideUpFadeIn(
                          delay: const Duration(milliseconds: 590),
                          offset: 14,
                          child: _ControlBrief(mode: state.selectedMode),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TennisLobbyEmblem extends StatelessWidget {
  const _TennisLobbyEmblem({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CyberPulse(
      period: const Duration(milliseconds: 2600),
      builder: (context, pulse) {
        return SizedBox(
          width: size,
          height: size,
          child: ChamferedActionSurface(
            clipper: const HudChamferClipper(bigCut: 16, smallCut: 5),
            borderColor: Cyber.lime.withValues(alpha: 0.32 + pulse * 0.12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.66),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.sports_tennis,
                    size: size * 0.58,
                    color: Cyber.lime,
                  ),
                  Positioned(
                    top: 13,
                    right: 13,
                    child: Container(
                      width: 5,
                      height: 5,
                      color: Cyber.cyan.withValues(alpha: 0.72),
                    ),
                  ),
                  Positioned(
                    left: 11,
                    bottom: 11,
                    child: Text(
                      'TR//01',
                      style: Cyber.display(
                        6.5,
                        color: Cyber.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TennisLobbyCourtPainter extends CustomPainter {
  const _TennisLobbyCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final court = Path()
      ..moveTo(size.width * 0.25, size.height * 0.34)
      ..lineTo(size.width * 0.75, size.height * 0.34)
      ..lineTo(size.width * 1.08, size.height)
      ..lineTo(size.width * -0.08, size.height)
      ..close();
    canvas.drawPath(
      court,
      Paint()..color = Cyber.lime.withValues(alpha: 0.025),
    );

    final line = Paint()
      ..color = Cyber.lime.withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.34),
      Offset(size.width * 0.5, size.height),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.11, size.height * 0.72),
      Offset(size.width * 0.89, size.height * 0.72),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.53),
      Offset(size.width * 0.8, size.height * 0.53),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VersusPanel extends StatelessWidget {
  const _VersusPanel({
    required this.player,
    required this.opponent,
    required this.difficulty,
  });

  final TennisPlayer player;
  final TennisPlayer opponent;
  final TennisDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'SEEDED MATCH',
                style: Cyber.display(8, color: Cyber.muted, letterSpacing: 1.6),
              ),
              const Spacer(),
              CyberChip(label: difficulty.label, color: Cyber.gold),
            ],
          ),
          const SizedBox(height: 14),
          const HudLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PreviewAthlete(player: player, side: 'YOU'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Text('VS', style: Cyber.display(23, color: Cyber.lime)),
              ),
              Expanded(
                child: _PreviewAthlete(player: opponent, side: 'RIVAL'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewAthlete extends StatelessWidget {
  const _PreviewAthlete({required this.player, required this.side});

  final TennisPlayer player;
  final String side;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayerMonogram(player: player, size: 66),
        const SizedBox(height: 9),
        Text(
          player.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Cyber.display(10),
        ),
        const SizedBox(height: 4),
        Text(
          '$side // OVR ${player.ratings.overall}',
          style: Cyber.display(7, color: Cyber.muted),
        ),
      ],
    );
  }
}

class _ControlBrief extends StatelessWidget {
  const _ControlBrief({required this.mode});

  final TennisMode mode;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.lime,
      child: Row(
        children: [
          const Icon(Icons.open_with, color: Cyber.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DRAG TO MOVE // QUICK FLICK TO SPRINT',
              style: Cyber.display(8, color: Cyber.muted),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.swipe, color: Cyber.lime),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TAP, HOLD OR SWIPE TO SHAPE THE SHOT',
              style: Cyber.display(8, color: Cyber.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingScreen extends StatelessWidget {
  const _TrainingScreen({
    required this.state,
    required this.onBack,
    required this.onSelectPlayer,
    required this.onStart,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onSelectPlayer;
  final ValueChanged<int> onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'TRAINING LAB',
        subtitle: '// 8 LESSONS',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CyberPanel(
                        accent: Cyber.cyan,
                        child: Row(
                          children: [
                            _PlayerMonogram(
                              player: state.selectedPlayer,
                              size: 48,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.selectedPlayer.name.toUpperCase(),
                                    style: Cyber.display(11),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${state.profile.completedLessons.length}/8 COMPLETE',
                                    style: Cyber.display(8, color: Cyber.cyan),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: onSelectPlayer,
                              child: Text(
                                'CHANGE',
                                style: Cyber.display(9, color: Cyber.cyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final lesson in _lessons) ...[
                        _LessonCard(
                          lesson: lesson,
                          complete: state.profile.completedLessons.contains(
                            lesson.number,
                          ),
                          onStart: () => onStart(lesson.number),
                        ),
                        const SizedBox(height: 9),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.complete,
    required this.onStart,
  });

  final _LessonSpec lesson;
  final bool complete;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: complete ? Cyber.lime : Cyber.cyan,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            color: (complete ? Cyber.lime : Cyber.cyan).withValues(alpha: 0.14),
            child: complete
                ? const Icon(Icons.check, color: Cyber.lime)
                : Text(
                    '${lesson.number}',
                    style: Cyber.display(16, color: Cyber.cyan),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.name, style: Cyber.display(10)),
                const SizedBox(height: 4),
                Text(
                  lesson.objective,
                  style: Cyber.body(10, color: Cyber.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onStart,
            child: Text(
              complete ? 'REPLAY' : 'START',
              style: Cyber.display(
                9,
                color: complete ? Cyber.lime : Cyber.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _lessons = <_LessonSpec>[
  _LessonSpec(1, 'MOVEMENT', 'Reach the marker and return three normal shots.'),
  _LessonSpec(2, 'TIMING', 'Read early, good, perfect and late contact.'),
  _LessonSpec(3, 'DIRECTION', 'Aim one return left and one return right.'),
  _LessonSpec(4, 'POWER SHOT', 'Hold through a short ball and manage stamina.'),
  _LessonSpec(5, 'LOB', 'Lift a long upward gesture over the net player.'),
  _LessonSpec(6, 'SERVING', 'Complete a first serve and a safe second serve.'),
  _LessonSpec(7, 'STAMINA', 'Sprint, recover and return to centre position.'),
  _LessonSpec(8, 'SCORING', 'Play through Love, Deuce, Advantage and Game.'),
];

class _LessonSpec {
  const _LessonSpec(this.number, this.name, this.objective);

  final int number;
  final String name;
  final String objective;
}

class _TournamentScreen extends StatelessWidget {
  const _TournamentScreen({
    required this.state,
    required this.onBack,
    required this.onStart,
    required this.onNewDraw,
  });

  final TennisState state;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final VoidCallback onNewDraw;

  @override
  Widget build(BuildContext context) {
    final tournament = state.profile.tournament;
    final active = tournament?.active ?? false;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'STAToz OPEN',
        subtitle: '// 8 PLAYER BRACKET',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TournamentHeader(
                      tournament: tournament,
                      profile: state.profile,
                    ),
                    const SizedBox(height: 14),
                    if (tournament != null) _Bracket(tournament: tournament),
                    const SizedBox(height: 16),
                    if (active)
                      HudCtaButton(
                        label: 'PLAY ${_roundName(tournament!.currentRound)}',
                        icon: Icons.sports_tennis,
                        accent: Cyber.gold,
                        helper:
                            '${tournament.difficulty.label} // WIN TO ADVANCE',
                        onTap: onStart,
                      )
                    else
                      HudCtaButton(
                        label: 'CREATE NEW DRAW',
                        icon: Icons.casino_outlined,
                        accent: Cyber.gold,
                        onTap: onNewDraw,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _roundName(int round) => switch (round) {
  0 => 'QUARTERFINAL',
  1 => 'SEMIFINAL',
  _ => 'FINAL',
};

class _TournamentHeader extends StatelessWidget {
  const _TournamentHeader({required this.tournament, required this.profile});

  final TennisTournament? tournament;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      glow: true,
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Cyber.gold, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament?.champion == true
                      ? 'TITLE SECURED'
                      : 'THREE WINS TO THE TROPHY',
                  style: Cyber.display(12, color: Cyber.gold),
                ),
                const SizedBox(height: 5),
                Text(
                  '${tennisPlayerById(tournament?.playerId ?? profile.selectedPlayerId).name.toUpperCase()} // '
                  '${tournament?.difficulty.label ?? profile.difficulty.label}',
                  style: Cyber.display(8, color: Cyber.muted),
                ),
              ],
            ),
          ),
          Text(
            '${tournament?.results.where((result) => result == 'W').length ?? 0}/3',
            style: Cyber.display(19, color: Cyber.gold),
          ),
        ],
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  const _Bracket({required this.tournament});

  final TennisTournament tournament;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TOURNAMENT DRAW', style: Cyber.display(11, color: Cyber.cyan)),
          const SizedBox(height: 12),
          for (var i = 0; i < tournament.opponents.length; i++) ...[
            _BracketRound(
              round: i,
              opponent: tennisPlayerById(tournament.opponents[i]),
              result: i < tournament.results.length
                  ? tournament.results[i]
                  : null,
              current: tournament.active && i == tournament.currentRound,
            ),
            if (i < tournament.opponents.length - 1)
              Center(
                child: Container(width: 1, height: 13, color: Cyber.border),
              ),
          ],
          const SizedBox(height: 14),
          Text('FIELD OF 8', style: Cyber.display(8, color: Cyber.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in tournament.entrants)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  color: id == tournament.playerId
                      ? Cyber.cyan.withValues(alpha: 0.18)
                      : Cyber.bg.withValues(alpha: 0.62),
                  child: Text(
                    tennisPlayerById(id).name.toUpperCase(),
                    style: Cyber.display(
                      7,
                      color: id == tournament.playerId
                          ? Cyber.cyan
                          : Cyber.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BracketRound extends StatelessWidget {
  const _BracketRound({
    required this.round,
    required this.opponent,
    required this.result,
    required this.current,
  });

  final int round;
  final TennisPlayer opponent;
  final String? result;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = result == 'W'
        ? Cyber.lime
        : (result == 'L'
              ? Cyber.danger
              : (current ? Cyber.gold : Cyber.border));
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: current
            ? Cyber.gold.withValues(alpha: 0.08)
            : Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _roundName(round),
              style: Cyber.display(8, color: color),
            ),
          ),
          _PlayerMonogram(player: opponent, size: 34),
          const SizedBox(width: 9),
          Expanded(
            child: Text(opponent.name.toUpperCase(), style: Cyber.display(9)),
          ),
          Text(
            result ?? (current ? 'NEXT' : '--'),
            style: Cyber.display(10, color: color),
          ),
        ],
      ),
    );
  }
}

class _CareerScreen extends StatelessWidget {
  const _CareerScreen({required this.state, required this.onBack});

  final TennisState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'TENNIS CAREER',
        subtitle: '// MASTERY & TROPHIES',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CareerNumbers(profile: profile),
                    const SizedBox(height: 14),
                    _TrophyCabinet(profile: profile),
                    const SizedBox(height: 14),
                    const SectionLabel(label: 'ATHLETE MASTERY'),
                    const SizedBox(height: 9),
                    for (final player in tennisPlayers) ...[
                      _MasteryRow(player: player, profile: profile),
                      const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 12),
                    const SectionLabel(label: 'ACHIEVEMENTS'),
                    const SizedBox(height: 9),
                    for (final achievement in _tennisAchievements) ...[
                      _AchievementRow(
                        spec: achievement,
                        unlocked: profile.achievements.contains(achievement.id),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerNumbers extends StatelessWidget {
  const _CareerNumbers({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Row(
        children: [
          _CareerNumber(label: 'SETS', value: '${profile.setsPlayed}'),
          _CareerNumber(label: 'WINS', value: '${profile.setsWon}'),
          _CareerNumber(label: 'ACES', value: '${profile.totalAces}'),
          _CareerNumber(label: 'RALLY', value: '${profile.longestRally}'),
        ],
      ),
    );
  }
}

class _CareerNumber extends StatelessWidget {
  const _CareerNumber({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Cyber.display(19, color: Cyber.cyan)),
          const SizedBox(height: 4),
          Text(label, style: Cyber.display(7, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _TrophyCabinet extends StatelessWidget {
  const _TrophyCabinet({required this.profile});

  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TROPHY CABINET', style: Cyber.display(11, color: Cyber.gold)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final difficulty in TennisDifficulty.values)
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: (profile.trophies[difficulty.name] ?? 0) > 0
                            ? Cyber.gold
                            : Cyber.border,
                        size: 31,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        difficulty.label,
                        style: Cyber.display(7, color: Cyber.muted),
                      ),
                      Text(
                        'x${profile.trophies[difficulty.name] ?? 0}',
                        style: Cyber.display(9, color: Cyber.gold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.player, required this.profile});

  final TennisPlayer player;
  final TennisProfile profile;

  @override
  Widget build(BuildContext context) {
    final level = profile.masteryLevel(player.id);
    return Container(
      padding: const EdgeInsets.all(11),
      color: Cyber.panel,
      child: Row(
        children: [
          _PlayerMonogram(player: player, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name.toUpperCase(), style: Cyber.display(9)),
                const SizedBox(height: 6),
                CyberProgressBar(
                  value: profile.masteryProgress(player.id),
                  accent: _playerAccent(player.id),
                  height: 5,
                  animate: false,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'LV $level',
            style: Cyber.display(10, color: _playerAccent(player.id)),
          ),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.spec, required this.unlocked});

  final _AchievementSpec spec;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: unlocked ? Cyber.lime : Cyber.border),
        ),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.military_tech : Icons.lock_outline,
              color: unlocked ? Cyber.lime : Cyber.muted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.name,
                    style: Cyber.display(
                      9,
                      color: unlocked ? Colors.white : Cyber.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.condition,
                    style: Cyber.body(10, color: Cyber.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _tennisAchievements = <_AchievementSpec>[
  _AchievementSpec(
    'clean-hold',
    'CLEAN HOLD',
    'Win a service game without losing a point.',
  ),
  _AchievementSpec('break-through', 'BREAK THROUGH', 'Convert a break point.'),
  _AchievementSpec(
    'unbreakable',
    'UNBREAKABLE',
    'Save three break points in one match.',
  ),
  _AchievementSpec(
    'ace-high',
    'ACE HIGH',
    'Hit five aces across completed sets.',
  ),
  _AchievementSpec(
    'rally-architect',
    'RALLY ARCHITECT',
    'Complete a 20-shot rally.',
  ),
  _AchievementSpec(
    'net-authority',
    'NET AUTHORITY',
    'Win ten net points with a serve-and-volley athlete.',
  ),
  _AchievementSpec(
    'comeback-set',
    'COMEBACK SET',
    'Win after trailing by three games.',
  ),
  _AchievementSpec(
    'tiebreak-nerve',
    'TIEBREAK NERVE',
    'Win after saving set point in a tiebreak.',
  ),
  _AchievementSpec(
    'all-styles',
    'ALL STYLES',
    'Win with every base archetype.',
  ),
  _AchievementSpec('champion', 'CHAMPION', 'Win the eight-player tournament.'),
];

class _AchievementSpec {
  const _AchievementSpec(this.id, this.name, this.condition);

  final String id;
  final String name;
  final String condition;
}

class _HubSettingsScreen extends StatelessWidget {
  const _HubSettingsScreen({required this.settings, required this.onBack});

  final TennisSettings settings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TennisCubit>();
    return Scaffold(
      backgroundColor: Cyber.bg,
      appBar: ReactHeaderBar(
        title: 'TENNIS SETTINGS',
        subtitle: '// CONTROLS & ACCESS',
        onBack: onBack,
      ),
      body: CyberBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: CyberPanel(
                  child: Column(
                    children: [
                      _HubSwitch(
                        label: 'LEFT-HANDED CONTROL LAYOUT',
                        value: settings.leftHanded,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(leftHanded: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'MOVEMENT ASSIST',
                        value: settings.movementAssist,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(movementAssist: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'REDUCED MOTION',
                        value: settings.reducedMotion,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(reducedMotion: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'STRONG FLASHES',
                        value: settings.strongFlashes,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(strongFlashes: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'HAPTICS',
                        value: settings.haptics,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(haptics: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'MUSIC',
                        value: settings.music,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(music: value),
                        ),
                      ),
                      _HubSwitch(
                        label: 'SOUND EFFECTS',
                        value: settings.sound,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(sound: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _HubSlider(
                        label: 'CONTROL SIZE',
                        value: settings.controlScale,
                        min: 0.8,
                        max: 1.25,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(controlScale: value),
                        ),
                      ),
                      _HubSlider(
                        label: 'CONTROL OPACITY',
                        value: settings.controlOpacity,
                        min: 0.45,
                        max: 1,
                        onChanged: (value) => cubit.updateSettings(
                          settings.copyWith(controlOpacity: value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubSwitch extends StatelessWidget {
  const _HubSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Cyber.display(9)),
      value: value,
      activeThumbColor: Cyber.cyan,
      onChanged: onChanged,
    );
  }
}

class _HubSlider extends StatelessWidget {
  const _HubSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: Cyber.cyan,
          inactiveColor: Cyber.border,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
