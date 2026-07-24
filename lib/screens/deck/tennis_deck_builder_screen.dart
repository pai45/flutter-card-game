import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/tennis/tennis_cubit.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../models/tennis.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';

class TennisDeckBuilderScreen extends StatefulWidget {
  const TennisDeckBuilderScreen({
    required this.onBack,
    this.onSaved,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaved;

  @override
  State<TennisDeckBuilderScreen> createState() =>
      _TennisDeckBuilderScreenState();
}

class _TennisDeckBuilderScreenState extends State<TennisDeckBuilderScreen> {
  String? _selectedPlayerId;

  bool get _valid => _selectedPlayerId != null;

  @override
  void initState() {
    super.initState();
    final game = context.read<GameBloc>().state;
    _selectedPlayerId = game.deckTennisStarter?.id ??
        game.deckTennisPlayers.firstOrNull?.id;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, game) {
        final active = game.deckSlots.firstWhere(
          (slot) => slot.id == game.activeDeckId,
          orElse: () => game.deckSlots.first,
        );
        final owned = tennisPlayerCards
            .where((card) => game.ownedCardIds.contains(card.id))
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final selected = _selectedPlayerId == null
            ? null
            : tennisPlayerCards
                .where((card) => card.id == _selectedPlayerId)
                .firstOrNull;

        return GameScaffold(
          title: 'Tennis Deck',
          subtitle: '// SINGLES ATHLETE',
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
                    _TennisCourtBoard(
                      deckName: active.name,
                      player: selected,
                    ),
                    const SizedBox(height: 12),
                    if (selected != null)
                      _TennisTelemetryPanel(playerId: selected.id),
                    const SizedBox(height: 12),
                    _TennisAthletePicker(
                      cards: owned,
                      selectedId: _selectedPlayerId,
                      onSelected: (card) =>
                          setState(() => _selectedPlayerId = card.id),
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'SAVE LOADOUT',
                primaryEnabled: _valid,
                primaryOnTap: () => _save(active),
                secondaryLabel: 'BACK',
                secondaryOnTap: () => _attemptBack(active),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save(StoredDeckSlot active) async {
    final playerId = _selectedPlayerId;
    if (playerId == null) return;
    if (active.tennisStarter == playerId &&
        active.tennisPlayers.length == 1 &&
        active.tennisPlayers.first == playerId) {
      await context.read<TennisCubit>().syncFromDeck([playerId], playerId);
      if (!mounted) return;
      (widget.onSaved ?? widget.onBack).call();
      return;
    }
    final bloc = context.read<GameBloc>();
    final saved = bloc.stream.firstWhere(
      (state) =>
          state.deckTennisStarter?.id == playerId &&
          state.deckTennisPlayers.length == 1,
    );
    bloc.add(
      DeckSaved(
        active.copyWith(
          tennisPlayers: [playerId],
          tennisStarter: playerId,
        ),
      ),
    );
    await saved.timeout(const Duration(seconds: 2), onTimeout: () => bloc.state);
    if (!mounted) return;
    await context.read<TennisCubit>().syncFromDeck([playerId], playerId);
    if (!mounted) return;
    (widget.onSaved ?? widget.onBack).call();
  }

  Future<void> _attemptBack(StoredDeckSlot active) async {
    final dirty = active.tennisStarter != _selectedPlayerId ||
        (_selectedPlayerId != null &&
            (active.tennisPlayers.length != 1 ||
                active.tennisPlayers.first != _selectedPlayerId));
    if (dirty) {
      final discard = await showCyberConfirmDialog(
        context,
        title: 'DISCARD CHANGES?',
        message: 'Your Tennis Rally athlete selection has not been saved.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!mounted || !discard) return;
    }
    widget.onBack();
  }
}

class _TennisCourtBoard extends StatelessWidget {
  const _TennisCourtBoard({required this.deckName, required this.player});

  final String deckName;
  final PlayerCard? player;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.lime,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 292,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: TennisMysterySignalPainter()),
            ),
            Positioned(
              left: 14,
              right: 14,
              top: 14,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BASELINE LOADOUT',
                          style: Cyber.label(
                            9,
                            color: Cyber.lime,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deckName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.display(13, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                  CyberChip(
                    label: player == null ? 'BUILD' : 'READY',
                    color: player == null ? Cyber.amber : Cyber.success,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Center(
                child: player == null
                    ? const _EmptyTennisSlot()
                    : CyberPlayerCardTile(
                        card: player!,
                        selected: true,
                        selectedAccent: Cyber.lime,
                        size: VisualCardSize.md,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTennisSlot extends StatelessWidget {
  const _EmptyTennisSlot();

  @override
  Widget build(BuildContext context) {
    return HudCornerFrame(
      accent: Cyber.lime,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 104,
        height: 142,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_tennis, color: Cyber.lime, size: 28),
            const SizedBox(height: 10),
            Text(
              'SELECT\nATHLETE',
              textAlign: TextAlign.center,
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TennisTelemetryPanel extends StatelessWidget {
  const _TennisTelemetryPanel({required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context) {
    final player = tennisPlayerById(playerId);
    final ratings = player.ratings;
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionLabel(label: 'COURT TELEMETRY'),
              const Spacer(),
              Text(
                player.archetype.label,
                style: Cyber.label(8, color: Cyber.lime, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TennisStat(label: 'SERVE', value: ratings.serve),
              _TennisStat(label: 'POWER', value: ratings.power),
              _TennisStat(label: 'CONTROL', value: ratings.control),
              _TennisStat(label: 'SPEED', value: ratings.speed),
            ],
          ),
        ],
      ),
    );
  }
}

class _TennisStat extends StatelessWidget {
  const _TennisStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Cyber.display(
              15,
              color: Cyber.lime,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Cyber.label(7, color: Cyber.muted, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _TennisAthletePicker extends StatelessWidget {
  const _TennisAthletePicker({
    required this.cards,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PlayerCard> cards;
  final String? selectedId;
  final ValueChanged<PlayerCard> onSelected;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel(label: 'OWNED ATHLETES')),
              Text(
                '${cards.length} CARDS',
                style: Cyber.label(
                  8,
                  color: Cyber.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cards.isEmpty)
            Text(
              'OPEN THE TENNIS STARTER PACK IN GAMES TO SIGN AN ATHLETE.',
              style: Cyber.body(12, color: Cyber.muted, height: 1.4),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards)
                  CyberPlayerCardTile(
                    card: card,
                    selected: card.id == selectedId,
                    selectedAccent: Cyber.lime,
                    size: VisualCardSize.sm,
                    onTap: () => onSelected(card),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
