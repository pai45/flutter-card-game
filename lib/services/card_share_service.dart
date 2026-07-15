import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';
import '../models/cards.dart';
import '../utils/label_helpers.dart';
import '../widgets/cyber/cyber_widgets.dart';

class CardShareController {
  const CardShareController();

  Future<void> sharePlayer(
    BuildContext context,
    PlayerCard card, {
    Rect? sharePositionOrigin,
  }) {
    return _share(
      context,
      _CardSharePayload.player(card),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> shareAction(
    BuildContext context,
    ActionCard card, {
    Rect? sharePositionOrigin,
  }) {
    return _share(
      context,
      _CardSharePayload.action(card),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _share(
    BuildContext context,
    _CardSharePayload payload, {
    Rect? sharePositionOrigin,
  }) async {
    final bytes = await _renderPoster(context, payload);
    final fileName = _shareFileName(payload.title);
    await SharePlus.instance.share(
      ShareParams(
        title: 'My StatOz card',
        subject: 'My StatOz card',
        text: payload.shareText,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<Uint8List> _renderPoster(
    BuildContext context,
    _CardSharePayload payload,
  ) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey();
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final media =
        MediaQuery.maybeOf(context) ??
        MediaQueryData.fromView(View.of(context));

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: MediaQuery(
            data: media.copyWith(
              size: const Size(360, 450),
              devicePixelRatio: 1,
              textScaler: TextScaler.noScaling,
            ),
            child: Directionality(
              textDirection: textDirection,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: 360,
                  height: 450,
                  child: _CardSharePoster(payload: payload),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Share poster was not ready.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('Share poster could not be encoded.');
      }
      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }
}

@visibleForTesting
String playerCardShareText(PlayerCard card) {
  return 'I just pulled ${_article(card.tier.name)} '
      '${card.tier.name.toUpperCase()} ${playerRoleLabel(card)} card: '
      '${card.name} (${card.rating} OVR). ${card.trait}. '
      'Can your squad stop this?';
}

@visibleForTesting
String actionCardShareText(ActionCard card) {
  final risk = card.risky ? ' High risk, high reward.' : '';
  return 'I just packed ${_article(card.category.name)} '
      '${card.category.name.toUpperCase()} action card: ${card.title} '
      '(${card.power > 0 ? '+' : ''}${card.power} PWR). '
      '${card.effect}.$risk';
}

String _article(String word) {
  final first = word.isEmpty ? '' : word[0].toLowerCase();
  return 'aeiou'.contains(first) ? 'an' : 'a';
}

String _shareFileName(String title) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'statoz-${slug.isEmpty ? 'card' : slug}-card.png';
}

class _CardSharePayload {
  const _CardSharePayload({
    required this.title,
    required this.kicker,
    required this.accent,
    required this.stats,
    required this.caption,
    required this.shareText,
    required this.card,
  });

  factory _CardSharePayload.player(PlayerCard card) {
    final tier = card.tier.name.toUpperCase();
    return _CardSharePayload(
      title: card.name,
      kicker: '$tier ${playerRoleLabel(card)} // ${card.country}',
      accent: tierColor(card.tier),
      stats: [
        ('OVR', '${card.rating}'),
        ('POS', card.position),
        ('TRAIT', card.trait.toUpperCase()),
      ],
      caption:
          'I just pulled $tier ${playerRoleLabel(card)} heat. '
          'Can your squad stop this?',
      shareText: playerCardShareText(card),
      card: CyberPlayerCardTile(
        card: card,
        selected: true,
        selectedAccent: tierColor(card.tier),
        size: VisualCardSize.lg,
      ),
    );
  }

  factory _CardSharePayload.action(ActionCard card) {
    final category = card.category.name.toUpperCase();
    final accent = actionColor(card.category);
    return _CardSharePayload(
      title: card.title,
      kicker: '$category ACTION // ${card.tier.name.toUpperCase()}',
      accent: accent,
      stats: [
        ('PWR', '${card.power > 0 ? '+' : ''}${card.power}'),
        ('TYPE', actionCode(card.category)),
        ('RISK', card.risky ? 'YES' : 'NO'),
      ],
      caption:
          'This card can flip a match in one move.'
          '${card.risky ? ' High risk, high reward.' : ''}',
      shareText: actionCardShareText(card),
      card: CyberActionCardTile(
        card: card,
        selected: true,
        selectedAccent: accent,
        size: VisualCardSize.lg,
      ),
    );
  }

  final String title;
  final String kicker;
  final Color accent;
  final List<(String, String)> stats;
  final String caption;
  final String shareText;
  final Widget card;
}

class _CardSharePoster extends StatelessWidget {
  const _CardSharePoster({required this.payload});

  final _CardSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Cyber.bg,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff07111f), Color(0xff120c24), Color(0xff04070f)],
        ),
        border: Border.all(color: payload.accent.withValues(alpha: 0.9)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PosterGridPainter())),
          Positioned(
            left: -38,
            top: 38,
            child: _AccentRail(color: payload.accent, width: 190),
          ),
          Positioned(
            right: -34,
            bottom: 74,
            child: _AccentRail(color: Cyber.cyan, width: 160),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              children: [
                _PosterHeader(payload: payload),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 190,
                        height: 284,
                        child: payload.card,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PosterStats(payload: payload),
                const SizedBox(height: 12),
                Text(
                  payload.caption,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Onest',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'STATOZ // CARD FLEX',
                  style: TextStyle(
                    color: payload.accent,
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterHeader extends StatelessWidget {
  const _PosterHeader({required this.payload});

  final _CardSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          payload.kicker,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: payload.accent,
            fontFamily: 'Orbitron',
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          payload.title.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _PosterStats extends StatelessWidget {
  const _PosterStats({required this.payload});

  final _CardSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final stat in payload.stats)
          Expanded(
            child: Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                color: payload.accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: payload.accent.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: payload.accent.withValues(alpha: 0.82),
                      fontFamily: 'Orbitron',
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stat.$2,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AccentRail extends StatelessWidget {
  const _AccentRail({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.42,
      child: SizedBox(
        width: width,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.42), width: 2),
              bottom: BorderSide(
                color: color.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final scan = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.5;
    for (double y = 2; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
