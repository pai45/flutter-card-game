import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../utils/card_helpers.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';

class CricketDeckBuilderScreen extends StatefulWidget {
  const CricketDeckBuilderScreen({
    required this.onBack,
    this.onPlaySuperOver,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onPlaySuperOver;

  @override
  State<CricketDeckBuilderScreen> createState() =>
      _CricketDeckBuilderScreenState();
}

class _CricketDeckBuilderScreenState extends State<CricketDeckBuilderScreen> {
  late List<String?> selectedBatsmen;
  int activeSlotIndex = 0;

  bool get valid => selectedBatsmen.every((id) => id != null);

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
        final selectedCards = cardsByIds(
          batsmen,
          selectedBatsmen.whereType<String>().toList(),
        );
        final ownedBatsmen =
            batsmen
                .where((card) => state.ownedCardIds.contains(card.id))
                .toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));

        return GameScaffold(
          title: 'Cricket Deck',
          subtitle: '// Super Over',
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
                    _BattingOrderPanel(
                      deckName: active.name,
                      valid: valid,
                      batsmen: selectedCards,
                      focusedIndex: activeSlotIndex,
                      onSlotTap: (index) =>
                          setState(() => activeSlotIndex = index),
                    ),
                    const SizedBox(height: 10),
                    _BatsmanPickerPanel(
                      selectedBatsman: selectedCards.elementAtOrNull(
                        activeSlotIndex,
                      ),
                      slotIndex: activeSlotIndex,
                      cards: ownedBatsmen,
                      isCardDisabled: _isBatsmanLocked,
                      onSlotTap: (index) =>
                          setState(() => activeSlotIndex = index),
                      onClear: _clearActiveSlot,
                      onSelect: _assignBatsmanToActiveSlot,
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'SAVE',
                primaryEnabled: true,
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

  void _loadDeckIntoEditor(GameState state) {
    selectedBatsmen = List<String?>.generate(
      3,
      (index) =>
          index < state.deckBatsmen.length ? state.deckBatsmen[index].id : null,
    );
  }

  Future<void> _save(StoredDeckSlot active) async {
    final bloc = context.read<GameBloc>();
    final nextBatsmen = selectedBatsmen.whereType<String>().toList();
    final saved = bloc.stream.firstWhere(
      (state) => _sameIds(
        state.deckBatsmen.map((card) => card.id).toList(),
        nextBatsmen,
      ),
    );
    bloc.add(
      DeckSaved(
        StoredDeckSlot(
          id: active.id,
          name: active.name,
          attackers: active.attackers,
          defenders: active.defenders,
          actions: active.actions,
          batsmen: nextBatsmen,
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

  bool _isBatsmanLocked(String id) {
    final currentId = selectedBatsmen[activeSlotIndex];
    return selectedBatsmen.contains(id) && currentId != id;
  }

  void _assignBatsmanToActiveSlot(PlayerCard card) {
    setState(() {
      final next = [...selectedBatsmen];
      final previousIndex = next.indexOf(card.id);
      final currentId = next[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        next[previousIndex] = currentId;
      }
      next[activeSlotIndex] = card.id;
      selectedBatsmen = next;
      final empty = selectedBatsmen.indexOf(null);
      if (empty != -1) activeSlotIndex = empty;
    });
  }

  void _clearActiveSlot() {
    setState(() => selectedBatsmen[activeSlotIndex] = null);
  }
}

class _BattingOrderPanel extends StatelessWidget {
  const _BattingOrderPanel({
    required this.deckName,
    required this.valid,
    required this.batsmen,
    required this.focusedIndex,
    required this.onSlotTap,
  });

  final String deckName;
  final bool valid;
  final List<PlayerCard> batsmen;
  final int focusedIndex;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.lime,
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
                      'BATTING ORDER',
                      style: TextStyle(
                        color: Cyber.lime.withValues(alpha: 0.75),
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
                color: valid ? Cyber.lime : Cyber.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _BatsmanSlot(
                    index: i,
                    card: batsmen.elementAtOrNull(i),
                    selected: focusedIndex == i,
                    onTap: () => onSlotTap(i),
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

class _BatsmanSlot extends StatelessWidget {
  const _BatsmanSlot({
    required this.index,
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final PlayerCard? card;
  final bool selected;
  final VoidCallback onTap;

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
              ? Cyber.lime.withValues(alpha: 0.14)
              : Cyber.bg.withValues(alpha: 0.42),
          border: Border.all(
            color: selected ? Cyber.lime : Cyber.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              'BAT ${index + 1}',
              style: Cyber.label(
                9,
                color: selected ? Cyber.lime : Cyber.muted,
                letterSpacing: 1.2,
              ),
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
                selected: selected,
                size: VisualCardSize.sm,
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _BatsmanPickerPanel extends StatelessWidget {
  const _BatsmanPickerPanel({
    required this.selectedBatsman,
    required this.slotIndex,
    required this.cards,
    required this.isCardDisabled,
    required this.onSlotTap,
    required this.onClear,
    required this.onSelect,
  });

  final PlayerCard? selectedBatsman;
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
                  label: '${i + 1}',
                  selected: slotIndex == i,
                  onTap: () => onSlotTap(i),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: selectedBatsman == null ? null : onClear,
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
                const Icon(Icons.sports_cricket, color: Cyber.cyan, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedBatsman?.name ?? 'No card assigned',
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
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final card in cards)
                    CyberPlayerCardTile(
                      card: card,
                      selected: selectedBatsman?.id == card.id,
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
