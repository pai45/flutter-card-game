import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../screens/shop/shop_screen.dart' show CoinIcon;

class ReferralRewardCelebration extends StatelessWidget {
  const ReferralRewardCelebration({required this.amount, super.key});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            builder: (context, value, child) {
              final entering = (value / 0.45).clamp(0.0, 1.0);
              final leaving = ((1 - value) / 0.28).clamp(0.0, 1.0);
              return Opacity(
                opacity: Curves.easeOut.transform(leaving),
                child: Transform.scale(
                  scale: 0.65 + Curves.easeOutBack.transform(entering) * 0.35,
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Cyber.panel,
                border: Border.all(color: Cyber.gold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Cyber.gold.withValues(alpha: 0.28),
                    blurRadius: 32,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 52),
                  const SizedBox(height: 14),
                  Text(
                    '+$amount COINS',
                    style: Cyber.display(
                      30,
                      color: Cyber.gold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'FRIEND REFERRAL REWARDED',
                    style: Cyber.label(
                      11,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
