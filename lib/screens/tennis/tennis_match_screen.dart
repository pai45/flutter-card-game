import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/tennis/tennis_cubit.dart';
import '../../config/theme.dart';
import '../../games/tennis/tennis_engine.dart';
import '../../games/tennis/tennis_game.dart';
import '../../models/tennis.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/tennis_controls.dart';
import 'widgets/tennis_hud.dart';

class TennisMatchScreen extends StatefulWidget {
  const TennisMatchScreen({
    required this.config,
    required this.onExit,
    required this.onRestart,
    required this.onContinueTournament,
    super.key,
  });

  final TennisMatchConfig config;
  final VoidCallback onExit;
  final VoidCallback onRestart;
  final VoidCallback onContinueTournament;

  @override
  State<TennisMatchScreen> createState() => _TennisMatchScreenState();
}

class _TennisMatchScreenState extends State<TennisMatchScreen>
    with WidgetsBindingObserver {
  late final TennisCubit _cubit;
  late final TennisGame _game;
  late TennisSettings _settings;
  bool _paused = false;
  bool _showSettings = false;
  bool _settling = false;
  bool _settled = false;
  bool _deliberateExit = false;
  TennisMatchSummary? _summary;
  TennisReward _reward = TennisReward.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<TennisCubit>();
    _settings = _cubit.state.profile.settings;
    final candidate = _cubit.state.resumeSnapshot;
    final resume = candidate?.config.matchId == widget.config.matchId
        ? candidate
        : null;
    _game = TennisGame(
      config: widget.config,
      settings: _settings.copyWith(
        reducedMotion:
            _settings.reducedMotion ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations,
      ),
      resume: resume,
      onEvents: _onEvents,
    );
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pause(auto: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_settled && !_deliberateExit) {
      unawaited(_cubit.saveSnapshot(_game.snapshot()));
    }
    if (!kIsWeb) {
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    super.dispose();
  }

  void _onEvents(List<TennisEvent> events) {
    for (final event in events) {
      if (_settings.sound) {
        switch (event.type) {
          case TennisEventType.contact:
            playSound(SoundEffect.tennisContact);
            break;
          case TennisEventType.bounce:
            playSound(SoundEffect.tennisBounce);
            break;
          case TennisEventType.net:
            playSound(SoundEffect.tennisNet);
            break;
          case TennisEventType.ace:
          case TennisEventType.winner:
            playSound(SoundEffect.goal);
            break;
          case TennisEventType.fault:
          case TennisEventType.doubleFault:
            playSound(SoundEffect.redCard);
            break;
          default:
            break;
        }
      }
      if (_settings.haptics && event.team == 0) {
        if (event.type == TennisEventType.perfectContact) {
          HapticFeedback.selectionClick();
        } else if (event.type == TennisEventType.winner ||
            event.type == TennisEventType.ace) {
          HapticFeedback.mediumImpact();
        }
      }
      if (event.type == TennisEventType.setEnded) {
        unawaited(_finish());
      }
    }
  }

  Future<void> _finish() async {
    if (_settling || _settled) return;
    _settling = true;
    _game.setPaused(true);
    final tournamentChampion =
        widget.config.mode == TennisMode.tournament &&
        widget.config.tournamentRound == 2 &&
        _game.engine.score.setWinner == 0;
    final summary = _game.summary(tournamentChampion: tournamentChampion);
    final reward = await _cubit.settle(summary);
    if (!mounted) return;
    context.read<GameBloc>().add(
      TennisFinished(
        matchId: summary.matchId,
        playerName: tennisPlayerById(summary.playerId).name,
        opponentName: tennisPlayerById(summary.opponentId).name,
        modeLabel: summary.mode.label,
        difficultyLabel: summary.difficulty.label,
        resultLabel: _resultLabel(summary),
        grade: summary.grade,
        playerGames:
            summary.mode == TennisMode.quickMatch ||
                summary.mode == TennisMode.tournament
            ? summary.playerGames
            : summary.practiceScore,
        opponentGames:
            summary.mode == TennisMode.quickMatch ||
                summary.mode == TennisMode.tournament
            ? summary.opponentGames
            : 0,
        xp: reward.xp,
        coins: reward.coins,
      ),
    );
    if (_settings.sound) {
      playSound(summary.won ? SoundEffect.matchWin : SoundEffect.matchLose);
    }
    if (_settings.haptics) HapticFeedback.heavyImpact();
    setState(() {
      _summary = summary;
      _reward = reward;
      _settled = true;
      _settling = false;
      _paused = false;
      _showSettings = false;
    });
  }

  String _resultLabel(TennisMatchSummary summary) {
    if (summary.mode == TennisMode.training) return 'Lesson Complete';
    if (summary.mode == TennisMode.endlessRally ||
        summary.mode == TennisMode.targetPractice) {
      return 'Completed';
    }
    return summary.won ? 'Victory' : 'Defeat';
  }

  void _pause({bool auto = false}) {
    if (_settled || _game.engine.complete) return;
    _game.setPaused(true);
    unawaited(_cubit.saveSnapshot(_game.snapshot()));
    if (mounted) {
      setState(() {
        _paused = true;
        if (auto) _showSettings = false;
      });
    }
  }

  void _resume() {
    _game.setPaused(false);
    setState(() {
      _paused = false;
      _showSettings = false;
    });
  }

  Future<void> _quit() async {
    if (_settled) {
      widget.onExit();
      return;
    }
    _pause();
    final leave = await showCyberConfirmDialog(
      context,
      title: 'QUIT MATCH?',
      message: 'This run will be cleared and grants no XP or Oz Coins.',
      confirmLabel: 'Quit',
      cancelLabel: 'Resume',
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      _deliberateExit = true;
      await _cubit.abandonMatch();
      widget.onExit();
    } else {
      _resume();
    }
  }

  Future<void> _restart() async {
    _deliberateExit = true;
    await _cubit.abandonMatch();
    widget.onRestart();
  }

  void _updateSettings(TennisSettings settings) {
    _game.applySettings(settings);
    setState(() => _settings = settings);
    _cubit.updateSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_quit());
      },
      child: Scaffold(
        backgroundColor: Cyber.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameWidget<TennisGame>(game: _game),
                TennisHud(game: _game, onPause: _pause),
                TennisStingLayer(game: _game),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: _paused || _settled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TennisStatusRails(game: _game),
                        TennisControls(game: _game, settings: _settings),
                      ],
                    ),
                  ),
                ),
                if (_paused)
                  _PauseOverlay(
                    settings: _settings,
                    showSettings: _showSettings,
                    onResume: _resume,
                    onSettings: () =>
                        setState(() => _showSettings = !_showSettings),
                    onUpdateSettings: _updateSettings,
                    onRestart: () => unawaited(_restart()),
                    onQuit: () => unawaited(_quit()),
                  ),
                if (_summary != null)
                  _ResultOverlay(
                    summary: _summary!,
                    reward: _reward,
                    tournamentContinues:
                        _summary!.mode == TennisMode.tournament &&
                        _summary!.won &&
                        !_summary!.tournamentChampion,
                    onContinueTournament: widget.onContinueTournament,
                    onRestart: widget.onRestart,
                    onExit: widget.onExit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.settings,
    required this.showSettings,
    required this.onResume,
    required this.onSettings,
    required this.onUpdateSettings,
    required this.onRestart,
    required this.onQuit,
  });

  final TennisSettings settings;
  final bool showSettings;
  final VoidCallback onResume;
  final VoidCallback onSettings;
  final ValueChanged<TennisSettings> onUpdateSettings;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: CyberPanel(
                accent: Cyber.cyan,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: showSettings
                      ? _SettingsPanel(
                          settings: settings,
                          onChanged: onUpdateSettings,
                          onBack: onSettings,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'MATCH PAUSED',
                              textAlign: TextAlign.center,
                              style: Cyber.display(24, color: Cyber.cyan),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your exact point has been saved.',
                              textAlign: TextAlign.center,
                              style: Cyber.body(13, color: Cyber.muted),
                            ),
                            const SizedBox(height: 22),
                            HudCtaButton(
                              label: 'RESUME',
                              icon: Icons.play_arrow_rounded,
                              onTap: onResume,
                            ),
                            const SizedBox(height: 10),
                            _PauseAction(
                              label: 'SETTINGS',
                              icon: Icons.tune,
                              onTap: onSettings,
                            ),
                            _PauseAction(
                              label: 'RESTART MATCH',
                              icon: Icons.refresh,
                              onTap: onRestart,
                            ),
                            _PauseAction(
                              label: 'QUIT WITHOUT REWARD',
                              icon: Icons.exit_to_app,
                              color: Cyber.danger,
                              onTap: onQuit,
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

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.onChanged,
    required this.onBack,
  });

  final TennisSettings settings;
  final ValueChanged<TennisSettings> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
            ),
            Text('ACCESSIBILITY', style: Cyber.display(17, color: Cyber.cyan)),
          ],
        ),
        _SettingSwitch(
          label: 'LEFT-HANDED CONTROLS',
          value: settings.leftHanded,
          onChanged: (value) => onChanged(settings.copyWith(leftHanded: value)),
        ),
        _SettingSwitch(
          label: 'MOVEMENT ASSIST',
          value: settings.movementAssist,
          onChanged: (value) =>
              onChanged(settings.copyWith(movementAssist: value)),
        ),
        _SettingSwitch(
          label: 'REDUCED MOTION',
          value: settings.reducedMotion,
          onChanged: (value) =>
              onChanged(settings.copyWith(reducedMotion: value)),
        ),
        _SettingSwitch(
          label: 'STRONG FLASHES',
          value: settings.strongFlashes,
          onChanged: (value) =>
              onChanged(settings.copyWith(strongFlashes: value)),
        ),
        _SettingSwitch(
          label: 'HAPTICS',
          value: settings.haptics,
          onChanged: (value) => onChanged(settings.copyWith(haptics: value)),
        ),
        _SettingSwitch(
          label: 'SOUND',
          value: settings.sound,
          onChanged: (value) => onChanged(settings.copyWith(sound: value)),
        ),
        const SizedBox(height: 10),
        Text('CONTROL SIZE', style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: settings.controlScale,
          min: 0.8,
          max: 1.25,
          activeColor: Cyber.cyan,
          inactiveColor: Cyber.border,
          onChanged: (value) =>
              onChanged(settings.copyWith(controlScale: value)),
        ),
        Text('CONTROL OPACITY', style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: settings.controlOpacity,
          min: 0.45,
          max: 1,
          activeColor: Cyber.lime,
          inactiveColor: Cyber.border,
          onChanged: (value) =>
              onChanged(settings.copyWith(controlOpacity: value)),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
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
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Cyber.display(9, color: Colors.white)),
      value: value,
      activeThumbColor: Cyber.cyan,
      onChanged: onChanged,
    );
  }
}

class _PauseAction extends StatelessWidget {
  const _PauseAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = Cyber.muted,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: Cyber.display(10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.summary,
    required this.reward,
    required this.tournamentContinues,
    required this.onContinueTournament,
    required this.onRestart,
    required this.onExit,
  });

  final TennisMatchSummary summary;
  final TennisReward reward;
  final bool tournamentContinues;
  final VoidCallback onContinueTournament;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final accent = summary.won ? Cyber.lime : Cyber.danger;
    final matchMode =
        summary.mode == TennisMode.quickMatch ||
        summary.mode == TennisMode.tournament;
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: CyberPanel(
                accent: accent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        summary.tournamentChampion
                            ? 'CHAMPION'
                            : _resultTitle(summary),
                        textAlign: TextAlign.center,
                        style: Cyber.display(29, color: accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        matchMode
                            ? '${summary.playerGames} - ${summary.opponentGames}'
                            : summary.mode == TennisMode.training
                            ? 'LESSON ${summary.trainingLesson} COMPLETE'
                            : '${summary.practiceScore} POINTS',
                        textAlign: TextAlign.center,
                        style: Cyber.display(24, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ResultStat(label: 'GRADE', value: summary.grade),
                          _ResultStat(label: 'XP', value: '+${reward.xp}'),
                          _ResultStat(
                            label: 'COINS',
                            value: '+${reward.coins}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PerformanceRow(
                        label: 'FIRST SERVE',
                        value:
                            '${(summary.stats.firstServePercentage * 100).round()}%',
                      ),
                      _PerformanceRow(
                        label: 'WINNERS / ERRORS',
                        value:
                            '${summary.stats.winners} / ${summary.stats.unforcedErrors}',
                      ),
                      _PerformanceRow(
                        label: 'LONGEST RALLY',
                        value: '${summary.stats.longestRally}',
                      ),
                      _PerformanceRow(
                        label: 'PERFECT CONTACTS',
                        value: '${summary.stats.perfectContacts}',
                      ),
                      if (reward.farmed)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'REPEAT BONUS SUPPRESSED - CHANGE RIVAL OR DIFFICULTY',
                            textAlign: TextAlign.center,
                            style: Cyber.display(8, color: Cyber.amber),
                          ),
                        ),
                      const SizedBox(height: 20),
                      HudCtaButton(
                        label: tournamentContinues
                            ? 'NEXT ROUND'
                            : 'BACK TO TENNIS',
                        icon: tournamentContinues
                            ? Icons.arrow_forward
                            : Icons.sports_tennis,
                        accent: accent,
                        onTap: tournamentContinues
                            ? onContinueTournament
                            : onExit,
                      ),
                      if (!tournamentContinues) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: onRestart,
                          icon: const Icon(Icons.refresh, color: Cyber.muted),
                          label: Text(
                            'PLAY AGAIN',
                            style: Cyber.display(10, color: Cyber.muted),
                          ),
                        ),
                      ],
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

  String _resultTitle(TennisMatchSummary summary) {
    if (summary.mode == TennisMode.training) return 'LESSON COMPLETE';
    if (summary.mode == TennisMode.endlessRally ||
        summary.mode == TennisMode.targetPractice) {
      return 'SESSION COMPLETE';
    }
    return summary.won ? 'VICTORY' : 'DEFEAT';
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Cyber.display(19, color: Cyber.cyan)),
          const SizedBox(height: 4),
          Text(label, style: Cyber.display(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: Cyber.display(9, color: Cyber.muted)),
          const Spacer(),
          Text(value, style: Cyber.display(10, color: Colors.white)),
        ],
      ),
    );
  }
}
