import 'dart:async';
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
/// the opponent's face-down deck on their pitch half up top, a central arena
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
    duration: const Duration(milliseconds: 2100),
  );

  /// Round resolution: opponent card deals in, both flip, powers tick,
  /// verdict stamps, score pays off.
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  /// Full-bleed GOAL!/DENIED! stamp fired at the verdict beat.
  late final AnimationController _stinger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  /// CPU commit: a beat into the play phase the opponent's chosen face-down
  /// card lifts and locks, UNO-style — they've moved, now it's on you.
  late final AnimationController _cpuCommitCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _cpuThinkTimer;
  bool _cpuCommitted = false;

  bool _roleStingFired = false;
  bool _flipFired = false;
  bool _meterFired = false;
  bool _verdictFired = false;
  bool _scoreFired = false;
  bool _revealDone = false;
  bool _bootstrapped = false;

  // Spotlight walkthrough targets (same tutorial keys as the old phases so
  // players who saw them never see them twice).
  final _powerKey = GlobalKey();
  final _playersKey = GlobalKey();
  final _actionsKey = GlobalKey();
  final _arenaKey = GlobalKey();
  final _scenarioSpotKey = GlobalKey();
  final _countdownKey = GlobalKey<NextRoundCountdownState>();
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
    _cpuThinkTimer?.cancel();
    switch (_phase) {
      case MatchPhase.roleReveal:
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
        _cpuCommitted = false;
        _cpuCommitCtrl.value = 0;
        if (_reduceMotion) {
          _cpuCommitted = true;
          _cpuCommitCtrl.value = 1;
        } else {
          // A short randomized "thinking" beat before the CPU commits.
          _cpuThinkTimer = Timer(
            Duration(milliseconds: 1500 + Random().nextInt(1000)),
            _commitCpu,
          );
        }
      case MatchPhase.roundResult:
        _startRevealBeat();
      default:
        // The scenario beat needs no controller: the embedded
        // [ScenarioBriefingSection] owns its decrypt entrance + countdown and
        // dispatches [PlayStarted] itself.
        break;
    }
  }

  void _commitCpu() {
    if (!mounted ||
        _phase != MatchPhase.play ||
        widget.state.opponentSelectedPlayerCard == null) {
      return;
    }
    setState(() => _cpuCommitted = true);
    _cpuCommitCtrl.forward(from: 0);
    playSound(SoundEffect.commit);
    HapticFeedback.lightImpact();
  }

  void _startRevealBeat() {
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
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted && !_revealDone) setState(() => _revealDone = true);
      });
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
    _cpuThinkTimer?.cancel();
    _roleCtrl.dispose();
    _revealCtrl.dispose();
    _stinger.dispose();
    _cpuCommitCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────

  List<SpotlightStep> get _playSpotlightSteps => [
    SpotlightStep(
      targetKey: _powerKey,
      title: 'Power Preview',
      body: 'OVR + action + bonus. Timing adds up to +20.',
      icon: Icons.bolt,
      accent: Cyber.gold,
    ),
    SpotlightStep(
      targetKey: _playersKey,
      title: 'Player Card',
      body: 'Pick one player. It deploys face-down to the arena.',
      icon: Icons.person,
      accent: Cyber.cyan,
    ),
    SpotlightStep(
      targetKey: _actionsKey,
      title: 'Action Card',
      body: 'Pick one action for your role.',
      icon: Icons.style,
      accent: Cyber.magenta,
    ),
  ];

  List<SpotlightStep> get _scenarioSpotlightSteps => [
    SpotlightStep(
      targetKey: _scenarioSpotKey,
      title: 'Scenario',
      body: 'Read the scenario. ATK/DEF bonuses apply this round.',
      icon: Icons.flag,
      accent: Cyber.lime,
    ),
  ];

  List<SpotlightStep> get _resultSpotlightSteps => [
    SpotlightStep(
      targetKey: _arenaKey,
      title: 'Round Result',
      body: 'Both cards flip — Goal, Saved, Blocked, Missed, Foul, Red Card.',
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
      grain: true,
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
          const Positioned.fill(child: StadiumBackground()),
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
              startDelay: const Duration(milliseconds: 700),
            ),
          if (resultWalkthrough)
            SpotlightTutorial(
              keyName: 'round-result',
              steps: _resultSpotlightSteps,
              enabled: _revealDone,
              startDelay: const Duration(milliseconds: 350),
              onComplete: () => _countdownKey.currentState?.beginCountdown(),
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
    double bottomInset,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _OpponentDuelHand(
            state: state,
            commitCtrl: _cpuCommitCtrl,
            committed: _cpuCommitted,
          ),
        ),
        Align(
          alignment: const Alignment(0, -0.08),
          child: SpotlightTarget(
            spotlightKey: _powerKey,
            child: _DuelIntelStrip(state: state),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: boardHeight * 0.48,
          bottom: 0,
          child: _buildPlayHand(context, state, bottomInset),
        ),
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
                max(
                  12,
                  boardHeight * 0.5 - opponentHeight - (resolveBeat ? 104 : 94),
                ),
                16,
                (hasBottomAction ? 128 : 16) + bottomInset,
              ),
              children: [
                SpotlightTarget(
                  spotlightKey: _arenaKey,
                  child: _DuelArena(
                    state: state,
                    roleCtrl: _roleCtrl,
                    revealCtrl: _revealCtrl,
                    result: resolveBeat ? _lastResult : null,
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
    final scenarioBonus = state.playerAttacking
        ? state.currentScenario?.attackBonus ?? 0
        : state.currentScenario?.defenseBonus ?? 0;
    final selectedAction = state.selectedActionCard!;
    final basePower =
        state.selectedPlayerCard!.rating + selectedAction.power + scenarioBonus;
    final successChance = playerSuccessChance(state, basePower.toDouble());
    final chancePct = (successChance * 100).round();
    final chanceLabel = state.playerAttacking ? 'GOAL CHANCE' : 'STOP CHANCE';

    return BottomLockButton(
      key: ValueKey(state.playerAttacking ? 'commit-attack' : 'commit-defense'),
      label: state.playerAttacking ? 'COMMIT ATTACK' : 'COMMIT DEFENSE',
      helper: state.playerAttacking
          ? '$chancePct% GOAL CHANCE • TIME YOUR STRIKE'
          : '$chancePct% STOP CHANCE • TIME YOUR BLOCK',
      accent: accent,
      icon: state.playerAttacking ? Icons.sports_soccer : Icons.shield,
      onPressed: () async {
        final bloc = context.read<GameBloc>();
        if (MediaQuery.of(context).disableAnimations) {
          bloc.add(MovePlayed());
          return;
        }
        final surge = await showShotMeter(
          context,
          base: basePower.toDouble(),
          accent: accent,
          chanceLabel: chanceLabel,
          successChance: successChance,
          isRisky: selectedAction.risky,
        );
        if (surge != null) bloc.add(MovePlayed(playerSurge: surge));
      },
    );
  }

  List<Widget> _buildLowerChildren(
    BuildContext context,
    GameState state,
    bool resolveBeat,
  ) {
    // ── Resolution: powers tick, verdict stamps, score pays off ──
    if (resolveBeat) {
      final result = _lastResult;
      if (result == null) return const [];
      final playerAttacking = result.playerAttacking;
      final playerPower = playerAttacking
          ? result.attackPower
          : result.defensePower;
      final oppPower = playerAttacking
          ? result.defensePower
          : result.attackPower;
      final goalScored = result.outcome == RoundOutcome.goal;
      return [
        AnimatedBuilder(
          animation: _revealCtrl,
          builder: (context, _) {
            final meterT = _timelineT(
              _kFlipEnd,
              _kMeterEnd,
              Curves.easeOutCubic,
            );
            final deflated = result.outcome == RoundOutcome.missed;
            final verdictT = _timelineT(
              _kVerdictStart,
              _kVerdictEnd,
              deflated ? Curves.easeOut : Curves.easeOutBack,
            );
            final scoreT = _timelineT(_kVerdictEnd, 1.0, Curves.easeOutCubic);
            return Column(
              children: [
                Opacity(
                  opacity: meterT.clamp(0.0, 1.0),
                  child: HeadToHeadPowerMeter(
                    playerRole: playerAttacking ? 'ATTACK' : 'DEFEND',
                    oppRole: playerAttacking ? 'DEFEND' : 'ATTACK',
                    playerPower: playerPower,
                    oppPower: oppPower,
                    playerAccent: roleAccent(playerAttacking),
                    oppAccent: roleAccent(!playerAttacking),
                    progress: meterT,
                  ),
                ),
                const SizedBox(height: 14),
                VerdictHero(
                  outcome: result.outcome,
                  playerAttacking: playerAttacking,
                  accent: outcomeColor(result.outcome),
                  t: verdictT,
                ),
                const SizedBox(height: 12),
                ScoreImpactStrip(
                  playerScore: state.playerScore,
                  opponentScore: state.opponentScore,
                  opponentLabel: compactOpponentName(state),
                  goalScored: goalScored,
                  scoringIsPlayer: playerAttacking,
                  t: scoreT,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (state.currentRound < 4)
          AnimatedOpacity(
            opacity: _revealDone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _revealDone
                ? NextRoundCountdown(
                    key: _countdownKey,
                    deferCountdown:
                        state.currentRound == 1 &&
                        !context.read<GameBloc>().state.tutorialSeen.contains(
                          'round-result',
                        ),
                    onComplete: () =>
                        context.read<GameBloc>().add(RoundAdvanced()),
                  )
                : const SizedBox(height: 72),
          ),
      ];
    }

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
            initialSeconds: 3,
            deferCountdown: _scenarioWalkthrough(context, state),
          ),
        ),
      ];
    }

    return const [];
  }

  /// The zero-scroll play hand: your FULL four-card hand on your pitch half
  /// (the on-role pair full-size and live, the off-role pair benched) above the
  /// action rail — everything visible at once. On extreme small screens the
  /// whole block scales down instead of scrolling or overflowing.
  Widget _buildPlayHand(
    BuildContext context,
    GameState state,
    double bottomInset,
  ) {
    final accent = roleAccent(state.playerAttacking);
    // Fixed order across rounds, mirroring the opponent's hand: attackers
    // left, defenders right — the lifted pair seesaws with the role.
    final handCards = [...state.deckAttackers, ...state.deckDefenders];
    final activeIds =
        (state.playerAttacking ? state.deckAttackers : state.deckDefenders)
            .map((card) => card.id)
            .toSet();
    final availableActions = state.deckActions
        .where(
          (card) => state.playerAttacking
              ? card.category == ActionCategory.attack ||
                    card.category == ActionCategory.special
              : card.category == ActionCategory.defense ||
                    card.category == ActionCategory.special,
        )
        .toList();

    final hand = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpotlightTarget(
          spotlightKey: _playersKey,
          child: _BoardHandPlayers(
            cards: handCards,
            activeIds: activeIds,
            selectedId: state.selectedPlayerCard?.id,
            usedIds: state.usedPlayerCards,
            redCardedIds: state.redCardedCards,
            accent: accent,
            onSelect: (card) =>
                context.read<GameBloc>().add(PlayerSelected(card)),
          ),
        ),
        const SizedBox(height: 8),
        SpotlightTarget(
          spotlightKey: _actionsKey,
          child: _BoardActionRail(
            cards: availableActions,
            selectedId: state.selectedActionCard?.id,
            usedIds: state.usedActionCards,
            accent: accent,
            onSelect: (card) =>
                context.read<GameBloc>().add(ActionSelected(card)),
          ),
        ),
      ],
    );

    // The guidance/commit dock needs ~102px of clearance. If the remaining
    // band is too short, scale the whole hand down instead of scrolling.
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 108 + bottomInset),
      child: LayoutBuilder(
        builder: (context, box) {
          const needed = 332.0; // players 168 + gap 8 + actions 156
          // Anchor the hand to the bottom, hugging the move dock — cards held
          // at the table's edge, with the pitch breathing above them.
          if (box.maxHeight >= needed) {
            return Align(alignment: Alignment.bottomCenter, child: hand);
          }
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: box.maxWidth, child: hand),
          );
        },
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
                    style: Cyber.body(11, color: Cyber.muted),
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
    // Their role-relevant pool this round: when you attack, their defenders
    // stand between you and the goal (mirrors GameBloc's pick in MovePlayed).
    final attackingRound = state.phase == MatchPhase.roundResult
        ? (state.roundResults.isEmpty
              ? state.playerAttacking
              : state.roundResults.last.playerAttacking)
        : state.playerAttacking;
    final pool = [...state.opponentAttackers, ...state.opponentDefenders];
    final oppRole = attackingRound ? 'DEFENDING' : 'ATTACKING';
    final oppAccent = roleAccent(!attackingRound);

    return SizedBox(
      key: const ValueKey('opponent-compact-hand'),
      height: 78,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${compactOpponentName(state)} //',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            11,
                            color: Cyber.muted,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CyberChip(label: oppRole, color: oppAccent),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Face-down squad: you can see they hold cards, not the values.
                for (var i = 0; i < pool.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  SizedBox(
                    width: 34,
                    height: 53,
                    child: CardBackFace(
                      accent: Cyber.danger,
                      dimmed: state.opponentRedCarded.contains(pool[i].id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Opponent duel hand — role-valid actions above the full player hand, all
// face-down and mirrored across the table during the play beat.
// ═════════════════════════════════════════════════════════════════════════════

class _OpponentDuelHand extends StatelessWidget {
  const _OpponentDuelHand({
    required this.state,
    required this.commitCtrl,
    required this.committed,
  });

  final GameState state;
  final AnimationController commitCtrl;
  final bool committed;

  static const _playerCardW = 76.0;
  static const _playerCardH = 119.0;
  static const _actionCardW = 64.0;
  static const _actionCardH = 86.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final oppRole = state.playerAttacking ? 'DEFENDING' : 'ATTACKING';
    final oppAccent = roleAccent(!state.playerAttacking);
    // Fixed order across rounds — reading their backs is a memory game.
    final playerHand = [...state.opponentAttackers, ...state.opponentDefenders];
    final playerLockIndex = playerHand.indexWhere(
      (card) => card.id == state.opponentSelectedPlayerCard?.id,
    );
    final relevantCategory = state.playerAttacking
        ? ActionCategory.defense
        : ActionCategory.attack;
    final roleActions = state.opponentActions
        .where(
          (card) =>
              card.category == relevantCategory ||
              card.category == ActionCategory.special,
        )
        .toList();
    // Match GameBloc's CPU fallback exactly: an unusual deck with no
    // role-valid actions still shows the pool the CPU may draw from.
    final actionHand = roleActions.isEmpty
        ? state.opponentActions
        : roleActions;
    final actionLockIndex = actionHand.indexWhere(
      (card) => card.id == state.opponentSelectedActionCard?.id,
    );

    return SizedBox(
      key: const ValueKey('opponent-full-hand'),
      height: 264,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Column(
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${compactOpponentName(state)} //',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.label(
                      11,
                      color: Cyber.muted,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CyberChip(label: oppRole, color: oppAccent),
              ],
            ),
            const SizedBox(height: 3),
            _straightRail(
              key: const ValueKey('opponent-action-rail'),
              height: 92,
              children: [
                for (var i = 0; i < actionHand.length; i++)
                  _hiddenBack(
                    key: ValueKey('opponent-action-card-${actionHand[i].id}'),
                    width: _actionCardW,
                    height: _actionCardH,
                    silhouette: CardBackSilhouette.action,
                    locked: committed && i == actionLockIndex,
                    actionLock: true,
                  ),
              ],
            ),
            const SizedBox(height: 3),
            _straightRail(
              key: const ValueKey('opponent-player-rail'),
              height: 128,
              children: [
                for (var i = 0; i < playerHand.length; i++)
                  _hiddenBack(
                    key: ValueKey('opponent-player-card-${playerHand[i].id}'),
                    width: _playerCardW,
                    height: _playerCardH,
                    silhouette: CardBackSilhouette.player,
                    dimmed: state.opponentRedCarded.contains(playerHand[i].id),
                    locked: committed && i == playerLockIndex,
                    actionLock: false,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _straightRail({
    required Key key,
    required double height,
    required List<Widget> children,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hiddenBack({
    required Key key,
    required double width,
    required double height,
    required CardBackSilhouette silhouette,
    required bool locked,
    required bool actionLock,
    bool dimmed = false,
  }) {
    final face = SizedBox(
      width: width,
      height: height,
      child: CardBackFace(
        accent: Cyber.danger,
        dimmed: dimmed,
        silhouette: silhouette,
      ),
    );
    Widget rotatedFace(Widget child) =>
        Transform.rotate(key: key, angle: pi, child: child);

    if (!locked || dimmed) return rotatedFace(face);

    // The committed player moves first. The action follows a fraction later;
    // both travel down toward midfield and finish flat. The stamp lives inside
    // the 180-degree transform so it faces the rival along with the card.
    return AnimatedBuilder(
      animation: commitCtrl,
      builder: (context, child) {
        final rawT = commitCtrl.value;
        final stagedT = actionLock
            ? const Interval(0.22, 1, curve: Curves.easeOutBack).transform(rawT)
            : const Interval(
                0,
                0.82,
                curve: Curves.easeOutBack,
              ).transform(rawT);
        final pulseT = stagedT.clamp(0.0, 1.0);
        final pulse = sin(pi * pulseT);
        final travel = actionLock ? 8.0 : 12.0;
        return Transform.translate(
          offset: Offset(0, travel * stagedT),
          child: Transform.scale(
            scale: 1 + 0.04 * stagedT,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: pulse > 0.01
                    ? Cyber.glow(Cyber.danger, alpha: 0.45 * pulse)
                    : null,
              ),
              child: rotatedFace(
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child!,
                    Positioned(
                      left: 2,
                      right: 2,
                      bottom: 6,
                      child: Center(
                        child: Opacity(
                          opacity: ((stagedT - 0.5) * 2).clamp(0.0, 1.0),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: CyberChip(
                              label: 'LOCKED',
                              color: Cyber.danger,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      child: face,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// The central arena — two placement slots facing each other across the VS
// ═════════════════════════════════════════════════════════════════════════════

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
  const _DuelIntelStrip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final attacking = state.playerAttacking;
    final accent = roleAccent(attacking);
    final scenario = state.currentScenario;
    final bonus = attacking
        ? scenario?.attackBonus ?? 0
        : scenario?.defenseBonus ?? 0;
    final player = state.selectedPlayerCard;
    final action = state.selectedActionCard;
    final total = player == null || action == null
        ? null
        : player.rating + action.power + bonus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SizedBox(
          width: double.infinity,
          child: CyberPanel(
            accent: accent,
            glow: false,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ArenaScenarioStrip(
                  title: scenario?.title ?? 'Awaiting intel',
                  bonus: bonus,
                  attacking: attacking,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      CyberChip(
                        label: attacking ? 'ATTACKING' : 'DEFENDING',
                        color: accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _PowerEquation(
                            player: player,
                            action: action,
                            bonus: bonus,
                            total: total,
                            attacking: attacking,
                            accent: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line live power readout: `⚽ 80 + ⚡ 12 + +5 = 97–117`, with `--`
/// placeholders until each pick lands. Honest range (floor..floor+20).
class _PowerEquation extends StatelessWidget {
  const _PowerEquation({
    required this.player,
    required this.action,
    required this.bonus,
    required this.total,
    required this.attacking,
    required this.accent,
  });

  final PlayerCard? player;
  final ActionCard? action;
  final int bonus;
  final int? total;
  final bool attacking;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    Text num(String text, Color color) => Text(
      text,
      style: Cyber.display(
        15,
        color: color,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
    Widget sym(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(text, style: Cyber.display(13, color: Cyber.muted)),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            attacking ? Icons.sports_soccer : Icons.shield,
            color: accent,
            size: 14,
          ),
          const SizedBox(width: 6),
          num(player == null ? '--' : '${player!.rating}', accent),
          sym('+'),
          Icon(action?.icon ?? Icons.style, color: Cyber.magenta, size: 14),
          const SizedBox(width: 6),
          num(action == null ? '--' : '${action!.power}', Cyber.magenta),
          sym('+'),
          num('+$bonus', Cyber.success),
          sym('='),
          num(total == null ? '--' : '$total–${total! + 20}', Cyber.gold),
        ],
      ),
    );
  }
}

/// Your FULL four-card hand as a centered straight row — the on-role pair is
/// full-size and live, the off-role pair waits benched (small, dim, inert) at the
/// baseline. USED cards stay visible but locked: each player card plays once
/// per match, UNO-style. No heading, no backdrop panel: the pitch half behind
/// the board already sets the scene.
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
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('user-player-rail'),
      // sm tile (144) + selection lift/shadow headroom.
      height: 168,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 168,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _StaggerIn(index: i, child: _tile(cards[i])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(PlayerCard card) {
    final active = activeIds.contains(card.id);
    final used = usedIds.contains(card.id);
    final redCarded = redCardedIds.contains(card.id);
    final locked = used || redCarded;
    final selected = selectedId == card.id;

    final Widget tile = CyberPlayerCardTile(
      key: ValueKey('user-player-card-${card.id}'),
      card: card,
      selected: selected,
      disabled: active && locked,
      disabledLabel: redCarded ? 'SENT OFF' : 'USED',
      size: VisualCardSize.sm,
      selectedAccent: accent,
      tiltOnSelect: false,
      onTap: active && !locked ? () => onSelect(card) : null,
    );

    if (!active) {
      // Off-role: benched this round — smaller, dim and inert. IgnorePointer
      // is required (not just a null onTap): the shell still plays the tap
      // SFX otherwise.
      return SizedBox(
        width: 78,
        height: 117,
        child: FittedBox(
          child: SizedBox(
            width: 96,
            height: 144,
            child: Opacity(opacity: 0.45, child: IgnorePointer(child: tile)),
          ),
        ),
      );
    }
    // Every resting card shares one baseline. Only the live selection lifts.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
      child: tile,
    );
  }
}

/// The role actions as one compact row — centered when they fit, a horizontal
/// card-hand swipe when they don't. USED cards stay visible but locked.
class _BoardActionRail extends StatelessWidget {
  const _BoardActionRail({
    required this.cards,
    required this.selectedId,
    required this.usedIds,
    required this.accent,
    required this.onSelect,
  });

  final List<ActionCard> cards;
  final String? selectedId;
  final List<String> usedIds;
  final Color accent;
  final ValueChanged<ActionCard> onSelect;

  static const _tileW = 96.0;
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    Widget tile(ActionCard card, int index) {
      final used = usedIds.contains(card.id);
      return _StaggerIn(
        index: index,
        baseDelayMs: 220,
        child: CyberActionCardTile(
          key: ValueKey('user-action-card-${card.id}'),
          card: card,
          selected: selectedId == card.id,
          disabled: used,
          disabledLabel: 'USED',
          size: VisualCardSize.sm,
          selectedAccent: accent,
          tiltOnSelect: false,
          onTap: used ? null : () => onSelect(card),
        ),
      );
    }

    Widget elevated(int index, Widget child) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          selectedId == cards[index].id ? -8 : 0,
          0,
        ),
        child: child,
      );
    }

    return SizedBox(
      key: const ValueKey('user-action-rail'),
      height: 156,
      child: LayoutBuilder(
        builder: (context, box) {
          final fitsAsRow =
              cards.length * _tileW + (cards.length - 1) * _gap <= box.maxWidth;
          if (fitsAsRow) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  elevated(i, tile(cards[i], i)),
                ],
              ],
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) => Align(
              alignment: Alignment.bottomCenter,
              child: elevated(index, tile(cards[index], index)),
            ),
          );
        },
      ),
    );
  }
}

/// Small dealt-in entrance: fade + rise, staggered per card index.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({
    required this.index,
    required this.child,
    this.baseDelayMs = 60,
  });

  final int index;
  final Widget child;
  final int baseDelayMs;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
      Duration(milliseconds: widget.baseDelayMs + widget.index * 70),
      () {
        if (mounted) _c.forward();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Role assignment sweeping across the arena: "YOU ATTACK" / "YOU DEFEND"
/// with the toss/switch context line. Auto-advances from the board's
/// controller — no tap needed.
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
