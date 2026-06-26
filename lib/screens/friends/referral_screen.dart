import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/referral/referral_cubit.dart';
import '../../config/theme.dart';
import '../../models/oz_coin_ledger.dart';
import '../../models/referral.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/referral_reward_celebration.dart';
import '../shop/shop_screen.dart' show CoinIcon;
import '../leaderboard/widgets/rank_widgets.dart' show cutCornerDecoration;

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReferralCubit(SecureGameStorage())..load(),
      child: const _ReferralView(),
    );
  }
}

class _ReferralView extends StatefulWidget {
  const _ReferralView();

  @override
  State<_ReferralView> createState() => _ReferralViewState();
}

class _ReferralViewState extends State<_ReferralView> {
  Timer? _copyTimer;
  Timer? _rewardTimer;
  bool _showReward = false;

  @override
  void dispose() {
    _copyTimer?.cancel();
    _rewardTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyLink() async {
    final cubit = context.read<ReferralCubit>();
    final link = cubit.state.referralLink;
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.selectionClick();
    cubit.setCopied(true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) cubit.setCopied(false);
    });
    if (!mounted) return;
    _showMessage('Referral link copied');
  }

  Future<void> _shareLink(BuildContext buttonContext) async {
    final cubit = context.read<ReferralCubit>();
    if (cubit.state.sharing || cubit.state.referralLink.isEmpty) return;
    cubit.setSharing(true);
    final link = cubit.state.referralLink;
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Join me on StatOz',
          subject: 'Your StatOz invite',
          text:
              'Join me on StatOz and start building your football legacy! '
              'Use my invite link: $link. '
              'When you join, I earn 500 Oz Coins.',
          sharePositionOrigin: origin,
        ),
      );
      if (mounted) _showMessage('Invite ready to send');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      cubit.setCopied(true);
      if (mounted) _showMessage('Sharing unavailable - link copied');
    } finally {
      if (mounted) cubit.setSharing(false);
    }
  }

  Future<void> _simulateReward() async {
    final entry = await context.read<ReferralCubit>().simulateFriendJoined();
    if (!mounted || entry == null) return;
    context.read<GameBloc>().add(
      CoinsAdded(
        500,
        source: OzCoinTransactionSource.referralReward,
        type: OzCoinTransactionType.earn,
        title: 'FRIEND REFERRAL',
        subtitle: entry.friendName,
      ),
    );
    HapticFeedback.heavyImpact();
    setState(() => _showReward = true);
    _rewardTimer?.cancel();
    _rewardTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _showReward = false);
      context.read<ReferralCubit>().clearLatestReward();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
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
    return GameScaffold(
      title: 'REFER A FRIEND',
      subtitle: '// INVITE & EARN',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: Stack(
        children: [
          BlocBuilder<ReferralCubit, ReferralState>(
            builder: (context, state) {
              if (state.loading) {
                return const Center(
                  child: CircularProgressIndicator(color: Cyber.cyan),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  const _RewardHero(),
                  const SizedBox(height: 16),
                  const _HowItWorks(),
                  const SizedBox(height: 16),
                  _ReferralLinkCard(
                    link: state.referralLink,
                    copied: state.copied,
                    onCopy: _copyLink,
                    onShare: _shareLink,
                    sharing: state.sharing,
                  ),
                  const SizedBox(height: 16),
                  _ProgressCard(state: state),
                  const SizedBox(height: 18),
                  _RecentReferrals(entries: state.referrals),
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    CyberCtaButton(
                      label: state.pendingCount > 0
                          ? 'SIMULATE FRIEND JOINED'
                          : 'DEMO REWARD CLAIMED',
                      onPressed: state.pendingCount > 0
                          ? _simulateReward
                          : null,
                    ),
                  ],
                ],
              );
            },
          ),
          if (_showReward)
            const Positioned.fill(
              child: ReferralRewardCelebration(amount: 500),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _referralSurface({
  Color accent = Cyber.cyan,
  double fillAlpha = 0.62,
  double borderAlpha = 0.16,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        accent.withValues(alpha: 0.07),
        Cyber.panel.withValues(alpha: fillAlpha),
        Cyber.bg.withValues(alpha: 0.42),
      ],
      stops: const [0, 0.48, 1],
    ),
    border: Border.all(color: accent.withValues(alpha: borderAlpha)),
  );
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.2),
    );
  }
}

class _RewardHero extends StatelessWidget {
  const _RewardHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: cutCornerDecoration(
        color: Cyber.panel.withValues(alpha: 0.66),
        borderColor: Cyber.gold.withValues(alpha: 0.24),
        cut: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.gold.withValues(alpha: 0.1),
                  border: Border.all(color: Cyber.gold.withValues(alpha: 0.22)),
                  boxShadow: Cyber.glow(
                    Cyber.gold,
                    alpha: 0.12,
                    blur: 20,
                    spread: -6,
                  ),
                ),
                child: const CoinIcon(size: 42),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EARN 500 OZ COINS',
                        maxLines: 1,
                        style: Cyber.display(
                          22,
                          color: Cyber.gold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Invite a friend into StatOz and get paid when they join.',
                      style: Cyber.body(13, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 17,
                color: Cyber.cyan.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your personal invite link is ready to share.',
                  style: Cyber.label(
                    10,
                    color: Cyber.cyan.withValues(alpha: 0.86),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.ios_share_rounded, 'SHARE LINK'),
      (Icons.person_add_alt_1_rounded, 'FRIEND JOINS'),
      (Icons.toll_rounded, '+500 COINS'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: _referralSurface(borderAlpha: 0.13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle('HOW IT WORKS'),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: _StepItem(
                    index: i + 1,
                    icon: steps[i].$1,
                    label: steps[i].$2,
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 26,
                    height: 1,
                    margin: const EdgeInsets.only(bottom: 21),
                    color: Cyber.cyan.withValues(alpha: 0.18),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.index,
    required this.icon,
    required this.label,
  });

  final int index;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.5),
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: Cyber.cyan, size: 21),
            ),
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.gold.withValues(alpha: 0.14),
                  border: Border.all(color: Cyber.gold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$index',
                  style: Cyber.label(8, color: Cyber.gold, letterSpacing: 0),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8.5, color: Colors.white, letterSpacing: 0.45),
        ),
      ],
    );
  }
}

class _ReferralLinkCard extends StatelessWidget {
  const _ReferralLinkCard({
    required this.link,
    required this.copied,
    required this.onCopy,
    required this.onShare,
    required this.sharing,
  });

  final String link;
  final bool copied;
  final VoidCallback onCopy;
  final Future<void> Function(BuildContext context) onShare;
  final bool sharing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
      decoration: _referralSurface(fillAlpha: 0.68, borderAlpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelTitle('YOUR REFERRAL LINK'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.72),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: Cyber.cyan.withValues(alpha: 0.74),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 3),
                Tooltip(
                  message: copied ? 'Copied' : 'Copy referral link',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onCopy,
                    icon: Icon(
                      copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      color: copied ? Cyber.success : Cyber.cyan,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Cyber.cyan.withValues(alpha: 0.06),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  copied ? Icons.check_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: copied ? Cyber.success : Cyber.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copied
                        ? 'Link copied. Send it anywhere your squad chats.'
                        : 'Share or copy this invite to bring a friend in.',
                    style: Cyber.body(11, color: Cyber.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (buttonContext) => HudCtaButton(
              label: sharing ? 'OPENING SHARE...' : 'SHARE REFERRAL LINK',
              icon: Icons.ios_share_rounded,
              height: 56,
              accent: Cyber.cyan,
              onTap: sharing ? () {} : () => onShare(buttonContext),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final ReferralState state;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('INVITED', state.invitedCount, Cyber.cyan),
      ('PENDING', state.pendingCount, Cyber.amber),
      ('REWARDED', state.rewardedCount, Cyber.success),
      ('COINS', state.coinsEarned, Cyber.gold),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: _referralSurface(fillAlpha: 0.58, borderAlpha: 0.12),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  children: [
                    Text(
                      '${values[i].$2}',
                      style: Cyber.display(19, color: values[i].$3),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      values[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8,
                        color: Cyber.muted,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < values.length - 1)
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.07),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentReferrals extends StatelessWidget {
  const _RecentReferrals({required this.entries});

  final List<ReferralEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: _referralSurface(fillAlpha: 0.54, borderAlpha: 0.11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT REFERRALS',
                  style: Cyber.display(13, letterSpacing: 1),
                ),
              ),
              Text(
                '${entries.length} TOTAL',
                style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.38),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Text(
                'No referrals yet. Share your link to invite your first friend.',
                textAlign: TextAlign.center,
                style: Cyber.body(12, color: Cyber.muted),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              _ReferralRow(entry: entries[i]),
              if (i < entries.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow({required this.entry});

  final ReferralEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (entry.status) {
      ReferralStatus.invited => ('INVITED', Cyber.cyan),
      ReferralStatus.pending => ('PENDING', Cyber.amber),
      ReferralStatus.rewarded => ('REWARDED +${entry.reward}', Cyber.success),
    };
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Text(
            entry.friendName.substring(0, 1).toUpperCase(),
            style: Cyber.display(13, color: color),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.friendName, style: Cyber.body(13)),
              const SizedBox(height: 4),
              Text(
                _dateLabel(entry.createdAt),
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Text(
            label,
            style: Cyber.label(8, color: color, letterSpacing: 0.55),
          ),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = const [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ][local.month - 1];
  return '$day $month';
}
