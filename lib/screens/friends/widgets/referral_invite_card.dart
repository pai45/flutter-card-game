import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../leaderboard/widgets/rank_widgets.dart' show cutCornerDecoration;

class ReferralInviteCard extends StatelessWidget {
  const ReferralInviteCard({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Invite friends and earn 500 Oz Coins',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: cutCornerDecoration(
            color: Cyber.panel.withValues(alpha: 0.82),
            borderColor: Cyber.gold.withValues(alpha: 0.72),
            cut: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cyber.gold.withValues(alpha: 0.13),
                      border: Border.all(
                        color: Cyber.gold.withValues(alpha: 0.48),
                      ),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: Cyber.gold,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'INVITE FRIENDS',
                          maxLines: 1,
                          style: Cyber.display(
                            14,
                            color: Colors.white,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'EARN 500 OZ COINS',
                          maxLines: 1,
                          style: Cyber.display(
                            15,
                            color: Cyber.gold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Share your link. Earn when your friend joins.',
                style: Cyber.body(12, color: Cyber.muted),
              ),
              const SizedBox(height: 13),
              Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.cyan.withValues(alpha: 0.12),
                  border: Border.all(color: Cyber.cyan.withValues(alpha: 0.55)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'INVITE & EARN',
                      style: Cyber.label(
                        10,
                        color: Cyber.cyan,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Cyber.cyan,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
