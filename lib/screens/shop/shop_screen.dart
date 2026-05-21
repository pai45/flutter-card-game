import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/shop.dart';
import '../../widgets/card_unpack_animation.dart';
import '../../widgets/cyber/cyber_widgets.dart';

String _rarityString(CardRarity r) => switch (r) {
  CardRarity.common => 'common',
  CardRarity.rare => 'rare',
  CardRarity.epic => 'epic',
  CardRarity.legendary => 'legendary',
};

const Color _bg = Color(0xff0d111a);
const Color _surface = Color(0xff1e2538);
const Color _cyan = Color(0xff5cdfff);
const Color _success = Color(0xff22c55e);
const Color _warning = Color(0xffeab308);
const Color _error = Color(0xffef4444);
const Color _secondary = Color(0xff94a3b8);

class ShopScreen extends StatefulWidget {
  const ShopScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _indicatorController;
  late Animation<double> _indicatorAnimation;
  int _activeTab = 0;
  int _previousTab = 0;
  int? _celebrationCoins;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0,
    );
    _indicatorAnimation = AlwaysStoppedAnimation<double>(_activeTab.toDouble());
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setTab(int index) {
    if (index == _activeTab) return;
    _previousTab = _activeTab;
    _activeTab = index;
    _indicatorAnimation =
        Tween<double>(
          begin: _previousTab.toDouble(),
          end: _activeTab.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _indicatorController,
            curve: Curves.easeOutCubic,
          ),
        );
    _tabController.animateTo(index);
    _indicatorController.forward(from: 0);
    setState(() {});
  }

  void _showCelebration(int amount) {
    setState(() => _celebrationCoins = amount);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _celebrationCoins = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (BuildContext context, GameState state) {
        return Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _ShopHeader(
                      coins: state.coins,
                      onBack: () => widget.onNavigate(AppSection.game),
                      onCoinsTap: () => _setTab(0),
                    ),
                    _ShopTabs(
                      activeTab: _activeTab,
                      indicatorAnimation: _indicatorAnimation,
                      onTap: _setTab,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final Animation<Offset> slide = Tween<Offset>(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                        child: KeyedSubtree(
                          key: ValueKey<int>(_activeTab),
                          child: _buildTab(state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_celebrationCoins != null)
                _CelebrationOverlay(amount: _celebrationCoins!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(GameState state) {
    return switch (_activeTab) {
      0 => CoinsTab(onPurchased: _showCelebration),
      1 => const PacksTab(),
      2 => const CardsTab(),
      _ => CardBacksTab(isVisible: _activeTab == 3),
    };
  }
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({
    required this.coins,
    required this.onBack,
    required this.onCoinsTap,
  });

  final int coins;
  final VoidCallback onBack;
  final VoidCallback onCoinsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _surface)),
      ),
      child: Row(
        children: [
          _Pressable(
            onTap: onBack,
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.arrow_back, color: _cyan),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'SHOP',
            style: TextStyle(
              color: _cyan,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          CoinIcon(size: 24),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: coins.toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return Text(
                _formatInt(value.round()),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _Pressable(
            onTap: onCoinsTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cyan,
                border: Border.all(color: _cyan),
                borderRadius: BorderRadius.zero,
              ),
              child: const Icon(Icons.add, color: _bg, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopTabs extends StatelessWidget {
  const _ShopTabs({
    required this.activeTab,
    required this.indicatorAnimation,
    required this.onTap,
  });

  final int activeTab;
  final Animation<double> indicatorAnimation;
  final ValueChanged<int> onTap;

  static const List<String> labels = ['COINS', 'PACKS', 'CARDS', 'CARD BACKS'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(color: _surface)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double tabWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (int index = 0; index < labels.length; index++)
                    Expanded(
                      child: _Pressable(
                        onTap: () => onTap(index),
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              color: activeTab == index ? _cyan : _secondary,
                              fontFamily: 'Orbitron',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedBuilder(
                animation: indicatorAnimation,
                builder: (BuildContext context, Widget? child) {
                  return Positioned(
                    left: tabWidth * indicatorAnimation.value,
                    bottom: 0,
                    width: tabWidth,
                    height: 2,
                    child: child!,
                  );
                },
                child: const ColoredBox(color: _cyan),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CoinsTab extends StatelessWidget {
  const CoinsTab({required this.onPurchased, super.key});

  final ValueChanged<int> onPurchased;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: coinTiers.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 720 ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.74,
      ),
      itemBuilder: (BuildContext context, int index) {
        final CoinTier tier = coinTiers[index];
        return _CoinTierTile(tier: tier, onPurchased: onPurchased);
      },
    );
  }
}

class _CoinTierTile extends StatelessWidget {
  const _CoinTierTile({required this.tier, required this.onPurchased});

  final CoinTier tier;
  final ValueChanged<int> onPurchased;

  @override
  Widget build(BuildContext context) {
    final bool champion = tier.id == 'champion';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: champion ? _cyan : _surface),
        borderRadius: BorderRadius.zero,
        boxShadow: champion
            ? [
                BoxShadow(
                  color: _cyan.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          CoinIcon(size: 32),
          const SizedBox(height: 10),
          Text(
            _formatInt(tier.coins),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 20,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tier.name.toUpperCase(),
            style: const TextStyle(
              color: _secondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          if (tier.bonusPercent > 0) ...[
            const SizedBox(height: 10),
            _MiniBadge(label: '+${tier.bonusPercent}% BONUS', filled: false),
          ],
          if (tier.tag != null) ...[
            const SizedBox(height: 8),
            _MiniBadge(label: tier.tag!, filled: true),
          ],
          const Spacer(),
          _ShopButton(
            label: '₹${_formatInt(tier.inrPrice)}',
            filled: true,
            onTap: () async {
              final bool confirmed = await _confirmPurchase(
                context,
                name: tier.name,
                price: '₹${_formatInt(tier.inrPrice)}',
                preview: CoinIcon(size: 42),
              );
              if (!context.mounted || !confirmed) return;
              context.read<GameBloc>().add(CoinsAdded(tier.coins));
              onPurchased(tier.coins);
              _showSnack(context, '+${_formatInt(tier.coins)} coins added');
            },
          ),
        ],
      ),
    );
  }
}

class PacksTab extends StatelessWidget {
  const PacksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: shopPacks.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PackTile(pack: shopPacks[index]),
        );
      },
    );
  }
}

// ─── Pack tile with visual pack art ──────────────────────────────────────────
class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack});

  final ShopPack pack;

  @override
  Widget build(BuildContext context) {
    final Widget inner = Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _surface),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual pack art
          PackDesignWidget(pack: pack, width: 110, height: 158),
          // Info + buttons
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pack.cardCount} CARDS',
                    style: const TextStyle(
                      color: _cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pack.guarantee,
                    style: const TextStyle(
                      color: _secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ShopButton(
                    label: _formatInt(pack.coinPrice),
                    filled: false,
                    icon: CoinIcon(size: 16),
                    onTap: () => _buyWithCoins(context),
                  ),
                  const SizedBox(height: 7),
                  _ShopButton(
                    label: '₹${_formatInt(pack.inrPrice)}',
                    filled: true,
                    onTap: () => _buyWithInr(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!pack.gradientAccent) return inner;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xffff3df7), Color(0xff8a5cff)],
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: inner,
    );
  }

  void _buyWithCoins(BuildContext context) {
    final GameBloc bloc = context.read<GameBloc>();
    if (bloc.state.coins < pack.coinPrice) {
      _showSnack(context, 'Not enough coins — top up in the Coins tab.', false);
      return;
    }
    bloc.add(CoinsSpent(pack.coinPrice));
    _openPack(context);
  }

  Future<void> _buyWithInr(BuildContext context) async {
    final bool confirmed = await _confirmPurchase(
      context,
      name: pack.name,
      price: '₹${_formatInt(pack.inrPrice)}',
      preview: PackDesignWidget(pack: pack, width: 110, height: 158),
    );
    if (!context.mounted || !confirmed) return;
    _openPack(context);
  }

  void _openPack(BuildContext context) {
    final GameBloc bloc = context.read<GameBloc>();
    final List<PlayerCard> cards = _rollPack(pack, bloc.state.ownedCardIds);
    int refund = 0;
    for (final PlayerCard card in cards) {
      if (bloc.state.ownedCardIds.contains(card.id)) {
        refund += duplicateRefund(card.rarity);
      }
    }
    bloc.add(
      PackOpened(
        packId: pack.id,
        rolledCardIds: cards.map((c) => c.id).toList(),
        refund: refund,
      ),
    );
    _showSnack(
      context,
      refund > 0
          ? '${pack.name} opened. ${_formatInt(refund)} duplicate refund.'
          : '${pack.name} opened.',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PackRevealSequence(cards: cards),
      ),
    );
  }
}

// ─── Card-by-card reveal sequence ────────────────────────────────────────────
class _PackRevealSequence extends StatefulWidget {
  const _PackRevealSequence({required this.cards});
  final List<PlayerCard> cards;

  @override
  State<_PackRevealSequence> createState() => _PackRevealSequenceState();
}

class _PackRevealSequenceState extends State<_PackRevealSequence> {
  int _index = 0;

  void _advance() {
    if (_index < widget.cards.length - 1) {
      setState(() => _index++);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return CardUnpackAnimation(
      key: ValueKey(_index),
      playerName: card.shortName,
      position: card.position,
      rating: card.rating,
      rarity: _rarityString(card.rarity),
      onComplete: _advance,
      frontFace: CyberPlayerCardTile(
        card: card,
        selected: true,
        size: VisualCardSize.md,
      ),
    );
  }
}

// ─── Animated pack design widget ─────────────────────────────────────────────
class PackDesignWidget extends StatefulWidget {
  const PackDesignWidget({
    required this.pack,
    required this.width,
    required this.height,
    super.key,
  });

  final ShopPack pack;
  final double width;
  final double height;

  @override
  State<PackDesignWidget> createState() => _PackDesignWidgetState();
}

class _PackDesignWidgetState extends State<PackDesignWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, child) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRect(
          child: CustomPaint(
            painter: _PackDesignPainter(
              packId: widget.pack.id,
              accent: widget.pack.accent,
              shimmer: _shimmer.value,
              gradientAccent: widget.pack.gradientAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _PackDesignPainter extends CustomPainter {
  const _PackDesignPainter({
    required this.packId,
    required this.accent,
    required this.shimmer,
    required this.gradientAccent,
  });

  final String packId;
  final Color accent;
  final double shimmer;
  final bool gradientAccent;

  // Per-tier background gradient colours
  static const _bronzeBg = [Color(0xff1E0C00), Color(0xff6B3200)];
  static const _silverBg = [Color(0xff141822), Color(0xff2E3A50)];
  static const _goldBg = [Color(0xff1A1000), Color(0xff5C3A00)];
  static const _iconBg = [Color(0xff0A0018), Color(0xff3D0070)];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipRect(rect);

    // Background gradient
    final bgColors = switch (packId) {
      'bronze' => _bronzeBg,
      'silver' => _silverBg,
      'gold' => _goldBg,
      _ => _iconBg,
    };
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: bgColors,
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Tier pattern
    switch (packId) {
      case 'bronze':
        _paintBronze(canvas, size);
      case 'silver':
        _paintSilver(canvas, size);
      case 'gold':
        _paintGold(canvas, size);
      default:
        _paintIcon(canvas, size);
    }

    // Shimmer sweep (diagonal light band)
    final shimmerX = -size.width * 0.6 + shimmer * size.width * 2.2;
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: gradientAccent ? 0.22 : 0.14),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(rect);
    canvas.save();
    canvas.translate(shimmerX, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.4, size.height),
      shimmerPaint,
    );
    canvas.restore();

    // Left accent bar
    final barColor = gradientAccent ? const Color(0xffff3df7) : accent;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, 3, size.height),
      Paint()..color = barColor,
    );

    // Pack name text drawn via TextPainter
    _drawLabel(canvas, size);

    canvas.restore();

    // Outer border
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.55),
    );
  }

  void _paintBronze(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..strokeWidth = 1.2;
    // Diagonal metallic lines
    for (double d = -size.height; d < size.width + size.height; d += 18) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
    }
    // Glow dot in centre
    _paintCenterGlow(canvas, size, accent.withValues(alpha: 0.30), 40);
  }

  void _paintSilver(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xffc0c0c0).withValues(alpha: 0.18)
      ..strokeWidth = 0.8;
    for (double x = 0; x <= size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    _paintCenterGlow(
      canvas,
      size,
      const Color(0xffc0c0c0).withValues(alpha: 0.25),
      36,
    );
  }

  void _paintGold(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Paint()
      ..color = accent.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    // Starburst rays
    for (int i = 0; i < 16; i++) {
      final angle = (i / 16) * 2 * pi;
      canvas.drawLine(
        center + Offset(cos(angle) * 14, sin(angle) * 14),
        center +
            Offset(
              cos(angle) * size.longestSide * 0.7,
              sin(angle) * size.longestSide * 0.7,
            ),
        p,
      );
    }
    _paintCenterGlow(canvas, size, accent.withValues(alpha: 0.40), 44);
  }

  void _paintIcon(Canvas canvas, Size size) {
    // Holographic rainbow bands
    for (int i = 0; i < 6; i++) {
      final hue = (i / 6 * 360 + shimmer * 360) % 360;
      final color = HSVColor.fromAHSV(0.15, hue, 0.9, 1.0).toColor();
      final p = Paint()
        ..color = color
        ..strokeWidth = size.height / 6;
      canvas.drawLine(
        Offset(0, size.height / 6 * i + size.height / 12),
        Offset(size.width, size.height / 6 * i + size.height / 12),
        p,
      );
    }
    _paintCenterGlow(
      canvas,
      size,
      const Color(0xffff3df7).withValues(alpha: 0.38),
      50,
    );
    // Diagonal overlay
    final dp = Paint()
      ..color = const Color(0xffa855f7).withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (double d = -size.height; d < size.width + size.height; d += 22) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), dp);
    }
  }

  void _paintCenterGlow(Canvas canvas, Size size, Color color, double radius) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawLabel(Canvas canvas, Size size) {
    final label = switch (packId) {
      'bronze' => 'BRONZE',
      'silver' => 'SILVER',
      'gold' => 'GOLD',
      _ => 'ICON',
    };
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: gradientAccent
              ? const Color(0xffff3df7)
              : accent.withValues(alpha: 0.90),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height - tp.height - 8),
    );
  }

  @override
  bool shouldRepaint(_PackDesignPainter old) =>
      old.shimmer != shimmer || old.packId != packId;
}

class CardsTab extends StatefulWidget {
  const CardsTab({super.key});

  @override
  State<CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends State<CardsTab> with TickerProviderStateMixin {
  String _filter = 'All';
  String? _shakingCardId;
  String? _flashingCardId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (BuildContext context, GameState state) {
        final List<PlayerCard> cards = _filteredCards();
        return Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                children: [
                  for (final String label in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChipButton(
                        label: label,
                        active: _filter == label,
                        onTap: () => setState(() => _filter = label),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 720
                      ? 3
                      : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.47,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final PlayerCard card = cards[index];
                  return _PurchasableCardTile(
                    card: card,
                    owned: state.ownedCardIds.contains(card.id),
                    shake: _shakingCardId == card.id,
                    flash: _flashingCardId == card.id,
                    onInsufficient: () => _shake(card.id),
                    onPurchased: () => _flash(card.id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<PlayerCard> _filteredCards() {
    final List<PlayerCard> source = allPlayerCards.take(48).toList();
    return source.where((PlayerCard card) {
      return switch (_filter) {
        'Attackers' => card.role == PlayerRole.attacker,
        'Defenders' => card.role != PlayerRole.attacker,
        'Common' => card.rarity == CardRarity.common,
        'Rare' => card.rarity == CardRarity.rare,
        'Epic' => card.rarity == CardRarity.epic,
        'Legendary' => card.rarity == CardRarity.legendary,
        _ => true,
      };
    }).toList();
  }

  void _shake(String cardId) {
    setState(() => _shakingCardId = cardId);
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _shakingCardId = null);
    });
  }

  void _flash(String cardId) {
    setState(() => _flashingCardId = cardId);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _flashingCardId = null);
    });
  }
}

class _PurchasableCardTile extends StatelessWidget {
  const _PurchasableCardTile({
    required this.card,
    required this.owned,
    required this.shake,
    required this.flash,
    required this.onInsufficient,
    required this.onPurchased,
  });

  final PlayerCard card;
  final bool owned;
  final bool shake;
  final bool flash;
  final VoidCallback onInsufficient;
  final VoidCallback onPurchased;

  @override
  Widget build(BuildContext context) {
    final int coinPrice = _cardCoinPrice(card);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: shake ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      builder: (BuildContext context, double value, Widget? child) {
        final double x = sin(value * pi * 4) * 4;
        return Transform.translate(offset: Offset(x, 0), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(
            color: flash ? _cyan : _surface,
            width: flash ? 2 : 1,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 4),
                CyberPlayerCardTile(
                  card: card,
                  selected: flash,
                  size: VisualCardSize.md,
                ),
                const SizedBox(height: 4),
                if (!owned) ...[
                  const SizedBox(height: 8),
                  _ShopButton(
                    label: _formatInt(coinPrice),
                    filled: false,
                    icon: CoinIcon(size: 16),
                    onTap: () => _buyWithCoins(context, coinPrice),
                  ),
                  const SizedBox(height: 6),
                  _ShopButton(
                    label: '₹${_formatInt(_cardInrPrice(card))}',
                    filled: true,
                    onTap: () => _buyWithInr(context),
                  ),
                ],
              ],
            ),
            if (owned)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.70),
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: -0.14,
                    child: const Text(
                      'OWNED',
                      style: TextStyle(
                        color: _cyan,
                        fontFamily: 'Orbitron',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _buyWithCoins(BuildContext context, int price) {
    final GameBloc bloc = context.read<GameBloc>();
    if (bloc.state.coins < price) {
      onInsufficient();
      _showSnack(context, 'Not enough coins — top up in the Coins tab.', false);
      return;
    }
    bloc.add(CoinsSpent(price));
    bloc.add(CardPurchased(card.id));
    onPurchased();
    _showSnack(context, '${card.shortName} added to your cards.');
    _revealCard(context);
  }

  Future<void> _buyWithInr(BuildContext context) async {
    final bool confirmed = await _confirmPurchase(
      context,
      name: card.name,
      price: '₹${_formatInt(_cardInrPrice(card))}',
      preview: CyberPlayerCardTile(
        card: card,
        selected: true,
        size: VisualCardSize.sm,
      ),
    );
    if (!context.mounted || !confirmed) return;
    context.read<GameBloc>().add(CardPurchased(card.id));
    onPurchased();
    _showSnack(context, '${card.shortName} added to your cards.');
    _revealCard(context);
  }

  void _revealCard(BuildContext context) {
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CardUnpackAnimation(
          playerName: card.shortName,
          position: card.position,
          rating: card.rating,
          rarity: _rarityString(card.rarity),
          onComplete: nav.pop,
          frontFace: CyberPlayerCardTile(
            card: card,
            selected: true,
            size: VisualCardSize.md,
          ),
        ),
      ),
    );
  }
}

class CardBacksTab extends StatelessWidget {
  const CardBacksTab({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (BuildContext context, GameState state) {
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cardBacks.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.52,
          ),
          itemBuilder: (BuildContext context, int index) {
            final CardBackItem back = cardBacks[index];
            final bool owned = state.ownedCardBackIds.contains(back.id);
            final bool equipped = state.equippedCardBackId == back.id;
            return _CardBackTile(
              back: back,
              owned: owned,
              equipped: equipped,
              isVisible: isVisible,
            );
          },
        );
      },
    );
  }
}

class _CardBackTile extends StatelessWidget {
  const _CardBackTile({
    required this.back,
    required this.owned,
    required this.equipped,
    required this.isVisible,
  });

  final CardBackItem back;
  final bool owned;
  final bool equipped;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: equipped ? _cyan : _surface),
        borderRadius: BorderRadius.zero,
        boxShadow: equipped
            ? [BoxShadow(color: _cyan.withValues(alpha: 0.35), blurRadius: 18)]
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 2.5 / 3.5,
              child: CardBackWidget(id: back.id, isAnimating: isVisible),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            back.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          if (equipped)
            const _EquippedLabel()
          else if (owned)
            _ShopButton(
              label: 'EQUIP',
              filled: false,
              onTap: () =>
                  context.read<GameBloc>().add(CardBackEquipped(back.id)),
            )
          else ...[
            _ShopButton(
              label: _formatInt(back.coinPrice),
              filled: false,
              icon: CoinIcon(size: 16),
              onTap: () => _buyWithCoins(context),
            ),
            const SizedBox(height: 6),
            _ShopButton(
              label: '₹${_formatInt(back.inrPrice)}',
              filled: true,
              onTap: () => _buyWithInr(context),
            ),
          ],
        ],
      ),
    );
  }

  void _buyWithCoins(BuildContext context) {
    final GameBloc bloc = context.read<GameBloc>();
    if (bloc.state.coins < back.coinPrice) {
      _showSnack(context, 'Not enough coins — top up in the Coins tab.', false);
      return;
    }
    bloc.add(CoinsSpent(back.coinPrice));
    bloc.add(CardBackPurchased(back.id));
    _showSnack(context, '${back.name} card back unlocked.');
  }

  Future<void> _buyWithInr(BuildContext context) async {
    final bool confirmed = await _confirmPurchase(
      context,
      name: back.name,
      price: '₹${_formatInt(back.inrPrice)}',
      preview: SizedBox(
        width: 70,
        height: 98,
        child: CardBackWidget(id: back.id, isAnimating: true),
      ),
    );
    if (!context.mounted || !confirmed) return;
    context.read<GameBloc>().add(CardBackPurchased(back.id));
    _showSnack(context, '${back.name} card back unlocked.');
  }
}

class CardBackWidget extends StatefulWidget {
  const CardBackWidget({
    required this.id,
    required this.isAnimating,
    super.key,
  });

  final String id;
  final bool isAnimating;

  @override
  State<CardBackWidget> createState() => _CardBackWidgetState();
}

class _CardBackWidgetState extends State<CardBackWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncTicker();
  }

  @override
  void didUpdateWidget(CardBackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncTicker() {
    if (widget.isAnimating && _isAnimated(widget.id)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return CustomPaint(
          painter: _CardBackPainter(id: widget.id, progress: t),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _surface),
              borderRadius: BorderRadius.zero,
            ),
          ),
        );
      },
    );
  }
}

class _CardBackPainter extends CustomPainter {
  const _CardBackPainter({required this.id, required this.progress});

  final String id;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint bgPaint = Paint()..color = _bg;
    canvas.drawRect(rect, bgPaint);

    if (id == 'blue-grid') _paintGrid(canvas, size, _cyan);
    if (id == 'red-streak') _paintStreaks(canvas, size, _error);
    if (id == 'cyan-circuit') _paintCircuit(canvas, size);
    if (id == 'yellow-edge') _paintEdge(canvas, size, _warning);
    if (id == 'pulse-cyan') _paintPulse(canvas, size);
    if (id == 'scan-blue') _paintScan(canvas, size);
    if (id == 'flux-green') _paintGradient(canvas, size, _success);
    if (id == 'drift-violet') {
      _paintGradient(canvas, size, const Color(0xffa855f7));
    }
    if (id == 'holo-foil') _paintHolo(canvas, size);
    if (id == 'prism') _paintPrism(canvas, size);
    if (id == 'obsidian') _paintObsidian(canvas, size);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _cyan.withValues(alpha: 0.45);
    canvas.drawRect(rect.deflate(8), border);
  }

  void _paintGrid(Canvas canvas, Size size, Color color) {
    final Paint line = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  void _paintStreaks(Canvas canvas, Size size, Color color) {
    final Paint line = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 4;
    for (double x = -size.width; x < size.width * 2; x += 28) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.width, 0), line);
    }
  }

  void _paintCircuit(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = _cyan.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    final Paint dot = Paint()..color = _cyan;
    for (int i = 0; i < 6; i++) {
      final double y = 18 + i * 24;
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), line);
      canvas.drawCircle(Offset(24 + i * 9, y), 3, dot);
    }
  }

  void _paintEdge(Canvas canvas, Size size, Color color) {
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color;
    canvas.drawRect((Offset.zero & size).deflate(4), edge);
  }

  void _paintPulse(Canvas canvas, Size size) {
    final double radius = size.longestSide * (0.4 + progress * 0.3);
    final Paint pulse = Paint()
      ..shader =
          RadialGradient(
            colors: [_cyan.withValues(alpha: 0.55), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
          );
    canvas.drawRect(Offset.zero & size, pulse);
  }

  void _paintScan(Canvas canvas, Size size) {
    _paintGrid(canvas, size, _cyan);
    final double y = size.height * progress;
    final Paint scan = Paint()..color = _cyan.withValues(alpha: 0.45);
    canvas.drawRect(Rect.fromLTWH(0, y - 8, size.width, 16), scan);
  }

  void _paintGradient(Canvas canvas, Size size, Color color) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + progress, -1),
        end: Alignment(1, 1 - progress),
        colors: [_bg, color.withValues(alpha: 0.65), _bg],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintHolo(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + progress * 2, -1),
        end: Alignment(1, 1),
        colors: const [_cyan, Color(0xffff3df7), Color(0xffffd700), _cyan],
      ).createShader(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      paint..color = paint.color.withValues(alpha: 0.35),
    );
  }

  void _paintPrism(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(progress * pi),
        colors: const [_cyan, _success, _warning, Color(0xffff3df7), _cyan],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintObsidian(Canvas canvas, Size size) {
    final Paint fleck = Paint()..color = const Color(0xffffd700);
    for (int i = 0; i < 24; i++) {
      final double x = (i * 37 % size.width.toInt()).toDouble();
      final double y = ((i * 19 + progress * 60) % size.height).toDouble();
      canvas.drawCircle(Offset(x, y), 1.2, fleck);
    }
  }

  @override
  bool shouldRepaint(_CardBackPainter oldDelegate) {
    return oldDelegate.id != id || oldDelegate.progress != progress;
  }
}

// PackOpeningOverlay removed — replaced by _PackRevealSequence + CardUnpackAnimation

class CoinIcon extends StatelessWidget {
  const CoinIcon({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint base = Paint()..color = _cyan;
    final Paint inner = Paint()..color = Colors.white.withValues(alpha: 0.34);
    final Rect lower = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.32,
      size.width * 0.76,
      size.height * 0.42,
    );
    final Rect upper = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.16,
      size.width * 0.76,
      size.height * 0.42,
    );
    canvas.drawOval(lower, base);
    canvas.drawOval(upper, base);
    canvas.drawOval(upper.deflate(size.width * 0.16), inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: _pressed ? 0.97 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: _cyan.withValues(alpha: 0.25),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ShopButton extends StatelessWidget {
  const _ShopButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _cyan : Colors.transparent,
          border: Border.all(color: _cyan),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                color: filled ? _bg : _cyan,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _cyan : Colors.transparent,
          border: Border.all(color: _cyan),
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? _bg : _cyan,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? _cyan : Colors.transparent,
        border: Border.all(color: _cyan),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? _bg : _cyan,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _EquippedLabel extends StatelessWidget {
  const _EquippedLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _cyan,
        border: Border.all(color: _cyan),
        borderRadius: BorderRadius.zero,
      ),
      child: const Text(
        'EQUIPPED',
        style: TextStyle(
          color: _bg,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

// _PackPreview removed — replaced by PackDesignWidget

class _CelebrationOverlay extends StatelessWidget {
  const _CelebrationOverlay({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        builder: (BuildContext context, double value, Widget? child) {
          final double scale = value < 0.5
              ? 0.5 + Curves.easeOutBack.transform(value * 2) * 0.7
              : 1.2 - ((value - 0.5) * 0.4);
          final double opacity = value < 0.5 ? 1 : 1 - ((value - 0.5) * 2);
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Center(
          child: Text(
            '+${_formatInt(amount)} COINS',
            style: const TextStyle(
              color: _cyan,
              fontFamily: 'Orbitron',
              fontSize: 34,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmPurchase(
  BuildContext context, {
  required String name,
  required String price,
  required Widget preview,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: _bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: _cyan),
              borderRadius: BorderRadius.zero,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                preview,
                const SizedBox(height: 14),
                Text(
                  price,
                  style: const TextStyle(
                    color: _cyan,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ShopButton(
                        label: 'CANCEL',
                        filled: false,
                        onTap: () => Navigator.pop(context, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ShopButton(
                        label: 'CONFIRM',
                        filled: true,
                        onTap: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

void _showSnack(BuildContext context, String message, [bool success = true]) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 2500),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      content: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: success ? _success : _error, width: 2),
          ),
          borderRadius: BorderRadius.zero,
        ),
        padding: const EdgeInsets.only(left: 10),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    ),
  );
}

List<PlayerCard> _rollPack(ShopPack pack, List<String> ownedIds) {
  final Random random = Random();
  final List<CardRarity> rarities = <CardRarity>[];
  for (int i = 0; i < pack.cardCount; i++) {
    rarities.add(_rollRarity(pack.id, random));
  }
  _applyGuarantees(pack.id, rarities);
  return [
    for (final CardRarity rarity in rarities)
      _pickCardByRarity(rarity, random, ownedIds),
  ];
}

CardRarity _rollRarity(String packId, Random random) {
  final double roll = random.nextDouble();
  return switch (packId) {
    'bronze' => roll < 0.95 ? CardRarity.common : CardRarity.rare,
    'silver' =>
      roll < 0.60
          ? CardRarity.common
          : roll < 0.95
          ? CardRarity.rare
          : CardRarity.epic,
    'gold' =>
      roll < 0.30
          ? CardRarity.common
          : roll < 0.75
          ? CardRarity.rare
          : roll < 0.95
          ? CardRarity.epic
          : CardRarity.legendary,
    _ =>
      roll < 0.25
          ? CardRarity.rare
          : roll < 0.75
          ? CardRarity.epic
          : CardRarity.legendary,
  };
}

void _applyGuarantees(String packId, List<CardRarity> rarities) {
  if (packId == 'silver' &&
      !rarities.any((CardRarity r) => r.index >= CardRarity.rare.index)) {
    rarities[0] = CardRarity.rare;
  }
  if (packId == 'gold' &&
      !rarities.any((CardRarity r) => r.index >= CardRarity.epic.index)) {
    rarities[0] = CardRarity.epic;
  }
  if (packId == 'icon') {
    rarities[0] = CardRarity.legendary;
    rarities[1] = CardRarity.epic;
    rarities[2] = CardRarity.epic;
  }
}

PlayerCard _pickCardByRarity(
  CardRarity rarity,
  Random random,
  List<String> ownedIds,
) {
  final List<PlayerCard> pool = allPlayerCards
      .where((PlayerCard card) => card.rarity == rarity)
      .toList();
  final List<PlayerCard> unowned = pool
      .where((PlayerCard card) => !ownedIds.contains(card.id))
      .toList();
  final List<PlayerCard> source = unowned.isEmpty ? pool : unowned;
  return source[random.nextInt(source.length)];
}

int _cardCoinPrice(PlayerCard card) {
  final int basePrice = (card.rating - 65) * 100;
  return basePrice * rarityMultiplier(card.rarity);
}

int _cardInrPrice(PlayerCard card) {
  return max(10, (_cardCoinPrice(card) / 100).ceil());
}

bool _isAnimated(String id) {
  return cardBacks.any((CardBackItem back) => back.id == id && back.animated);
}

String _formatInt(int value) {
  final String raw = value.toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final int fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

const List<String> _filters = [
  'All',
  'Attackers',
  'Defenders',
  'Common',
  'Rare',
  'Epic',
  'Legendary',
];
