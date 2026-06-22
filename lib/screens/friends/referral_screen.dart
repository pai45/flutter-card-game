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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  const _RewardHero(),
                  const SizedBox(height: 14),
                  const _HowItWorks(),
                  const SizedBox(height: 14),
                  _ReferralLinkCard(
                    link: state.referralLink,
                    copied: state.copied,
                    onCopy: _copyLink,
                    onShare: _shareLink,
                    sharing: state.sharing,
                  ),
                  const SizedBox(height: 14),
                  _ProgressCard(state: state),
                  const SizedBox(height: 14),
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

class _RewardHero extends StatelessWidget {
  const _RewardHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: cutCornerDecoration(
        color: Cyber.panel.withValues(alpha: 0.88),
        borderColor: Cyber.gold.withValues(alpha: 0.72),
        cut: 18,
      ),
      child: Column(
        children: [
          const CoinIcon(size: 58),
          const SizedBox(height: 10),
          Text(
            'EARN 500 OZ COINS',
            textAlign: TextAlign.center,
            style: Cyber.display(25, color: Cyber.gold, letterSpacing: 1),
          ),
          const SizedBox(height: 7),
          Text(
            'INVITE. PLAY. EARN.',
            style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your personal link with a friend. When they join, your reward is ready.',
            textAlign: TextAlign.center,
            style: Cyber.body(13, color: Cyber.muted),
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
      (Icons.ios_share_rounded, 'SHARE YOUR LINK'),
      (Icons.person_add_alt_1_rounded, 'FRIEND JOINS'),
      (Icons.toll_rounded, 'YOU GET 500'),
    ];
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: Cyber.panel.withValues(alpha: 0.62),
                border: Border.all(color: Cyber.line),
              ),
              child: Column(
                children: [
                  Icon(steps[i].$1, color: Cyber.cyan, size: 23),
                  const Spacer(),
                  Text('${i + 1}', style: Cyber.label(9, color: Cyber.gold)),
                  const SizedBox(height: 3),
                  Text(
                    steps[i].$2,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Cyber.label(
                      8,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i < steps.length - 1) const SizedBox(width: 7),
        ],
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.72),
        border: Border.all(color: Cyber.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YOUR REFERRAL LINK',
            style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.1),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.72),
              border: Border.all(color: Cyber.cyan.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(12, color: Colors.white),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy referral link',
                  visualDensity: VisualDensity.compact,
                  onPressed: onCopy,
                  icon: Icon(
                    copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: copied ? Cyber.success : Cyber.cyan,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.65),
        border: Border.all(color: Cyber.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${values[i].$2}',
                    style: Cyber.display(18, color: values[i].$3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    values[i].$1,
                    style: Cyber.label(
                      8,
                      color: Cyber.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            if (i < values.length - 1)
              Container(width: 1, height: 28, color: Cyber.line),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('RECENT REFERRALS', style: Cyber.display(13, letterSpacing: 1)),
        const SizedBox(height: 9),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Cyber.panel.withValues(alpha: 0.55),
              border: Border.all(color: Cyber.line),
            ),
            child: Text(
              'No referrals yet. Share your link to invite your first friend.',
              textAlign: TextAlign.center,
              style: Cyber.body(12, color: Cyber.muted),
            ),
          )
        else
          for (final entry in entries) ...[
            _ReferralRow(entry: entry),
            const SizedBox(height: 8),
          ],
      ],
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.58),
        border: Border.all(color: Cyber.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
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
                const SizedBox(height: 3),
                Text(
                  _dateLabel(entry.createdAt),
                  style: Cyber.label(9, color: Cyber.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              label,
              style: Cyber.label(8, color: color, letterSpacing: 0.6),
            ),
          ),
        ],
      ),
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
