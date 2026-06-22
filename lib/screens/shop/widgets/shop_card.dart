import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared shop-card design system.
//
// Every purchasable tile in the shop — avatar, border, banner, coin, pack, card —
// is composed from these primitives so the six categories read as one family
// (same chamfered silhouette, gradient + border, header tag, name/price footer and
// owned/equipped treatment) while each still shows what it denotes in its own
// preview slot. The shop keeps its own near-black palette (mirrors theme.dart) so
// the look is unchanged; the signature corner-cut comes from [CyberClipper].
// ─────────────────────────────────────────────────────────────────────────────

const Color kShopBg = Color(0xff0d111a);
const Color kShopSurface = Color(0xff1e2538);
const Color kShopCyan = Color(0xff5cdfff);
const Color kShopSecondary = Color(0xff94a3b8);

/// The Oz-coin glyph. Lives here (next to the shop's price widgets) and is
/// re-exported from `shop_screen.dart` so existing importers keep working.
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

/// Tap + hover feedback shared by every shop control (scale on press, a faint
/// cyan halo on hover). Replaces the old per-file `_Pressable`.
class ShopPressable extends StatefulWidget {
  const ShopPressable({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<ShopPressable> createState() => _ShopPressableState();
}

class _ShopPressableState extends State<ShopPressable> {
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
                  ? [BoxShadow(color: kShopCyan.withValues(alpha: 0.25), blurRadius: 16)]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The one chamfered surface every shop tile sits on: accent-tinted gradient,
/// 1px accent border that follows the corner-cut, optional [stamp] overlay
/// (owned / equipped / claimed) and a single opt-in [focal] glow.
///
/// Per the glow rule, [focal] is reserved for the one "live" tile (an equipped
/// border, a selected card) — resting tiles get depth from fill + border only.
class ShopCardFrame extends StatelessWidget {
  const ShopCardFrame({
    required this.accent,
    required this.child,
    this.focal = false,
    this.stamp,
    super.key,
  });

  final Color accent;
  final Widget child;
  final bool focal;
  final Widget? stamp;

  @override
  Widget build(BuildContext context) {
    Widget frame = CustomPaint(
      foregroundPainter: _ShopFrameBorder(
        color: accent.withValues(alpha: focal ? 0.9 : 0.4),
        width: focal ? 1.6 : 1.0,
      ),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.12), kShopBg],
            ),
          ),
          child: Stack(
            children: [
              child,
              if (stamp != null) Positioned.fill(child: stamp!),
            ],
          ),
        ),
      ),
    );
    if (focal) {
      // Glow sits behind the (lightly chamfered) frame — the single focal accent.
      frame = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: Cyber.glow(accent, alpha: 0.32, blur: 22, spread: 1),
        ),
        child: frame,
      );
    }
    return frame;
  }
}

class _ShopFrameBorder extends CustomPainter {
  const _ShopFrameBorder({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_ShopFrameBorder old) =>
      old.color != color || old.width != width;
}

/// A thin top strip that carries an optional rarity label and an optional [tag]
/// chip — this is where the old bespoke clutter (coin ribbon + rotated bonus
/// sticker, pack guarantee box, card tier badge) collapses into one calm row.
class ShopHeaderStrip extends StatelessWidget {
  const ShopHeaderStrip({
    this.rarity,
    this.rarityColor,
    this.tag,
    this.padding = const EdgeInsets.fromLTRB(8, 7, 8, 0),
    super.key,
  });

  final String? rarity;
  final Color? rarityColor;
  final ShopTag? tag;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (rarity != null)
            Text(
              rarity!.toUpperCase(),
              style: TextStyle(
                color: (rarityColor ?? kShopSecondary).withValues(alpha: 0.9),
                fontFamily: 'Orbitron',
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          const Spacer(),
          ?tag,
        ],
      ),
    );
  }
}

/// One small accent chip — POPULAR / BEST VALUE / +BONUS% / GUARANTEE / tier.
class ShopTag extends StatelessWidget {
  const ShopTag({required this.label, required this.accent, this.icon, super.key});

  final String label;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, color: accent, size: 9), const SizedBox(width: 3)],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontFamily: 'Orbitron',
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shared price read-out: a coin amount, a ₹ amount, or both. Display only
/// (wrap in [ShopActionButton] when it should be tappable).
class ShopPricePill extends StatelessWidget {
  const ShopPricePill({
    this.coins,
    this.inr,
    this.accent = kShopCyan,
    this.size = 14,
    super.key,
  });

  final int? coins;
  final int? inr;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (coins != null) ...[
          CoinIcon(size: size + 1),
          const SizedBox(width: 5),
          Text(
            _formatInt(coins!),
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: size,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (coins != null && inr != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '·',
              style: TextStyle(color: kShopSecondary, fontSize: size),
            ),
          ),
        if (inr != null)
          Text(
            '₹${_formatInt(inr!)}',
            style: TextStyle(
              color: accent,
              fontFamily: 'Orbitron',
              fontSize: size,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

/// The one shop button — filled (primary buy) or outline (secondary). Replaces
/// the old per-file `_ShopButton`.
class ShopActionButton extends StatelessWidget {
  const ShopActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
    this.accent = kShopCyan,
    this.height = 38,
    super.key,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;
  final Widget? icon;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShopPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          border: Border.all(color: accent),
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
                color: filled ? kShopBg : accent,
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

enum ShopStampKind { owned, equipped, claimed }

/// The shared "you have this" stamp: a tilted accent badge over a dark scrim —
/// generalises the old rotated "OWNED" overlay so owned / equipped / claimed all
/// read the same across categories.
class ShopStateStamp extends StatelessWidget {
  const ShopStateStamp({required this.kind, this.accent = kShopCyan, super.key});

  final ShopStampKind kind;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String label = switch (kind) {
      ShopStampKind.owned => 'OWNED',
      ShopStampKind.equipped => 'EQUIPPED',
      ShopStampKind.claimed => 'CLAIMED',
    };
    return Container(
      color: Colors.black.withValues(alpha: 0.66),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: -0.14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            border: Border.all(color: accent, width: 1.5),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16)],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontFamily: 'Orbitron',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thousands-separated integer ("1,500"). Shared by the price widgets.
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
