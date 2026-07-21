import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';

class BasketballDeckBuilderScreen extends StatefulWidget {
  const BasketballDeckBuilderScreen({
    required this.onBack,
    this.onPlayHoopDuel,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onPlayHoopDuel;

  @override
  State<BasketballDeckBuilderScreen> createState() =>
      _BasketballDeckBuilderScreenState();
}

class _BasketballDeckBuilderScreenState
    extends State<BasketballDeckBuilderScreen> {
  late List<String?> selectedPlayers;
  String? selectedStarterId;
  int activeSlotIndex = 0;

  static const _slotRoles = [
    PlayerRole.basketballGuard,
    PlayerRole.basketballWing,
    PlayerRole.basketballBig,
  ];

  bool get valid =>
      selectedPlayers.every((id) => id != null) &&
      selectedStarterId != null &&
      selectedPlayers.contains(selectedStarterId);

  @override
  void initState() {
    super.initState();
    _loadDeckIntoEditor(context.read<GameBloc>().state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (_, state) => _loadDeckIntoEditor(state),
      builder: (context, state) {
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
          orElse: () => state.deckSlots.first,
        );
        final selectedCards = [
          for (final id in selectedPlayers)
            id == null
                ? null
                : basketballPlayerCards
                      .where((card) => card.id == id)
                      .firstOrNull,
        ];
        final activeRole = _slotRoles[activeSlotIndex];
        final ownedCards =
            basketballPlayerCards
                .where(
                  (card) =>
                      card.role == activeRole &&
                      state.ownedCardIds.contains(card.id),
                )
                .toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));

        return GameScaffold(
          title: 'Roster Deck',
          subtitle: '// Hoop Duel',
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
                    _RosterPanel(
                      deckName: active.name,
                      valid: valid,
                      cards: selectedCards,
                      starterId: selectedStarterId,
                      focusedIndex: activeSlotIndex,
                      onSlotTap: (index) =>
                          setState(() => activeSlotIndex = index),
                      onStarter: (id) => setState(() => selectedStarterId = id),
                    ),
                    const SizedBox(height: 10),
                    _BasketballPickerPanel(
                      selectedCard: selectedCards[activeSlotIndex],
                      slotIndex: activeSlotIndex,
                      cards: ownedCards,
                      isCardDisabled: _isCardLocked,
                      onSlotTap: (index) =>
                          setState(() => activeSlotIndex = index),
                      onClear: _clearActiveSlot,
                      onSelect: _assignCardToActiveSlot,
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'PLAY',
                primaryEnabled: valid && widget.onPlayHoopDuel != null,
                primaryOnTap: () async {
                  await _save(active);
                  if (!context.mounted) return;
                  widget.onPlayHoopDuel?.call();
                },
                secondaryLabel: 'SAVE',
                secondaryOnTap: () async => _save(active),
                tertiaryLabel: 'BACK',
                tertiaryOnTap: widget.onBack,
              ),
            ],
          ),
        );
      },
    );
  }

  void _loadDeckIntoEditor(GameState state) {
    selectedPlayers = List<String?>.generate(
      3,
      (index) => index < state.deckBasketballPlayers.length
          ? state.deckBasketballPlayers[index].id
          : null,
    );
    selectedStarterId = state.deckBasketballStarter?.id;
    if (selectedStarterId != null &&
        !selectedPlayers.contains(selectedStarterId)) {
      selectedStarterId = selectedPlayers.whereType<String>().firstOrNull;
    }
  }

  Future<void> _save(StoredDeckSlot active) async {
    final bloc = context.read<GameBloc>();
    final nextPlayers = selectedPlayers.whereType<String>().toList();
    final starterId = selectedStarterId ?? nextPlayers.firstOrNull;
    final saved = bloc.stream.firstWhere(
      (state) =>
          _sameIds(
            state.deckBasketballPlayers.map((card) => card.id).toList(),
            nextPlayers,
          ) &&
          state.deckBasketballStarter?.id == starterId,
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
          basketballPlayers: nextPlayers,
          basketballStarter: starterId,
          keeper: active.keeper,
          chessFormation: active.chessFormation,
        ),
      ),
    );
    await saved.timeout(
      const Duration(seconds: 2),
      onTimeout: () => bloc.state,
    );
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _isCardLocked(String id) {
    final currentId = selectedPlayers[activeSlotIndex];
    return selectedPlayers.contains(id) && currentId != id;
  }

  void _assignCardToActiveSlot(PlayerCard card) {
    setState(() {
      final next = [...selectedPlayers];
      final previousIndex = next.indexOf(card.id);
      final currentId = next[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        next[previousIndex] = currentId;
      }
      next[activeSlotIndex] = card.id;
      selectedPlayers = next;
      selectedStarterId ??= card.id;
      final empty = selectedPlayers.indexOf(null);
      if (empty != -1) activeSlotIndex = empty;
    });
  }

  void _clearActiveSlot() {
    setState(() {
      final clearing = selectedPlayers[activeSlotIndex];
      selectedPlayers[activeSlotIndex] = null;
      if (selectedStarterId == clearing) {
        selectedStarterId = selectedPlayers.whereType<String>().firstOrNull;
      }
    });
  }
}

class _RosterPanel extends StatelessWidget {
  const _RosterPanel({
    required this.deckName,
    required this.valid,
    required this.cards,
    required this.starterId,
    required this.focusedIndex,
    required this.onSlotTap,
    required this.onStarter,
  });

  final String deckName;
  final bool valid;
  final List<PlayerCard?> cards;
  final String? starterId;
  final int focusedIndex;
  final ValueChanged<int> onSlotTap;
  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.gold,
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
                      'HOOP DUEL ROSTER',
                      style: TextStyle(
                        color: Cyber.gold.withValues(alpha: 0.78),
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
                color: valid ? Cyber.gold : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _RosterSlot(
                    index: i,
                    card: cards.elementAtOrNull(i),
                    selected: focusedIndex == i,
                    starter: cards.elementAtOrNull(i)?.id == starterId,
                    onTap: () => onSlotTap(i),
                    onStarter: cards.elementAtOrNull(i) == null
                        ? null
                        : () => onStarter(cards[i]!.id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RosterSlot extends StatelessWidget {
  const _RosterSlot({
    required this.index,
    required this.card,
    required this.selected,
    required this.starter,
    required this.onTap,
    required this.onStarter,
  });

  final int index;
  final PlayerCard? card;
  final bool selected;
  final bool starter;
  final VoidCallback onTap;
  final VoidCallback? onStarter;

  String get _label => switch (index) {
    0 => 'GUARD',
    1 => 'WING',
    _ => 'BIG',
  };

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected
              ? Cyber.gold.withValues(alpha: 0.14)
              : Cyber.bg.withValues(alpha: 0.42),
          border: Border.all(
            color: selected ? Cyber.gold : Cyber.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _label,
                  style: Cyber.label(
                    9,
                    color: selected ? Cyber.gold : Cyber.muted,
                    letterSpacing: 1.2,
                  ),
                ),
                if (card != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onStarter,
                    child: Icon(
                      starter ? Icons.star_rounded : Icons.star_border_rounded,
                      color: starter ? Cyber.gold : Cyber.muted,
                      size: 15,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            if (card == null)
              const SizedBox(
                height: 102,
                child: Center(
                  child: Icon(Icons.add, color: Cyber.muted, size: 22),
                ),
              )
            else
              CyberPlayerCardTile(
                card: card,
                selected: selected || starter,
                size: VisualCardSize.sm,
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _BasketballPickerPanel extends StatelessWidget {
  const _BasketballPickerPanel({
    required this.selectedCard,
    required this.slotIndex,
    required this.cards,
    required this.isCardDisabled,
    required this.onSlotTap,
    required this.onClear,
    required this.onSelect,
  });

  final PlayerCard? selectedCard;
  final int slotIndex;
  final List<PlayerCard> cards;
  final bool Function(String id) isCardDisabled;
  final ValueChanged<int> onSlotTap;
  final VoidCallback onClear;
  final ValueChanged<PlayerCard> onSelect;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _SlotChip(
                  label: switch (i) {
                    0 => 'G',
                    1 => 'W',
                    _ => 'BIG',
                  },
                  selected: slotIndex == i,
                  onTap: () => onSlotTap(i),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: selectedCard == null ? null : onClear,
                icon: const Icon(Icons.remove_circle_outline, size: 14),
                label: const Text('CLEAR'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_basketball,
                  color: Cyber.cyan,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedCard?.name ?? 'No card assigned',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: Cyber.displayFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 330,
            child: cards.isEmpty
                ? Center(
                    child: Text(
                      'No owned cards for this slot yet.',
                      style: Cyber.body(12, color: Cyber.muted),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final card in cards)
                          CyberPlayerCardTile(
                            card: card,
                            selected: selectedCard?.id == card.id,
                            disabled: isCardDisabled(card.id),
                            size: VisualCardSize.sm,
                            onTap: () => onSelect(card),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Cyber.cyan.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(color: selected ? Cyber.cyan : Cyber.line),
        ),
        child: Text(
          label,
          style: Cyber.label(
            10,
            color: selected ? Cyber.cyan : Cyber.muted,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
