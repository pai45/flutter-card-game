import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';

class StadiumBackdrop extends StatelessWidget {
  const StadiumBackdrop({
    super.key,
    this.child,
    this.dim = .22,
    this.assetPackage,
  });

  final Widget? child;
  final double dim;
  final String? assetPackage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [FinalOverPalette.deepBlue, FinalOverPalette.night],
            ),
          ),
        ),
        Image.asset(
          'assets/backgrounds/final_over_stadium.png',
          package: assetPackage,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: dim)),
        child ?? const SizedBox.shrink(),
      ],
    );
  }
}
