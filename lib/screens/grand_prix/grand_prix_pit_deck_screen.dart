import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/racing.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';
import 'widgets/grand_prix_livery_selector.dart';

class GrandPrixPitDeckScreen extends StatefulWidget {
  const GrandPrixPitDeckScreen({
    required this.onBack,
    this.onSaved,
    this.onBrowseShop,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onBrowseShop;

  @override
  State<GrandPrixPitDeckScreen> createState() => _GrandPrixPitDeckScreenState();
}

class _GrandPrixPitDeckScreenState extends State<GrandPrixPitDeckScreen> {
  String? selectedDriverId;

  bool get valid => selectedDriverId != null;

  @override
  void initState() {
    super.initState();
    _loadFromState(context.read<GameBloc>().state);
    _syncLiveryOwnership(context.read<GameBloc>().state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        _loadFromState(state);
        _syncLiveryOwnership(state);
      },
      builder: (context, state) {
        final gpState = context.watch<GrandPrixCubit>().state;
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
          orElse: () => state.deckSlots.first,
        );
        final selectedDriver = selectedDriverId == null
            ? null
            : racingPlayerCards
                .where((card) => card.id == selectedDriverId)
                .firstOrNull;
        final ownedDrivers =
            racingPlayerCards
                .where((card) => state.ownedCardIds.contains(card.id))
                .toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));

        return GameScaffold(
          title: 'Racing Pit Deck',
          subtitle: '// DRIVER + LIVERY',
          leading: IconButton(
            onPressed: () => _attemptBack(active),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
                  children: [
                    _DriverPanel(
                      deckName: active.name,
                      valid: valid,
                      driver: selectedDriver,
                    ),
                    const SizedBox(height: 10),
                    _DriverPickerPanel(
                      selectedDriver: selectedDriver,
                      cards: ownedDrivers,
                      onSelect: (card) =>
                          setState(() => selectedDriverId = card.id),
                    ),
                    const SizedBox(height: 10),
                    GrandPrixLiverySelector(
                      selected: gpState.livery,
                      ownedLiveryIds: state.ownedGrandPrixLiveryIds,
                      onSelected: (livery) => context
                          .read<GrandPrixCubit>()
                          .selectLivery(
                            livery,
                            ownedLiveryIds: state.ownedGrandPrixLiveryIds,
                          ),
                      onBrowseShop: widget.onBrowseShop,
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'SAVE LOADOUT',
                primaryEnabled: valid,
                primaryOnTap: () async => _save(active),
                secondaryLabel: 'BACK',
                secondaryOnTap: () => _attemptBack(active),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncLiveryOwnership(GameState state) {
    context.read<GrandPrixCubit>().ensureEquippedLiveryOwned(
      state.ownedGrandPrixLiveryIds,
    );
  }

  void _loadFromState(GameState state) {
    selectedDriverId = state.deckRacingStarter?.id ??
        state.deckRacingPlayers.firstOrNull?.id;
  }

  Future<void> _save(StoredDeckSlot active) async {
    final driverId = selectedDriverId;
    if (driverId == null) return;
    if (active.racingStarter == driverId &&
        active.racingPlayers.length == 1 &&
        active.racingPlayers.first == driverId) {
      (widget.onSaved ?? widget.onBack).call();
      return;
    }
    final bloc = context.read<GameBloc>();
    final saved = bloc.stream.firstWhere(
      (state) => state.deckRacingStarter?.id == driverId,
    );
    bloc.add(
      DeckSaved(
        active.copyWith(
          racingPlayers: [driverId],
          racingStarter: driverId,
        ),
      ),
    );
    await saved.timeout(
      const Duration(seconds: 2),
      onTimeout: () => bloc.state,
    );
    if (!mounted) return;
    (widget.onSaved ?? widget.onBack).call();
  }

  Future<void> _attemptBack(StoredDeckSlot active) async {
    final driverId = selectedDriverId;
    if (active.racingStarter != driverId ||
        (driverId != null &&
            (active.racingPlayers.length != 1 ||
                active.racingPlayers.first != driverId))) {
      final discard = await showCyberConfirmDialog(
        context,
        title: 'DISCARD CHANGES?',
        message: 'Your racing driver selection has not been saved.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!mounted || !discard) return;
    }
    widget.onBack();
  }
}

class _DriverPanel extends StatelessWidget {
  const _DriverPanel({
    required this.deckName,
    required this.valid,
    required this.driver,
  });

  final String deckName;
  final bool valid;
  final PlayerCard? driver;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.f1Red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PIT LANE LOADOUT',
                      style: Cyber.label(
                        9,
                        color: Cyber.f1Red,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deckName.toUpperCase(),
                      style: Cyber.display(15, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),
              CyberChip(
                label: valid ? 'Ready' : 'Build',
                color: valid ? Cyber.f1Red : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRect(
            child: CustomPaint(
              painter: const F1MysterySignalPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: driver == null
                    ? SizedBox(
                        height: 174,
                        child: Center(
                          child: Text(
                            'SELECT YOUR RACE DRIVER',
                            style: Cyber.label(
                              9,
                              color: Cyber.muted,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      )
                    : _EquippedDriverTelemetry(card: driver!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverPickerPanel extends StatelessWidget {
  const _DriverPickerPanel({
    required this.selectedDriver,
    required this.cards,
    required this.onSelect,
  });

  final PlayerCard? selectedDriver;
  final List<PlayerCard> cards;
  final ValueChanged<PlayerCard> onSelect;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(label: 'YOUR DRIVERS'),
          const SizedBox(height: 10),
          if (cards.isEmpty)
            Text(
              'NO DRIVERS IN YOUR GARAGE YET',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in cards)
                  CyberPlayerCardTile(
                    card: card,
                    selected: selectedDriver?.id == card.id,
                    selectedAccent: Cyber.f1Red,
                    size: VisualCardSize.sm,
                    onTap: () => onSelect(card),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EquippedDriverTelemetry extends StatelessWidget {
  const _EquippedDriverTelemetry({required this.card});

  final PlayerCard card;

  @override
  Widget build(BuildContext context) {
    final driver = racingDriverById(card.id);
    final stats = [
      ('PACE', driver.ratings.pace),
      ('RACE', driver.ratings.racecraft),
      ('TYRES', driver.ratings.tyreManagement),
      ('WET', driver.ratings.wetWeather),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CyberPlayerCardTile(
          card: card,
          selected: false,
          selectedAccent: Cyber.f1Red,
          size: VisualCardSize.md,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.68),
              border: Border.all(color: Cyber.f1Red.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CyberChip(label: driver.series.label, color: Cyber.f1Red),
                const SizedBox(height: 8),
                Text(
                  driver.archetype.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(
                    8,
                    color: Cyber.f1Red,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < stats.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stats[i].$1,
                          style: Cyber.label(7, color: Cyber.muted),
                        ),
                      ),
                      Text(
                        '${stats[i].$2}',
                        style: Cyber.display(11, color: Cyber.f1Red),
                      ),
                    ],
                  ),
                  if (i != stats.length - 1) const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
