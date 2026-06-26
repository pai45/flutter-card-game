import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/friends/friends_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../config/theme.dart';
import '../../models/avatar_option.dart';
import '../../models/player_stats.dart';
import '../../models/rival_dossier.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/avatar_frame_ring.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../../widgets/team_logo.dart' show OctagonClipper;
import 'achievements_screen.dart';
import 'widgets/achievement_grid.dart';
import 'widgets/level_progress.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_stat_band.dart';

/// A leaderboard rival's "scouting dossier" — a deterministic, fabricated
/// profile (see [RivalDossier]) framed as a head-to-head against the player.
/// View-only beyond the two actions: CHALLENGE (play a themed match) and
/// ADD FRIEND (bookmark them locally).
class RivalProfileScreen extends StatelessWidget {
  const RivalProfileScreen({
    required this.name,
    required this.rank,
    required this.xp,
    required this.pro,
    required this.userRank,
    this.onChallenge,
    super.key,
  });

  final String name;
  final int rank;
  final int xp;
  final bool pro;
  final int userRank;

  /// Launches a card match vs a CPU themed as this rival. Null hides CHALLENGE.
  final void Function(String opponentName, int opponentLevel)? onChallenge;

  void _challenge(BuildContext context, RivalDossier dossier) {
    final challenge = onChallenge;
    if (challenge == null) return;
    if (!context.read<GameBloc>().state.deckReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Build a match deck to challenge a rival.')),
      );
      return;
    }
    playSound(SoundEffect.uiTap);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    challenge(name, dossier.level);
  }

  Future<void> _toggleFriend(BuildContext context) async {
    final cubit = context.read<FriendsCubit>();
    final nowFriend = await cubit.toggleFriend(name);
    if (!context.mounted) return;
    playSound(SoundEffect.uiTap);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            nowFriend ? '$name added to friends' : '$name removed from friends',
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final dossier = RivalDossier.fromSeed(name: name, xp: xp, pro: pro);
    final game = context.watch<GameBloc>().state;
    final youRecord = MatchRecord.fromHistory(game.matchHistory);

    return GameScaffold(
      title: 'RIVAL DOSSIER',
      subtitle: '// ID ${rank.toString().padLeft(4, '0')}',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _RivalHero(name: name, rank: rank, pro: pro, dossier: dossier),
          const SizedBox(height: 14),
          _ActionRow(
            isChallengeable: onChallenge != null,
            onChallenge: () => _challenge(context, dossier),
            onToggleFriend: () => _toggleFriend(context),
            name: name,
          ),
          const SizedBox(height: 16),
          _VsYouCard(
            rivalRank: rank,
            youRank: userRank,
            rivalLevel: dossier.level,
            youLevel: game.progression.playerLevel,
            rivalWinRate: dossier.winRate,
            youWinRate: youRecord.winRate,
          ),
          const SizedBox(height: 14),
          AchievementGrid(
            stats: dossier.achievementStats,
            onViewAll: () =>
                showAchievementsScreen(context, dossier.achievementStats),
          ),
          const SizedBox(height: 14),
          _RivalStatBand(
            title: 'GAMES',
            accent: Cyber.amber,
            iconAsset: 'assets/icons/game.svg',
            streak: dossier.bestStreak,
            stats: [
              ProfileStat.number('MATCHES', dossier.matchesPlayed),
              ProfileStat.number('WIN %', dossier.winRate, suffix: '%'),
              ProfileStat.number('DRAWS', dossier.draws),
            ],
          ),
          const SizedBox(height: 12),
          _RivalStatBand(
            title: 'PREDICTS',
            accent: Cyber.cyan,
            iconAsset: 'assets/icons/match.svg',
            stats: [
              ProfileStat.number('PLAYED', dossier.predictionsMade),
              ProfileStat.number(
                'ACCURACY',
                dossier.predictionAccuracy,
                suffix: '%',
              ),
              ProfileStat.number('CORRECT', dossier.correctPredictions),
            ],
          ),
          const SizedBox(height: 12),
          _RivalStatBand(
            title: 'PICKS',
            accent: Cyber.lime,
            iconAsset: 'assets/icons/pick.svg',
            stats: [
              ProfileStat.number('PICKS', dossier.picksPlaced),
              ProfileStat.number('WIN RATE', dossier.pickWinRate, suffix: '%'),
              ProfileStat.number('ACTIVE', dossier.activePicks),
            ],
          ),
        ],
      ),
    );
  }
}

/// The rival's hero card: octagon avatar + equipped border (the focal glow),
/// name, greeble ID, level chip and XP meter — mirrors the self-profile hero.
class _RivalHero extends StatelessWidget {
  const _RivalHero({
    required this.name,
    required this.rank,
    required this.pro,
    required this.dossier,
  });

  final String name;
  final int rank;
  final bool pro;
  final RivalDossier dossier;

  @override
  Widget build(BuildContext context) {
    final avatar = avatarForName(name);
    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: AvatarFrameRing(
                  frame: dossier.frame,
                  glow: true,
                  shape: AvatarFrameShape.octagon,
                  child: ClipPath(
                    clipper: const OctagonClipper(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Cyber.panel),
                        Image.asset(
                          avatar.assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person,
                            color: Cyber.muted,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(22, letterSpacing: 0.6),
                          ),
                        ),
                        if (pro) ...[
                          const SizedBox(width: 8),
                          _ProChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OPERATIVE // RANK ${rank.toString().padLeft(2, '0')}',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              LevelChip(level: dossier.level),
            ],
          ),
          const SizedBox(height: 16),
          XpMeter(progression: dossier.progression),
        ],
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Cyber.violet.withValues(alpha: 0.16),
        border: Border.all(color: Cyber.violet.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'PRO',
        style: Cyber.label(9, color: Cyber.violet, letterSpacing: 1.2),
      ),
    );
  }
}

/// CHALLENGE (focal, glowing) + ADD FRIEND (secondary, toggles to FRIEND ✓).
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isChallengeable,
    required this.onChallenge,
    required this.onToggleFriend,
    required this.name,
  });

  final bool isChallengeable;
  final VoidCallback onChallenge;
  final VoidCallback onToggleFriend;
  final String name;

  @override
  Widget build(BuildContext context) {
    // Same chamfered HUD pager buttons as the quiz dock: ADD FRIEND is the calm
    // dark plate (like PREVIOUS), CHALLENGE the glowing focal plate (like NEXT).
    final friendButton = BlocBuilder<FriendsCubit, FriendsState>(
      builder: (context, state) {
        final isFriend = state.contains(name);
        return HudPagerButton(
          label: isFriend ? 'FRIEND ✓' : 'ADD FRIEND',
          leadingIcon: isFriend ? Icons.check : Icons.person_add_alt_1,
          focal: false,
          enabled: true,
          onTap: onToggleFriend,
        );
      },
    );

    if (!isChallengeable) return friendButton;

    return Row(
      children: [
        Expanded(
          child: HudPagerButton(
            label: 'CHALLENGE',
            trailingIcon: Icons.bolt,
            focal: true,
            enabled: true,
            onTap: onChallenge,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: friendButton),
      ],
    );
  }
}

/// Head-to-head card: RANK / LEVEL / WIN% as `rival ◀ Δ ▶ you`, the delta tinted
/// by whether you lead. Calm by design — no glow (the hero owns the focal glow).
class _VsYouCard extends StatelessWidget {
  const _VsYouCard({
    required this.rivalRank,
    required this.youRank,
    required this.rivalLevel,
    required this.youLevel,
    required this.rivalWinRate,
    required this.youWinRate,
  });

  final int rivalRank;
  final int youRank;
  final int rivalLevel;
  final int youLevel;
  final int rivalWinRate;
  final int youWinRate;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Cyber.gold, size: 18),
              const SizedBox(width: 8),
              Text('VS YOU', style: Cyber.display(15, letterSpacing: 1.2)),
              const Spacer(),
              Text(
                'HEAD-TO-HEAD',
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _VsRow(
            label: 'RANK',
            rival: rivalRank,
            you: youRank,
            lowerIsBetter: true,
          ),
          const HudLine(),
          _VsRow(label: 'LEVEL', rival: rivalLevel, you: youLevel),
          const HudLine(),
          _VsRow(
            label: 'WIN %',
            rival: rivalWinRate,
            you: youWinRate,
            suffix: '%',
          ),
        ],
      ),
    );
  }
}

class _VsRow extends StatelessWidget {
  const _VsRow({
    required this.label,
    required this.rival,
    required this.you,
    this.lowerIsBetter = false,
    this.suffix = '',
  });

  final String label;
  final int rival;
  final int you;
  final bool lowerIsBetter;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final youLead = lowerIsBetter ? you < rival : you > rival;
    final tie = you == rival;
    final deltaColor = tie
        ? Cyber.muted
        : (youLead ? Cyber.success : Cyber.amber);
    final magnitude = (you - rival).abs();
    final deltaText = tie ? '—' : '${youLead ? '▲' : '▼'} $magnitude';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              '$rival$suffix',
              style: Cyber.display(
                18,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
                ),
                const SizedBox(height: 2),
                Text(
                  deltaText,
                  style: Cyber.label(11, color: deltaColor, letterSpacing: 1),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '$you$suffix',
              textAlign: TextAlign.right,
              style: Cyber.display(18, color: Cyber.muted).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [ProfileStatBand] fed from dossier numbers (no history link for a rival).
class _RivalStatBand extends StatelessWidget {
  const _RivalStatBand({
    required this.title,
    required this.accent,
    required this.iconAsset,
    required this.stats,
    this.streak = 0,
  });

  final String title;
  final Color accent;
  final String iconAsset;
  final List<ProfileStat> stats;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return ProfileStatBand(
      title: title,
      accent: accent,
      streak: streak,
      icon: SvgPicture.asset(
        iconAsset,
        colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
        width: 20,
        height: 20,
      ),
      stats: stats,
    );
  }
}
