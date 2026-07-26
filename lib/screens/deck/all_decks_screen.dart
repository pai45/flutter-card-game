import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/theme.dart';
import '../../models/deck.dart';
import '../../models/sport_match.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../final_over/final_over_deck_builder_screen.dart';
import '../grand_prix/grand_prix_pit_deck_screen.dart';
import 'basketball_deck_builder_screen.dart';
import 'deck_builder_screen.dart';
import 'tennis_deck_builder_screen.dart';

class AllDecksScreen extends StatelessWidget {
  const AllDecksScreen({required this.onBack, super.key});

  final VoidCallback onBack;

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
      child: _DeckLockerView(onBack: onBack),
    );
  }
}

class _DeckLockerView extends StatefulWidget {
  const _DeckLockerView({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_DeckLockerView> createState() => _DeckLockerViewState();
}

class _DeckLockerViewState extends State<_DeckLockerView> {
  Sport? _lastSavedSport;
  Timer? _sealTimer;

  @override
  void dispose() {
    _sealTimer?.cancel();
    super.dispose();
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

        final active = game.deckSlots.firstWhere(
          (slot) => slot.id == game.activeDeckId,
          orElse: () => game.deckSlots.first,
        );
        final entries = _entries(
          game,
          basketballTeamId: basketball.teamId,
          finalOverKitId: finalOver.kitId,
          racingLivery: grandPrix.livery.name,
        );

        return GameScaffold(
          title: 'Deck Locker',
          subtitle: '// ACTIVE SQUAD · ${active.name.toUpperCase()}',
          leading: IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          rightSlot: IconButton(
            tooltip: 'New squad',
            onPressed: _createSquad,
            icon: const Icon(Icons.add_box_outlined, color: Cyber.cyan),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _LockerProgress(
                deckName: active.name,
                readyCount: game.sportDeckReadyCount,
              ),
              const SizedBox(height: 14),
              const SectionLabel(label: 'SQUAD CHANNEL'),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: game.deckSlots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final slot = game.deckSlots[index];
                    return CyberDeckPill(
                      label: slot.name,
                      meta: '${_structuralReadyCount(slot)}/5 READY',
                      selected: slot.id == game.activeDeckId,
                      onTap: slot.id == game.activeDeckId
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              context.read<GameBloc>().add(DeckApplied(slot.id));
                            },
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _lastSavedSport == null
                    ? const SizedBox.shrink()
                    : _LoadoutLockedSeal(
                        key: ValueKey(_lastSavedSport),
                        label: _sportTitle(_lastSavedSport!),
                      ),
              ),
              if (_lastSavedSport != null) const SizedBox(height: 12),
              for (var index = 0; index < entries.length; index++) ...[
                CyberDealtCard(
                  index: index,
                  initialDelay: const Duration(milliseconds: 80),
                  flyDistance: 96,
                  child: _SportLoadoutCard(
                    entry: entries[index],
                    justSaved: entries[index].sport == _lastSavedSport,
                    onTap: entries[index].locked
                        ? null
                        : () => _openEditor(entries[index].sport),
                  ),
                ),
                if (index != entries.length - 1) const SizedBox(height: 10),
              ],
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
    String names(Iterable<String> values, String empty) {
      final list = values.where((value) => value.isNotEmpty).take(3).toList();
      return list.isEmpty ? empty : list.join(' · ');
    }

    return [
      _DeckEntry(
        sport: Sport.football,
        title: 'FOOTBALL',
        kicker: '// 5-A-SIDE + 6 ACTIONS',
        icon: Icons.sports_soccer,
        accent: Cyber.cyan,
        ready: game.pitchDuelDeckReady,
        locked: !game.starterPackClaimed,
        primary: names(
          [
            ...game.deckAttackers.map((card) => card.shortName),
            ...game.deckDefenders.map((card) => card.shortName),
            if (game.deckKeeper != null) game.deckKeeper!.shortName,
          ],
          'BUILD YOUR FIRST XI CORE',
        ),
        meta:
            '${game.deckAttackers.length + game.deckDefenders.length + (game.deckKeeper == null ? 0 : 1)}/5 PLAYERS · ${game.deckActions.length}/6 ACTIONS',
      ),
      _DeckEntry(
        sport: Sport.cricket,
        title: 'CRICKET',
        kicker: '// FINAL OVER BATTING ORDER',
        icon: Icons.sports_cricket,
        accent: Cyber.lime,
        ready: game.finalOverDeckReady,
        locked: !game.cricketStarterPackClaimed,
        primary: names(
          game.deckFinalOverBatsmen.map((card) => card.shortName),
          'SET A THREE-BAT CHASE UNIT',
        ),
        meta:
            '${game.deckFinalOverBatsmen.length}/3 BATTERS · KIT ${finalOverKitId.toUpperCase()}',
      ),
      _DeckEntry(
        sport: Sport.basketball,
        title: 'BASKETBALL',
        kicker: '// GUARD · WING · BIG',
        icon: Icons.sports_basketball,
        accent: Cyber.gold,
        ready: game.hoopDuelDeckReady,
        locked: !game.basketballStarterPackClaimed,
        primary: names(
          game.deckBasketballPlayers.map((card) => card.shortName),
          'DRAFT A THREE-PLAYER ROTATION',
        ),
        meta:
            '${game.deckBasketballPlayers.length}/3 PLAYERS · JERSEY ${basketballTeamId.toUpperCase()}',
      ),
      _DeckEntry(
        sport: Sport.tennis,
        title: 'TENNIS',
        kicker: '// SINGLES ATHLETE',
        icon: Icons.sports_tennis,
        accent: Cyber.lime,
        ready: game.tennisDeckReady,
        locked: !game.tennisStarterPackClaimed,
        primary: game.deckTennisStarter?.name.toUpperCase() ??
            'SIGN YOUR COURT ATHLETE',
        meta: game.deckTennisStarter == null
            ? '0/1 ATHLETE'
            : '${game.deckTennisStarter!.trait.toUpperCase()} · OVR ${game.deckTennisStarter!.rating}',
      ),
      _DeckEntry(
        sport: Sport.motorsport,
        title: 'F1 / RACING',
        kicker: '// DRIVER + LIVERY',
        icon: Icons.sports_motorsports,
        accent: Cyber.f1Red,
        ready: game.racingDriverDeckReady,
        locked: !game.grandPrixStarterPackClaimed,
        primary: game.deckRacingStarter?.name.toUpperCase() ??
            'SIGN A RACING DRIVER',
        meta: game.deckRacingStarter == null
            ? '0/1 DRIVER'
            : '${game.deckRacingStarter!.position.toUpperCase()} · ${racingLivery.toUpperCase()}',
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

  Future<void> _createSquad() async {
    final create = await showCyberConfirmDialog(
      context,
      title: 'CREATE NEW SQUAD?',
      message:
          'A blank five-sport squad channel will be created. Your current squad stays saved.',
      confirmLabel: 'Create',
      cancelLabel: 'Cancel',
    );
    if (!mounted || !create) return;
    HapticFeedback.mediumImpact();
    context.read<GameBloc>().add(DeckCreated());
  }
}

class _LockerProgress extends StatelessWidget {
  const _LockerProgress({required this.deckName, required this.readyCount});

  final String deckName;
  final int readyCount;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Cyber.cyan, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MULTI-SPORT LOADOUT',
                      style: Cyber.label(
                        9,
                        color: Cyber.cyan,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deckName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(16, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
              Text(
                '$readyCount/5',
                style: Cyber.display(
                  19,
                  color: readyCount == 5 ? Cyber.success : Cyber.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CyberProgressBar(
            value: readyCount / 5,
            accent: readyCount == 5 ? Cyber.success : Cyber.cyan,
          ),
          const SizedBox(height: 8),
          Text(
            readyCount == 5
                ? 'ALL SPORT CHANNELS READY // TAKE IT LIVE'
                : '${5 - readyCount} LOADOUT${5 - readyCount == 1 ? '' : 'S'} STILL NEED ATTENTION',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _SportLoadoutCard extends StatelessWidget {
  const _SportLoadoutCard({
    required this.entry,
    required this.justSaved,
    required this.onTap,
  });

  final _DeckEntry entry;
  final bool justSaved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.locked
        ? Cyber.muted
        : entry.ready
            ? Cyber.success
            : Cyber.amber;
    return PressableScale(
      onTap: onTap,
      child: CyberPanel(
        accent: justSaved ? Cyber.success : entry.accent,
        glow: justSaved,
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
                  entry.accent.withValues(alpha: 0.12),
                  Cyber.panel2,
                ),
                border: Border.all(
                  color: entry.accent.withValues(alpha: 0.52),
                ),
              ),
              child: Icon(entry.icon, color: entry.accent, size: 26),
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
                          entry.title,
                          style: Cyber.display(13, letterSpacing: 1),
                        ),
                      ),
                      CyberChip(
                        label: entry.locked
                            ? 'LOCKED'
                            : entry.ready
                                ? 'READY'
                                : 'BUILD',
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.kicker,
                    style: Cyber.label(
                      8,
                      color: entry.accent,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    entry.locked
                        ? 'OPEN THE STARTER PACK IN GAMES'
                        : entry.primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(
                      12,
                      color: entry.locked ? Cyber.muted : Colors.white,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.locked ? 'SPORT CHANNEL UNAVAILABLE' : entry.meta,
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
            if (!entry.locked) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: entry.accent, size: 22),
            ],
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
    required this.title,
    required this.kicker,
    required this.icon,
    required this.accent,
    required this.ready,
    required this.locked,
    required this.primary,
    required this.meta,
  });

  final Sport sport;
  final String title;
  final String kicker;
  final IconData icon;
  final Color accent;
  final bool ready;
  final bool locked;
  final String primary;
  final String meta;
}

int _structuralReadyCount(StoredDeckSlot slot) => [
      slot.attackers.length == 2 &&
          slot.defenders.length == 2 &&
          slot.actions.length == 6 &&
          slot.keeper != null,
      slot.finalOverBatsmen.length == 3,
      slot.basketballPlayers.length == 3 &&
          slot.basketballStarter != null,
      slot.tennisPlayers.isNotEmpty && slot.tennisStarter != null,
      slot.racingPlayers.isNotEmpty && slot.racingStarter != null,
    ].where((ready) => ready).length;

String _sportTitle(Sport sport) => switch (sport) {
      Sport.football => 'FOOTBALL',
      Sport.cricket => 'CRICKET',
      Sport.basketball => 'BASKETBALL',
      Sport.tennis => 'TENNIS',
      Sport.motorsport => 'F1 / RACING',
    };
