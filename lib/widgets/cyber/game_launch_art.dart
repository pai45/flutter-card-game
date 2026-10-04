import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Hand-drawn vector scenes for game discovery. No bitmap or icon stand-ins.
enum CyberGameArt {
  tactics,
  penalty,
  chess,
  cricket,
  basketball,
  racing,
  tennis,
  quiz,
  bingo,
  player,
  driver,
  winner,
}

class CyberGameIllustration extends StatefulWidget {
  const CyberGameIllustration({
    required this.art,
    required this.accent,
    this.animate = true,
    super.key,
  });

  final CyberGameArt art;
  final Color accent;
  final bool animate;

  @override
  State<CyberGameIllustration> createState() => _CyberGameIllustrationState();
}

class _CyberGameIllustrationState extends State<CyberGameIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );

  void _syncMotion() {
    final active =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (active) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
      _loop.value = 0.28;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(CyberGameIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _GameLaunchPainter(widget.art, widget.accent, _loop),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _GameLaunchPainter extends CustomPainter {
  _GameLaunchPainter(this.art, this.accent, this.loop) : super(repaint: loop);
  final CyberGameArt art;
  final Color accent;
  final Animation<double> loop;
  late Canvas c;
  double get t => loop.value;
  static const tau = math.pi * 2;

  Paint ink([double alpha = 0.8, double width = 1.2]) => Paint()
    ..color = accent.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void line(
    double x,
    double y,
    double ex,
    double ey, [
    double alpha = 0.4,
    double width = 1,
  ]) => c.drawLine(Offset(x, y), Offset(ex, ey), ink(alpha, width));

  void path(List<Offset> points, [double alpha = 0.7, double width = 1.2]) {
    final p = Path()..addPolygon(points, false);
    c.drawPath(p, ink(alpha, width));
  }

  void dot(Offset p, [double radius = 2.4]) =>
      c.drawCircle(p, radius, Paint()..color = accent);

  void label(String text, Offset point, [double alpha = 0.5, double size = 6]) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Cyber.label(
          size,
          color: accent.withValues(alpha: alpha),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, point);
  }

  void reticle(Offset center, double radius, {bool animate = true}) {
    c.drawCircle(center, radius, ink(0.25, 0.7));
    for (var i = 0; i < 4; i++) {
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius + 4),
        (animate ? t * tau : 0) + i * math.pi / 2,
        math.pi / 3.5,
        false,
        ink(0.8),
      );
    }
    line(
      center.dx - radius - 8,
      center.dy,
      center.dx - radius + 3,
      center.dy,
      0.5,
    );
    line(
      center.dx + radius - 3,
      center.dy,
      center.dx + radius + 8,
      center.dy,
      0.5,
    );
    line(
      center.dx,
      center.dy - radius - 8,
      center.dx,
      center.dy - radius + 3,
      0.5,
    );
    line(
      center.dx,
      center.dy + radius - 3,
      center.dx,
      center.dy + radius + 8,
      0.5,
    );
  }

  void trail(Path p, {double phase = 0, double radius = 3}) {
    c.drawPath(p, ink(0.22, 0.8));
    for (final metric in p.computeMetrics()) {
      final progress = (t + phase) % 1;
      final head = metric.length * progress;
      c.drawPath(
        metric.extractPath(math.max(0, head - 24), head),
        ink(0.95, 1.8),
      );
      final pose = metric.getTangentForOffset(head);
      if (pose != null) dot(pose.position, radius);
    }
  }

  void ball(Offset center, double radius, {bool football = false}) {
    c.drawCircle(center, radius, Paint()..color = Cyber.panel);
    c.drawCircle(center, radius, ink(0.95, 1.6));
    if (football) {
      final points = List.generate(
        5,
        (i) =>
            center +
            Offset(
                  math.cos(i * tau / 5 - math.pi / 2),
                  math.sin(i * tau / 5 - math.pi / 2),
                ) *
                radius *
                0.42,
      );
      c.drawPath(Path()..addPolygon(points, true), ink(0.8));
      for (final p in points) {
        final d = p - center;
        c.drawLine(p, center + d * 2.2, ink(0.6, 0.8));
      }
    } else {
      c.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        -1.2,
        2.4,
        false,
        ink(0.65, 0.8),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    c = canvas;
    c.save();
    final scale = math.min(size.width / 220, size.height / 160);
    c.translate(
      (size.width - 220 * scale) / 2,
      (size.height - 160 * scale) / 2,
    );
    c.scale(scale);
    // Quiet schematic scaffolding; moving strokes belong to the scene itself.
    for (var x = 20.0; x < 220; x += 20) {
      for (var y = 20.0; y < 155; y += 20) {
        c.drawCircle(
          Offset(x, y),
          0.65,
          Paint()..color = accent.withValues(alpha: 0.16),
        );
      }
    }
    path(const [
      Offset(12, 42),
      Offset(12, 22),
      Offset(24, 10),
      Offset(52, 10),
    ], 0.35);
    path(const [
      Offset(168, 150),
      Offset(196, 150),
      Offset(208, 138),
      Offset(208, 118),
    ], 0.35);
    label(
      'SIM // ${art.index.toString().padLeft(2, '0')}',
      const Offset(152, 8),
    );
    switch (art) {
      case CyberGameArt.tactics:
        _tactics();
      case CyberGameArt.penalty:
        _penalty();
      case CyberGameArt.chess:
        _chess();
      case CyberGameArt.cricket:
        _cricket();
      case CyberGameArt.basketball:
        _basketball();
      case CyberGameArt.racing:
        _racing();
      case CyberGameArt.tennis:
        _tennis();
      case CyberGameArt.quiz:
        _quiz();
      case CyberGameArt.bingo:
        _bingo();
      case CyberGameArt.player:
        _identity();
      case CyberGameArt.driver:
        _identity(driver: true);
      case CyberGameArt.winner:
        _winner();
    }
    c.restore();
  }

  void _penalty() {
    // Goal cage in perspective, nested wireframe net and a locked-on shot.
    final front = const Rect.fromLTRB(36, 30, 188, 96);
    final back = const Rect.fromLTRB(50, 21, 202, 78);
    c.drawRect(back, ink(0.28));
    for (var i = 0; i <= 8; i++) {
      final x = front.left + front.width * i / 8;
      final bx = back.left + back.width * i / 8;
      line(x, front.top, bx, back.top, 0.22, 0.7);
      line(bx, back.top, bx, back.bottom, 0.22, 0.7);
      line(x, front.bottom, bx, back.bottom, 0.22, 0.7);
    }
    for (var i = 1; i < 5; i++) {
      final y = back.top + back.height * i / 5;
      line(back.left, y, back.right, y, 0.2, 0.7);
    }
    c.drawRect(front, ink(0.9, 1.6));
    line(20, 106, 205, 106, 0.22);
    final target = Offset(153 + math.sin(t * tau) * 9, 48);
    reticle(target, 15);
    dot(target, 2);
    final shot = Path()
      ..moveTo(89, 135)
      ..quadraticBezierTo(115, 92, target.dx, target.dy);
    trail(shot, radius: 4);
    ball(const Offset(86, 137), 13, football: true);
    label('AIM / STRIKE', const Offset(119, 129), 0.7);
    for (var i = 0; i < 5; i++) {
      line(34 + i * 6, 116, 34 + i * 6, 121 + i % 2 * 4, 0.5);
    }
  }

  void _tactics() {
    // Playing cards hover above an isometric tactical pitch.
    path(const [
      Offset(38, 94),
      Offset(129, 56),
      Offset(199, 88),
      Offset(108, 132),
      Offset(38, 94),
    ], 0.5);
    line(73, 110, 163, 72, 0.25);
    c.drawOval(const Rect.fromLTRB(101, 79, 138, 107), ink(0.3));
    for (var i = 0; i < 3; i++) {
      c.save();
      c.translate(66 + i * 38, 54 - (i == 1 ? 12 : 0));
      c.rotate((i - 1) * 0.16);
      final card = Path()
        ..addPolygon(const [
          Offset(-18, -23),
          Offset(-12, -29),
          Offset(18, -29),
          Offset(18, 21),
          Offset(12, 27),
          Offset(-18, 27),
        ], true);
      c.drawPath(card, Paint()..color = Cyber.panel);
      c.drawPath(card, ink(i == 1 ? 0.95 : 0.5));
      c.drawCircle(const Offset(0, -7), 6, ink(0.65));
      path(const [
        Offset(-10, 13),
        Offset(-7, 4),
        Offset(7, 4),
        Offset(10, 13),
      ], 0.6);
      line(-10, 19, 9, 19, 0.3);
      c.restore();
    }
    final p = Path()
      ..moveTo(61, 100)
      ..lineTo(106, 113)
      ..lineTo(144, 94)
      ..lineTo(178, 94);
    trail(p);
    for (final node in const [
      Offset(61, 100),
      Offset(106, 113),
      Offset(144, 94),
    ]) {
      c.drawCircle(node, 5, ink(0.5));
    }
    reticle(const Offset(178, 94), 9);
    label('CHAIN / OUTPLAY', const Offset(31, 141), 0.65);
  }

  Offset _board(double x, double y) =>
      Offset(111 + (x - y) * 18, 41 + (x + y) * 9);

  void _chess() {
    for (var i = 0.0; i <= 5; i++) {
      c.drawLine(_board(i, 0), _board(i, 5), ink(0.25, 0.8));
      c.drawLine(_board(0, i), _board(5, i), ink(0.25, 0.8));
    }
    path([
      _board(0, 0),
      _board(5, 0),
      _board(5, 5),
      _board(0, 5),
      _board(0, 0),
    ], 0.6);
    for (final xy in const [
      Offset(0.5, 2.5),
      Offset(1.5, 3.5),
      Offset(3.5, 1.5),
      Offset(4.5, 2.5),
    ]) {
      final p = _board(xy.dx, xy.dy);
      c.drawOval(Rect.fromCenter(center: p, width: 14, height: 7), ink(0.7));
      path([
        p.translate(-5, -1),
        p.translate(-3, -15),
        p.translate(3, -15),
        p.translate(5, -1),
      ], 0.8);
      c.drawCircle(p.translate(0, -18), 4, ink(0.9));
    }
    final start = _board(1.5, 3.5);
    final end = _board(2.5, 2.5);
    trail(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy),
    );
    reticle(end, 12);
    label('05 V 05 / YOUR MOVE', const Offset(30, 143), 0.65);
  }

  void _basketball() {
    path(const [
      Offset(23, 137),
      Offset(52, 82),
      Offset(189, 82),
      Offset(210, 137),
    ], 0.35);
    c.drawOval(const Rect.fromLTRB(80, 104, 167, 140), ink(0.25));
    c.drawRect(const Rect.fromLTRB(104, 25, 181, 69), ink(0.7, 1.6));
    c.drawRect(const Rect.fromLTRB(128, 44, 156, 63), ink(0.3));
    c.drawOval(const Rect.fromLTRB(125, 65, 163, 75), ink(0.95, 1.8));
    for (var i = 0; i < 6; i++) {
      line(127 + i * 7, 72, 134 + i * 4, 90, 0.4, 0.8);
    }
    line(132, 83, 156, 83, 0.4, 0.8);
    line(142, 25, 142, 13, 0.4);
    final arc = Path()
      ..moveTo(45, 126)
      ..cubicTo(47, 20, 96, 5, 145, 67);
    trail(arc, radius: 5);
    ball(const Offset(45, 126), 12);
    line(33, 126, 57, 126, 0.7);
    line(45, 114, 45, 138, 0.7);
    label('RISE / RELEASE', const Offset(82, 145), 0.65);
  }

  void _cricket() {
    path(const [
      Offset(86, 40),
      Offset(133, 40),
      Offset(169, 140),
      Offset(45, 140),
      Offset(86, 40),
    ], 0.45);
    line(76, 61, 142, 61, 0.3);
    line(54, 119, 159, 119, 0.45);
    for (var i = 0; i < 3; i++) {
      line(101 + i * 7, 26, 101 + i * 7, 54, 0.9, 2);
    }
    line(99, 28, 117, 28, 0.9, 1.8);
    c.save();
    c.translate(164, 80);
    c.rotate(-0.45);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-7, -18, 7, 25),
        const Radius.circular(2),
      ),
      ink(0.7, 1.5),
    );
    line(0, -18, 0, -36, 0.9, 3);
    line(-3, -11, -3, 17, 0.25);
    c.restore();
    trail(
      Path()
        ..moveTo(109, 52)
        ..lineTo(93, 99)
        ..quadraticBezierTo(149, 104, 190, 43),
      radius: 4,
    );
    for (var i = 0; i < 6; i++) {
      c.drawCircle(
        Offset(39 + i * 7, 17),
        2,
        i == (t * 6).floor() ? (Paint()..color = accent) : ink(0.4, 0.8),
      );
    }
    label('06 BALLS / ONE CHASE', const Offset(34, 148), 0.65);
  }

  void _racing() {
    // Blueprint F1 chassis, speed rails and a moving circuit trace.
    final circuit = Path()
      ..moveTo(154, 31)
      ..lineTo(184, 31)
      ..quadraticBezierTo(205, 31, 193, 50)
      ..lineTo(170, 78)
      ..quadraticBezierTo(161, 92, 188, 99)
      ..lineTo(192, 127)
      ..quadraticBezierTo(180, 145, 151, 128)
      ..lineTo(136, 66)
      ..close();
    trail(circuit, radius: 2.5);
    c.save();
    c.translate(84, 84);
    c.rotate(0.35);
    final car = Path()
      ..addPolygon(const [
        Offset(-4, -54),
        Offset(4, -54),
        Offset(9, -18),
        Offset(16, 2),
        Offset(13, 30),
        Offset(-13, 30),
        Offset(-16, 2),
        Offset(-9, -18),
      ], true);
    c.drawPath(car, Paint()..color = Cyber.panel);
    c.drawPath(car, ink(0.9, 1.4));
    c.drawRect(const Rect.fromLTRB(-27, -47, 27, -40), ink(0.8));
    c.drawRect(const Rect.fromLTRB(-24, 30, 24, 39), ink(0.8));
    for (final x in [-24.0, 17.0]) {
      for (final y in [-29.0, 14.0]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 8, 19),
            const Radius.circular(2),
          ),
          ink(0.65),
        );
      }
    }
    c.drawOval(const Rect.fromLTRB(-6, -10, 6, 9), ink(0.8));
    line(0, -42, 0, -16, 0.4);
    for (var i = 0; i < 3; i++) {
      final y = 44 + ((t + i / 3) % 1) * 25;
      line(-7 + i * 7, y, -7 + i * 7, y + 12, 0.55);
    }
    c.restore();
    label('ERS / FULL SEND', const Offset(26, 148), 0.7);
  }

  void _tennis() {
    path(const [
      Offset(54, 44),
      Offset(165, 44),
      Offset(201, 133),
      Offset(19, 133),
      Offset(54, 44),
    ], 0.6);
    line(36, 92, 183, 92, 0.65);
    line(45, 73, 176, 73, 0.3);
    line(32, 109, 189, 109, 0.3);
    line(110, 44, 110, 133, 0.25);
    for (var i = 0; i < 13; i++) {
      line(37 + i * 12, 83, 37 + i * 12, 91, 0.3, 0.7);
    }
    c.save();
    c.translate(160, 42);
    c.rotate(0.55 + math.sin(t * tau) * 0.08);
    c.drawOval(const Rect.fromLTRB(-15, -20, 15, 20), ink(0.9, 1.6));
    c.drawOval(const Rect.fromLTRB(-11, -16, 11, 16), ink(0.35));
    for (var i = -2; i <= 2; i++) {
      line(i * 4.0, -14, i * 4.0, 14, 0.3, 0.7);
      line(-10, i * 5.0, 10, i * 5.0, 0.3, 0.7);
    }
    line(0, 20, 0, 43, 0.8, 4);
    c.restore();
    trail(
      Path()
        ..moveTo(66, 120)
        ..quadraticBezierTo(65, 20, 148, 57),
      radius: 4,
    );
    label('SERVE / RALLY / WIN', const Offset(36, 147), 0.65);
  }

  void _quiz() {
    // Neural core held inside a hexagonal answer lattice.
    final center = const Offset(110, 77);
    for (final radius in [43.0, 55.0]) {
      final points = List.generate(
        6,
        (i) =>
            center +
            Offset(math.cos(i * tau / 6), math.sin(i * tau / 6)) * radius,
      );
      c.drawPath(
        Path()..addPolygon(points, true),
        ink(radius == 43 ? 0.7 : 0.2),
      );
    }
    reticle(center, 30);
    label('?', const Offset(98, 52), 1, 35);
    final nodes = const [
      Offset(38, 43),
      Offset(185, 43),
      Offset(185, 115),
      Offset(38, 115),
    ];
    for (var i = 0; i < nodes.length; i++) {
      final p = nodes[i];
      c.drawLine(center + (p - center) * 0.55, p, ink(0.25));
      c.drawRect(Rect.fromCenter(center: p, width: 22, height: 19), ink(0.55));
      label(String.fromCharCode(65 + i), p.translate(-4, -5), 0.9, 8);
      if (i == (t * 4).floor()) {
        c.drawRect(
          Rect.fromCenter(center: p, width: 28, height: 25),
          ink(0.75),
        );
      }
    }
    label('THINK / LOCK IN', const Offset(55, 145), 0.7);
  }

  void _bingo() {
    const origin = Offset(62, 26);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 3; x++) {
        final cell = Rect.fromLTWH(
          origin.dx + x * 33,
          origin.dy + y * 33,
          29,
          29,
        );
        c.drawRect(cell, ink(x == y ? 0.7 : 0.25));
        if (x == y) {
          path(
            [
              cell.center.translate(-6, 0),
              cell.center.translate(-1, 5),
              cell.center.translate(7, -5),
            ],
            0.9,
            1.8,
          );
        } else {
          c.drawCircle(cell.center, 3, ink(0.3));
        }
      }
    }
    trail(
      Path()
        ..moveTo(76, 40)
        ..lineTo(142, 106),
      radius: 4,
    );
    reticle(const Offset(142, 106), 18);
    label('LINK / COMPLETE', const Offset(50, 145), 0.65);
  }

  void _identity({bool driver = false}) {
    final frame = Path()
      ..addPolygon(const [
        Offset(65, 22),
        Offset(144, 22),
        Offset(163, 41),
        Offset(163, 115),
        Offset(144, 134),
        Offset(65, 134),
        Offset(46, 115),
        Offset(46, 41),
      ], true);
    c.drawPath(frame, ink(0.65));
    if (driver) {
      final helmet = Path()
        ..moveTo(76, 78)
        ..lineTo(73, 61)
        ..cubicTo(72, 28, 139, 28, 139, 62)
        ..lineTo(137, 83)
        ..lineTo(124, 91)
        ..lineTo(84, 87)
        ..close();
      c.drawPath(helmet, ink(0.9, 1.4));
      path(const [
        Offset(74, 58),
        Offset(130, 56),
        Offset(141, 65),
        Offset(117, 73),
        Offset(76, 70),
      ], 0.7);
      line(100, 82, 128, 82, 0.4);
    } else {
      c.drawOval(const Rect.fromLTRB(87, 38, 123, 80), ink(0.8, 1.4));
      path(
        const [
          Offset(63, 115),
          Offset(69, 98),
          Offset(88, 88),
          Offset(104, 99),
          Offset(120, 88),
          Offset(141, 98),
          Offset(148, 115),
        ],
        0.9,
        1.4,
      );
      label('?', const Offset(96, 46), 0.8, 18);
    }
    // The dossier scan crosses the actual subject, rather than the whole card.
    final y = 32 + t * 92;
    line(51, y, 157, y, 0.75, 1.3);
    c.drawRect(
      Rect.fromLTWH(52, y, 104, 5),
      Paint()..color = accent.withValues(alpha: 0.05),
    );
    for (var i = 0; i < 4; i++) {
      line(172, 55 + i * 12, 188 + i % 2 * 12, 55 + i * 12, 0.4);
    }
    label('IDENTITY / UNKNOWN', const Offset(35, 147), 0.65);
  }

  void _winner() {
    path(
      const [
        Offset(84, 31),
        Offset(136, 31),
        Offset(130, 73),
        Offset(110, 87),
        Offset(90, 73),
        Offset(84, 31),
      ],
      0.9,
      1.5,
    );
    path(const [
      Offset(84, 40),
      Offset(66, 40),
      Offset(69, 61),
      Offset(91, 70),
    ], 0.6);
    path(const [
      Offset(136, 40),
      Offset(154, 40),
      Offset(151, 61),
      Offset(129, 70),
    ], 0.6);
    line(110, 87, 110, 107, 0.8, 2);
    c.drawRect(const Rect.fromLTRB(91, 107, 129, 114), ink(0.8));
    label('?', const Offset(102, 44), 0.9, 20);
    reticle(const Offset(110, 73), 57);
    label('READ / PREDICT', const Offset(55, 147), 0.65);
  }

  @override
  bool shouldRepaint(covariant _GameLaunchPainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.accent != accent ||
      oldDelegate.loop != loop;
}
