import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/cyber/sport_signal_painters.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';
import 'widgets/final_over_kit_picker.dart';

class FinalOverDeckBuilderScreen extends StatefulWidget {
  const FinalOverDeckBuilderScreen({
    required this.onBack,
    this.onSaved,
    this.onBrowseShop,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onBrowseShop;

  @override
  State<FinalOverDeckBuilderScreen> createState() =>
      _FinalOverDeckBuilderScreenState();
}

class _FinalOverDeckBuilderScreenState extends State<FinalOverDeckBuilderScreen> {
  late List<String?> selectedBatsmen;
  int activeSlotIndex = 0;

  bool get valid => selectedBatsmen.every((id) => id != null);

  @override
  void initState() {
    super.initState();
    _loadDeckIntoEditor(context.read<GameBloc>().state);
    _syncKitOwnership(context.read<GameBloc>().state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        _loadDeckIntoEditor(state);
        _syncKitOwnership(state);
      },
      builder: (context, state) {
        final foState = context.watch<FinalOverCubit>().state;
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
          orElse: () => state.deckSlots.first,
        );
        final selectedCards = <PlayerCard?>[
          for (final id in selectedBatsmen)
            id == null
                ? null
                : batsmen.where((card) => card.id == id).firstOrNull,
        ];
        final ownedBatsmen =
            batsmen
                .where((card) => state.ownedCardIds.contains(card.id))
                .toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));

        return GameScaffold(
          title: 'Final Over Squad',
          subtitle: '// 5-BAT CHASE UNIT',
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
                    const SizedBox(height: 10),
                    FinalOverKitSelector(
                      selectedId: foState.kitId,
                      ownedKitIds: state.ownedFinalOverKitIds,
                      onSelected: (kitId) => context
                          .read<FinalOverCubit>()
                          .selectKit(
                            kitId,
                            ownedKitIds: state.ownedFinalOverKitIds,
                          ),
                      onBrowseShop: widget.onBrowseShop,
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'SAVE SQUAD',
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

  void _syncKitOwnership(GameState state) {
    context.read<FinalOverCubit>().ensureEquippedKitOwned(
      state.ownedFinalOverKitIds,
    );
  }

  void _loadDeckIntoEditor(GameState state) {
    selectedBatsmen = List<String?>.generate(
      5,
      (index) => index < state.deckFinalOverBatsmen.length
          ? state.deckFinalOverBatsmen[index].id
          : null,
    );
  }

  Future<void> _save(StoredDeckSlot active) async {
    final nextBatsmen = selectedBatsmen.whereType<String>().toList();
    if (_sameIds(active.finalOverBatsmen, nextBatsmen)) {
      (widget.onSaved ?? widget.onBack).call();
      return;
    }
    final bloc = context.read<GameBloc>();
    final saved = bloc.stream.firstWhere(
      (state) => _sameIds(
        state.deckFinalOverBatsmen.map((card) => card.id).toList(),
        nextBatsmen,
      ),
    );
    bloc.add(
      DeckSaved(
        active.copyWith(
          finalOverBatsmen: nextBatsmen,
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
    final next = selectedBatsmen.whereType<String>().toList();
    if (!_sameIds(active.finalOverBatsmen, next)) {
      final discard = await showCyberConfirmDialog(
        context,
        title: 'DISCARD CHANGES?',
        message: 'Your cricket batting order has not been saved.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );
      if (!mounted || !discard) return;
    }
    widget.onBack();
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
  final List<PlayerCard?> batsmen;
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
                      'CHASE SQUAD',
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
          ClipRect(
            child: CustomPaint(
              painter: const CricketCreaseSignalPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 14, 5, 12),
                child: Column(
                  children: [
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 3; i < 5; i++) ...[
                          if (i > 3) const SizedBox(width: 8),
                          Expanded(
                            child: _BatsmanSlot(
                              index: i,
                              card: batsmen.elementAtOrNull(i),
                              selected: focusedIndex == i,
                              onTap: () => onSlotTap(i),
                            ),
                          ),
                        ],
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _CricketTelemetry(
            card: batsmen.elementAtOrNull(focusedIndex),
            slotIndex: focusedIndex,
          ),
        ],
      ),
    );
  }
}

class _CricketTelemetry extends StatelessWidget {
  const _CricketTelemetry({required this.card, required this.slotIndex});

  final PlayerCard? card;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final stats = card == null
        ? const <(String, int)>[]
        : <(String, int)>[
            ('OVR', card.rating),
            ('TIMING', (card.rating + 4).clamp(0, 99)),
            ('BOUNDARY', (card.rating + 7).clamp(0, 99)),
            ('NERVE', (card.rating - 2).clamp(0, 99)),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.50),
        border: Border.all(color: Cyber.lime.withValues(alpha: 0.25)),
      ),
      child: card == null
          ? Text(
              'BAT ${slotIndex + 1} // ASSIGN A FINISHER',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.trait.toUpperCase()} // CREASE TELEMETRY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(8, color: Cyber.lime, letterSpacing: 1),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (final stat in stats)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${stat.$2}',
                              style: Cyber.display(13, color: Cyber.lime),
                            ),
                            Text(
                              stat.$1,
                              style: Cyber.label(6, color: Cyber.muted),
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
              for (var i = 0; i < 5; i++) ...[
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
