import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/shop.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/card_unpack_animation.dart';
import '../../widgets/cyber/cyber_underline_tabs.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/stat_oz_top_bar.dart';

String _tierString(CardTier t) => t.name;

const Color _bg = Color(0xff0d111a);
const Color _surface = Color(0xff1e2538);
const Color _cyan = Color(0xff5cdfff);
const Color _success = Color(0xff22c55e);
const Color _error = Color(0xffef4444);
const Color _secondary = Color(0xff94a3b8);
const Color _bronze = Color(0xffcd7f32);
const Color _silver = Color(0xffc0c0c0);
const Color _gold = Color(0xffffd700);
const Color _magenta = Color(0xffff3df7);
const Color _violet = Color(0xffa855f7);

Color _tierAccent(String id) => switch (id) {
  'rookie' => _bronze,
  'starter' => _silver,
  'pro' => _cyan,
  'elite' => _violet,
  'champion' => _gold,
  'legendary' => _magenta,
  _ => _cyan,
};

const int _shopTabCount = 5;

const List<
  ({
    String id,
    int price,
    Color background,
    Color skin,
    Color hair,
    Color kit,
    Color accent,
  })
>
_avatarPlaceholders = [
  (
    id: 'captain',
    price: 25,
    background: Color(0xff2ca45f),
    skin: Color(0xffffbe91),
    hair: Color(0xff171b25),
    kit: Color(0xff24344a),
    accent: Color(0xffff4b52),
  ),
  (
    id: 'playmaker',
    price: 25,
    background: Color(0xffffa600),
    skin: Color(0xfff1a574),
    hair: Color(0xff432d34),
    kit: Color(0xff16335f),
    accent: Color(0xffd83c46),
  ),
  (
    id: 'keeper',
    price: 25,
    background: Color(0xff36455f),
    skin: Color(0xfff2b085),
    hair: Color(0xff4a2434),
    kit: Color(0xff7b274f),
    accent: Color(0xff22c1ff),
  ),
  (
    id: 'blank-red',
    price: 25,
    background: Color(0xffe91414),
    skin: Color(0xffffc09a),
    hair: Color(0xff141820),
    kit: Color(0xff0d111a),
    accent: Color(0xffffd700),
  ),
  (
    id: 'striker',
    price: 25,
    background: Color(0xffffd22e),
    skin: Color(0xffcc8a62),
    hair: Color(0xff17202e),
    kit: Color(0xff2856a5),
    accent: Color(0xfff5f7ff),
  ),
  (
    id: 'speedster',
    price: 25,
    background: Color(0xff4d89e5),
    skin: Color(0xfff0aa79),
    hair: Color(0xffffd16a),
    kit: Color(0xff3b2351),
    accent: Color(0xfff05d7b),
  ),
  (
    id: 'academy',
    price: 25,
    background: Color(0xffd900d9),
    skin: Color(0xffd79369),
    hair: Color(0xff12151f),
    kit: Color(0xff1d68be),
    accent: Color(0xffffffff),
  ),
  (
    id: 'midfield',
    price: 25,
    background: Color(0xffb75b00),
    skin: Color(0xfff1b486),
    hair: Color(0xff4a2830),
    kit: Color(0xff262d44),
    accent: Color(0xfff0edf5),
  ),
  (
    id: 'finisher',
    price: 25,
    background: Color(0xff28456f),
    skin: Color(0xffc8865f),
    hair: Color(0xff15171e),
    kit: Color(0xffba2330),
    accent: Color(0xffdfe8ff),
  ),
];

const List<
  ({String id, int price, Color start, Color end, Color accent, IconData icon})
>
_bannerPlaceholders = [
  (
    id: 'nebula',
    price: 25,
    start: Color(0xff111d60),
    end: Color(0xff050b1e),
    accent: Color(0xff5cdfff),
    icon: Icons.waves,
  ),
  (
    id: 'sunburst',
    price: 25,
    start: Color(0xffffb000),
    end: Color(0xffff5a00),
    accent: Color(0xffffd700),
    icon: Icons.flash_on,
  ),
  (
    id: 'night',
    price: 25,
    start: Color(0xff431064),
    end: Color(0xff130018),
    accent: Color(0xffff3df7),
    icon: Icons.nightlight_round,
  ),
  (
    id: 'inferno',
    price: 25,
    start: Color(0xffb00012),
    end: Color(0xff1b0207),
    accent: Color(0xffffd166),
    icon: Icons.local_fire_department,
  ),
  (
    id: 'flare',
    price: 25,
    start: Color(0xffff7a00),
    end: Color(0xffffc02e),
    accent: Color(0xffffffff),
    icon: Icons.wb_sunny,
  ),
];

class ShopScreen extends StatefulWidget {
  const ShopScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTab = 0;
  int? _celebrationCoins;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _shopTabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setTab(int index) {
    if (index == _activeTab) return;
    _tabController.animateTo(index);
    setState(() => _activeTab = index);
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
              const Positioned.fill(child: _AnimatedShopBackground()),
              const Positioned.fill(child: CyberTextureOverlay()),
              SafeArea(
                child: Column(
                  children: [
                    StatOzTopBar(
                      title: 'Shop',
                      accent: _cyan,
                      onAddCoins: () => _setTab(2),
                    ),
                    CyberUnderlineTabs(
                      labels: const [
                        'AVATAR',
                        'BANNER',
                        'COINS',
                        'PACKS',
                        'CARDS',
                      ],
                      activeIndex: _activeTab,
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
          bottomNavigationBar: LandingBottomNavigation(
            selectedIndex: 1,
            onNavigate: widget.onNavigate,
            includeShop: false,
          ),
        );
      },
    );
  }

  Widget _buildTab(GameState state) {
    return switch (_activeTab) {
      0 => const AvatarsTab(),
      1 => const BannersTab(),
      2 => CoinsTab(onPurchased: _showCelebration),
      3 => const PacksTab(),
      _ => const CardsTab(),
    };
  }
}

class AvatarsTab extends StatelessWidget {
  const AvatarsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720
            ? 5
            : constraints.maxWidth >= 480
            ? 4
            : 3;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _avatarPlaceholders.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _AvatarShopTile(item: _avatarPlaceholders[index]);
          },
        );
      },
    );
  }
}

class BannersTab extends StatelessWidget {
  const BannersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      itemCount: _bannerPlaceholders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _BannerShopTile(item: _bannerPlaceholders[index]),
          ),
        );
      },
    );
  }
}

class _AvatarShopTile extends StatelessWidget {
  const _AvatarShopTile({required this.item});

  final ({
    String id,
    int price,
    Color background,
    Color skin,
    Color hair,
    Color kit,
    Color accent,
  })
  item;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => _showSnack(context, 'Avatar placeholder reserved.'),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: item.accent.withValues(alpha: 0.28)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              bottom: 32,
              child: CustomPaint(
                painter: _AvatarPlaceholderPainter(
                  background: item.background,
                  skin: item.skin,
                  hair: item.hair,
                  kit: item.kit,
                  accent: item.accent,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 34,
              child: _CosmeticPriceStrip(price: item.price),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerShopTile extends StatelessWidget {
  const _BannerShopTile({required this.item});

  final ({
    String id,
    int price,
    Color start,
    Color end,
    Color accent,
    IconData icon,
  })
  item;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: () => _showSnack(context, 'Banner placeholder reserved.'),
      child: SizedBox(
        height: 112,
        child: ClipPath(
          clipper: const _BannerNotchClipper(),
          child: CustomPaint(
            painter: _BannerPlaceholderPainter(
              start: item.start,
              end: item.end,
              accent: item.accent,
            ),
            foregroundPainter: _BannerBorderPainter(item.accent),
            child: Stack(
              children: [
                Positioned(
                  right: 22,
                  top: 18,
                  bottom: 18,
                  child: _BannerCrest(icon: item.icon, color: item.accent),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 92,
                  height: 38,
                  child: _CosmeticPriceStrip(price: item.price, compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CosmeticPriceStrip extends StatelessWidget {
  const _CosmeticPriceStrip({required this.price, this.compact = false});

  final int price;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: compact ? 0.56 : 0.86),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          CoinIcon(size: compact ? 16 : 14),
          const SizedBox(width: 6),
          Text(
            _formatInt(price),
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: compact ? 15 : 14,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCrest extends StatelessWidget {
  const _BannerCrest({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.24),
              color.withValues(alpha: 0.38),
              _bg.withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.62), blurRadius: 24),
          ],
        ),
        child: Center(child: Icon(icon, color: Colors.white, size: 34)),
      ),
    );
  }
}

class _AvatarPlaceholderPainter extends CustomPainter {
  const _AvatarPlaceholderPainter({
    required this.background,
    required this.skin,
    required this.hair,
    required this.kit,
    required this.accent,
  });

  final Color background;
  final Color skin;
  final Color hair;
  final Color kit;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, background.withValues(alpha: 0.72)],
        ).createShader(bounds),
    );

    final Paint line = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }

    final double w = size.width;
    final double h = size.height;
    final Offset headCenter = Offset(w * 0.5, h * 0.38);

    final Path shoulders = Path()
      ..moveTo(w * 0.13, h)
      ..quadraticBezierTo(w * 0.24, h * 0.70, w * 0.41, h * 0.66)
      ..lineTo(w * 0.59, h * 0.66)
      ..quadraticBezierTo(w * 0.76, h * 0.70, w * 0.87, h)
      ..close();
    canvas.drawPath(shoulders, Paint()..color = kit);

    final Path stripe = Path()
      ..moveTo(w * 0.44, h * 0.70)
      ..lineTo(w * 0.56, h * 0.70)
      ..lineTo(w * 0.62, h)
      ..lineTo(w * 0.38, h)
      ..close();
    canvas.drawPath(stripe, Paint()..color = accent.withValues(alpha: 0.78));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.64),
          width: w * 0.17,
          height: h * 0.18,
        ),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = skin,
    );

    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: w * 0.36, height: h * 0.42),
      Paint()..color = skin,
    );

    final Path hairPath = Path()
      ..moveTo(w * 0.31, h * 0.34)
      ..quadraticBezierTo(w * 0.36, h * 0.15, w * 0.54, h * 0.16)
      ..quadraticBezierTo(w * 0.70, h * 0.20, w * 0.70, h * 0.38)
      ..quadraticBezierTo(w * 0.58, h * 0.31, w * 0.49, h * 0.30)
      ..quadraticBezierTo(w * 0.42, h * 0.31, w * 0.31, h * 0.34)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);

    final Paint eye = Paint()..color = const Color(0xff111827);
    canvas.drawCircle(Offset(w * 0.43, h * 0.39), w * 0.018, eye);
    canvas.drawCircle(Offset(w * 0.57, h * 0.39), w * 0.018, eye);
    canvas.drawLine(
      Offset(w * 0.45, h * 0.51),
      Offset(w * 0.55, h * 0.51),
      Paint()
        ..color = const Color(0xff7f1d1d).withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AvatarPlaceholderPainter old) =>
      old.background != background ||
      old.skin != skin ||
      old.hair != hair ||
      old.kit != kit ||
      old.accent != accent;
}

class _BannerPlaceholderPainter extends CustomPainter {
  const _BannerPlaceholderPainter({
    required this.start,
    required this.end,
    required this.accent,
  });

  final Color start;
  final Color end;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [start, end],
        ).createShader(bounds),
    );

    final Paint dust = Paint()..color = Colors.white.withValues(alpha: 0.09);
    for (int i = 0; i < 52; i++) {
      final double x = (i * 37.0) % size.width;
      final double y = (i * 19.0) % size.height;
      canvas.drawCircle(Offset(x, y), (i % 3 + 1) * 0.75, dust);
    }

    final Paint slash = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..strokeWidth = 2.0;
    for (double x = -size.height; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        slash,
      );
    }

    final Offset burst = Offset(size.width * 0.72, size.height * 0.48);
    canvas.drawCircle(
      burst,
      size.height * 0.72,
      Paint()
        ..shader =
            RadialGradient(
              colors: [accent.withValues(alpha: 0.56), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: burst, radius: size.height * 0.72),
            ),
    );
  }

  @override
  bool shouldRepaint(_BannerPlaceholderPainter old) =>
      old.start != start || old.end != end || old.accent != accent;
}

class _BannerBorderPainter extends CustomPainter {
  const _BannerBorderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      const _BannerNotchClipper().getClip(size),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_BannerBorderPainter old) => old.color != color;
}

class _BannerNotchClipper extends CustomClipper<Path> {
  const _BannerNotchClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 24)
      ..lineTo(size.width - 24, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_BannerNotchClipper oldClipper) => false;
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.66,
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
    final Color accent = _tierAccent(tier.id);
    final bool premium = tier.id == 'champion' || tier.id == 'legendary';
    final bool hasRibbon = tier.tag != null;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.14), _bg],
        ),
        border: Border.all(
          color: accent.withValues(alpha: premium ? 0.95 : 0.55),
          width: premium ? 1.8 : 1.0,
        ),
        // Only premium (champion/legendary) tiers glow; standard tiers rely on
        // the gradient + border so the premium tiers stand out.
        boxShadow: premium
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TierBackgroundPainter(accent)),
          ),
          if (hasRibbon)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: accent,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  tier.tag!,
                  style: TextStyle(
                    color: _bg,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, hasRibbon ? 32 : 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 64,
                  child: Center(child: _CoinStackArt(accent: accent)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _formatInt(tier.coins),
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.6,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 14,
                        ),
                      ],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'COINS',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.85),
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    tier.name.toUpperCase(),
                    style: const TextStyle(
                      color: _secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
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
                    _showSnack(
                      context,
                      '+${_formatInt(tier.coins)} coins added',
                    );
                  },
                ),
              ],
            ),
          ),
          if (tier.bonusPercent > 0)
            Positioned(
              top: hasRibbon ? -10 : -12,
              right: -8,
              child: _BonusSticker(percent: tier.bonusPercent, color: accent),
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

// ─── Pack reveal sequence screen ────────────────────────────────────────────
class _PackRevealSequenceScreen extends StatefulWidget {
  const _PackRevealSequenceScreen({
    required this.cards,
    required this.packName,
    required this.packAccent,
    required this.onComplete,
  });

  final List<PlayerCard> cards;
  final String packName;
  final Color packAccent;
  final VoidCallback onComplete;

  @override
  State<_PackRevealSequenceScreen> createState() =>
      _PackRevealSequenceScreenState();
}

class _PackRevealSequenceScreenState extends State<_PackRevealSequenceScreen> {
  int _currentIndex = 0;

  // Reveal lowest-rated first so the best pull is the climactic last walkout.
  late final List<PlayerCard> _order = [...widget.cards]
    ..sort((a, b) => a.rating.compareTo(b.rating));

  void _advanceCard() {
    if (_currentIndex < widget.cards.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _currentIndex = widget.cards.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _currentIndex >= widget.cards.length;

    if (isComplete) {
      return _buildSummaryScreen();
    } else {
      return _buildCardReveal();
    }
  }

  Widget _buildCardReveal() {
    final card = _order[_currentIndex];
    final totalCards = _order.length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(),
        // Progress pills — the active card's pill elongates and glows.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < totalCards; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _currentIndex ? 20 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= _currentIndex
                      ? widget.packAccent
                      : widget.packAccent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: i == _currentIndex
                      ? [
                          BoxShadow(
                            color: widget.packAccent.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: CardUnpackAnimation(
        playerName: card.shortName,
        position: card.position,
        rating: card.rating,
        rarity: _tierString(card.tier),
        onComplete: _advanceCard,
        frontFace: CyberPlayerCardTile(
          card: card,
          selected: true,
          size: VisualCardSize.md,
        ),
      ),
    );
  }

  Widget _buildSummaryScreen() {
    // Best-to-worst so the hero is the top pull and the grid reads by rarity.
    final sorted = [...widget.cards]
      ..sort((a, b) => b.rating.compareTo(a.rating));
    final best = sorted.first;
    final rest = sorted.skip(1).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                '${widget.packName.toUpperCase()} OPENED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.packAccent,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: widget.packAccent.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'ALL CARDS REVEALED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.packAccent.withValues(alpha: 0.7),
                  fontFamily: 'Orbitron',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              // ── Hero: the top pull, enlarged and glowing, with a TOP PULL tag.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.packAccent.withValues(alpha: 0.16),
                  border: Border.all(color: widget.packAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: widget.packAccent, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      'TOP PULL',
                      style: TextStyle(
                        color: widget.packAccent,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: widget.packAccent.withValues(alpha: 0.45),
                      blurRadius: 36,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: CyberPlayerCardTile(
                  card: best,
                  selected: true,
                  size: VisualCardSize.lg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                best.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'REST OF PACK',
                  style: TextStyle(
                    color: _cyan.withValues(alpha: 0.7),
                    fontFamily: 'Orbitron',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.4),
                    border: Border.all(
                      color: widget.packAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in rest)
                        SizedBox(
                          width: 80,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CyberPlayerCardTile(
                                card: card,
                                selected: true,
                                size: VisualCardSize.sm,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.shortName,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Orbitron',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: _ShopButton(
                  label: 'COLLECT ALL',
                  filled: true,
                  onTap: () {
                    widget.onComplete();
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pack tile with visual pack art ──────────────────────────────────────────
class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack});

  final ShopPack pack;

  @override
  Widget build(BuildContext context) {
    final Color accent = pack.gradientAccent ? _magenta : pack.accent;
    final Widget inner = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.10), _bg.withValues(alpha: 0.95)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 26,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: PackDesignWidget(pack: pack, width: 120, height: 172),
                ),
                if (pack.gradientAccent)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _CornerStar(color: _gold),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.name.toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.8,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.style, color: _cyan, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${pack.cardCount} CARDS',
                        style: const TextStyle(
                          color: _cyan,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      border: Border.all(color: accent.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified, color: accent, size: 11),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pack.guarantee,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  BlocBuilder<GameBloc, GameState>(
                    builder: (context, state) {
                      final isStarterPack = pack.id == 'starter';
                      final isDisabled =
                          isStarterPack && state.starterPackClaimed;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: isDisabled ? 0.5 : 1.0,
                            child: _ShopButton(
                              label: isStarterPack
                                  ? (isDisabled ? 'CLAIMED' : 'FREE')
                                  : _formatInt(pack.coinPrice),
                              filled: false,
                              icon: isStarterPack ? null : CoinIcon(size: 14),
                              onTap: isDisabled
                                  ? () {}
                                  : () => _buyWithCoins(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!isStarterPack)
                            _ShopButton(
                              label: '₹${_formatInt(pack.inrPrice)}',
                              filled: true,
                              onTap: () => _buyWithInr(context),
                            ),
                        ],
                      );
                    },
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffff3df7), Color(0xff8a5cff), Color(0xffff3df7)],
        ),
        boxShadow: [
          BoxShadow(color: _magenta.withValues(alpha: 0.45), blurRadius: 22),
        ],
      ),
      child: inner,
    );
  }

  void _buyWithCoins(BuildContext context) {
    final GameBloc bloc = context.read<GameBloc>();
    if (pack.id == 'starter' && bloc.state.starterPackClaimed) {
      _showSnack(context, 'Starter Pack already claimed!', false);
      return;
    }
    if (bloc.state.coins < pack.coinPrice) {
      _showSnack(context, 'Not enough coins — top up in the Coins tab.', false);
      return;
    }
    playSound(SoundEffect.packOpen);
    bloc.add(ShopPackPurchased(pack.id));
  }

  Future<void> _buyWithInr(BuildContext context) async {
    final bool confirmed = await _confirmPurchase(
      context,
      name: pack.name,
      price: '₹${_formatInt(pack.inrPrice)}',
      preview: PackDesignWidget(pack: pack, width: 110, height: 158),
    );
    if (!context.mounted || !confirmed) return;
    playSound(SoundEffect.packOpen);
    context.read<GameBloc>().add(ShopPackPurchased(pack.id, spendCoins: false));
  }

  // ignore: unused_element
  void _openPack(BuildContext context) {
    context.read<GameBloc>().add(ShopPackPurchased(pack.id));
  }
}

// ─── Card-by-card reveal sequence ────────────────────────────────────────────
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
    final pack = widget.pack;
    final holo = _packHolo(pack.id);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1 ── Base art: try .webp (app standard) → .png → painted
              //      per-tier fallback, so the art shows whatever format is
              //      dropped into assets/packs/, and packs still render before
              //      any art ships.
              Image.asset(
                pack.artAsset, // assets/packs/<id>.webp
                fit: BoxFit.cover,
                // ignore: prefer_void_to_null
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/packs/${pack.id}.png',
                  fit: BoxFit.cover,
                  // ignore: prefer_void_to_null
                  errorBuilder: (_, _, _) => AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, _) => CustomPaint(
                      painter: _PackDesignPainter(
                        packId: pack.id,
                        accent: pack.accent,
                        shimmer: _shimmer.value,
                        gradientAccent: pack.gradientAccent,
                      ),
                    ),
                  ),
                ),
              ),

              // 2 ── Multi-colour holographic shimmer, keyed to pack rarity.
              //      Sweeps brighter, faster and with more colour bands the
              //      rarer the pack (drama escalates with tier).
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, _) => CustomPaint(
                      painter: _PackHoloPainter(
                        shimmer: _shimmer.value,
                        colors: holo.colors,
                        intensity: holo.intensity,
                        bands: holo.bands,
                        speed: holo.speed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Multi-colour holographic sweep tuned per pack rarity. Lower tiers stay calm
// (one cooler band); the elite pack gets a full rainbow foil — honouring the
// glow-scarcity rule (drama escalates with rarity). Intensities are deliberately
// moderate so the sweep reads as light over the art, not a white-out — tune here.
({List<Color> colors, double intensity, int bands, double speed}) _packHolo(
  String packId,
) => switch (packId) {
  'starter' => (
    colors: [_cyan, Colors.white, _violet],
    intensity: 0.35,
    bands: 1,
    speed: 1.0,
  ),
  'bronze' => (
    colors: [_bronze, Color(0xffffd9a8), Colors.white],
    intensity: 0.35,
    bands: 1,
    speed: 1.0,
  ),
  'gold' => (
    colors: [_gold, Colors.white, Color(0xffffe9a8), _gold],
    intensity: 0.42,
    bands: 2,
    speed: 1.15,
  ),
  _ => (
    colors: [_magenta, _violet, _cyan, _gold, _magenta],
    intensity: 0.50,
    bands: 2,
    speed: 1.3,
  ),
};

// Sweeps one or more diagonal multi-colour bands across the pack, additively so
// it reads as light playing over the art (holographic foil).
class _PackHoloPainter extends CustomPainter {
  const _PackHoloPainter({
    required this.shimmer,
    required this.colors,
    required this.intensity,
    required this.bands,
    required this.speed,
  });

  final double shimmer;
  final List<Color> colors;
  final double intensity;
  final int bands;
  final double speed;

  @override
  void paint(Canvas canvas, Size size) {
    // Half-width of the colour band in normalised canvas-diagonal units.
    const double hw = 0.24;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var b = 0; b < bands; b++) {
      final phase = ((shimmer * speed) + b / bands) % 1.0;
      // Center travels from -hw (off left) to 1+hw (off right) as phase 0→1.
      final center = phase * (1 + 2 * hw) - hw;
      final left = (center - hw) * size.width;
      final right = (center + hw) * size.width;
      // Skip completely off-screen bands — avoids degenerate zero-width rects.
      if (right <= 0 || left >= size.width) continue;

      // Build stops uniformly within the band rect (no clamping needed).
      final cols = <Color>[Colors.transparent];
      final stops = <double>[0.0];
      for (var i = 0; i < colors.length; i++) {
        final f = colors.length == 1 ? 0.5 : i / (colors.length - 1).toDouble();
        cols.add(colors[i].withValues(alpha: intensity));
        stops.add(f);
      }
      cols.add(Colors.transparent);
      stops.add(1.0);

      final bandRect = Rect.fromLTRB(left, 0, right, size.height);
      canvas.drawRect(
        bandRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cols,
            stops: stops,
          ).createShader(bandRect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PackHoloPainter old) => old.shimmer != shimmer;
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
      'starter' => _silverBg,
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
      case 'starter':
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
      'starter' => 'STARTER',
      'bronze' => 'BRONZE',
      'gold' => 'GOLD',
      _ => 'ELITE',
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
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  for (final String label in _filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 720
                      ? 3
                      : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.58,
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
        'Bronze' => card.tier == CardTier.bronze,
        'Silver' => card.tier == CardTier.silver,
        'Gold' => card.tier == CardTier.gold,
        'Platinum' => card.tier == CardTier.platinum,
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
    final Color rarityColor = switch (card.tier) {
      CardTier.bronze => _secondary,
      CardTier.silver => _cyan,
      CardTier.gold => _violet,
      CardTier.platinum => _gold,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: shake ? 1 : 0),
      duration: const Duration(milliseconds: 400),
      builder: (BuildContext context, double value, Widget? child) {
        final double x = sin(value * pi * 4) * 4;
        return Transform.translate(offset: Offset(x, 0), child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [rarityColor.withValues(alpha: 0.10), _bg],
          ),
          border: Border.all(
            color: flash ? _cyan : rarityColor.withValues(alpha: 0.55),
            width: flash ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: flash ? 0.5 : 0.18),
              blurRadius: flash ? 22 : 14,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.18),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    _tierString(card.tier).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: rarityColor,
                      fontFamily: 'Orbitron',
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                CyberPlayerCardTile(
                  card: card,
                  selected: flash,
                  size: VisualCardSize.md,
                ),
                if (!owned) ...[
                  const SizedBox(height: 6),
                  _ShopButton(
                    label: _formatInt(coinPrice),
                    filled: false,
                    icon: CoinIcon(size: 14),
                    onTap: () => _buyWithCoins(context, coinPrice),
                  ),
                  const SizedBox(height: 4),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _cyan.withValues(alpha: 0.14),
                        border: Border.all(color: _cyan, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withValues(alpha: 0.45),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: const Text(
                        'OWNED',
                        style: TextStyle(
                          color: _cyan,
                          fontFamily: 'Orbitron',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
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
    playSound(SoundEffect.coins);
    bloc.add(DirectCardPurchased(cardId: card.id, price: price));
    onPurchased();
    _showSnack(context, '${card.shortName} added to your cards.');
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
    playSound(SoundEffect.coins);
    context.read<GameBloc>().add(
      DirectCardPurchased(cardId: card.id, price: 0, spendCoins: false),
    );
    onPurchased();
    _showSnack(context, '${card.shortName} added to your cards.');
  }

  // ignore: unused_element
  void _revealCard(BuildContext context) {
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CardUnpackAnimation(
          playerName: card.shortName,
          position: card.position,
          rating: card.rating,
          rarity: _tierString(card.tier),
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

// PackOpeningOverlay removed — replaced by _PackRevealSequence + CardUnpackAnimation

class CoinIcon extends StatelessWidget {
  const CoinIcon({this.size = 24, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/icons/oz_coins.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
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

// ─── Gamified helpers (background, stickers, odds, art) ─────────────────────

class _AnimatedShopBackground extends StatefulWidget {
  const _AnimatedShopBackground();

  @override
  State<_AnimatedShopBackground> createState() =>
      _AnimatedShopBackgroundState();
}

class _AnimatedShopBackgroundState extends State<_AnimatedShopBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _ShopBackgroundPainter(_c.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ShopBackgroundPainter extends CustomPainter {
  const _ShopBackgroundPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 1.25,
          colors: const [Color(0xff14213a), _bg],
        ).createShader(Offset.zero & size),
    );
    final double scanY = (t * (size.height + 220)) - 110;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY, size.width, 1.4),
      Paint()
        ..color = _cyan.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_ShopBackgroundPainter old) => old.t != t;
}

class _TierBackgroundPainter extends CustomPainter {
  const _TierBackgroundPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = accent.withValues(alpha: 0.06)
      ..strokeWidth = 0.9;
    for (double d = -size.height; d < size.width + size.height; d += 16) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_TierBackgroundPainter old) => old.accent != accent;
}

class _CoinStackArt extends StatelessWidget {
  const _CoinStackArt({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent.withValues(alpha: 0.45), Colors.transparent],
              ),
            ),
          ),
          const Positioned(top: 4, child: CoinIcon(size: 30)),
          const Positioned(top: 16, left: -2, child: CoinIcon(size: 24)),
          const Positioned(top: 16, right: -2, child: CoinIcon(size: 24)),
          const Positioned(bottom: 0, child: CoinIcon(size: 32)),
        ],
      ),
    );
  }
}

class _BonusSticker extends StatelessWidget {
  const _BonusSticker({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.22,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$percent%',
              style: const TextStyle(
                color: _bg,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const Text(
              'BONUS',
              style: TextStyle(
                color: _bg,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 7,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerStar extends StatelessWidget {
  const _CornerStar({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12),
        ],
      ),
      child: const Icon(Icons.star, color: _bg, size: 16),
    );
  }
}

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

// ignore: unused_element
List<PlayerCard> _rollPack(ShopPack pack, List<String> ownedIds) {
  final Random random = Random();
  final List<CardTier> tiers = <CardTier>[];
  for (int i = 0; i < pack.cardCount; i++) {
    tiers.add(_rollTier(pack.id, random));
  }
  _applyGuarantees(pack.id, tiers);
  final seenIds = <String>{...ownedIds};
  return [
    for (final CardTier tier in tiers)
      () {
        final card = _pickCardByTier(tier, random, seenIds.toList());
        seenIds.add(card.id);
        return card;
      }(),
  ];
}

CardTier _rollTier(String packId, Random random) {
  final double roll = random.nextDouble();
  return switch (packId) {
    'bronze' => roll < 0.95 ? CardTier.bronze : CardTier.silver,
    'silver' =>
      roll < 0.60
          ? CardTier.bronze
          : roll < 0.95
          ? CardTier.silver
          : CardTier.gold,
    'gold' =>
      roll < 0.30
          ? CardTier.bronze
          : roll < 0.75
          ? CardTier.silver
          : roll < 0.95
          ? CardTier.gold
          : CardTier.platinum,
    _ =>
      roll < 0.25
          ? CardTier.silver
          : roll < 0.75
          ? CardTier.gold
          : CardTier.platinum,
  };
}

void _applyGuarantees(String packId, List<CardTier> tiers) {
  if (packId == 'silver' &&
      !tiers.any((CardTier t) => t.index >= CardTier.silver.index)) {
    tiers[0] = CardTier.silver;
  }
  if (packId == 'gold' &&
      !tiers.any((CardTier t) => t.index >= CardTier.gold.index)) {
    tiers[0] = CardTier.gold;
  }
  if (packId == 'icon') {
    tiers[0] = CardTier.platinum;
    tiers[1] = CardTier.gold;
    tiers[2] = CardTier.gold;
  }
}

PlayerCard _pickCardByTier(
  CardTier tier,
  Random random,
  List<String> ownedIds,
) {
  final List<PlayerCard> pool = allPlayerCards
      .where((PlayerCard card) => card.tier == tier)
      .toList();
  final List<PlayerCard> unowned = pool
      .where((PlayerCard card) => !ownedIds.contains(card.id))
      .toList();
  final List<PlayerCard> source = unowned.isEmpty ? pool : unowned;
  return source[random.nextInt(source.length)];
}

int _cardCoinPrice(PlayerCard card) {
  final int basePrice = (card.rating - 65) * 100;
  return basePrice * tierMultiplier(card.tier);
}

int _cardInrPrice(PlayerCard card) {
  return max(10, (_cardCoinPrice(card) / 100).ceil());
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
  'Bronze',
  'Silver',
  'Gold',
  'Platinum',
];
