import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

class AllCardsScreen extends StatefulWidget {
  const AllCardsScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<AllCardsScreen> createState() => _AllCardsScreenState();
}

class _AllCardsScreenState extends State<AllCardsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  PlayerRole? _roleFilter;
  ActionCategory? _actionFilter;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<PlayerCard> get _players {
    final all = [...attackers, ...defenders];
    if (_roleFilter == null) return all;
    return all.where((c) => c.role == _roleFilter).toList();
  }

  List<ActionCard> get _actions {
    if (_actionFilter == null) return actionCards;
    return actionCards.where((c) => c.category == _actionFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'All Cards',
      subtitle: '// Your Collection',
      leading: IconButton(
        onPressed: () => widget.onNavigate(AppSection.deck),
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        children: [
          _TabBar(controller: _tab),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PlayersTab(
                  cards: _players,
                  filter: _roleFilter,
                  onFilter: (r) => setState(() => _roleFilter = r),
                ),
                _ActionsTab(
                  cards: _actions,
                  filter: _actionFilter,
                  onFilter: (c) => setState(() => _actionFilter = c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff0b1120),
      child: TabBar(
        controller: controller,
        indicatorColor: Cyber.cyan,
        indicatorWeight: 2,
        labelColor: Cyber.cyan,
        unselectedLabelColor: Cyber.muted,
        labelStyle: const TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
        tabs: const [
          Tab(text: 'PLAYERS'),
          Tab(text: 'ACTIONS'),
        ],
      ),
    );
  }
}

// ── Players tab ──────────────────────────────────────────────────────────────

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({
    required this.cards,
    required this.filter,
    required this.onFilter,
  });

  final List<PlayerCard> cards;
  final PlayerRole? filter;
  final ValueChanged<PlayerRole?> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterRow(
          chips: [
            _FilterChip(
              label: 'ALL',
              color: Cyber.cyan,
              selected: filter == null,
              onTap: () => onFilter(null),
            ),
            _FilterChip(
              label: 'ATK',
              color: Cyber.lime,
              selected: filter == PlayerRole.attacker,
              onTap: () => onFilter(PlayerRole.attacker),
            ),
            _FilterChip(
              label: 'DEF',
              color: Cyber.violet,
              selected: filter == PlayerRole.defender,
              onTap: () => onFilter(PlayerRole.defender),
            ),
          ],
          count: cards.length,
        ),
        Expanded(
          child: _CardGrid(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in cards)
                  CyberPlayerCardTile(
                    card: card,
                    selected: false,
                    size: VisualCardSize.md,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Actions tab ───────────────────────────────────────────────────────────────

class _ActionsTab extends StatelessWidget {
  const _ActionsTab({
    required this.cards,
    required this.filter,
    required this.onFilter,
  });

  final List<ActionCard> cards;
  final ActionCategory? filter;
  final ValueChanged<ActionCategory?> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterRow(
          chips: [
            _FilterChip(
              label: 'ALL',
              color: Cyber.cyan,
              selected: filter == null,
              onTap: () => onFilter(null),
            ),
            _FilterChip(
              label: 'ATK',
              color: Cyber.danger,
              selected: filter == ActionCategory.attack,
              onTap: () => onFilter(ActionCategory.attack),
            ),
            _FilterChip(
              label: 'DEF',
              color: Cyber.violet,
              selected: filter == ActionCategory.defense,
              onTap: () => onFilter(ActionCategory.defense),
            ),
            _FilterChip(
              label: 'SPC',
              color: Cyber.gold,
              selected: filter == ActionCategory.special,
              onTap: () => onFilter(ActionCategory.special),
            ),
          ],
          count: cards.length,
        ),
        Expanded(
          child: _CardGrid(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in cards)
                  CyberActionCardTile(
                    card: card,
                    selected: false,
                    size: VisualCardSize.md,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared ───────────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.chips, required this.count});

  final List<Widget> chips;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xff1e2538))),
      ),
      child: Row(
        children: [
          ...chips.expand(
            (chip) => [chip, const SizedBox(width: 6)],
          ),
          const Spacer(),
          Text(
            '$count cards',
            style: const TextStyle(
              color: Cyber.muted,
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : color.withValues(alpha: 0.6),
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CyberBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
