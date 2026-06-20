import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/friends/friends_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../config/theme.dart';
import '../../data/rival_roster.dart';
import '../../models/avatar_border_option.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';
import '../leaderboard/leaderboard_screen.dart' show showRivalDossier;
import '../leaderboard/widgets/rank_widgets.dart';

/// FRIENDS ARENA — search the rival network by tag or username, then add and
/// challenge friends from a single friends-scoped leaderboard. Reaches the same
/// fabricated roster ([kRivalRoster]) the global leaderboard uses, the local
/// [FriendsCubit] for membership, and the rival dossier for the full profile.
class FriendsArenaScreen extends StatefulWidget {
  const FriendsArenaScreen({required this.onChallenge, super.key});

  /// Launches a card match against a CPU themed as the chosen friend.
  final void Function(String opponentName, int opponentLevel) onChallenge;

  @override
  State<FriendsArenaScreen> createState() => _FriendsArenaScreenState();
}

class _FriendsArenaScreenState extends State<FriendsArenaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SecureGameStorage _storage = SecureGameStorage();
  String _query = '';
  String? _myTag;

  @override
  void initState() {
    super.initState();
    _loadMyTag();
  }

  Future<void> _loadMyTag() async {
    final tag = await _storage.loadPlayerTag();
    if (!mounted) return;
    setState(() => _myTag = tag);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesMyTag(String query) {
    final tag = _myTag;
    if (tag == null) return false;
    String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return norm(query) == norm(tag);
  }

  void _openDossier(String name) {
    playSound(SoundEffect.uiTap);
    showRivalDossier(context, name, onChallenge: widget.onChallenge);
  }

  Future<void> _toggleFriend(String name) async {
    final cubit = context.read<FriendsCubit>();
    final nowFriend = await cubit.toggleFriend(name);
    if (!mounted) return;
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

  void _challenge(RivalSeed seed) {
    if (!context.read<GameBloc>().state.deckReady) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Build a match deck to challenge a friend.'),
          ),
        );
      return;
    }
    playSound(SoundEffect.uiTap);
    HapticFeedback.mediumImpact();
    widget.onChallenge(seed.name, rivalLevelFor(seed));
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'FRIENDS ARENA',
      subtitle: '// SCOUT NETWORK',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: _SearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<FriendsCubit, FriendsState>(
              builder: (context, friendsState) {
                final friends = friendsState.friends;
                final entries =
                    kRivalRoster
                        .where((s) => s.isUser || friends.contains(s.name))
                        .toList()
                      ..sort((a, b) => b.base.compareTo(a.base));
                final hasFriends = friends.isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (_query.trim().isNotEmpty) ...[
                      _buildSearchResult(friends),
                      const SizedBox(height: 18),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.leaderboard_rounded,
                          color: Cyber.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'FRIENDS LEADERBOARD',
                          style: Cyber.display(15, letterSpacing: 1),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '// ${friends.length}',
                          style: Cyber.label(
                            10,
                            color: Cyber.muted,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < entries.length; i++) ...[
                      _FriendLeaderRow(
                        seed: entries[i],
                        rank: i + 1,
                        onChallenge: () => _challenge(entries[i]),
                        onTap: entries[i].isUser
                            ? null
                            : () => _openDossier(entries[i].name),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!hasFriends)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Search a tag or username above to add your first rival.',
                          style: Cyber.body(13, color: Cyber.muted),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResult(List<String> friends) {
    final query = _query.trim();
    if (_matchesMyTag(query)) {
      return const _SearchNotice(
        icon: Icons.person_pin_rounded,
        message: "That's your own tag — share it so friends can add you.",
        accent: Cyber.cyan,
      );
    }
    final seed = resolveRival(query);
    if (seed == null) {
      return _SearchNotice(
        icon: Icons.search_off_rounded,
        message: 'No player found for "$query".',
        accent: Cyber.muted,
      );
    }
    final isFriend = friends.contains(seed.name);
    return _SearchResultCard(
      seed: seed,
      isFriend: isFriend,
      onView: () => _openDossier(seed.name),
      onToggleFriend: () => _toggleFriend(seed.name),
    );
  }
}

/// Cyber-styled search input (tag or username).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: cutCornerDecoration(
        color: Cyber.bg.withValues(alpha: 0.55),
        borderColor: Cyber.line,
        cut: 11,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Cyber.cyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textCapitalization: TextCapitalization.characters,
              cursorColor: Cyber.cyan,
              style: Cyber.body(14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Player tag or username',
                hintStyle: Cyber.body(14, color: Cyber.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, color: Cyber.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small notice card for the "not found" / "that's you" search states.
class _SearchNotice extends StatelessWidget {
  const _SearchNotice({
    required this.icon,
    required this.message,
    required this.accent,
  });

  final IconData icon;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: cutCornerDecoration(
        color: Cyber.panel.withValues(alpha: 0.4),
        borderColor: accent.withValues(alpha: 0.35),
        cut: 12,
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: Cyber.body(13, color: Cyber.muted))),
        ],
      ),
    );
  }
}

/// The resolved-player card: avatar, identity, level + tag, and the VIEW /
/// ADD-FRIEND actions. The ADD-FRIEND CTA is the screen's one focal glow.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.seed,
    required this.isFriend,
    required this.onView,
    required this.onToggleFriend,
  });

  final RivalSeed seed;
  final bool isFriend;
  final VoidCallback onView;
  final VoidCallback onToggleFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cutCornerDecoration(
        color: Cyber.panel.withValues(alpha: 0.5),
        borderColor: Cyber.cyan.withValues(alpha: 0.45),
        cut: 14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              RivalAvatar(name: seed.name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            seed.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Cyber.display(18, letterSpacing: 0.5),
                          ),
                        ),
                        if (seed.isPro) ...[
                          const SizedBox(width: 8),
                          const _ProTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'LVL ${rivalLevelFor(seed)}  //  ${playerTagForName(seed.name)}',
                      style: Cyber.label(
                        10,
                        color: Cyber.muted,
                        letterSpacing: 1.2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: CyberCtaButton(label: 'View', onPressed: onView)),
              const SizedBox(width: 10),
              Expanded(
                child: CyberCtaButton(
                  label: isFriend ? 'Friend ✓' : 'Add Friend',
                  primary: !isFriend,
                  onPressed: onToggleFriend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of the friends leaderboard: rank · avatar · identity · score, plus an
/// inline CHALLENGE for friends (the user's own row shows no challenge and gets
/// the one row glow).
class _FriendLeaderRow extends StatelessWidget {
  const _FriendLeaderRow({
    required this.seed,
    required this.rank,
    required this.onChallenge,
    required this.onTap,
  });

  final RivalSeed seed;
  final int rank;
  final VoidCallback onChallenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUser = seed.isUser;
    final rankColor = rank <= 3 ? Cyber.gold : Cyber.muted;

    List<Color>? userBorder;
    if (isUser) {
      final equippedId = context.select<GameBloc, String>(
        (b) => b.state.equippedAvatarBorderId,
      );
      final equipped = avatarBorderOptionById(equippedId);
      if (equipped != null) userBorder = borderRingColors(equipped.primary);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: cutCornerDecoration(
          color: isUser
              ? Cyber.cyan.withValues(alpha: 0.1)
              : Cyber.panel.withValues(alpha: 0.34),
          borderColor: isUser
              ? Cyber.cyan.withValues(alpha: 0.5)
              : Colors.transparent,
          cut: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#$rank',
                style: Cyber.label(
                  14,
                  color: rankColor,
                  letterSpacing: 0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            RivalAvatar(
              name: seed.name,
              size: 46,
              highlight: isUser,
              borderColors: userBorder,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          seed.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(15, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isUser)
                        const _MiniTag(label: 'YOU', color: Cyber.cyan)
                      else if (seed.isPro)
                        const _MiniTag(label: 'PRO', color: Cyber.violet),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatInt(seed.base)} XP',
                    style: Cyber.label(
                      10,
                      color: Cyber.muted,
                      letterSpacing: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (!isUser) _ChallengeChip(onTap: onChallenge),
          ],
        ),
      ),
    );
  }
}

/// Compact calm "VS" challenge button used on each friend row (kept non-glowing
/// so a list of them doesn't flood the screen with glow).
class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: cutCornerDecoration(
          color: Cyber.cyan.withValues(alpha: 0.12),
          borderColor: Cyber.cyan.withValues(alpha: 0.55),
          cut: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_kabaddi_rounded, color: Cyber.cyan, size: 15),
            const SizedBox(width: 6),
            Text(
              'VS',
              style: Cyber.label(12, color: Cyber.cyan, letterSpacing: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Cyber.label(9, color: color, letterSpacing: 1.2),
      ),
    );
  }
}

class _ProTag extends StatelessWidget {
  const _ProTag();

  @override
  Widget build(BuildContext context) => const _MiniTag(label: 'PRO', color: Cyber.violet);
}

String _formatInt(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
