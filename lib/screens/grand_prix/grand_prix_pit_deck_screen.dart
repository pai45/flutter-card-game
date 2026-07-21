import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../utils/label_helpers.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';
import 'widgets/grand_prix_livery_selector.dart';

class GrandPrixPitDeckScreen extends StatefulWidget {
  const GrandPrixPitDeckScreen({
    required this.onBack,
    this.onBrowseShop,
    super.key,
  });

  final VoidCallback onBack;
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
          title: 'Pit Deck',
          subtitle: '// DRIVER + LIVERY',
          leading: IconButton(
            onPressed: widget.onBack,
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
                primaryLabel: 'SAVE PIT CREW',
                primaryEnabled: valid,
                primaryOnTap: () async => _save(active),
                secondaryLabel: 'BACK',
                secondaryOnTap: widget.onBack,
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
    final bloc = context.read<GameBloc>();
    final saved = bloc.stream.firstWhere(
      (state) => state.deckRacingStarter?.id == driverId,
    );
    bloc.add(
      DeckSaved(
        StoredDeckSlot(
          id: active.id,
          name: active.name,
          attackers: active.attackers,
          defenders: active.defenders,
          actions: active.actions,
          finalOverBatsmen: active.finalOverBatsmen,
          keeper: active.keeper,
          basketballPlayers: active.basketballPlayers,
          basketballStarter: active.basketballStarter,
          tennisPlayers: active.tennisPlayers,
          tennisStarter: active.tennisStarter,
          racingPlayers: [driverId],
          racingStarter: driverId,
          chessFormation: active.chessFormation,
        ),
      ),
    );
    await saved.timeout(
      const Duration(seconds: 2),
      onTimeout: () => bloc.state,
    );
    if (mounted) widget.onBack();
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
      accent: Cyber.magenta,
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
                      'PIT CREW',
                      style: TextStyle(
                        color: Cyber.magenta.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      deckName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: Cyber.displayFont,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              CyberChip(
                label: valid ? 'Ready' : 'Build',
                color: valid ? Cyber.magenta : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (driver == null)
            Text(
              'SELECT YOUR RACE DRIVER',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
            )
          else
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Cyber.panel2,
                    border: Border.all(
                      color: tierColor(driver!.tier).withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(
                    driver!.icon,
                    color: tierColor(driver!.tier),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver!.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(13, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${driver!.position} · OVR ${driver!.rating}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Cyber.muted,
                          fontFamily: Cyber.bodyFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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
                  _DriverPickTile(
                    card: card,
                    selected: selectedDriver?.id == card.id,
                    onTap: () => onSelect(card),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DriverPickTile extends StatelessWidget {
  const _DriverPickTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final PlayerCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = tierColor(card.tier);
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 148,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.12), Cyber.panel)
              : Cyber.panel,
          border: Border.all(
            color: selected ? accent : Cyber.border.withValues(alpha: 0.5),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? Cyber.glow(accent, alpha: 0.35, blur: 12) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(11, letterSpacing: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              card.position,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Cyber.muted,
                fontFamily: Cyber.bodyFont,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'OVR ${card.rating}',
              style: Cyber.label(
                8,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
