import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../blocs/game/game_event.dart';
import '../../../blocs/game/game_state.dart';
import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../models/cards.dart';
import '../../../models/match.dart';
import '../../../models/pitch_duel_rules.dart';
import '../../../models/pitch_duel_mastery.dart';
import '../../../utils/game_audio_mappings.dart';
import '../../../utils/label_helpers.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/squad_faceoff.dart';
import '../../../widgets/game_scaffold.dart';
import '../../../widgets/match_widgets.dart';
import '../../../widgets/pitch_background.dart';
import '../../../widgets/spotlight_walkthrough.dart';
import 'match_phases.dart';
import 'round_result_cinematic.dart';

/// The persistent two-sided Duel Board — the whole round loop (role reveal →
/// scenario → play → resolve) happens on this ONE screen, Pokémon-TCG style:
/// a compact hidden rival play up top, a central arena
/// where both sides' cards are placed face-down and flip together, and your
/// hand on your pitch half below. Only the coin toss (before) and the final
/// result (after) remain separate cinematic bookends.
///
/// Presentation only: every rule stays in [GameBloc] — the board just drives
/// the same events the old phase screens did ([RoleRevealAcknowledged],
/// [PlayStarted], [PlayerSelected], [ActionSelected], [MovePlayed],
/// [RoundAdvanced]).
class DuelBoardPhase extends StatefulWidget {
  const DuelBoardPhase({required this.state, required this.onQuit, super.key});

  final GameState state;
  final VoidCallback onQuit;

  @override
  State<DuelBoardPhase> createState() => _DuelBoardPhaseState();
}

class _DuelBoardPhaseState extends State<DuelBoardPhase>
    with TickerProviderStateMixin {
  // ── Reveal timeline thresholds (deal-in → flip → power → verdict → score) ──
  static const _kDealEnd = 0.14;
  static const _kFlipStart = 0.18;
  static const _kFlipEnd = 0.40;
  static const _kMeterEnd = 0.66;
  static const _kVerdictStart = 0.68;
  static const _kVerdictEnd = 0.86;

  /// Role banner: sweep in, sting, hold, then auto-advance.
  late final AnimationController _roleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// Round resolution: opponent card deals in, both flip, powers tick,
  /// verdict stamps, score pays off.
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Full-bleed GOAL!/DENIED! stamp fired at the verdict beat.
  late final AnimationController _stinger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool _roleStingFired = false;
  bool _flipFired = false;
  bool _meterFired = false;
  bool _verdictFired = false;
  bool _scoreFired = false;
  bool _revealDone = false;
  bool _bootstrapped = false;
  bool _shotMeterOpen = false;

  void _finishReveal() {
    if (_phase != MatchPhase.roundResult || _revealDone) return;
    _flipFired = _meterFired = _verdictFired = _scoreFired = true;
    _stinger.value = 1;
    _revealCtrl.value = 1;
    setState(() => _revealDone = true);
  }

  // Spotlight walkthrough targets (same tutorial keys as the old phases so
  // players who saw them never see them twice).
  final _powerKey = GlobalKey();
  final _playersKey = GlobalKey();
  final _actionsKey = GlobalKey();
  final _arenaKey = GlobalKey();
  final _scenarioSpotKey = GlobalKey();
  final _briefingKey = GlobalKey<ScenarioBriefingSectionState>();

  bool _scenarioWalkthrough(BuildContext context, GameState state) =>
      state.currentRound == 1 &&
      !context.read<GameBloc>().state.tutorialSeen.contains('scenario');

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  MatchPhase get _phase => widget.state.phase;

  @override
  void initState() {
    super.initState();
    _roleCtrl.addListener(_onRoleTick);
    _roleCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _advanceRole();
    });
    _revealCtrl.addListener(_onRevealTick);
    _revealCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_revealDone) {
        setState(() => _revealDone = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    _enterBeat(from: null);
  }

  @override
  void didUpdateWidget(DuelBoardPhase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.phase != widget.state.phase) {
      _enterBeat(from: oldWidget.state.phase);
    }
  }

  void _enterBeat({required MatchPhase? from}) {
    switch (_phase) {
      case MatchPhase.roleReveal:
        _stinger.value = 0;
        _roleStingFired = false;
        if (_reduceMotion) {
          _fireRoleSting();
          // Reset then complete so the completed status (→ auto-advance)
          // fires even when the controller already sat at 1.0.
          _roleCtrl.value = 0;
          _roleCtrl.value = 1.0;
        } else {
          _roleCtrl.forward(from: 0);
        }
      case MatchPhase.play:
        break;
      case MatchPhase.roundResult:
        _startRevealBeat();
      default:
        // The scenario beat needs no controller: the embedded
        // [ScenarioBriefingSection] owns its decrypt entrance + countdown and
        // dispatches [PlayStarted] itself.
        break;
    }
  }

  void _startRevealBeat() {
    _stinger.value = 0;
    _flipFired = false;
    _meterFired = false;
    _verdictFired = false;
    _scoreFired = false;
    _revealDone = false;
    if (_reduceMotion) {
      _flipFired = true;
      _meterFired = true;
      _verdictFired = true;
      _scoreFired = true;
      _revealCtrl.value = 1.0;
      _fireFlipSounds();
      _fireVerdictSounds();
      _revealDone = true;
      return;
    }
    _revealCtrl.forward(from: 0);
  }

  void _advanceRole() {
    if (!mounted || _phase != MatchPhase.roleReveal) return;
    context.read<GameBloc>().add(RoleRevealAcknowledged());
  }

  void _onRoleTick() {
    if (_roleStingFired || _roleCtrl.value < 0.30) return;
    _fireRoleSting();
  }

  void _fireRoleSting() {
    if (_roleStingFired) return;
    _roleStingFired = true;
    playSound(
      widget.state.playerAttacking ? SoundEffect.attack : SoundEffect.defense,
    );
    HapticFeedback.mediumImpact();
  }

  void _onRevealTick() {
    final t = _revealCtrl.value;
    if (!_flipFired && t >= _kFlipStart) {
      _flipFired = true;
      _fireFlipSounds();
    }
    if (!_meterFired && t >= _kFlipEnd) {
      _meterFired = true;
      HapticFeedback.mediumImpact();
    }
    if (!_verdictFired && t >= _kVerdictStart) {
      _verdictFired = true;
      _fireVerdictSounds();
      if (_stingerKind != null) _stinger.forward(from: 0);
    }
    if (!_scoreFired && t >= _kVerdictEnd) {
      _scoreFired = true;
      if (_lastResult?.outcome == RoundOutcome.goal) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _fireFlipSounds() {
    playSound(SoundEffect.whoosh);
    playSound(SoundEffect.cardSlam);
    HapticFeedback.heavyImpact();
  }

  void _fireVerdictSounds() {
    final outcome = _lastResult?.outcome;
    if (outcome == null) return;
    playSound(pitchDuelSoundForOutcome(outcome));
    if (outcome == RoundOutcome.goal || outcome == RoundOutcome.redCard) {
      HapticFeedback.heavyImpact();
    }
  }

  RoundResult? get _lastResult =>
      widget.state.roundResults.isEmpty ? null : widget.state.roundResults.last;

  StingerKind? get _stingerKind => switch (_lastResult?.outcome) {
    RoundOutcome.goal => StingerKind.goal,
    RoundOutcome.saved || RoundOutcome.blocked => StingerKind.denied,
    _ => null,
  };

  @override
  void dispose() {
    _roleCtrl.dispose();
    _revealCtrl.dispose();
    _stinger.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────

  List<SpotlightStep> get _playSpotlightSteps => [
    SpotlightStep(
      targetKey: _playersKey,
      title: 'Choose your player',
      body:
          'Pick an attacker or defender for this round. Each card can play once per match. Long-press a card to see its affinity.',
      icon: Icons.person,
      accent: Cyber.cyan,
    ),
    SpotlightStep(
      targetKey: _actionsKey,
      title: 'Link an action',
      body:
          'Look for MATCH +4, +6 or +10. Link your player’s affinity and the scenario for a stronger play. Swipe to see more actions. RESERVED cards protect a later round.',
      icon: Icons.style,
      accent: Cyber.cyan,
    ),
    SpotlightStep(
      targetKey: _powerKey,
      title: 'Commit your play',
      body:
          'Your power includes the card and combination bonuses. Timing adds up to +8. The rival range is an estimate; their cards stay hidden. Pick both cards, then COMMIT.',
      icon: Icons.bolt,
      accent: Cyber.cyan,
    ),
  ];

  List<SpotlightStep> get _scenarioSpotlightSteps => [
    SpotlightStep(
      targetKey: _scenarioSpotKey,
      title: 'Scenario',
      body:
          'Read the scenario bonuses and matching actions. A matching action earns +6.',
      icon: Icons.flag,
      accent: Cyber.lime,
    ),
  ];

  List<SpotlightStep> get _resultSpotlightSteps => [
    SpotlightStep(
      targetKey: _arenaKey,
      title: 'Round Result',
      body:
          'Watch player, action, scenario, combination and timing build your total. Higher power wins; exact ties flip a coin. Tap to finish the reveal.',
      icon: Icons.sports_soccer,
      accent: Cyber.cyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final round = max(1, state.currentRound);
    final playBeat = state.phase == MatchPhase.play;
    final resolveBeat = state.phase == MatchPhase.roundResult;
    final roundOne = round == 1;
    final tutorialSeen = context.watch<GameBloc>().state.tutorialSeen;
    final playWalkthrough =
        playBeat && roundOne && !tutorialSeen.contains('play');
    final resultWalkthrough =
        resolveBeat && roundOne && !tutorialSeen.contains('round-result');
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final bottomAction = _buildBottomAction(context, state, resolveBeat);

    return GameScaffold(
      title: 'Round $round',
      subtitle: null,
      showShop: false,
      compactHeader: true,
      safeAreaBottom: false,
      titleUnderlay: round >= 1 && round <= 4
          ? RoundProgressMeter(currentRound: round)
          : null,
      rightSlot: MatchHeaderScore(
        playerScore: state.playerScore,
        opponentScore: state.opponentScore,
      ),
      leading: IconButton(
        onPressed: widget.onQuit,
        icon: const Icon(Icons.close, color: Cyber.cyan),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: FullPitchBackground(key: ValueKey('duel-full-pitch')),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, board) => playBeat
                  ? _buildPlayBoard(
                      context,
                      state,
                      board.maxHeight,
                      board.maxWidth,
                      bottomInset,
                    )
                  : _buildRoundBeatBoard(
                      context,
                      state,
                      resolveBeat,
                      board.maxHeight,
                      bottomInset,
                      bottomAction != null,
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 1,
                color: Cyber.cyan.withValues(alpha: 0.16),
              ),
            ),
          ),
          // Full-bleed GOAL!/DENIED! payoff over the whole board.
          Positioned.fill(
            child: OutcomeStingerOverlay(
              kind: _stingerKind,
              accent: _stingerAccent,
              animation: _stinger,
            ),
          ),
          if (state.phase == MatchPhase.scenario &&
              state.currentScenario != null &&
              roundOne &&
              !tutorialSeen.contains('scenario'))
            SpotlightTutorial(
              keyName: 'scenario',
              steps: _scenarioSpotlightSteps,
              startDelay: const Duration(milliseconds: 450),
              onComplete: () => _briefingKey.currentState?.beginCountdown(),
              cardAnchor: SpotlightCardAnchor.bottom,
              cardBottomInset: 24,
            ),
          if (playWalkthrough)
            SpotlightTutorial(
              keyName: 'play',
              steps: _playSpotlightSteps,
              startDelay: const Duration(milliseconds: 400),
            ),
          if (resultWalkthrough)
            SpotlightTutorial(
              keyName: 'round-result',
              steps: _resultSpotlightSteps,
              enabled: _revealDone,
              startDelay: const Duration(milliseconds: 350),

              cardAnchor: SpotlightCardAnchor.bottom,
              cardBottomInset: 24,
            ),
          if (bottomAction != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 32 + bottomInset,
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: _reduceMotion ? 120 : 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: bottomAction,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayBoard(
    BuildContext context,
    GameState state,
    double boardHeight,
    double boardWidth,
    double bottomInset,
  ) {
    return Column(
      children: [
        _OpponentBoardStrip(state: state),
        SpotlightTarget(
          spotlightKey: _powerKey,
          child: _DuelIntelStrip(
            key: const ValueKey('duel-intel-strip'),
            state: state,
          ),
        ),
        Expanded(child: _buildPlayHand(context, state, bottomInset)),
      ],
    );
  }

  Widget _buildRoundBeatBoard(
    BuildContext context,
    GameState state,
    bool resolveBeat,
    double boardHeight,
    double bottomInset,
    bool hasBottomAction,
  ) {
    const opponentHeight = 78.0;
    final lowerChildren = _buildLowerChildren(context, state, resolveBeat);
    final result = resolveBeat ? _lastResult : null;
    final resolutionChildren = result == null
        ? const <Widget>[]
        : _buildResolutionChildren(context, state, result);
    final contentTopPadding = resolveBeat && result?.playerAttacking == true
        ? 12.0
        : max(
            12.0,
            boardHeight * 0.5 - opponentHeight - (resolveBeat ? 104 : 94),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _OpponentBoardStrip(state: state),
        ),
        if (state.phase == MatchPhase.scenario)
          Positioned.fill(
            top: opponentHeight,
            child: LayoutBuilder(
              builder: (context, available) {
                final bottomPadding = 16 + bottomInset;
                return SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max(
                        0,
                        available.maxHeight - 12 - bottomPadding,
                      ),
                    ),
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -opponentHeight / 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: lowerChildren,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Positioned.fill(
            top: opponentHeight,
            child: ListView(
              clipBehavior: Clip.none,
              padding: EdgeInsets.fromLTRB(
                16,
                contentTopPadding,
                16,
                (hasBottomAction ? 128 : 16) + bottomInset,
              ),
              children: resolveBeat
                  ? resolutionChildren
                  : [
                      SpotlightTarget(
                        spotlightKey: _arenaKey,
                        child: _DuelArena(
                          state: state,
                          roleCtrl: _roleCtrl,
                          revealCtrl: _revealCtrl,
                          result: null,
                        ),
                      ),
                      if (lowerChildren.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...lowerChildren,
                      ],
                    ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildResolutionChildren(
    BuildContext context,
    GameState state,
    RoundResult result,
  ) {
    final playerAttacking = result.playerAttacking;
    final playerPower = playerAttacking
        ? result.attackPower
        : result.defensePower;
    final oppPower = playerAttacking ? result.defensePower : result.attackPower;
    final goalScored = result.outcome == RoundOutcome.goal;

    return [
      AnimatedBuilder(
        animation: _revealCtrl,
        builder: (context, _) {
          final meterT = _timelineT(_kFlipEnd, _kMeterEnd, Curves.easeOutCubic);
          final playerBreakdown = playerAttacking
              ? result.attackBreakdown
              : result.defenseBreakdown;
          final opponentBreakdown = playerAttacking
              ? result.defenseBreakdown
              : result.attackBreakdown;
          double shownPower(PowerBreakdown? power, double fallback) {
            if (power == null) return fallback * meterT;
            final contributions = [
              power.player,
              power.action,
              power.scenario,
              power.combo,
              power.timing,
            ];
            return contributions
                .take((meterT * contributions.length).floor())
                .fold<int>(0, (sum, value) => sum + value)
                .toDouble();
          }

          final deflated = result.outcome == RoundOutcome.missed;
          final verdictT = _timelineT(
            _kVerdictStart,
            _kVerdictEnd,
            deflated ? Curves.easeOut : Curves.easeOutBack,
          );
          final scoreT = _timelineT(_kVerdictEnd, 1.0, Curves.easeOutCubic);
          final verdict = VerdictHero(
            outcome: result.outcome,
            playerAttacking: playerAttacking,
            accent: outcomeColor(result.outcome),
            t: verdictT,
          );

          return Column(
            children: [
              if (playerAttacking) ...[verdict, const SizedBox(height: 12)],
              ScoreImpactStrip(
                playerScore: state.playerScore,
                opponentScore: state.opponentScore,
                opponentLabel: compactOpponentName(state),
                goalScored: goalScored,
                scoringIsPlayer: playerAttacking,
                t: scoreT,
              ),
              SpotlightTarget(
                spotlightKey: _arenaKey,
                child: _DuelArena(
                  state: state,
                  roleCtrl: _roleCtrl,
                  revealCtrl: _revealCtrl,
                  result: result,
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: meterT.clamp(0.0, 1.0),
                child: HeadToHeadPowerMeter(
                  playerRole: playerAttacking ? 'ATTACK' : 'DEFEND',
                  oppRole: playerAttacking ? 'DEFEND' : 'ATTACK',
                  playerPower: shownPower(playerBreakdown, playerPower),
                  oppPower: shownPower(opponentBreakdown, oppPower),
                  playerAccent: roleAccent(playerAttacking),
                  oppAccent: roleAccent(!playerAttacking),
                  progress: 1,
                ),
              ),
              if (playerBreakdown != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: PitchContributionStrip(
                    power: playerBreakdown,
                    progress: meterT,
                  ),
                ),
              if (!playerAttacking) ...[const SizedBox(height: 14), verdict],
            ],
          );
        },
      ),
      const SizedBox(height: 14),
    ];
  }

  Color get _stingerAccent {
    final result = _lastResult;
    if (result == null) return Colors.transparent;
    return switch (_stingerKind) {
      StingerKind.goal => result.playerAttacking ? Cyber.lime : Cyber.danger,
      StingerKind.denied => Cyber.violet,
      null => Colors.transparent,
    };
  }

  Widget? _buildBottomAction(
    BuildContext context,
    GameState state,
    bool resolveBeat,
  ) {
    if (resolveBeat && !_revealDone) {
      return CyberCtaButton(
        label: 'TAP TO FINISH REVEAL',
        onPressed: _finishReveal,
      );
    }
    if (resolveBeat && _revealDone && state.currentRound < 4) {
      return CyberCtaButton(
        label: 'NEXT ROUND',
        primary: true,
        onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
      );
    }
    if (resolveBeat && _revealDone && state.currentRound >= 4) {
      return CyberCtaButton(
        key: const ValueKey('full-time-result'),
        label: 'Full-Time Result',
        primary: true,
        onPressed: () => context.read<GameBloc>().add(RoundAdvanced()),
      );
    }
    if (state.phase != MatchPhase.play) return null;
    final hasPlayer = state.selectedPlayerCard != null;
    final hasAction = state.selectedActionCard != null;
    if (!hasPlayer || !hasAction) {
      return _MoveGuidanceDock(
        key: ValueKey('move-guidance-$hasPlayer-$hasAction'),
        attacking: state.playerAttacking,
        playerSelected: hasPlayer,
        actionSelected: hasAction,
      );
    }

    final accent = roleAccent(state.playerAttacking);
    final scenario = state.currentScenario;
    if (scenario == null) return null;
    final selectedAction = state.selectedActionCard!;
    final power = pitchPower(
      player: state.selectedPlayerCard!,
      action: selectedAction,
      scenario: scenario,
      attacking: state.playerAttacking,
    );

    return BottomLockButton(
      key: ValueKey(state.playerAttacking ? 'commit-attack' : 'commit-defense'),
      label: state.playerAttacking ? 'COMMIT ATTACK' : 'COMMIT DEFENSE',
      helper: '${power.base} CARD POWER • TIMING +0–8',
      accent: accent,
      icon: state.playerAttacking ? Icons.sports_soccer : Icons.shield,
      onPressed: () async {
        if (_shotMeterOpen) return;
        final bloc = context.read<GameBloc>();
        if (MediaQuery.of(context).disableAnimations) {
          bloc.add(MovePlayed(shotTiming: ShotTimingResult.accessible));
          return;
        }
        _shotMeterOpen = true;
        try {
          final timing = await showShotMeter(
            context,
            power: power,
            accent: accent,
            rivalRange: playerRivalRange(state),
            attacking: state.playerAttacking,
          );
          if (mounted &&
              timing != null &&
              bloc.state.phase == MatchPhase.play &&
              bloc.state.currentRound == state.currentRound) {
            bloc.add(MovePlayed(shotTiming: timing));
          }
        } finally {
          _shotMeterOpen = false;
        }
      },
    );
  }

  List<Widget> _buildLowerChildren(
    BuildContext context,
    GameState state,
    bool resolveBeat,
  ) {
    if (resolveBeat) return const [];

    // ── Scenario briefing: the shipped decrypt cinematic, embedded on the
    // board. It owns its entrance + countdown and dispatches [PlayStarted]
    // itself, so the board needs no controller for this beat.
    if (state.phase == MatchPhase.scenario) {
      final scenario = state.currentScenario;
      if (scenario == null) {
        return const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: CircularProgressIndicator(color: Cyber.cyan),
            ),
          ),
        ];
      }
      return [
        SpotlightTarget(
          spotlightKey: _scenarioSpotKey,
          child: ScenarioBriefingSection(
            key: _briefingKey,
            scenario: scenario,
            attacking: state.playerAttacking,
            initialSeconds: 1,
            deferCountdown: _scenarioWalkthrough(context, state),
          ),
        ),
      ];
    }

    return const [];
  }

  /// Only the two players who can play this role. On short/enlarged screens
  /// the hand scrolls at its real size; the COMMIT dock stays reachable.
  Widget _buildPlayHand(
    BuildContext context,
    GameState state,
    double bottomInset,
  ) {
    final accent = roleAccent(state.playerAttacking);
    final players = state.playerAttacking
        ? state.deckAttackers
        : state.deckDefenders;
    final actions = state.deckActions
        .where((a) => pitchActionFitsRole(a, state.playerAttacking))
        .toList();
    final legalIds = pitchLegalActions(
      actions: state.deckActions,
      usedIds: state.usedActionCards,
      round: state.currentRound,
      attacking: state.playerAttacking,
    ).map((a) => a.id).toSet();
    final reserved = actions.any(
      (a) => !state.usedActionCards.contains(a.id) && !legalIds.contains(a.id),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        108 +
            bottomInset +
            (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 14) * 5,
      ),
      child: SingleChildScrollView(
        key: const ValueKey('play-hand-scroll'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1  CHOOSE YOUR ${state.playerAttacking ? 'ATTACKER' : 'DEFENDER'}',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
            ),
            SpotlightTarget(
              spotlightKey: _playersKey,
              child: _BoardHandPlayers(
                cards: players,
                activeIds: players.map((p) => p.id).toSet(),
                selectedId: state.selectedPlayerCard?.id,
                usedIds: state.usedPlayerCards,
                redCardedIds: state.redCardedCards,
                accent: accent,
                onSelect: (card) =>
                    context.read<GameBloc>().add(PlayerSelected(card)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '2  LINK AN ACTION',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.8),
            ),
            if (reserved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'RESERVED: needed for a later ${state.playerAttacking ? 'defense' : 'attack'}.',
                  style: Cyber.bodyFor(context, 11, color: Cyber.amber),
                ),
              ),
            SpotlightTarget(
              spotlightKey: _actionsKey,
              child: _BoardActionRail(
                cards: actions,
                selectedId: state.selectedActionCard?.id,
                usedIds: state.usedActionCards,
                legalIds: legalIds,
                accent: accent,
                player: state.selectedPlayerCard,
                scenario: state.currentScenario,
                attacking: state.playerAttacking,
                onSelect: (card) =>
                    context.read<GameBloc>().add(ActionSelected(card)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _timelineT(double a, double b, Curve curve) {
    final v = _revealCtrl.value;
    if (v <= a) return 0;
    if (v >= b) return 1;
    return curve.transform(((v - a) / (b - a)).clamp(0.0, 1.0));
  }
}

/// Calm two-step guidance that occupies the commit dock until both cards are
/// ready. It never glows; the decisive commit CTA inherits that focus once the
/// move is complete.
class _MoveGuidanceDock extends StatelessWidget {
  const _MoveGuidanceDock({
    required this.attacking,
    required this.playerSelected,
    required this.actionSelected,
    super.key,
  });

  final bool attacking;
  final bool playerSelected;
  final bool actionSelected;

  @override
  Widget build(BuildContext context) {
    final accent = roleAccent(attacking);
    final playerRole = attacking ? 'attacker' : 'defender';
    final actionPrompt = attacking
        ? 'Now play an attack action card'
        : 'Now play a defense action card';

    final (title, helper, icon) = switch ((playerSelected, actionSelected)) {
      (false, false) => (
        attacking ? 'BUILD YOUR ATTACK' : 'SET YOUR DEFENSE',
        'Play 1 $playerRole + 1 action card',
        attacking ? Icons.sports_soccer : Icons.shield,
      ),
      (true, false) => ('PLAYER READY', actionPrompt, Icons.style),
      (false, true) => (
        'ACTION PRIMED',
        'Now choose your $playerRole',
        Icons.person_search,
      ),
      (true, true) => throw StateError('Complete moves use BottomLockButton'),
    };

    return CyberPanel(
      cornerCuts: true,
      accent: accent,
      glow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(12, color: accent, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helper,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.bodyFor(context, 11, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MoveStepStatus(
                  label: 'PLAYER',
                  complete: playerSelected,
                  active: !playerSelected,
                  accent: accent,
                ),
                const SizedBox(height: 4),
                _MoveStepStatus(
                  label: 'ACTION',
                  complete: actionSelected,
                  active: playerSelected && !actionSelected,
                  accent: accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveStepStatus extends StatelessWidget {
  const _MoveStepStatus({
    required this.label,
    required this.complete,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool complete;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = complete || active ? accent : Cyber.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          complete ? Icons.check : Icons.chevron_right,
          color: color,
          size: 12,
        ),
        const SizedBox(width: 3),
        Text(label, style: Cyber.label(8, color: color, letterSpacing: 1.2)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Opponent strip — their name plus a face-down squad row on their pitch half
// ═════════════════════════════════════════════════════════════════════════════

class _OpponentBoardStrip extends StatelessWidget {
  const _OpponentBoardStrip({required this.state});
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final ready =
        state.opponentSelectedPlayerCard != null &&
        state.opponentSelectedActionCard != null;
    final goal = pitchMasteryGoal(state.matchHistory);
    final progress = goal.progress(pitchPlayerPlays(state.roundResults));
    return SizedBox(
      key: const ValueKey('opponent-compact-hand'),
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    compactOpponentName(state),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      10,
                      color: Cyber.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.phase == MatchPhase.play
                        ? 'YOUR GOAL $progress/${goal.target} · ${goal.title}'
                        : ready
                        ? 'PLAY LOCKED'
                        : state.playerAttacking
                        ? 'DEFENDING'
                        : 'ATTACKING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.bodyFor(context, 10, color: Cyber.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              key: const ValueKey('opponent-hidden-player'),
              width: 30,
              height: 46,
              child: CardBackFace(accent: Cyber.muted),
            ),
            const SizedBox(width: 6),
            SizedBox(
              key: const ValueKey('opponent-hidden-action'),
              width: 30,
              height: 40,
              child: CardBackFace(
                accent: Cyber.muted,
                silhouette: CardBackSilhouette.action,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuelArena extends StatelessWidget {
  const _DuelArena({
    required this.state,
    required this.roleCtrl,
    required this.revealCtrl,
    required this.result,
  });

  final GameState state;
  final AnimationController roleCtrl;
  final AnimationController revealCtrl;

  /// Non-null only during the resolve beat.
  final RoundResult? result;

  static const _slotW = 84.0;
  static const _slotH = 131.0;

  @override
  Widget build(BuildContext context) {
    final resolving = result != null;
    final attackingRound = resolving
        ? result!.playerAttacking
        : state.playerAttacking;
    final playerAccent = roleAccent(attackingRound);
    final oppAccent = roleAccent(!attackingRound);
    final playerCard = resolving
        ? (result!.playerAttacking
              ? result!.attackerCard
              : result!.defenderCard)
        : state.selectedPlayerCard;
    final oppCard = resolving
        ? (result!.playerAttacking
              ? result!.defenderCard
              : result!.attackerCard)
        : null;
    final playerAction = resolving
        ? (result!.playerAttacking
              ? result!.attackAction
              : result!.defenseAction)
        : state.selectedActionCard;
    final oppAction = resolving
        ? (result!.playerAttacking
              ? result!.defenseAction
              : result!.attackAction)
        : null;

    final scenario = state.currentScenario;

    return SizedBox(
      // Grows only for the resolve beat's action chips under the slots.
      height: resolving ? 208 : 188,
      child: Stack(
        children: [
          // Calm flat arena plate — the flip is the only glow moment here.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Cyber.panel.withValues(alpha: 0.72),
                border: const Border(
                  top: BorderSide(color: Cyber.borderSubtle),
                  bottom: BorderSide(color: Cyber.borderSubtle),
                ),
              ),
            ),
          ),
          Column(
            children: [
              // The round's scenario folded onto the arena's top edge — the
              // full briefing already played, this is just the reminder.
              if (scenario != null)
                _ArenaScenarioStrip(
                  title: scenario.title,
                  bonus: state.playerAttacking
                      ? scenario.attackBonus
                      : scenario.defenseBonus,
                  attacking: attackingRound,
                ),
              Expanded(
                child: AnimatedBuilder(
                  animation: revealCtrl,
                  builder: (context, _) {
                    final t = resolving ? revealCtrl.value : 0.0;
                    final dealT = resolving
                        ? Curves.easeOutCubic.transform(
                            (t / _DuelBoardPhaseState._kDealEnd).clamp(
                              0.0,
                              1.0,
                            ),
                          )
                        : 0.0;
                    final flipT = resolving
                        ? ((t - _DuelBoardPhaseState._kFlipStart) /
                                  (_DuelBoardPhaseState._kFlipEnd -
                                      _DuelBoardPhaseState._kFlipStart))
                              .clamp(0.0, 1.0)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // Your placement, facing the opponent's across the VS.
                          Expanded(
                            child: _ArenaSlot(
                              label: 'YOU',
                              accent: playerAccent,
                              placedBack: playerCard != null,
                              revealCard: resolving ? playerCard : null,
                              flipT: flipT,
                              actionTitle: resolving && flipT >= 1
                                  ? playerAction?.title
                                  : null,
                              actionColor: playerAction == null
                                  ? playerAccent
                                  : actionColor(playerAction.category),
                              slotW: _slotW,
                              slotH: _slotH,
                              showChipRow: resolving,
                            ),
                          ),
                          _VsMedallion(
                            hot: resolving && flipT > 0 && flipT < 1,
                          ),
                          Expanded(
                            child: _ArenaSlot(
                              label: compactOpponentName(state),
                              accent: oppAccent,
                              placedBack: resolving && dealT > 0,
                              dealT: dealT,
                              revealCard: resolving ? oppCard : null,
                              flipT: flipT,
                              actionTitle: resolving && flipT >= 1
                                  ? oppAction?.title
                                  : null,
                              actionColor: oppAction == null
                                  ? oppAccent
                                  : actionColor(oppAction.category),
                              slotW: _slotW,
                              slotH: _slotH,
                              showChipRow: resolving,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Role banner sweeps over the arena at the top of every round.
          if (state.phase == MatchPhase.roleReveal)
            Positioned.fill(
              child: _RoleBanner(state: state, ctrl: roleCtrl),
            ),
        ],
      ),
    );
  }
}

/// Slim scenario reminder on the arena's top edge: title left, your bonus
/// right. The full decrypt briefing already ran — no panel, no risk chip.
class _ArenaScenarioStrip extends StatelessWidget {
  const _ArenaScenarioStrip({
    required this.title,
    required this.bonus,
    required this.attacking,
  });

  final String title;
  final int bonus;
  final bool attacking;

  @override
  Widget build(BuildContext context) {
    final accent = roleAccent(attacking);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cyber.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '// ${title.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${attacking ? 'ATK' : 'DEF'} +$bonus',
            style: Cyber.label(
              9,
              color: accent,
              letterSpacing: 1.4,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// One placement slot: an empty dashed target, a face-down [CardBackFace], or
/// a 3-D flip from back to the revealed [FaceoffCard].
class _ArenaSlot extends StatelessWidget {
  const _ArenaSlot({
    required this.label,
    required this.accent,
    required this.placedBack,
    required this.revealCard,
    required this.flipT,
    required this.actionTitle,
    required this.actionColor,
    required this.slotW,
    required this.slotH,
    required this.showChipRow,
    this.dealT = 1.0,
  });

  final String label;
  final Color accent;
  final bool placedBack;
  final PlayerCard? revealCard;
  final double flipT;
  final String? actionTitle;
  final Color actionColor;
  final double slotW;
  final double slotH;

  /// Reserve the action-chip row under the slot (resolve beat only — chips
  /// exist only after the flip).
  final bool showChipRow;

  /// Deal-in progress for the opponent's back sliding onto the board.
  final double dealT;

  @override
  Widget build(BuildContext context) {
    Widget slot;
    if (revealCard != null && flipT > 0) {
      // 3-D flip: back → front, front pre-mirrored so it lands readable.
      final angle = flipT * pi;
      final showFront = flipT >= 0.5;
      final face = showFront
          ? Transform(
              transform: Matrix4.rotationY(pi),
              alignment: Alignment.center,
              child: FaceoffCard(card: revealCard!, accent: accent),
            )
          : const CardBackFace();
      slot = Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateY(angle),
        alignment: Alignment.center,
        child: SizedBox(width: slotW, height: slotH, child: face),
      );
    } else if (placedBack) {
      slot = Transform.translate(
        offset: Offset(0, -34 * (1 - dealT)),
        child: Opacity(
          opacity: dealT.clamp(0.0, 1.0),
          child: SizedBox(
            width: slotW,
            height: slotH,
            child: CardBackFace(accent: accent),
          ),
        ),
      );
    } else {
      slot = SizedBox(
        width: slotW,
        height: slotH,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Cyber.borderSubtle),
            color: Cyber.bg2.withValues(alpha: 0.5),
          ),
          child: Center(
            child: Text(
              'AWAITING\nDEPLOY',
              textAlign: TextAlign.center,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.4),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
        ),
        const SizedBox(height: 6),
        slot,
        if (showChipRow)
          SizedBox(
            height: 22,
            child: actionTitle == null
                ? null
                : Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CyberChip(label: actionTitle!, color: actionColor),
                    ),
                  ),
          ),
      ],
    );
  }
}

/// The arena's VS coin — hot (gold + glow) only while the flip is live.
class _VsMedallion extends StatelessWidget {
  const _VsMedallion({required this.hot});

  final bool hot;

  @override
  Widget build(BuildContext context) {
    final color = hot ? Cyber.gold : Cyber.muted;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Cyber.bg,
        border: Border.all(color: color.withValues(alpha: hot ? 1 : 0.5)),
        boxShadow: hot ? Cyber.glow(Cyber.gold) : null,
      ),
      child: Text('VS', style: Cyber.display(14, color: color)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Zero-scroll play hand — intel strip + sm-card rows
// ═════════════════════════════════════════════════════════════════════════════

/// The play beat's middle band: the two hands face each other across this
/// strip — scenario reminder up top, then your role chip and the
/// live power equation. A calm flat plate; the glow stays on the cards.

class _DuelIntelStrip extends StatelessWidget {
  const _DuelIntelStrip({required this.state, super.key});
  final GameState state;
  @override
  Widget build(BuildContext context) {
    final scenario = state.currentScenario;
    final player = state.selectedPlayerCard;
    final action = state.selectedActionCard;
    final power = scenario != null && player != null && action != null
        ? pitchPower(
            player: player,
            action: action,
            scenario: scenario,
            attacking: state.playerAttacking,
          )
        : null;
    final rival = playerRivalRange(state);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CyberPanel(
        cornerCuts: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (scenario != null)
                  PitchVectorArt(
                    asset: pitchScenarioAsset(scenario),
                    width: 24,
                    height: 20,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scenario?.title.toUpperCase() ?? 'READ THE PITCH',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      10,
                      color: AppTheme.whiteColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Play details',
                    icon: const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Cyber.muted,
                    ),
                    onPressed: () => _showDetails(context, power, rival),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  power == null
                      ? 'PICK YOUR CARDS'
                      : 'YOUR POWER ${power.base}',
                  style: Cyber.display(
                    14,
                    color: AppTheme.whiteColor,
                    letterSpacing: 0,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 120),
                  child: Text(
                    power != null && power.combo > 0
                        ? 'COMBO +${power.combo}'
                        : 'TIMING +0–8',
                    key: ValueKey(power?.combo ?? 0),
                    style: Cyber.label(
                      9,
                      color: power != null && power.combo > 0
                          ? Cyber.cyan
                          : Cyber.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              rival == null
                  ? 'RIVAL POWER RANGE —'
                  : 'RIVAL POWER RANGE ${rival.min}–${rival.max}',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    PowerBreakdown? power,
    PitchPowerRange? rival,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Cyber.bg,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('YOUR PLAY', style: Cyber.display(18)),
              const SizedBox(height: 16),
              if (power != null) PitchContributionStrip(power: power),
              const SizedBox(height: 16),
              if (state.currentScenario != null)
                Text(
                  'Scenario match +6: ${pitchScenarioActionNames(state.currentScenario!, attacking: state.playerAttacking).join(', ')}.',
                  style: Cyber.bodyFor(context, 13, color: Cyber.cyan),
                ),
              const SizedBox(height: 12),
              Text(
                'Your cards set the power. Timing adds up to +8. The rival range covers all its remaining legal plays; its pick stays hidden.',
                style: Cyber.bodyFor(context, 13, color: Cyber.muted),
              ),
              const SizedBox(height: 20),
              CyberCtaButton(
                label: 'BACK TO PLAY',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two current-role players at full size. USED cards keep their slots,
/// making the once-per-match limit readable without rearranging the hand.
class _BoardHandPlayers extends StatelessWidget {
  const _BoardHandPlayers({
    required this.cards,
    required this.activeIds,
    required this.selectedId,
    required this.usedIds,
    required this.redCardedIds,
    required this.accent,
    required this.onSelect,
  });

  final List<PlayerCard> cards;

  /// The on-role pair — selectable this round.
  final Set<String> activeIds;
  final String? selectedId;
  final List<String> usedIds;
  final List<String> redCardedIds;
  final Color accent;
  final ValueChanged<PlayerCard> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('user-player-rail'),
    height: 204,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          CyberPlayerCardTile(
            key: ValueKey('user-player-card-${cards[i].id}'),
            card: cards[i],
            selected: selectedId == cards[i].id,
            disabled:
                usedIds.contains(cards[i].id) ||
                redCardedIds.contains(cards[i].id),
            disabledLabel: redCardedIds.contains(cards[i].id)
                ? 'SENT OFF'
                : 'USED',
            size: VisualCardSize.md,
            selectedAccent: accent,
            tiltOnSelect: false,
            onTap:
                activeIds.contains(cards[i].id) &&
                    !usedIds.contains(cards[i].id) &&
                    !redCardedIds.contains(cards[i].id)
                ? () => onSelect(cards[i])
                : null,
          ),
        ],
      ],
    ),
  );
}

/// The role actions as one compact row — centered when they fit, a horizontal
/// card-hand swipe when they don't. USED cards stay visible but locked.
class _BoardActionRail extends StatelessWidget {
  const _BoardActionRail({
    required this.cards,
    required this.selectedId,
    required this.usedIds,
    required this.legalIds,
    required this.accent,
    required this.onSelect,
    required this.player,
    required this.scenario,
    required this.attacking,
  });
  final List<ActionCard> cards;
  final String? selectedId;
  final List<String> usedIds;
  final Set<String> legalIds;
  final Color accent;
  final ValueChanged<ActionCard> onSelect;
  final PlayerCard? player;
  final ScenarioCard? scenario;
  final bool attacking;
  @override
  Widget build(BuildContext context) {
    Widget tile(ActionCard card) {
      final used = usedIds.contains(card.id);
      final reserved = !used && !legalIds.contains(card.id);
      final bonus = player == null || scenario == null
          ? 0
          : pitchPower(
              player: player!,
              action: card,
              scenario: scenario!,
              attacking: attacking,
            ).combo;
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CyberActionCardTile(
            key: ValueKey('user-action-card-${card.id}'),
            card: card,
            selected: selectedId == card.id,
            disabled: used || reserved,
            disabledLabel: reserved ? 'RESERVED' : 'USED',
            size: VisualCardSize.sm,
            comboBonus: bonus,
            selectedAccent: accent,
            tiltOnSelect: false,
            onTap: used || reserved ? null : () => onSelect(card),
          ),
          const SizedBox(height: 4),
          Text(
            !used && !reserved && bonus > 0
                ? 'MATCH +$bonus'
                : used
                ? 'SPENT'
                : reserved
                ? 'LATER ROUND'
                : ' ',
            style: Cyber.label(
              8,
              color: bonus > 0 && !used && !reserved ? Cyber.cyan : Cyber.muted,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      key: const ValueKey('user-action-rail'),
      height: 156,
      child: LayoutBuilder(
        builder: (context, box) {
          final fits =
              cards.length * 96 + max(0, cards.length - 1) * 8 <= box.maxWidth;
          if (fits) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  tile(cards[i]),
                ],
              ],
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 6),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => tile(cards[i]),
          );
        },
      ),
    );
  }
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.state, required this.ctrl});

  final GameState state;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    final attacking = state.playerAttacking;
    final accent = roleAccent(attacking);
    final round = max(1, state.currentRound);
    final context2 = round > 1
        ? 'ROLES SWITCHED'
        : '${compactOpponentName(state).toUpperCase()} WON THE TOSS';

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final inT = Curves.easeOutCubic.transform(
          (ctrl.value / 0.30).clamp(0.0, 1.0),
        );
        final landT = Curves.easeOutBack.transform(
          ((ctrl.value - 0.25) / 0.25).clamp(0.0, 1.0),
        );
        return ColoredBox(
          color: Cyber.bg.withValues(alpha: 0.82 * inT),
          child: Center(
            child: Opacity(
              opacity: inT,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ROUND $round // $context2',
                    style: Cyber.label(10, color: Cyber.muted, letterSpacing: 2)
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: 10),
                  Transform.scale(
                    scale: 0.6 + 0.4 * landT,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          accent.withValues(alpha: 0.16),
                          Cyber.panel,
                        ),
                        border: Border.all(color: accent, width: 1.5),
                        boxShadow: landT > 0.4 ? Cyber.glow(accent) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attacking ? Icons.sports_soccer : Icons.shield,
                            color: accent,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            attacking ? 'YOU ATTACK' : 'YOU DEFEND',
                            style: Cyber.display(
                              22,
                              color: accent,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
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
