import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../config/tutorial_steps.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../utils/card_helpers.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';
import '../../widgets/tutorial.dart';

class DeckBuilderScreen extends StatefulWidget {
  const DeckBuilderScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<DeckBuilderScreen> createState() => _DeckBuilderScreenState();
}

class _DeckBuilderScreenState extends State<DeckBuilderScreen> {
  late List<String?> selectedAttackers;
  late List<String?> selectedDefenders;
  late List<String?> selectedActions;
  bool editing = false;
  DeckPickerLane activeLane = DeckPickerLane.attacker;
  int activeSlotIndex = 0;
  ActionCategory? actionFilter;
  final _scrollController = ScrollController();
  final _pickerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final state = context.read<GameBloc>().state;
    _loadDeckIntoEditor(state);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get valid =>
      selectedAttackers.every((id) => id != null) &&
      selectedDefenders.every((id) => id != null) &&
      selectedActions.every((id) => id != null);

  int _bestSlotIndex(DeckPickerLane lane) {
    final list = switch (lane) {
      DeckPickerLane.attacker => selectedAttackers,
      DeckPickerLane.defender => selectedDefenders,
      DeckPickerLane.action => selectedActions,
    };
    final idx = list.indexOf(null);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (_, state) {
        if (!editing) _loadDeckIntoEditor(state);
      },
      builder: (context, state) {
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
        );
        final selectedAttackerCards = cardsByIds(
          attackers,
          selectedAttackers.whereType<String>().toList(),
        );
        final selectedDefenderCards = cardsByIds(
          defenders,
          selectedDefenders.whereType<String>().toList(),
        );
        final selectedActionCards = actionCardsByIds(
          selectedActions.whereType<String>().toList(),
        );
        final actionAtk = selectedActionCards
            .where((card) => card.category == ActionCategory.attack)
            .length;
        final actionDef = selectedActionCards
            .where((card) => card.category == ActionCategory.defense)
            .length;
        final actionSpc = selectedActionCards
            .where((card) => card.category == ActionCategory.special)
            .length;
        final unbalancedActions =
            selectedActionCards.length == 6 &&
            (actionAtk == 0 || actionDef == 0);
        final focusedPlayer = switch (activeLane) {
          DeckPickerLane.attacker =>
            selectedAttackerCards.elementAtOrNull(activeSlotIndex),
          DeckPickerLane.defender =>
            selectedDefenderCards.elementAtOrNull(activeSlotIndex),
          DeckPickerLane.action => null,
        };
        final focusedAction = activeLane == DeckPickerLane.action
            ? selectedActionCards.elementAtOrNull(activeSlotIndex)
            : null;

        return Scaffold(
          appBar: ReactHeaderBar(
            title: 'Deck Builder',
            subtitle: editing ? 'Editing' : active.name,
            onBack: () => widget.onNavigate(AppSection.home),
            showShop: false,
            rightSlot: TextButton(
              onPressed: editing
                  ? null
                  : () {
                      context.read<GameBloc>().add(DeckCreated());
                      setState(() {
                        editing = true;
                        selectedAttackers = List<String?>.filled(2, null);
                        selectedDefenders = List<String?>.filled(2, null);
                        selectedActions = List<String?>.filled(6, null);
                        activeLane = DeckPickerLane.attacker;
                        activeSlotIndex = 0;
                        actionFilter = null;
                      });
                    },
              child: const Text('NEW DECK'),
            ),
          ),
          body: CyberBackground(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 104),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 52,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: state.deckSlots.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (_, index) {
                                      final slot = state.deckSlots[index];
                                      final activeSlot =
                                          slot.id == state.activeDeckId;
                                      return DeckPill(
                                        label: slot.name,
                                        meta:
                                            'P ${slot.attackers.length + slot.defenders.length}/4 · ACT ${slot.actions.length}/6',
                                        selected: activeSlot,
                                        onTap: editing
                                            ? null
                                            : () => context
                                                  .read<GameBloc>()
                                                  .add(DeckApplied(slot.id)),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FiveSideDeckPanel(
                                  deckName: active.name,
                                  valid: valid,
                                  attackers: selectedAttackerCards,
                                  defenders: selectedDefenderCards,
                                  actions: selectedActionCards,
                                  actionAtk: actionAtk,
                                  actionDef: actionDef,
                                  actionSpc: actionSpc,
                                  focusedLane: activeLane,
                                  focusedIndex: activeSlotIndex,
                                  editing: editing,
                                  onAttackTap: (index) => _focusSlot(
                                    DeckPickerLane.attacker,
                                    index,
                                  ),
                                  onDefenseTap: (index) => _focusSlot(
                                    DeckPickerLane.defender,
                                    index,
                                  ),
                                  onActionTap: (index) =>
                                      _focusSlot(DeckPickerLane.action, index),
                                ),
                                if (unbalancedActions) ...[
                                  const SizedBox(height: 8),
                                  const DeckActionWarningPanel(),
                                ],
                                if (editing) ...[
                                  const SizedBox(height: 8),
                                  DeckFocusedSelectionPanel(
                                    key: _pickerKey,
                                    lane: activeLane,
                                    slotIndex: activeSlotIndex,
                                    selectedPlayer: focusedPlayer,
                                    selectedAction: focusedAction,
                                    actionFilter: actionFilter,
                                    onFilterChanged: (filter) =>
                                        setState(() => actionFilter = filter),
                                    onClear: _clearActiveSlot,
                                    onLaneTap: (lane) => _focusSlot(
                                      lane,
                                      _bestSlotIndex(lane),
                                    ),
                                    onSlotTap: (index) =>
                                        _focusSlot(activeLane, index),
                                    playerOptions:
                                        activeLane == DeckPickerLane.attacker
                                        ? attackers
                                        : defenders,
                                    actionOptions:
                                        activeLane == DeckPickerLane.action
                                        ? actionCards
                                              .where(
                                                (card) =>
                                                    actionFilter == null ||
                                                    card.category ==
                                                        actionFilter,
                                              )
                                              .toList()
                                        : const [],
                                    isPlayerDisabled: (card) =>
                                        _isPlayerCardLocked(card.id),
                                    isActionDisabled: (card) =>
                                        _isActionCardLocked(card.id),
                                    onSelectPlayer: _assignPlayerToActiveSlot,
                                    onSelectAction: _assignActionToActiveSlot,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    BottomActionBar(
                      primaryLabel: 'PLAY',
                      primaryEnabled: valid,
                      primaryOnTap: () {
                        final slot = _buildStoredSlot(
                          active.name,
                          state.activeDeckId,
                        );
                        context.read<GameBloc>().add(DeckSaved(slot));
                        context.read<GameBloc>().add(MatchStarted());
                        widget.onNavigate(AppSection.match);
                      },
                      secondaryLabel: editing ? 'SAVE' : 'EDIT',
                      secondaryOnTap: () {
                        if (editing) {
                          context.read<GameBloc>().add(
                            DeckSaved(
                              _buildStoredSlot(active.name, state.activeDeckId),
                            ),
                          );
                        }
                        setState(() {
                          editing = !editing;
                          if (editing) {
                            activeLane = DeckPickerLane.attacker;
                            activeSlotIndex = 0;
                            actionFilter = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const TutorialTip(
                  keyName: 'deck-builder',
                  steps: deckTutorialSteps,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _loadDeckIntoEditor(GameState state) {
    selectedAttackers = List<String?>.generate(
      2,
      (index) => index < state.deckAttackers.length
          ? state.deckAttackers[index].id
          : null,
    );
    selectedDefenders = List<String?>.generate(
      2,
      (index) => index < state.deckDefenders.length
          ? state.deckDefenders[index].id
          : null,
    );
    selectedActions = List<String?>.generate(
      6,
      (index) =>
          index < state.deckActions.length ? state.deckActions[index].id : null,
    );
  }

  StoredDeckSlot _buildStoredSlot(String name, String id) => StoredDeckSlot(
    id: id,
    name: name,
    attackers: selectedAttackers.whereType<String>().toList(),
    defenders: selectedDefenders.whereType<String>().toList(),
    actions: selectedActions.whereType<String>().toList(),
  );

  void _focusSlot(DeckPickerLane lane, int index) {
    if (!editing) return;
    setState(() {
      activeLane = lane;
      activeSlotIndex = index;
      if (lane != DeckPickerLane.action) actionFilter = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _pickerKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.05,
        );
      }
    });
  }

  bool _isPlayerCardLocked(String id) {
    if (activeLane == DeckPickerLane.action) return true;
    final activeList = activeLane == DeckPickerLane.attacker
        ? selectedAttackers
        : selectedDefenders;
    final currentId = activeList[activeSlotIndex];
    return activeList.contains(id) && currentId != id;
  }

  bool _isActionCardLocked(String id) {
    final currentId = selectedActions[activeSlotIndex];
    return selectedActions.contains(id) && currentId != id;
  }

  void _assignPlayerToActiveSlot(PlayerCard card) {
    if (!editing || activeLane == DeckPickerLane.action) return;
    setState(() {
      final activeList = activeLane == DeckPickerLane.attacker
          ? [...selectedAttackers]
          : [...selectedDefenders];
      final previousIndex = activeList.indexOf(card.id);
      final currentId = activeList[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        activeList[previousIndex] = currentId;
      }
      activeList[activeSlotIndex] = card.id;
      if (activeLane == DeckPickerLane.attacker) {
        selectedAttackers = activeList;
      } else {
        selectedDefenders = activeList;
      }
      _advanceFocus();
    });
  }

  void _assignActionToActiveSlot(ActionCard card) {
    if (!editing || activeLane != DeckPickerLane.action) return;
    setState(() {
      final activeList = [...selectedActions];
      final previousIndex = activeList.indexOf(card.id);
      final currentId = activeList[activeSlotIndex];
      if (previousIndex != -1 && previousIndex != activeSlotIndex) {
        activeList[previousIndex] = currentId;
      }
      activeList[activeSlotIndex] = card.id;
      selectedActions = activeList;
      _advanceFocus();
    });
  }

  void _clearActiveSlot() {
    if (!editing) return;
    setState(() {
      switch (activeLane) {
        case DeckPickerLane.attacker:
          selectedAttackers[activeSlotIndex] = null;
          break;
        case DeckPickerLane.defender:
          selectedDefenders[activeSlotIndex] = null;
          break;
        case DeckPickerLane.action:
          selectedActions[activeSlotIndex] = null;
          break;
      }
    });
  }

  void _advanceFocus() {
    final nextAttacker = selectedAttackers.indexOf(null);
    final nextDefender = selectedDefenders.indexOf(null);
    final nextAction = selectedActions.indexOf(null);
    if (nextAttacker != -1) {
      activeLane = DeckPickerLane.attacker;
      activeSlotIndex = nextAttacker;
      return;
    }
    if (nextDefender != -1) {
      activeLane = DeckPickerLane.defender;
      activeSlotIndex = nextDefender;
      return;
    }
    if (nextAction != -1) {
      activeLane = DeckPickerLane.action;
      activeSlotIndex = nextAction;
    }
  }
}


class DeckFocusedSelectionPanel extends StatelessWidget {
  const DeckFocusedSelectionPanel({
    required this.lane,
    required this.slotIndex,
    required this.selectedPlayer,
    required this.selectedAction,
    required this.actionFilter,
    required this.onFilterChanged,
    required this.onClear,
    required this.onLaneTap,
    required this.onSlotTap,
    required this.playerOptions,
    required this.actionOptions,
    required this.isPlayerDisabled,
    required this.isActionDisabled,
    required this.onSelectPlayer,
    required this.onSelectAction,
    super.key,
  });

  final DeckPickerLane lane;
  final int slotIndex;
  final PlayerCard? selectedPlayer;
  final ActionCard? selectedAction;
  final ActionCategory? actionFilter;
  final ValueChanged<ActionCategory?> onFilterChanged;
  final VoidCallback onClear;
  final ValueChanged<DeckPickerLane> onLaneTap;
  final ValueChanged<int> onSlotTap;
  final List<PlayerCard> playerOptions;
  final List<ActionCard> actionOptions;
  final bool Function(PlayerCard card) isPlayerDisabled;
  final bool Function(ActionCard card) isActionDisabled;
  final ValueChanged<PlayerCard> onSelectPlayer;
  final ValueChanged<ActionCard> onSelectAction;

  @override
  Widget build(BuildContext context) {
    final accent = switch (lane) {
      DeckPickerLane.attacker => Cyber.lime,
      DeckPickerLane.defender => Cyber.cyan,
      DeckPickerLane.action => Cyber.magenta,
    };
    final slotCount = switch (lane) {
      DeckPickerLane.attacker || DeckPickerLane.defender => 2,
      DeckPickerLane.action => 6,
    };
    final slotLabels = switch (lane) {
      DeckPickerLane.attacker => ['LS', 'RS'],
      DeckPickerLane.defender => ['LCB', 'RCB'],
      DeckPickerLane.action => ['1', '2', '3', '4', '5', '6'],
    };

    return CyberPanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lane switcher tabs + clear button
          Row(
            children: [
              for (final l in DeckPickerLane.values) ...[
                if (l.index > 0) const SizedBox(width: 6),
                _LaneTab(
                  lane: l,
                  selected: lane == l,
                  onTap: () => onLaneTap(l),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: selectedPlayer != null || selectedAction != null
                    ? onClear
                    : null,
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
          // Slot chips
          Row(
            children: [
              for (var i = 0; i < slotCount; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _SlotChip(
                  label: slotLabels[i],
                  selected: slotIndex == i,
                  color: accent,
                  onTap: () => onSlotTap(i),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Current selection preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Icon(
                  switch (lane) {
                    DeckPickerLane.attacker => Icons.sports_soccer,
                    DeckPickerLane.defender => Icons.shield,
                    DeckPickerLane.action => Icons.style,
                  },
                  color: accent,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedPlayer?.name ??
                        selectedAction?.title ??
                        'No card assigned',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lane == DeckPickerLane.action) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  selected: actionFilter == null,
                  label: const Text('ALL'),
                  onSelected: (_) => onFilterChanged(null),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                for (final category in ActionCategory.values)
                  FilterChip(
                    selected: actionFilter == category,
                    label: Text(category.name.toUpperCase()),
                    onSelected: (_) => onFilterChanged(category),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 268,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lane == DeckPickerLane.action)
                    for (final card in actionOptions)
                      CyberActionCardTile(
                        card: card,
                        selected: selectedAction?.id == card.id,
                        disabled: isActionDisabled(card),
                        size: VisualCardSize.sm,
                        onTap: () => onSelectAction(card),
                      )
                  else
                    for (final card in playerOptions)
                      CyberPlayerCardTile(
                        card: card,
                        selected: selectedPlayer?.id == card.id,
                        disabled: isPlayerDisabled(card),
                        size: VisualCardSize.sm,
                        onTap: () => onSelectPlayer(card),
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


class _LaneTab extends StatelessWidget {
  const _LaneTab({
    required this.lane,
    required this.selected,
    required this.onTap,
  });

  final DeckPickerLane lane;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (lane) {
      DeckPickerLane.attacker => Cyber.lime,
      DeckPickerLane.defender => Cyber.cyan,
      DeckPickerLane.action => Cyber.magenta,
    };
    final label = switch (lane) {
      DeckPickerLane.attacker => 'ATTACK',
      DeckPickerLane.defender => 'DEFEND',
      DeckPickerLane.action => 'ACTION',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.38),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : color.withValues(alpha: 0.5),
            fontSize: 10,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}


class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: selected ? color : Cyber.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Cyber.muted,
            fontSize: 10,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}


class DeckPill extends StatelessWidget {
  const DeckPill({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String meta;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Cyber.lime, Cyber.cyan])
              : const LinearGradient(colors: [Cyber.panel2, Cyber.panel]),
          border: Border.all(color: selected ? Cyber.lime : Cyber.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 13, color: Cyber.bg),
              const SizedBox(width: 5),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: selected ? Cyber.bg : Colors.white,
                    fontSize: 11,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(
                    color: selected
                        ? Cyber.bg.withValues(alpha: 0.65)
                        : Cyber.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class DeckActionWarningPanel extends StatelessWidget {
  const DeckActionWarningPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.amber,
      padding: const EdgeInsets.all(12),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Cyber.amber, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Action strip is missing attack or defense coverage — one-sided decks feel brittle in live rounds.',
              style: TextStyle(
                color: Color(0xfff3f4f6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class FiveSideDeckPanel extends StatelessWidget {
  const FiveSideDeckPanel({
    required this.deckName,
    required this.valid,
    required this.attackers,
    required this.defenders,
    required this.actions,
    required this.actionAtk,
    required this.actionDef,
    required this.actionSpc,
    required this.focusedLane,
    required this.focusedIndex,
    required this.editing,
    required this.onAttackTap,
    required this.onDefenseTap,
    required this.onActionTap,
    super.key,
  });

  final String deckName;
  final bool valid;
  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final List<ActionCard> actions;
  final int actionAtk;
  final int actionDef;
  final int actionSpc;
  final DeckPickerLane focusedLane;
  final int focusedIndex;
  final bool editing;
  final ValueChanged<int> onAttackTap;
  final ValueChanged<int> onDefenseTap;
  final ValueChanged<int> onActionTap;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5-A-SIDE DECK',
                      style: TextStyle(
                        color: Cyber.cyan.withValues(alpha: 0.65),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deckName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
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
          const SizedBox(height: 10),
          FiveSidePitch(
            attackers: attackers,
            defenders: defenders,
            editing: editing,
            focusedAttackerIndex: focusedLane == DeckPickerLane.attacker
                ? focusedIndex
                : null,
            focusedDefenderIndex: focusedLane == DeckPickerLane.defender
                ? focusedIndex
                : null,
            onAttackTap: onAttackTap,
            onDefenseTap: onDefenseTap,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '6 ACTION CARDS',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.65),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const Spacer(),
              Text(
                'ATK $actionAtk · DEF $actionDef · SPC $actionSpc',
                style: TextStyle(
                  color: Cyber.cyan.withValues(alpha: 0.45),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final card = index < actions.length ? actions[index] : null;
                if (card == null) {
                  return EmptyActionSlot(
                    highlighted:
                        editing &&
                        focusedLane == DeckPickerLane.action &&
                        focusedIndex == index,
                    onTap: () => onActionTap(index),
                  );
                }
                return CyberActionCardTile(
                  card: card,
                  selected:
                      editing &&
                      focusedLane == DeckPickerLane.action &&
                      focusedIndex == index,
                  onTap: () => onActionTap(index),
                  size: VisualCardSize.sm,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class FiveSidePitch extends StatelessWidget {
  const FiveSidePitch({
    required this.attackers,
    required this.defenders,
    required this.editing,
    required this.focusedAttackerIndex,
    required this.focusedDefenderIndex,
    required this.onAttackTap,
    required this.onDefenseTap,
    super.key,
  });

  final List<PlayerCard> attackers;
  final List<PlayerCard> defenders;
  final bool editing;
  final int? focusedAttackerIndex;
  final int? focusedDefenderIndex;
  final ValueChanged<int> onAttackTap;
  final ValueChanged<int> onDefenseTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff073222), Color(0xff061b22), Color(0xff08111d)],
        ),
        border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: PitchPainter())),
          Positioned(
            left: 28,
            top: 18,
            child: FormationSlot(
              label: 'LS',
              card: attackers.firstOrNull,
              highlighted: editing && focusedAttackerIndex == 0,
              onTap: () => onAttackTap(0),
            ),
          ),
          Positioned(
            right: 28,
            top: 18,
            child: FormationSlot(
              label: 'RS',
              card: attackers.length > 1 ? attackers[1] : null,
              highlighted: editing && focusedAttackerIndex == 1,
              onTap: () => onAttackTap(1),
            ),
          ),
          Positioned(
            left: 28,
            top: 132,
            child: FormationSlot(
              label: 'LCB',
              card: defenders.firstOrNull,
              highlighted: editing && focusedDefenderIndex == 0,
              onTap: () => onDefenseTap(0),
            ),
          ),
          Positioned(
            right: 28,
            top: 132,
            child: FormationSlot(
              label: 'RCB',
              card: defenders.length > 1 ? defenders[1] : null,
              highlighted: editing && focusedDefenderIndex == 1,
              onTap: () => onDefenseTap(1),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 16, child: KeeperCore()),
        ],
      ),
    );
  }
}


class FormationSlot extends StatelessWidget {
  const FormationSlot({
    required this.label,
    required this.card,
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final String label;
  final PlayerCard? card;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (card != null) {
      return CyberPlayerCardTile(
        card: card!,
        selected: highlighted,
        onTap: onTap,
        size: VisualCardSize.sm,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 118,
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.58),
          border: Border.all(
            color: highlighted
                ? Cyber.lime.withValues(alpha: 0.85)
                : Cyber.cyan.withValues(alpha: 0.45),
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Cyber.lime.withValues(alpha: 0.24),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label.contains('S') ? Icons.sports_soccer : Icons.shield,
              color: highlighted ? Cyber.lime : Cyber.cyan,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: highlighted ? Cyber.lime : Cyber.cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Cyber.muted,
                  size: 10,
                ),
                const SizedBox(width: 3),
                const Text(
                  'ADD',
                  style: TextStyle(color: Cyber.muted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class KeeperCore extends StatelessWidget {
  const KeeperCore({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Cyber.magenta.withValues(alpha: 0.16),
          border: Border.all(color: Cyber.magenta.withValues(alpha: 0.65)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GK',
              style: TextStyle(
                color: Cyber.magenta,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
              ),
            ),
            Icon(Icons.back_hand, color: Cyber.magenta, size: 24),
            Text(
              'KEEPER CORE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class EmptyActionSlot extends StatelessWidget {
  const EmptyActionSlot({
    required this.highlighted,
    required this.onTap,
    super.key,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 80,
        decoration: BoxDecoration(
          color: Cyber.panel.withValues(alpha: 0.65),
          border: Border.all(
            color: highlighted ? Cyber.lime : Cyber.line,
            width: highlighted ? 2 : 1,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: Cyber.lime.withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: highlighted ? Cyber.lime : Cyber.cyan,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              'ACTION',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: highlighted ? Cyber.lime : Cyber.muted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class PitchPainter extends CustomPainter {
  const PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(16, size.height * 0.26),
      Offset(size.width - 16, size.height * 0.26),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.54),
      Offset(size.width - 16, size.height * 0.54),
      paint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.54), 40, paint);
    canvas.drawRect(
      Rect.fromLTWH(14, 14, size.width - 28, size.height - 28),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
