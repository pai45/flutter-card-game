import 'dart:async';

import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';
import 'widgets/stadium_backdrop.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _timer = Timer(const Duration(milliseconds: 1250), widget.onComplete);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StadiumBackdrop(
        dim: .48,
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: Tween(begin: .88, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutBack,
                  ),
                ),
                child: const _Wordmark(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: FinalOverPalette.white,
            border: Border.all(color: FinalOverPalette.cyan, width: 4),
            boxShadow: const [
              BoxShadow(color: FinalOverPalette.cyan, blurRadius: 28),
            ],
          ),
          child: const Icon(
            Icons.sports_cricket,
            color: FinalOverPalette.deepBlue,
            size: 43,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'FINAL',
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 52),
        ),
        Text(
          'OVER',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontSize: 62,
            color: FinalOverPalette.cyan,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SIX BALLS. ONE CHASE.',
          style: TextStyle(letterSpacing: 2, color: FinalOverPalette.muted),
        ),
      ],
    );
  }
}
