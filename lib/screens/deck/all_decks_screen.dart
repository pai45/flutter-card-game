import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/sport_match.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/sport_underline_tabs.dart';
import '../../widgets/game_scaffold.dart';
import '../final_over/final_over_deck_builder_screen.dart';
import '../grand_prix/grand_prix_pit_deck_screen.dart';
import 'basketball_deck_builder_screen.dart';
import 'deck_builder_screen.dart';
import 'tennis_deck_builder_screen.dart';

class AllDecksScreen extends StatelessWidget {
  const AllDecksScreen({
    required this.onBack,
    required this.onPlaySport,
    super.key,
  });

  final VoidCallback onBack;

  /// Fired from a locked tab's CTA — the caller pops the locker and routes
  /// to that sport's GAMES tab, where launching the game claims the starter
  /// pack (see `_enterCricketGameFlow` and friends in `app.dart`).
  final ValueChanged<Sport> onPlaySport;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => BasketballCubit(SecureGameStorage())..load(),
        ),
        BlocProvider(
          create: (_) => GrandPrixCubit(SecureGameStorage())..load(),
        ),
      ],
      child: _DeckLockerView(onBack: onBack, onPlaySport: onPlaySport),
    );
  }
}

class _DeckLockerView extends StatefulWidget {
  const _DeckLockerView({required this.onBack, required this.onPlaySport});

  final VoidCallback onBack;
  final ValueChanged<Sport> onPlaySport;

  @override
  State<_DeckLockerView> createState() => _DeckLockerViewState();
}

class _DeckLockerViewState extends State<_DeckLockerView> {
  int _activeSportTab = 0;
  Sport? _lastSavedSport;
  Timer? _sealTimer;
  bool _initialTabPicked = false;

  @override
  void dispose() {
    _sealTimer?.cancel();
    super.dispose();
  }

  Sport get _selectedSport => sportTabOrder[_activeSportTab];

  void _onSportTabChanged(int index) {
    setState(() => _activeSportTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final basketball = context.watch<BasketballCubit>().state;
    final grandPrix = context.watch<GrandPrixCubit>().state;
    final finalOver = context.watch<FinalOverCubit>().state;

    return BlocBuilder<GameBloc, GameState>(
      builder: (context, game) {
        if (game.loading || basketball.loading || grandPrix.loading) {
          return GameScaffold(
            title: 'Deck Locker',
            subtitle: '// SYNCING LOADOUTS',
            leading: IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Cyber.cyan),
            ),
          );
        }

        final entries = _entries(
          game,
          basketballTeamId: basketball.teamId,
          finalOverKitId: finalOver.kitId,
          racingLivery: grandPrix.livery.name,
        );

        // Open on the first sport that still needs attention (unlocked but
        // not ready), so the locker never lands on a channel that's already
        // squared away.
        if (!_initialTabPicked) {
          _initialTabPicked = true;
          final needsWork = entries.indexWhere(
            (entry) => !entry.locked && !entry.ready,
          );
          if (needsWork != -1) _activeSportTab = needsWork;
        }

        return GameScaffold(
          title: 'Deck Locker',
          subtitle:
              '// ${game.sportDeckReadyCount}/${entries.length} SPORT CHANNELS READY',
          leading: IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: CyberProgressBar(
                  value: game.sportDeckReadyCount / entries.length,
                  accent: game.sportDeckReadyCount == entries.length
                      ? Cyber.success
                      : Cyber.cyan,
                ),
              ),
              SportUnderlineTabs(
                activeIndex: _activeSportTab,
                selectedSport: _selectedSport,
                onTap: _onSportTabChanged,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: KeyedSubtree(
                    key: ValueKey<Sport>(_selectedSport),
                    child: _SportLoadoutTab(
                      entry: entries[_activeSportTab],
                      justSaved: entries[_activeSportTab].sport ==
                          _lastSavedSport,
                      onEdit: () => _openEditor(entries[_activeSportTab].sport),
                      onPlaySport: widget.onPlaySport,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_DeckEntry> _entries(
    GameState game, {
    required String basketballTeamId,
    required String finalOverKitId,
    required String racingLivery,
  }) {
    return [
      _DeckEntry(
        sport: Sport.football,
        kicker: '// 5-A-SIDE + 6 ACTIONS',
        ready: game.pitchDuelDeckReady,
        locked: !game.starterPackClaimed,
        meta: 'KIT READY',
        players: [
          ...game.deckAttackers.map((c) => (role: 'ATTACK', card: c)),
          ...game.deckDefenders.map((c) => (role: 'DEFENCE', card: c)),
        ],
        keeper: game.deckKeeper,
        actions: game.deckActions,
        filled: game.deckAttackers.length +
            game.deckDefenders.length +
            (game.deckKeeper == null ? 0 : 1),
        total: 5,
      ),
      _DeckEntry(
        sport: Sport.cricket,
        kicker: '// FINAL OVER BATTING ORDER',
        ready: game.finalOverDeckReady,
        locked: !game.cricketStarterPackClaimed,
        meta: 'KIT ${finalOverKitId.toUpperCase()}',
        players: game.deckFinalOverBatsmen
            .map((c) => (role: 'BATTING ORDER', card: c))
            .toList(),
        keeper: null,
        actions: const [],
        filled: game.deckFinalOverBatsmen.length,
        total: 5,
      ),
      _DeckEntry(
        sport: Sport.basketball,
        kicker: '// GUARD · WING · BIG',
        ready: game.hoopDuelDeckReady,
        locked: !game.basketballStarterPackClaimed,
        meta: 'JERSEY ${basketballTeamId.toUpperCase()}',
        players: game.deckBasketballPlayers
            .map((c) => (role: 'ROTATION', card: c))
            .toList(),
        keeper: null,
        actions: const [],
        starter: game.deckBasketballStarter,
        filled: game.deckBasketballPlayers.length,
        total: 3,
      ),
      _DeckEntry(
        sport: Sport.tennis,
        kicker: '// SINGLES ATHLETE',
        ready: game.tennisDeckReady,
        locked: !game.tennisStarterPackClaimed,
        meta: game.deckTennisStarter == null
            ? '0/1 ATHLETE'
            : '${game.deckTennisStarter!.trait.toUpperCase()} · OVR ${game.deckTennisStarter!.rating}',
        players: game.deckTennisPlayers
            .map((c) => (role: 'ATHLETE', card: c))
            .toList(),
        keeper: null,
        actions: const [],
        starter: game.deckTennisStarter,
        filled: game.deckTennisPlayers.isEmpty ? 0 : 1,
        total: 1,
      ),
      _DeckEntry(
        sport: Sport.motorsport,
        kicker: '// DRIVER + LIVERY',
        ready: game.racingDriverDeckReady,
        locked: !game.grandPrixStarterPackClaimed,
        meta: game.deckRacingStarter == null
            ? '0/1 DRIVER'
            : '${game.deckRacingStarter!.position.toUpperCase()} · ${racingLivery.toUpperCase()}',
        players: game.deckRacingPlayers
            .map((c) => (role: 'DRIVER', card: c))
            .toList(),
        keeper: null,
        actions: const [],
        starter: game.deckRacingStarter,
        filled: game.deckRacingPlayers.isEmpty ? 0 : 1,
        total: 1,
      ),
    ];
  }

  Future<void> _openEditor(Sport sport) async {
    HapticFeedback.selectionClick();
    final basketball = context.read<BasketballCubit>();
    final grandPrix = context.read<GrandPrixCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (routeContext) {
          void back() => Navigator.of(routeContext).pop(false);
          void onSaved() => Navigator.of(routeContext).pop(true);
          return switch (sport) {
            Sport.football => DeckBuilderScreen.management(
                onBack: back,
                onSaved: onSaved,
              ),
            Sport.cricket => FinalOverDeckBuilderScreen(
                onBack: back,
                onSaved: onSaved,
              ),
            Sport.basketball => BlocProvider.value(
                value: basketball,
                child: BasketballDeckBuilderScreen(
                  onBack: back,
                  onSaved: onSaved,
                ),
              ),
            Sport.tennis => TennisDeckBuilderScreen(
                onBack: back,
                onSaved: onSaved,
              ),
            Sport.motorsport => BlocProvider.value(
                value: grandPrix,
                child: GrandPrixPitDeckScreen(
                  onBack: back,
                  onSaved: onSaved,
                ),
              ),
          };
        },
      ),
    );
    if (!mounted || saved != true) return;
    HapticFeedback.mediumImpact();
    playSound(SoundEffect.uiConfirm);
    _sealTimer?.cancel();
    setState(() => _lastSavedSport = sport);
    _sealTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _lastSavedSport = null);
    });
  }
}

class _SportLoadoutTab extends StatelessWidget {
  const _SportLoadoutTab({
    required this.entry,
    required this.justSaved,
    required this.onEdit,
    required this.onPlaySport,
  });

  final _DeckEntry entry;
  final bool justSaved;
  final VoidCallback onEdit;
  final ValueChanged<Sport> onPlaySport;

  SportModule get _module => sportModuleFor(entry.sport);

  @override
  Widget build(BuildContext context) {
    if (entry.locked) {
      return _LoadoutLockedTab(
        module: _module,
        onPlay: () => onPlaySport(entry.sport),
      );
    }

    final accent = _module.accent;
    final ctaLabel = entry.ready ? 'EDIT LOADOUT' : 'BUILD LOADOUT';

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            _LoadoutHeader(entry: entry, accent: accent),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: justSaved
                  ? _LoadoutLockedSeal(
                      key: ValueKey(entry.sport),
                      label: _module.label.toUpperCase(),
                    )
                  : const SizedBox.shrink(),
            ),
            if (justSaved) const SizedBox(height: 12),
            ..._sections(accent),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: HudCtaButton(
            label: ctaLabel,
            icon: entry.ready ? Icons.edit_rounded : Icons.build_rounded,
            accent: accent,
            onTap: onEdit,
          ),
        ),
      ],
    );
  }

  List<Widget> _sections(Color accent) {
    final widgets = <Widget>[];
    var cardIndex = 0;

    void addGroup(String label, List<Widget> tiles) {
      if (tiles.isEmpty) return;
      widgets
        ..add(SectionLabel(label: label))
        ..add(const SizedBox(height: 8))
        ..add(Wrap(spacing: 10, runSpacing: 10, children: tiles))
        ..add(const SizedBox(height: 18));
    }

    if (entry.sport == Sport.football) {
      final attack = entry.players.where((p) => p.role == 'ATTACK').toList();
      final defence = entry.players.where((p) => p.role == 'DEFENCE').toList();
      addGroup('ATTACK', [
        for (var i = 0; i < 2; i++)
          _dealt(
            cardIndex++,
            i < attack.length
                ? _playerTile(attack[i].card, accent, VisualCardSize.sm)
                : _EmptyLoadoutSlot(
                    label: 'ATTACK',
                    accent: accent,
                    size: VisualCardSize.sm,
                  ),
          ),
      ]);
      addGroup('DEFENCE', [
        for (var i = 0; i < 2; i++)
          _dealt(
            cardIndex++,
            i < defence.length
                ? _playerTile(defence[i].card, accent, VisualCardSize.sm)
                : _EmptyLoadoutSlot(
                    label: 'DEFENCE',
                    accent: accent,
                    size: VisualCardSize.sm,
                  ),
          ),
      ]);
      addGroup('KEEPER', [
        _dealt(
          cardIndex++,
          entry.keeper != null
              ? _playerTile(entry.keeper!, accent, VisualCardSize.sm)
              : _EmptyLoadoutSlot(
                  label: 'KEEPER',
                  accent: accent,
                  size: VisualCardSize.sm,
                ),
        ),
      ]);
      addGroup('ACTION DECK', [
        for (var i = 0; i < 6; i++)
          _dealt(
            cardIndex++,
            i < entry.actions.length
                ? CyberActionCardTile(
                    card: entry.actions[i],
                    selected: false,
                    size: VisualCardSize.sm,
                  )
                : _EmptyLoadoutSlot(
                    label: 'ACTION',
                    accent: accent,
                    size: VisualCardSize.sm,
                  ),
          ),
      ]);
      return widgets;
    }

    if (entry.sport == Sport.cricket) {
      addGroup('BATTING ORDER', [
        for (var i = 0; i < entry.total; i++)
          _dealt(
            cardIndex++,
            i < entry.players.length
                ? _playerTile(entry.players[i].card, accent, VisualCardSize.sm)
                : _EmptyLoadoutSlot(
                    label: '#${i + 1}',
                    accent: accent,
                    size: VisualCardSize.sm,
                  ),
          ),
      ]);
      return widgets;
    }

    if (entry.sport == Sport.basketball) {
      addGroup('ROTATION', [
        for (var i = 0; i < entry.total; i++)
          _dealt(
            cardIndex++,
            i < entry.players.length
                ? _playerTile(
                    entry.players[i].card,
                    accent,
                    VisualCardSize.sm,
                    starred: entry.players[i].card.id == entry.starter?.id,
                  )
                : _EmptyLoadoutSlot(
                    label: 'PLAYER',
                    accent: accent,
                    size: VisualCardSize.sm,
                  ),
          ),
      ]);
      return widgets;
    }

    // Tennis / motorsport — single hero athlete.
    final label = entry.sport == Sport.tennis ? 'ATHLETE' : 'DRIVER';
    addGroup(label, [
      _dealt(
        cardIndex++,
        entry.starter != null
            ? _playerTile(entry.starter!, accent, VisualCardSize.lg,
                starred: true)
            : _EmptyLoadoutSlot(
                label: label,
                accent: accent,
                size: VisualCardSize.lg,
              ),
      ),
    ]);
    return widgets;
  }

  Widget _dealt(int index, Widget child) => CyberDealtCard(
        index: index,
        initialDelay: const Duration(milliseconds: 60),
        staggerMs: 45,
        flyDistance: 72,
        child: child,
      );

  Widget _playerTile(
    PlayerCard card,
    Color accent,
    VisualCardSize size, {
    bool starred = false,
  }) {
    return CyberPlayerCardTile(
      card: card,
      selected: starred,
      selectedAccent: accent,
      size: size,
    );
  }
}

class _LoadoutHeader extends StatelessWidget {
  const _LoadoutHeader({required this.entry, required this.accent});

  final _DeckEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(entry.sport);
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                accent.withValues(alpha: 0.12),
                Cyber.panel2,
              ),
              border: Border.all(color: accent.withValues(alpha: 0.52)),
            ),
            child: Icon(module.icon, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        module.label.toUpperCase(),
                        style: Cyber.display(13, letterSpacing: 1),
                      ),
                    ),
                    CyberChip(
                      label: entry.ready ? 'READY' : 'BUILD',
                      color: entry.ready ? Cyber.success : Cyber.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  entry.kicker,
                  style: Cyber.label(8, color: accent, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                CyberProgressBar(
                  value: entry.filled / entry.total,
                  accent: entry.ready ? Cyber.success : accent,
                  height: 6,
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.filled}/${entry.total} FILLED · ${entry.meta}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(
                    7,
                    color: Cyber.muted,
                    letterSpacing: 0.7,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLoadoutSlot extends StatelessWidget {
  const _EmptyLoadoutSlot({
    required this.label,
    required this.accent,
    required this.size,
  });

  final String label;
  final Color accent;
  final VisualCardSize size;

  @override
  Widget build(BuildContext context) {
    final large = size == VisualCardSize.lg;
    final small = size == VisualCardSize.sm;
    final width = small ? 96.0 : (large ? 144.0 : 128.0);
    final height = small ? 144.0 : (large ? 216.0 : 192.0);
    final bigCut = (width * 0.13).clamp(10.0, 19.0);
    final smallCut = bigCut * 0.5;
    return ClipPath(
      clipper: HudChamferClipper(bigCut: bigCut, smallCut: smallCut),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        color: Cyber.bg.withValues(alpha: 0.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Cyber.line),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Cyber.muted, size: 20),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Cyber.label(7, color: Cyber.muted, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadoutLockedTab extends StatelessWidget {
  const _LoadoutLockedTab({required this.module, required this.onPlay});

  final SportModule module;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CyberNoDataState(
              icon: Icons.lock_outline,
              spark: module.icon,
              accent: module.accent,
              title: '${module.label.toUpperCase()} SQUAD LOCKED',
              message:
                  'Play your first ${module.label} game to claim your '
                  'starter pack and fill this loadout.',
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: HudCtaButton(
                label: 'PLAY ${module.label.toUpperCase()}',
                icon: Icons.play_arrow_rounded,
                accent: module.accent,
                onTap: onPlay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadoutLockedSeal extends StatelessWidget {
  const _LoadoutLockedSeal({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.success,
      glow: true,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Cyber.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label LOADOUT LOCKED',
              style: Cyber.label(
                10,
                color: Cyber.success,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Text(
            'SYNC://OK',
            style: Cyber.label(7, color: Cyber.muted, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _DeckEntry {
  const _DeckEntry({
    required this.sport,
    required this.kicker,
    required this.ready,
    required this.locked,
    required this.meta,
    required this.players,
    required this.keeper,
    required this.actions,
    required this.filled,
    required this.total,
    this.starter,
  });

  final Sport sport;
  final String kicker;
  final bool ready;
  final bool locked;
  final String meta;
  final List<({String role, PlayerCard card})> players;
  final PlayerCard? keeper;
  final List<ActionCard> actions;
  final PlayerCard? starter;
  final int filled;
  final int total;
}
