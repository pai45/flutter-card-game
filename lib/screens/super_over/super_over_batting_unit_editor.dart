import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/theme.dart';
import '../../data/super_over_batter_profiles.dart';
import '../../models/cards.dart';
import '../../models/deck.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/match_widgets.dart';

/// Super Over-specific editor that writes the shared three-card deck while
/// exposing only original fictional Final Stand identities.
class SuperOverBattingUnitEditor extends StatefulWidget {
  const SuperOverBattingUnitEditor({
    required this.onBack,
    required this.onContinue,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<SuperOverBattingUnitEditor> createState() =>
      _SuperOverBattingUnitEditorState();
}

class _SuperOverBattingUnitEditorState
    extends State<SuperOverBattingUnitEditor> {
  late List<String?> _selected;
  int _focused = 0;

  bool get _valid => _selected.every((id) => id != null);

  @override
  void initState() {
    super.initState();
    _load(context.read<GameBloc>().state);
  }

  void _load(GameState state) {
    _selected = List<String?>.generate(
      3,
      (index) =>
          index < state.deckBatsmen.length ? state.deckBatsmen[index].id : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        final active = state.deckSlots.firstWhere(
          (slot) => slot.id == state.activeDeckId,
          orElse: () => state.deckSlots.first,
        );
        final selectedCards = <PlayerCard?>[
          for (final id in _selected)
            id == null
                ? null
                : batsmen.where((card) => card.id == id).firstOrNull,
        ];
        final owned =
            batsmen
                .where((card) => state.ownedCardIds.contains(card.id))
                .toList()
              ..sort((a, b) => b.rating.compareTo(a.rating));

        return GameScaffold(
          title: 'Batting Unit',
          subtitle: '// Final Stand roster',
          leading: IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                  children: [
                    CyberPanel(
                      accent: _valid ? Cyber.cyan : Cyber.amber,
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
                                      'THREE-BATTER ORDER',
                                      style: Cyber.label(9, color: Cyber.cyan),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Shared deck rules // Final Stand identities',
                                      style: Cyber.body(9, color: Cyber.muted),
                                    ),
                                  ],
                                ),
                              ),
                              CyberChip(
                                label: _valid ? 'READY' : 'INCOMPLETE',
                                color: _valid ? Cyber.lime : Cyber.amber,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (var i = 0; i < 3; i++) ...[
                                if (i > 0) const SizedBox(width: 7),
                                Expanded(
                                  child: _UnitSlot(
                                    order: i + 1,
                                    card: selectedCards[i],
                                    selected: _focused == i,
                                    onTap: () => setState(() => _focused = i),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'AVAILABLE FINISHERS',
                          style: Cyber.label(9, color: Cyber.cyan),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _selected[_focused] == null
                              ? null
                              : () =>
                                    setState(() => _selected[_focused] = null),
                          icon: const Icon(Icons.close, size: 15),
                          label: const Text('CLEAR SLOT'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final card in owned) ...[
                      _FictionalBatterTile(
                        card: card,
                        selectedIndex: _selected.indexOf(card.id),
                        onTap: () => _assign(card),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ],
                ),
              ),
              BottomActionBar(
                primaryLabel: 'CONTINUE',
                primaryEnabled: _valid,
                primaryOnTap: () async {
                  await _save(active);
                  if (mounted) widget.onContinue();
                },
                secondaryLabel: 'SAVE',
                secondaryOnTap: _valid ? () => _save(active) : () {},
                tertiaryLabel: 'BACK',
                tertiaryOnTap: widget.onBack,
              ),
            ],
          ),
        );
      },
    );
  }

  void _assign(PlayerCard card) {
    setState(() {
      final next = [..._selected];
      final previous = next.indexOf(card.id);
      final displaced = next[_focused];
      if (previous >= 0 && previous != _focused) next[previous] = displaced;
      next[_focused] = card.id;
      _selected = next;
      final empty = _selected.indexOf(null);
      _focused = empty >= 0 ? empty : (_focused + 1) % 3;
    });
  }

  Future<void> _save(StoredDeckSlot active) async {
    if (!_valid) return;
    final nextIds = _selected.whereType<String>().toList();
    final bloc = context.read<GameBloc>();
    bloc.add(
      DeckSaved(
        StoredDeckSlot(
          id: active.id,
          name: active.name,
          attackers: active.attackers,
          defenders: active.defenders,
          actions: active.actions,
          keeper: active.keeper,
          batsmen: nextIds,
          basketballPlayers: active.basketballPlayers,
          basketballStarter: active.basketballStarter,
          chessFormation: active.chessFormation,
        ),
      ),
    );
    await bloc.stream
        .firstWhere(
          (state) => _sameIds(
            state.deckBatsmen.map((card) => card.id).toList(),
            nextIds,
          ),
        )
        .timeout(const Duration(seconds: 2), onTimeout: () => bloc.state);
  }

  bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _UnitSlot extends StatelessWidget {
  const _UnitSlot({
    required this.order,
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final int order;
  final PlayerCard? card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = card == null
        ? null
        : SuperOverBatterProfiles.fromCard(card!, orderIndex: order - 1);
    return Semantics(
      button: true,
      selected: selected,
      label: card == null
          ? 'Batting slot $order, empty'
          : 'Batting slot $order, ${profile!.displayName}',
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 116,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? Cyber.cyan.withValues(alpha: .11)
                : Cyber.bg.withValues(alpha: .62),
            border: Border.all(
              color: selected ? Cyber.cyan : Cyber.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$order', style: Cyber.display(18, color: Cyber.gold)),
              const SizedBox(height: 7),
              Icon(
                card == null ? Icons.add : Icons.person_rounded,
                color: card == null ? Cyber.muted : Cyber.cyan,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                profile?.displayName ?? 'EMPTY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(8, color: Colors.white),
              ),
              if (profile != null)
                Text(
                  '${profile.rating} // ${profile.archetypeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(6.5, color: Cyber.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FictionalBatterTile extends StatelessWidget {
  const _FictionalBatterTile({
    required this.card,
    required this.selectedIndex,
    required this.onTap,
  });

  final PlayerCard card;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = SuperOverBatterProfiles.fromCard(
      card,
      orderIndex: selectedIndex < 0 ? 0 : selectedIndex,
    );
    final selected = selectedIndex >= 0;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${profile.displayName}, rating ${profile.rating}, ${profile.archetypeLabel}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Cyber.cyan.withValues(alpha: .08) : Cyber.panel,
            border: Border.all(color: selected ? Cyber.cyan : Cyber.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Cyber.bg,
                foregroundColor: selected ? Cyber.cyan : Cyber.muted,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: Cyber.display(10)),
                    const SizedBox(height: 2),
                    Text(
                      profile.archetypeLabel,
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              Text(
                '${profile.rating}',
                style: Cyber.display(17, color: Cyber.gold),
              ),
              const SizedBox(width: 9),
              if (selected)
                CyberChip(label: '#${selectedIndex + 1}', color: Cyber.cyan)
              else
                const Icon(Icons.add, color: Cyber.cyan),
            ],
          ),
        ),
      ),
    );
  }
}
