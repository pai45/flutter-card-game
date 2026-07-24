import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/sport_match.dart';
import '../../services/card_share_service.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

const _collectionSports = <Sport>[
  Sport.football,
  Sport.cricket,
  Sport.basketball,
  Sport.tennis,
  Sport.motorsport,
];

final _collectionSportLabels = _collectionSports
    .map(
      (sport) => sport == Sport.motorsport
          ? 'MOTORSPORT'
          : sportModuleFor(sport).label.toUpperCase(),
    )
    .toList(growable: false);

final _collectionSportIcons = _collectionSports
    .map((sport) => sportModuleFor(sport).icon)
    .toList(growable: false);

class AllCardsScreen extends StatefulWidget {
  const AllCardsScreen({
    required this.onNavigate,
    this.shareController = const CardShareController(),
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final CardShareController shareController;

  @override
  State<AllCardsScreen> createState() => _AllCardsScreenState();
}

class _AllCardsScreenState extends State<AllCardsScreen> {
  int _activeSportTab = 0;
  String _filter = 'ALL';

  Sport get _selectedSport => _collectionSports[_activeSportTab];

  void _onSportTabChanged(int index) {
    setState(() {
      _activeSportTab = index;
      _filter = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        return GameScaffold(
          title: 'All Cards',
          subtitle: '// Your Collection',
          leading: IconButton(
            onPressed: () => widget.onNavigate(AppSection.deck),
            icon: const Icon(Icons.arrow_back),
          ),
          child: Column(
            children: [
              _AllCardsSportsTabs(
                activeIndex: _activeSportTab,
                selectedSport: _selectedSport,
                onTap: _onSportTabChanged,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: KeyedSubtree(
                    key: ValueKey<Sport>(_selectedSport),
                    child: _SportCollectionTab(
                      sport: _selectedSport,
                      state: state,
                      filter: _filter,
                      onFilter: (value) => setState(() => _filter = value),
                      shareController: widget.shareController,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sport tabs (match-page style) ─────────────────────────────────────────────

class _AllCardsSportsTabs extends StatelessWidget {
  const _AllCardsSportsTabs({
    required this.activeIndex,
    required this.selectedSport,
    required this.onTap,
  });

  final int activeIndex;
  final Sport selectedSport;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CyberUnderlineTabs(
      labels: _collectionSportLabels,
      icons: _collectionSportIcons,
      activeIndex: activeIndex,
      accent: sportModuleFor(selectedSport).accent,
      onTap: onTap,
      minTabWidth: 72,
    );
  }
}

// ── Per-sport collection ──────────────────────────────────────────────────────

List<String> _filtersForSport(Sport sport) => switch (sport) {
  Sport.football => const ['ALL', 'ATK', 'DEF', 'GK', 'ACT'],
  Sport.cricket => const ['ALL', 'BAT', 'BOWL'],
  Sport.basketball => const ['ALL', 'G', 'W', 'BIG'],
  Sport.tennis => const ['ALL'],
  Sport.motorsport => const ['ALL', 'F1', 'F2', 'NASCAR', 'INDY'],
};

List<PlayerCard> _playerPoolFor(Sport sport) => switch (sport) {
  Sport.football => footballPlayerCards,
  Sport.cricket => cricketPlayerCards,
  Sport.basketball => basketballPlayerCards,
  Sport.tennis => tennisPlayerCards,
  Sport.motorsport => racingPlayerCards,
};

Color _filterChipColor(String label) => switch (label) {
  'ALL' => Cyber.cyan,
  'ATK' => Cyber.lime,
  'DEF' => Cyber.violet,
  'GK' => Cyber.gold,
  'ACT' => Cyber.magenta,
  'BAT' => Cyber.lime,
  'BOWL' => Cyber.violet,
  'G' => Cyber.gold,
  'W' => Cyber.cyan,
  'BIG' => Cyber.violet,
  'F1' || 'F2' || 'NASCAR' || 'INDY' => Cyber.f1Red,
  _ => Cyber.cyan,
};

bool _playerMatchesFilter(PlayerCard card, String filter) {
  return switch (filter) {
    'ATK' => card.role == PlayerRole.attacker,
    'DEF' => card.role == PlayerRole.defender,
    'GK' => card.role == PlayerRole.goalkeeper,
    'BAT' => card.role == PlayerRole.batsman,
    'BOWL' => card.role == PlayerRole.bowler,
    'G' => card.role == PlayerRole.basketballGuard,
    'W' => card.role == PlayerRole.basketballWing,
    'BIG' => card.role == PlayerRole.basketballBig,
    'F1' => card.role == PlayerRole.f1Driver,
    'F2' => card.role == PlayerRole.f2Driver,
    'NASCAR' => card.role == PlayerRole.nascarDriver,
    'INDY' => card.role == PlayerRole.indycarDriver,
    _ => true,
  };
}

class _SportCollectionTab extends StatelessWidget {
  const _SportCollectionTab({
    required this.sport,
    required this.state,
    required this.filter,
    required this.onFilter,
    required this.shareController,
  });

  final Sport sport;
  final GameState state;
  final String filter;
  final ValueChanged<String> onFilter;
  final CardShareController shareController;

  List<PlayerCard> get _players {
    final owned = _playerPoolFor(sport)
        .where((card) => state.ownedCardIds.contains(card.id))
        .where((card) => filter == 'ACT' ? false : _playerMatchesFilter(card, filter))
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return owned;
  }

  List<ActionCard> get _actions {
    if (sport != Sport.football) return const [];
    if (filter != 'ALL' && filter != 'ACT') return const [];
    return actionCards
        .where((card) => state.ownedActionCardIds.contains(card.id))
        .toList();
  }

  int get _totalCount => _players.length + _actions.length;

  @override
  Widget build(BuildContext context) {
    final filters = _filtersForSport(sport);
    final activeFilter = filters.contains(filter) ? filter : 'ALL';

    return Column(
      children: [
        _FilterRow(
          chips: [
            for (final label in filters)
              _FilterChip(
                label: label,
                color: _filterChipColor(label),
                selected: activeFilter == label,
                onTap: () => onFilter(label),
              ),
          ],
          count: _totalCount,
        ),
        Expanded(
          child: _totalCount == 0
              ? Center(
                  child: Text(
                    'NO ${sportModuleFor(sport).label.toUpperCase()} CARDS YET',
                    style: Cyber.label(10, color: Cyber.muted),
                  ),
                )
              : _CardGrid(
                  itemCount: _totalCount,
                  itemBuilder: (context, index) {
                    if (index < _players.length) {
                      final card = _players[index];
                      return CyberPlayerCardTile(
                        card: card,
                        selected: false,
                        size: VisualCardSize.md,
                        onTap: () => _showPlayerCardDetail(
                          context,
                          card,
                          shareController,
                        ),
                      );
                    }
                    final card = _actions[index - _players.length];
                    return CyberActionCardTile(
                      card: card,
                      selected: false,
                      size: VisualCardSize.md,
                      onTap: () => _showActionCardDetail(
                        context,
                        card,
                        shareController,
                      ),
                    );
                  },
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
    // Same wire as `_CardGrid` so the filter strip is the top rail of the net.
    final line = Cyber.border.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          ...chips.expand((chip) => [chip, const SizedBox(width: 6)]),
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
  const _CardGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Inset between a card and its cell's net lines — keeps the wireframe
  /// readable without crowding the tile.
  static const _cellPad = EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  /// Fixed md tile height used to size each net cell snugly.
  static const _cardH = 192.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 720 ? 3 : 2;
    final cellW = width / crossAxisCount;
    final cellH = _cardH + _cellPad.vertical;
    // Subtle HUD wire — calm divider, never a glow (cyber-ui glow rule).
    final line = Cyber.border.withValues(alpha: 0.55);

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        childAspectRatio: cellW / cellH,
      ),
      itemBuilder: (context, index) {
        final col = index % crossAxisCount;
        final isLastInRow = col == crossAxisCount - 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              // Vertical net lines between columns (not on outer edges).
              right: isLastInRow
                  ? BorderSide.none
                  : BorderSide(color: line),
              // Horizontal net lines under every row.
              bottom: BorderSide(color: line),
            ),
          ),
          child: Padding(
            padding: _cellPad,
            child: Center(child: itemBuilder(context, index)),
          ),
        );
      },
    );
  }
}

// ── Card detail overlays ──────────────────────────────────────────────────────

void _showPlayerCardDetail(
  BuildContext context,
  PlayerCard card,
  CardShareController shareController,
) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.72, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim, secondary) =>
        _PlayerCardDetailOverlay(card: card, shareController: shareController),
  );
}

void _showActionCardDetail(
  BuildContext context,
  ActionCard card,
  CardShareController shareController,
) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.88),
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.72, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim, secondary) =>
        _ActionCardDetailOverlay(card: card, shareController: shareController),
  );
}

// ── Player card detail overlay ────────────────────────────────────────────────

class _PlayerCardDetailOverlay extends StatefulWidget {
  const _PlayerCardDetailOverlay({
    required this.card,
    required this.shareController,
  });

  final PlayerCard card;
  final CardShareController shareController;

  @override
  State<_PlayerCardDetailOverlay> createState() =>
      _PlayerCardDetailOverlayState();
}

class _PlayerCardDetailOverlayState extends State<_PlayerCardDetailOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _rarityColor => switch (widget.card.tier) {
    CardTier.bronze => Cyber.muted,
    CardTier.silver => Cyber.cyan,
    CardTier.gold => Cyber.violet,
    CardTier.platinum => Cyber.gold,
  };

  String get _rarityLabel => switch (widget.card.tier) {
    CardTier.bronze => 'BRONZE',
    CardTier.silver => 'SILVER',
    CardTier.gold => 'GOLD',
    CardTier.platinum => 'PLATINUM',
  };

  Future<void> _shareCard(BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await widget.shareController.sharePlayer(
        context,
        widget.card,
        sharePositionOrigin: origin,
      );
      if (mounted) _showShareMessage('Card ready to share');
    } catch (_) {
      if (mounted) _showShareMessage('Sharing unavailable. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _rarityColor;
    final card = widget.card;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent dismiss when tapping panel
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Pulsing glow rings behind the panel
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) {
                    final t = _pulse.value;
                    return CustomPaint(
                      painter: _GlowRingsPainter(accent: accent, t: t),
                      size: const Size(320, 520),
                    );
                  },
                ),
                // Card panel
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Cyber.bg,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.40),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rarity header
                        _RarityHeader(label: _rarityLabel, color: accent),
                        const SizedBox(height: 22),
                        // Card front
                        CyberPlayerCardTile(
                          card: card,
                          selected: true,
                          selectedAccent: accent,
                          size: VisualCardSize.lg,
                        ),
                        const SizedBox(height: 18),
                        // Stats section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                card.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${card.position}  ·  ${card.country}',
                                style: TextStyle(
                                  color: Cyber.muted,
                                  fontFamily: 'Orbitron',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: _StatBadge(
                                      label: 'OVR',
                                      value: '${card.rating}',
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: _StatBadge(
                                      label: 'TRAIT',
                                      value: card.trait.toUpperCase(),
                                      color: Cyber.cyan,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                        // Bottom accent bar
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                accent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: -4,
                  right: -4,
                  child: _CloseButton(onClose: () => Navigator.pop(context)),
                ),
                Positioned(
                  top: -4,
                  left: -4,
                  child: Builder(
                    builder: (buttonContext) => _ShareButton(
                      sharing: _sharing,
                      color: accent,
                      onShare: () => _shareCard(buttonContext),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action card detail overlay ────────────────────────────────────────────────

class _ActionCardDetailOverlay extends StatefulWidget {
  const _ActionCardDetailOverlay({
    required this.card,
    required this.shareController,
  });

  final ActionCard card;
  final CardShareController shareController;

  @override
  State<_ActionCardDetailOverlay> createState() =>
      _ActionCardDetailOverlayState();
}

class _ActionCardDetailOverlayState extends State<_ActionCardDetailOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _categoryColor => switch (widget.card.category) {
    ActionCategory.attack => Cyber.danger,
    ActionCategory.defense => Cyber.violet,
    ActionCategory.special => Cyber.gold,
  };

  String get _categoryLabel => switch (widget.card.category) {
    ActionCategory.attack => 'ATTACK',
    ActionCategory.defense => 'DEFENSE',
    ActionCategory.special => 'SPECIAL',
  };

  Future<void> _shareCard(BuildContext buttonContext) async {
    if (_sharing) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await widget.shareController.shareAction(
        context,
        widget.card,
        sharePositionOrigin: origin,
      );
      if (mounted) _showShareMessage('Card ready to share');
    } catch (_) {
      if (mounted) _showShareMessage('Sharing unavailable. Try again.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor;
    final card = widget.card;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => CustomPaint(
                    painter: _GlowRingsPainter(accent: accent, t: _pulse.value),
                    size: const Size(300, 480),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Cyber.bg,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.40),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RarityHeader(label: _categoryLabel, color: accent),
                        const SizedBox(height: 22),
                        CyberActionCardTile(
                          card: card,
                          selected: true,
                          selectedAccent: accent,
                          size: VisualCardSize.lg,
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                card.title.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Text(
                                  card.effect,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StatBadge(
                                    label: 'PWR',
                                    value:
                                        '${card.power > 0 ? '+' : ''}${card.power}',
                                    color: accent,
                                  ),
                                  if (card.risky) ...[
                                    const SizedBox(width: 8),
                                    _StatBadge(
                                      label: 'RISKY',
                                      value: '⚠',
                                      color: Cyber.amber,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],
                          ),
                        ),
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                accent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: _CloseButton(onClose: () => Navigator.pop(context)),
                ),
                Positioned(
                  top: -4,
                  left: -4,
                  child: Builder(
                    builder: (buttonContext) => _ShareButton(
                      sharing: _sharing,
                      color: accent,
                      onShare: () => _shareCard(buttonContext),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared popup widgets ──────────────────────────────────────────────────────

class _RarityHeader extends StatelessWidget {
  const _RarityHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 5, height: 5, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 5, height: 5, color: color),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.60)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontFamily: 'Orbitron',
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onClose,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.88 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.bg,
            border: Border.all(color: Cyber.cyan, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Cyber.cyan.withValues(alpha: 0.45),
                blurRadius: 14,
              ),
            ],
          ),
          child: const Icon(Icons.close, color: Cyber.cyan, size: 18),
        ),
      ),
    );
  }
}

// ── Glow rings painter ────────────────────────────────────────────────────────

class _ShareButton extends StatefulWidget {
  const _ShareButton({
    required this.sharing,
    required this.color,
    required this.onShare,
  });

  final bool sharing;
  final Color color;
  final VoidCallback onShare;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.sharing ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.sharing ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.sharing ? null : widget.onShare,
      child: Semantics(
        button: true,
        label: 'Share card',
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.88 : 1.0,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.bg,
              border: Border.all(color: widget.color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
            child: widget.sharing
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.color,
                    ),
                  )
                : Icon(Icons.ios_share, color: widget.color, size: 18),
          ),
        ),
      ),
    );
  }
}

class _GlowRingsPainter extends CustomPainter {
  const _GlowRingsPainter({required this.accent, required this.t});
  final Color accent;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final radius = 80.0 + phase * 120;
      final alpha = (1.0 - phase) * 0.18;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = accent.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + (1 - phase) * 1.5,
      );
    }
    // Center glow
    canvas.drawCircle(
      center,
      55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.12 + t * 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 55)),
    );
    // Scanlines over glow area
    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }
  }

  @override
  bool shouldRepaint(_GlowRingsPainter old) =>
      old.t != t || old.accent != accent;
}
