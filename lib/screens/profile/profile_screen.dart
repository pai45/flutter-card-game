import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/friends/friends_cubit.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/sport_modules.dart';
import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../data/rival_roster.dart';
import '../../models/avatar_frame_option.dart';
import '../../models/avatar_option.dart';
import '../../models/picks.dart';
import '../../models/player_stats.dart';
import '../../models/sport_match.dart';
import '../../models/streak.dart';
import '../../models/profile_banner_option.dart';
import '../../models/progression.dart';
import '../../services/achievement_progress.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/avatar_frame_ring.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/profile_banner_visual.dart';
import '../../widgets/team_logo.dart';
import '../deck/all_cards_screen.dart';
import '../friends/friends_arena_screen.dart';
import '../how_to_play/how_to_play_hub_screen.dart';
import '../leaderboard/widgets/rank_widgets.dart';
import '../match_history/match_history_pages.dart';
import '../predictions/prediction_match_history_screen.dart';
import '../predictions/prediction_picks_history_screen.dart';
import 'achievements_screen.dart';
import 'oz_coin_history_screen.dart';
import 'xp_history_screen.dart';
import 'widgets/achievement_grid.dart';
import 'widgets/level_progress.dart';
import 'widgets/oz_coin_tracker_card.dart';
import 'widgets/profile_card.dart';
import 'widgets/profile_stat_band.dart';

/// PROFILE tab — a game-style "player dossier": a player-card hero (avatar,
/// banner, level + XP), a derived achievements showcase, and honest career /
/// prediction / picks telemetry bands, followed by the card-game utilities and
/// settings. All chrome is gradient-free — depth comes from flat fills, borders
/// and hard drop shadows (the FixtureCard language); the only focal glow is the
/// hero's level chip + XP meter, per the design system's glow rule.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.onNavigate,
    required this.onLogout,
    required this.onChallenge,
    super.key,
  });

  final ValueChanged<AppSection> onNavigate;
  final Future<void> Function() onLogout;

  /// Launches a card match against a CPU themed as the given rival (name,
  /// level). Threaded into the Friends Arena so a friend can be challenged.
  final void Function(String opponentName, int opponentLevel) onChallenge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            top: false,
            left: false,
            right: false,
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, game) {
                return BlocBuilder<PredictionCubit, PredictionState>(
                  builder: (context, pred) {
                    final picks = context.watch<PicksCubit>().state;
                    final record = MatchRecord.fromHistory(game.matchHistory);

                    // Prediction-quiz accuracy: correct answers / answers given.
                    final answersGiven = pred.predictions.values.fold<int>(
                      0,
                      (sum, p) => sum + p.answers.length,
                    );
                    final predAccuracy = answersGiven == 0
                        ? 0
                        : (pred.correctPredictions / answersGiven * 100)
                              .round();

                    // Picks win rate over settled (won/lost) positions only.
                    final settledPicks = picks.positions.values
                        .where(
                          (p) =>
                              p.status == PickPositionStatus.won ||
                              p.status == PickPositionStatus.lost,
                        )
                        .toList();
                    final wonPicks = settledPicks
                        .where((p) => p.status == PickPositionStatus.won)
                        .length;
                    final pickAccuracy = settledPicks.isEmpty
                        ? 0
                        : (wonPicks / settledPicks.length * 100).round();

                    // Single source of truth, shared with the app-root
                    // achievement-unlock watcher (services/achievement_progress).
                    final stats = currentAchievementStats(context);

                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _ProfileHeroCard(
                          progression: game.progression,
                          onChallenge: onChallenge,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _FollowingBand(),
                              OzCoinTrackerCard(
                                balance: game.coins,
                                ledger: game.coinLedger,
                                onViewHistory: () => showOzCoinHistory(context),
                              ),
                              const SizedBox(height: 14),
                              AchievementGrid(
                                stats: stats,
                                onViewAll: () =>
                                    showAchievementsScreen(context, stats),
                              ),
                              const SizedBox(height: 14),
                              ProfileStatBand(
                                title: 'PREDICTS',
                                streak: game.streak.current(
                                  StreakCategory.predict,
                                ),
                                accent: Cyber.cyan,
                                icon: SvgPicture.asset(
                                  'assets/icons/match.svg',
                                  colorFilter: const ColorFilter.mode(
                                    Cyber.cyan,
                                    BlendMode.srcIn,
                                  ),
                                  width: 20,
                                  height: 20,
                                ),
                                stats: [
                                  ProfileStat.number(
                                    'PLAYED',
                                    pred.predictionsMade,
                                  ),
                                  ProfileStat.number(
                                    'ACCURACY',
                                    predAccuracy,
                                    suffix: '%',
                                  ),
                                  ProfileStat.number(
                                    'CORRECT',
                                    pred.correctPredictions,
                                  ),
                                ],
                                onViewHistory: () =>
                                    showPredictionMatchHistory(context),
                              ),
                              const SizedBox(height: 12),
                              ProfileStatBand(
                                title: 'PICKS',
                                streak: game.streak.current(
                                  StreakCategory.pick,
                                ),
                                accent: Cyber.lime,
                                icon: SvgPicture.asset(
                                  'assets/icons/pick.svg',
                                  colorFilter: const ColorFilter.mode(
                                    Cyber.lime,
                                    BlendMode.srcIn,
                                  ),
                                  width: 20,
                                  height: 20,
                                ),
                                stats: [
                                  ProfileStat.number(
                                    'PICKS',
                                    picks.positions.length,
                                  ),
                                  ProfileStat.number(
                                    'WIN RATE',
                                    pickAccuracy,
                                    suffix: '%',
                                  ),
                                  ProfileStat.number(
                                    'ACTIVE',
                                    picks.activePositionCount,
                                  ),
                                ],
                                onViewHistory: () =>
                                    showPredictionPicksHistory(context),
                              ),
                              const SizedBox(height: 12),
                              ProfileStatBand(
                                title: 'GAMES',
                                streak: game.streak.current(
                                  StreakCategory.games,
                                ),
                                accent: Cyber.amber,
                                icon: SvgPicture.asset(
                                  'assets/icons/game.svg',
                                  colorFilter: const ColorFilter.mode(
                                    Cyber.amber,
                                    BlendMode.srcIn,
                                  ),
                                  width: 20,
                                  height: 20,
                                ),
                                stats: [
                                  ProfileStat.number('MATCHES', record.played),
                                  ProfileStat.number(
                                    'WIN %',
                                    record.winRate,
                                    suffix: '%',
                                  ),
                                  ProfileStat.number('DRAWS', record.draws),
                                ],
                                onViewHistory: () => showMatchHistoryArchive(
                                  context,
                                  game.matchHistory,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const _TimeZoneSetupCard(),
                              const SizedBox(height: 14),
                              _NavRow(
                                icon: Icons.style,
                                label: 'All Cards',
                                onTap: () => _push(
                                  context,
                                  (nav) => AllCardsScreen(onNavigate: nav),
                                ),
                              ),
                              _NavRow(
                                icon: Icons.menu_book,
                                label: 'How To Play',
                                onTap: () => _push(
                                  context,
                                  (nav) => HowToPlayHubScreen(onNavigate: nav),
                                ),
                              ),
                              _NavRow(
                                icon: Icons.bug_report,
                                label: 'Report a Bug / Mismatch',
                                onTap: () => _showBugReportDialog(context),
                              ),
                              _NavRow(
                                icon: Icons.settings,
                                label: 'Settings',
                                onTap: () => _showSettings(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: LandingBottomNavigation(
        selectedIndex: 3,
        onNavigate: onNavigate,
        includeShop: false,
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.74),
      builder: (sheetContext) {
        return _ProfileSettingsSheet(
          onLogout: () async {
            final shouldLogout = await _confirmLogout(sheetContext);
            if (!sheetContext.mounted || !shouldLogout) return;
            Navigator.of(sheetContext).pop();
            await onLogout();
          },
        );
      },
    );
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const _LogoutConfirmDialog(),
    );
    return result ?? false;
  }

  Future<void> _showBugReportDialog(BuildContext context) async {
    final report = await showDialog<_BugReport>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => const _BugReportDialog(),
    );

    if (!context.mounted || report == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Report submitted: ${report.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _push(
    BuildContext context,
    Widget Function(ValueChanged<AppSection>) builder,
  ) {
    final navigator = Navigator.of(context);
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => builder((_) => navigator.pop())),
    );
  }
}

// ─── Player-card hero ─────────────────────────────────────────────────────────

/// The dossier hero: a chamfered elevated card with a banner strip, an
/// overlapping avatar, the player name + a greeble telemetry line, a glowing
/// level chip (the focal element) and the XP meter.
class _TimeZoneOption {
  const _TimeZoneOption(this.id, this.label, this.utcOffset);

  final String id;
  final String label;
  final String utcOffset;
}

const _deviceTimeZoneId = 'device';

const _timeZoneOptions = <_TimeZoneOption>[
  _TimeZoneOption('Pacific/Pago_Pago', 'Pago Pago', 'UTC−11:00'),
  _TimeZoneOption('Pacific/Honolulu', 'Honolulu', 'UTC−10:00'),
  _TimeZoneOption('America/Anchorage', 'Anchorage', 'UTC−09:00'),
  _TimeZoneOption('America/Los_Angeles', 'Los Angeles', 'UTC−08:00'),
  _TimeZoneOption('America/Denver', 'Denver', 'UTC−07:00'),
  _TimeZoneOption('America/Chicago', 'Chicago', 'UTC−06:00'),
  _TimeZoneOption('America/New_York', 'New York', 'UTC−05:00'),
  _TimeZoneOption('America/Halifax', 'Halifax', 'UTC−04:00'),
  _TimeZoneOption('America/St_Johns', 'St. John’s', 'UTC−03:30'),
  _TimeZoneOption('America/Sao_Paulo', 'São Paulo', 'UTC−03:00'),
  _TimeZoneOption('Atlantic/South_Georgia', 'South Georgia', 'UTC−02:00'),
  _TimeZoneOption('Atlantic/Azores', 'Azores', 'UTC−01:00'),
  _TimeZoneOption('Etc/UTC', 'UTC / GMT', 'UTC+00:00'),
  _TimeZoneOption('Europe/London', 'London', 'UTC+00:00'),
  _TimeZoneOption('Europe/Paris', 'Paris', 'UTC+01:00'),
  _TimeZoneOption('Europe/Athens', 'Athens', 'UTC+02:00'),
  _TimeZoneOption('Africa/Nairobi', 'Nairobi', 'UTC+03:00'),
  _TimeZoneOption('Asia/Tehran', 'Tehran', 'UTC+03:30'),
  _TimeZoneOption('Asia/Dubai', 'Dubai', 'UTC+04:00'),
  _TimeZoneOption('Asia/Kabul', 'Kabul', 'UTC+04:30'),
  _TimeZoneOption('Asia/Karachi', 'Karachi', 'UTC+05:00'),
  _TimeZoneOption('Asia/Kolkata', 'Kolkata', 'UTC+05:30'),
  _TimeZoneOption('Asia/Kathmandu', 'Kathmandu', 'UTC+05:45'),
  _TimeZoneOption('Asia/Dhaka', 'Dhaka', 'UTC+06:00'),
  _TimeZoneOption('Asia/Yangon', 'Yangon', 'UTC+06:30'),
  _TimeZoneOption('Asia/Bangkok', 'Bangkok', 'UTC+07:00'),
  _TimeZoneOption('Asia/Singapore', 'Singapore', 'UTC+08:00'),
  _TimeZoneOption('Australia/Eucla', 'Eucla', 'UTC+08:45'),
  _TimeZoneOption('Asia/Tokyo', 'Tokyo', 'UTC+09:00'),
  _TimeZoneOption('Australia/Adelaide', 'Adelaide', 'UTC+09:30'),
  _TimeZoneOption('Australia/Sydney', 'Sydney', 'UTC+10:00'),
  _TimeZoneOption('Australia/Lord_Howe', 'Lord Howe Island', 'UTC+10:30'),
  _TimeZoneOption('Pacific/Noumea', 'Nouméa', 'UTC+11:00'),
  _TimeZoneOption('Pacific/Auckland', 'Auckland', 'UTC+12:00'),
  _TimeZoneOption('Pacific/Chatham', 'Chatham Islands', 'UTC+12:45'),
  _TimeZoneOption('Pacific/Tongatapu', 'Nukuʻalofa', 'UTC+13:00'),
  _TimeZoneOption('Pacific/Kiritimati', 'Kiritimati', 'UTC+14:00'),
];

class _TimeZoneSetupCard extends StatefulWidget {
  const _TimeZoneSetupCard();

  @override
  State<_TimeZoneSetupCard> createState() => _TimeZoneSetupCardState();
}

class _TimeZoneSetupCardState extends State<_TimeZoneSetupCard> {
  final SecureGameStorage _storage = SecureGameStorage();
  String? _selectedId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final selectedId = await _storage.loadSelectedTimeZoneId();
    if (!mounted) return;
    setState(() {
      _selectedId = selectedId;
      _loading = false;
    });
  }

  Future<void> _selectTimeZone() async {
    HapticFeedback.selectionClick();
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.76),
      builder: (context) => _TimeZonePickerSheet(selectedId: _selectedId),
    );
    if (!mounted || selectedId == null || selectedId == _selectedId) return;

    await _storage.saveSelectedTimeZoneId(selectedId);
    if (!mounted) return;
    setState(() => _selectedId = selectedId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Time zone set to ${_selectedLabel(selectedId)}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _selectedLabel(String id) {
    if (id == _deviceTimeZoneId) {
      return 'Device · ${_deviceTimeZoneDescription()}';
    }
    for (final option in _timeZoneOptions) {
      if (option.id == id) return '${option.label} · ${option.utcOffset}';
    }
    return 'Choose your local time zone';
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedId != null;
    final subtitle = _loading
        ? 'Loading preference…'
        : hasSelection
        ? _selectedLabel(_selectedId!)
        : 'Choose your local time zone';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loading ? null : _selectTimeZone,
      child: ProfileCard(
        borderColor: hasSelection
            ? Cyber.cyan.withValues(alpha: 0.58)
            : Cyber.border,
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Cyber.cyan.withValues(alpha: 0.1),
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.46)),
              ),
              child: const Icon(
                Icons.public_rounded,
                color: Cyber.cyan,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SET UP YOUR LOCAL TIME ZONE',
                    style: Cyber.label(
                      11,
                      color: Colors.white,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(
                      12,
                      color: hasSelection ? Cyber.cyan : Cyber.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Cyber.cyan, size: 21),
          ],
        ),
      ),
    );
  }
}

class _TimeZonePickerSheet extends StatelessWidget {
  const _TimeZonePickerSheet({required this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SizedBox(
          height: height,
          child: CyberPanel(
            accent: Cyber.cyan,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Cyber.cyan,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'SELECT TIME ZONE',
                          style: Cyber.label(
                            11,
                            color: Cyber.cyan,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Cyber.muted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const HudLine(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _TimeZoneOptionTile(
                        id: _deviceTimeZoneId,
                        label: 'Use device time zone',
                        subtitle: _deviceTimeZoneDescription(),
                        selected: selectedId == _deviceTimeZoneId,
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
                        child: Text(
                          'OR CHOOSE A CITY',
                          style: TextStyle(
                            color: Cyber.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      for (final option in _timeZoneOptions)
                        _TimeZoneOptionTile(
                          id: option.id,
                          label: option.label,
                          subtitle: option.utcOffset,
                          selected: selectedId == option.id,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeZoneOptionTile extends StatelessWidget {
  const _TimeZoneOptionTile({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.selected,
  });

  final String id;
  final String label;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Cyber.cyan.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(id),
        splashColor: Cyber.cyan.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 11, 16, 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Cyber.body(
                        14,
                        color: selected ? Cyber.cyan : Colors.white,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Cyber.body(11, color: Cyber.muted)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? Cyber.cyan : Cyber.muted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _deviceTimeZoneDescription() {
  final now = DateTime.now();
  final offset = now.timeZoneOffset;
  final sign = offset.isNegative ? '−' : '+';
  final hours = offset.inMinutes.abs() ~/ 60;
  final minutes = offset.inMinutes.abs() % 60;
  final formattedOffset =
      'UTC$sign${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
  final name = now.timeZoneName.trim();
  return name.isEmpty ? formattedOffset : '$name · $formattedOffset';
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.progression,
    required this.onChallenge,
  });

  final PlayerProgression progression;
  final void Function(String opponentName, int opponentLevel) onChallenge;

  @override
  Widget build(BuildContext context) {
    final level = progression.playerLevel;
    return SizedBox(
      height: 352,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 206,
            child: _EmblemBanner(height: 206),
          ),
          Positioned(
            top: 120,
            left: 8,
            right: 8,
            child: ProfileCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 228,
                child: Stack(
                  children: [
                    Positioned(
                      right: 16,
                      top: 18,
                      child: LevelChip(
                        level: level,
                        onTap: () => showXpHistory(context),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 76,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLAYER ONE',
                            style: Cyber.display(24, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'OPERATIVE // ID 0001',
                            style: Cyber.label(
                              10,
                              color: Cyber.muted,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          XpMeter(progression: progression),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Flexible(child: _PlayerTagPill()),
                              const SizedBox(width: 10),
                              _FriendsPill(onChallenge: onChallenge),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(left: 28, top: 72, child: _Avatar()),
        ],
      ),
    );
  }
}

/// The player's own shareable tag (e.g. `PL4Y-X7K9`), generated once and
/// persisted. Tap to copy it; another player pastes it in their Friends Arena
/// search to find and add you. Calm chamfered chip — no glow (the hero's focal
/// glow stays the level chip + XP meter).
class _PlayerTagPill extends StatefulWidget {
  const _PlayerTagPill();

  @override
  State<_PlayerTagPill> createState() => _PlayerTagPillState();
}

class _PlayerTagPillState extends State<_PlayerTagPill> {
  final SecureGameStorage _storage = SecureGameStorage();
  String? _tag;

  @override
  void initState() {
    super.initState();
    _loadTag();
  }

  Future<void> _loadTag() async {
    final tag = await _storage.loadOrCreatePlayerTag();
    if (!mounted) return;
    setState(() => _tag = tag);
  }

  Future<void> _copy() async {
    final tag = _tag;
    if (tag == null) return;
    await Clipboard.setData(ClipboardData(text: tag));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Player tag copied · $tag'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tag = _tag ?? '••••-••••';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tag == null ? null : _copy,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                16,
                weight: FontWeight.w600,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.copy_rounded,
            size: 16,
            color: Cyber.cyan.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

/// Hero entry point to the Friends Arena: total friend count + a live online
/// count. Faint cyan interactive border (it's tappable) but no glow, keeping the
/// hero's glow scarce.
class _FriendsPill extends StatelessWidget {
  const _FriendsPill({required this.onChallenge});

  final void Function(String opponentName, int opponentLevel) onChallenge;

  void _openArena(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendsArenaScreen(onChallenge: onChallenge),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FriendsCubit, FriendsState>(
      builder: (context, state) {
        final friends = state.friends;
        final online = friends.where(rivalIsOnline).length;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openArena(context),
          child: Container(
            height: 34,
            padding: const EdgeInsets.fromLTRB(11, 0, 8, 0),
            decoration: cutCornerDecoration(
              color: Cyber.panel.withValues(alpha: 0.55),
              borderColor: Cyber.cyan.withValues(alpha: 0.42),
              cut: 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_rounded, color: Cyber.cyan, size: 17),
                const SizedBox(width: 7),
                Text('FRIENDS', style: Cyber.display(12, letterSpacing: 1)),
                const SizedBox(width: 8),
                _CountBadge(value: friends.length, color: Cyber.violet),
                if (online > 0) ...[
                  const SizedBox(width: 6),
                  _CountBadge(value: online, color: Cyber.success, dot: true),
                ],
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right, color: Cyber.muted, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small count chip used inside [_FriendsPill] (violet = total, green dot =
/// online).
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.value,
    required this.color,
    this.dot = false,
  });

  final int value;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(dot ? 5 : 7, 2, 7, 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$value',
            style: Cyber.label(
              11,
              color: color,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bug report dialog ────────────────────────────────────────────────────────

class _BugReport {
  const _BugReport({required this.description, required this.content});

  final String description;
  final String content;
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _description = TextEditingController();
  final _content = TextEditingController();

  bool _submittedEmpty = false;

  @override
  void dispose() {
    _description.dispose();
    _content.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _description.text.trim();
    final content = _content.text.trim();

    if (description.isEmpty || content.isEmpty) {
      setState(() => _submittedEmpty = true);
      return;
    }

    Navigator.of(
      context,
    ).pop(_BugReport(description: description, content: content));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: CyberPanel(
          accent: Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bug_report,
                          color: Cyber.cyan,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'REPORT',
                          style: Cyber.label(
                            11,
                            color: Cyber.cyan,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'BUG / MISMATCH',
                      style: Cyber.display(16, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 14),
                    _BugReportField(
                      controller: _description,
                      label: 'Description',
                      hint: 'Short summary',
                      error:
                          _submittedEmpty && _description.text.trim().isEmpty,
                    ),
                    const SizedBox(height: 12),
                    _BugReportField(
                      controller: _content,
                      label: 'Content',
                      hint: 'What happened?',
                      maxLines: 5,
                      error: _submittedEmpty && _content.text.trim().isEmpty,
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _BugReportAction(
                        label: 'Cancel',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff2a303c)),
                    Expanded(
                      child: _BugReportAction(
                        label: 'Submit >',
                        color: Cyber.cyan,
                        onTap: _submit,
                      ),
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

class _BugReportField extends StatelessWidget {
  const _BugReportField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.error,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool error;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final borderColor = error ? Cyber.red : const Color(0xff343b49);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.3),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: Cyber.body(13),
          cursorColor: Cyber.cyan,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Cyber.body(13, color: Cyber.muted),
            filled: true,
            fillColor: Cyber.bg.withValues(alpha: 0.45),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: borderColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _BugReportAction extends StatelessWidget {
  const _BugReportAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Cyber.label(11, color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}

// Settings sheet.
class _ProfileSettingsSheet extends StatelessWidget {
  const _ProfileSettingsSheet({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: CyberPanel(
          accent: Cyber.cyan,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Row(
                  children: [
                    const Icon(Icons.settings, color: Cyber.cyan, size: 17),
                    const SizedBox(width: 9),
                    Text(
                      'SETTINGS',
                      style: Cyber.label(
                        11,
                        color: Cyber.cyan,
                        letterSpacing: 2.1,
                      ),
                    ),
                  ],
                ),
              ),
              const HudLine(),
              _SettingsActionRow(
                icon: Icons.logout,
                label: 'Log Out',
                subtitle: 'Return to avatar selection',
                color: Cyber.red,
                onTap: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await onTap();
        },
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: Cyber.label(12, color: color, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Cyber.body(12, color: Cyber.muted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: CyberPanel(
          accent: Cyber.red,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.logout, color: Cyber.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'LOG OUT',
                          style: Cyber.label(
                            11,
                            color: Cyber.red,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'RETURN TO AVATAR SELECTION?',
                      style: Cyber.display(16, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your profile setup choices will be cleared. Your cards, coins, matches, predictions, and picks stay saved.',
                      style: Cyber.body(13, color: Cyber.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const HudLine(),
              SizedBox(
                height: 50,
                child: Row(
                  children: [
                    Expanded(
                      child: _BugReportAction(
                        label: 'Cancel',
                        color: Cyber.muted,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    Container(width: 1, color: const Color(0xff2a303c)),
                    Expanded(
                      child: _BugReportAction(
                        label: 'Log Out >',
                        color: Cyber.red,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
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

// ─── Banner + avatar (with edit flows) ────────────────────────────────────────

/// Banner strip for the hero. Gradient-free: a flat banner visual with a thin
/// bottom blend into the profile background; the edit button floats top-right.
class _EmblemBanner extends StatefulWidget {
  const _EmblemBanner({this.height = 148});

  final double height;

  @override
  State<_EmblemBanner> createState() => _EmblemBannerState();
}

class _EmblemBannerState extends State<_EmblemBanner> {
  String? _selectedBannerId;
  final SecureGameStorage _storage = SecureGameStorage();

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final bannerId = await _storage.loadSelectedProfileBannerId();
    if (!mounted) return;
    setState(() => _selectedBannerId = bannerId);
  }

  Future<void> _showBannerPicker() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _BannerEditScreen(initialBannerId: _selectedBannerId),
      ),
    );

    if (selectedId == null) return;

    await _storage.saveSelectedProfileBannerId(selectedId);
    if (!mounted) return;
    setState(() => _selectedBannerId = selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final banner = profileBannerOptionById(_selectedBannerId);
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProfileBannerVisual(option: banner),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 76,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0),
                    Cyber.bg.withValues(alpha: 0.72),
                    Cyber.bg,
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned(
            // +32 to clear the status bar now that the banner full-bleeds behind
            // it under edge-to-edge.
            top: 44,
            right: 12,
            child: Tooltip(
              message: 'Edit banner',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showBannerPicker,
                  customBorder: const RoundedRectangleBorder(),
                  splashColor: Cyber.cyan.withValues(alpha: 0.18),
                  highlightColor: Cyber.cyan.withValues(alpha: 0.10),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cyber.bg.withValues(alpha: 0.86),
                      border: Border.all(color: AppTheme.gameCtaBorder),
                    ),
                    child: const Icon(Icons.edit, color: Cyber.cyan, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatefulWidget {
  const _Avatar();

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> {
  String? _selectedAvatarId;
  final SecureGameStorage _storage = SecureGameStorage();

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    if (!mounted) return;
    setState(() => _selectedAvatarId = avatarId);
  }

  Future<void> _showAvatarPicker() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AvatarEditScreen(initialAvatarId: _selectedAvatarId),
      ),
    );

    if (selectedId == null) return;

    await _storage.saveSelectedAvatarId(selectedId);
    if (!mounted) return;
    setState(() => _selectedAvatarId = selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarOptionById(_selectedAvatarId);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: BlocBuilder<GameBloc, GameState>(
              buildWhen: (a, b) =>
                  a.equippedAvatarFrameId != b.equippedAvatarFrameId,
              builder: (context, state) {
                final equipped = avatarFrameOptionById(
                  state.equippedAvatarFrameId,
                );
                return Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Cyber.panel,
                    // The equipped border's ring replaces the default cyan edge.
                    border: equipped == null
                        ? Border.all(color: Cyber.cyan, width: 2)
                        : null,
                    boxShadow: const [
                      BoxShadow(color: Color(0xff04060b), offset: Offset(0, 4)),
                    ],
                  ),
                  child: AvatarFrameRing(
                    frame: equipped,
                    // The user's own avatar is a legitimate focal element.
                    glow: true,
                    child: Image.asset(
                      avatar.assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Edit avatar & frame',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAvatarPicker,
                  customBorder: const RoundedRectangleBorder(),
                  splashColor: Cyber.cyan.withValues(alpha: 0.18),
                  highlightColor: Cyber.cyan.withValues(alpha: 0.10),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cyber.bg,
                      border: Border.all(color: AppTheme.gameCtaBorder),
                    ),
                    child: const Icon(Icons.edit, color: Cyber.cyan, size: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Avatar + frame editing screen — an AVATAR | FRAME segmented editor with a live
// preview. The AVATAR tab picks a portrait (committed on CONTINUE); the FRAME tab
// equips one of your owned frames instantly (persisted by GameBloc); buying more
// frames stays in the Shop.
class _AvatarEditScreen extends StatefulWidget {
  const _AvatarEditScreen({required this.initialAvatarId});

  final String? initialAvatarId;

  @override
  State<_AvatarEditScreen> createState() => _AvatarEditScreenState();
}

class _AvatarEditScreenState extends State<_AvatarEditScreen>
    with SingleTickerProviderStateMixin {
  late String _selectedAvatarId;
  int _tab = 0;

  late final AnimationController _tabIndicatorController;
  late Animation<double> _tabIndicatorAnimation;

  @override
  void initState() {
    super.initState();
    _selectedAvatarId = avatarOptionById(widget.initialAvatarId).id;
    _tabIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0,
    );
    _tabIndicatorAnimation = AlwaysStoppedAnimation<double>(0);
  }

  @override
  void dispose() {
    _tabIndicatorController.dispose();
    super.dispose();
  }

  void _setTab(int index) {
    if (index == _tab) return;
    _tabIndicatorAnimation =
        Tween<double>(begin: _tab.toDouble(), end: index.toDouble()).animate(
          CurvedAnimation(
            parent: _tabIndicatorController,
            curve: Curves.easeOutCubic,
          ),
        );
    _tabIndicatorController.forward(from: 0);
    HapticFeedback.selectionClick();
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = avatarOptionById(_selectedAvatarId);
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  decoration: const BoxDecoration(
                    color: Cyber.panel,
                    border: Border(bottom: BorderSide(color: Cyber.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CUSTOMISE PROFILE',
                          style: Cyber.display(19, letterSpacing: 1.1),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
                _AvatarEditorTabs(
                  activeTab: _tab,
                  indicatorAnimation: _tabIndicatorAnimation,
                  onTap: _setTab,
                ),
                Expanded(
                  child: BlocBuilder<GameBloc, GameState>(
                    buildWhen: (a, b) =>
                        a.equippedAvatarFrameId != b.equippedAvatarFrameId ||
                        a.ownedAvatarFrameIds != b.ownedAvatarFrameIds,
                    builder: (context, state) {
                      final equipped = avatarFrameOptionById(
                        state.equippedAvatarFrameId,
                      );
                      return Column(
                        children: [
                          const SizedBox(height: 18),
                          _PreviewAvatar(avatar: avatar, frame: equipped),
                          const SizedBox(height: 14),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Cyber.border,
                          ),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    6,
                                    24,
                                    104,
                                  ),
                                  child: _tab == 0
                                      ? _avatarGrid()
                                      : _frameGrid(context, state, avatar),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _AvatarTossCta(
                    label: 'DONE',
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedAvatarId),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarGrid() => GridView.builder(
    itemCount: avatarOptions.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1,
    ),
    itemBuilder: (context, index) {
      final avatar = avatarOptions[index];
      return _EditableAvatarTile(
        avatar: avatar,
        selected: avatar.id == _selectedAvatarId,
        onTap: () => setState(() => _selectedAvatarId = avatar.id),
      );
    },
  );

  Widget _frameGrid(
    BuildContext context,
    GameState state,
    AvatarOption avatar,
  ) {
    final owned = state.ownedAvatarFrameIds
        .map(avatarFrameOptionById)
        .whereType<AvatarFrameOption>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.builder(
            // A leading "NONE" tile (un-equip) + every owned frame.
            itemCount: owned.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final frame = index == 0 ? null : owned[index - 1];
              final selected = frame == null
                  ? state.equippedAvatarFrameId.isEmpty
                  : state.equippedAvatarFrameId == frame.id;
              return _EditableFrameTile(
                frame: frame,
                avatar: avatar,
                selected: selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<GameBloc>().add(
                    AvatarFrameEquipped(frame?.id ?? ''),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront, size: 14, color: Cyber.muted),
            const SizedBox(width: 6),
            Text(
              owned.isEmpty
                  ? 'UNLOCK TEAM FRAMES IN THE SHOP'
                  : 'GET MORE TEAM FRAMES IN THE SHOP',
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.1),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Avatar editor tab bar (matches leaderboard MATCH DAY / TOURNEY style) ───

class _AvatarEditorTabs extends StatelessWidget {
  const _AvatarEditorTabs({
    required this.activeTab,
    required this.indicatorAnimation,
    required this.onTap,
  });

  final int activeTab;
  final Animation<double> indicatorAnimation;
  final ValueChanged<int> onTap;

  static const List<String> _labels = ['AVATAR', 'FRAME'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.4),
        border: const Border(bottom: BorderSide(color: Color(0x38ffffff))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tabWidth = constraints.maxWidth / _labels.length;
          return Stack(
            children: [
              Row(
                children: [
                  for (int i = 0; i < _labels.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          color: activeTab == i
                              ? Cyber.cyan.withValues(alpha: 0.07)
                              : Colors.transparent,
                          alignment: Alignment.center,
                          child: Text(
                            _labels[i],
                            style: Cyber.label(
                              10,
                              color: activeTab == i
                                  ? Cyber.cyan
                                  : AppTheme.slate400,
                              weight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedBuilder(
                animation: indicatorAnimation,
                builder: (context, child) => Positioned(
                  left: tabWidth * indicatorAnimation.value + tabWidth * 0.18,
                  bottom: 0,
                  width: tabWidth * 0.64,
                  height: 3,
                  child: child!,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Cyber.cyan,
                    boxShadow: [
                      BoxShadow(
                        color: Cyber.cyan.withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Live avatar + equipped-frame preview at the top of the editor.
class _PreviewAvatar extends StatelessWidget {
  const _PreviewAvatar({required this.avatar, required this.frame});

  final AvatarOption avatar;
  final AvatarFrameOption? frame;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Container(
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: frame == null
              ? Border.all(color: Cyber.cyan, width: 2)
              : null,
        ),
        child: AvatarFrameRing(
          frame: frame,
          glow: true,
          child: Image.asset(
            avatar.assetPath,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
      ),
    );
  }
}

/// One frame option in the FRAME tab — the selected avatar wrapped in the
/// frame's ring (or no ring for the "NONE" tile), with a label caption and the
/// equipped tile carrying the lime select treatment.
class _EditableFrameTile extends StatelessWidget {
  const _EditableFrameTile({
    required this.frame,
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AvatarFrameOption? frame;
  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.lime : Cyber.line;
    return Semantics(
      button: true,
      selected: selected,
      label: frame?.label ?? 'No frame',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: accent, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
                child: AvatarFrameRing(
                  frame: frame,
                  child: Image.asset(
                    avatar.assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  color: Cyber.bg.withValues(alpha: 0.8),
                  child: Text(
                    (frame?.label ?? 'NONE').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Cyber.label(
                      8,
                      color: selected ? Cyber.lime : Cyber.muted,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              if (selected) const _EditableAvatarSelectedCorner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerEditScreen extends StatefulWidget {
  const _BannerEditScreen({required this.initialBannerId});

  final String? initialBannerId;

  @override
  State<_BannerEditScreen> createState() => _BannerEditScreenState();
}

class _BannerEditScreenState extends State<_BannerEditScreen> {
  late String _selectedBannerId;

  @override
  void initState() {
    super.initState();
    _selectedBannerId = profileBannerOptionById(widget.initialBannerId).id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  decoration: const BoxDecoration(
                    color: Cyber.panel,
                    border: Border(bottom: BorderSide(color: Cyber.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CHOOSE YOUR BANNER',
                          style: Cyber.display(19, letterSpacing: 1.1),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 104),
                        child: GridView.builder(
                          itemCount: profileBannerOptions.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 1,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 2.35,
                              ),
                          itemBuilder: (context, index) {
                            final banner = profileBannerOptions[index];
                            return SelectableBannerTile(
                              banner: banner,
                              selected: banner.id == _selectedBannerId,
                              onTap: () =>
                                  setState(() => _selectedBannerId = banner.id),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _AvatarTossCta(
                    label: 'CONTINUE',
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedBannerId),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Color _avatarCtaCyan = Color(0xFF5CDFFF);
const Color _avatarCtaInk = Color(0xFF0D111A);

class _AvatarTossCta extends StatefulWidget {
  const _AvatarTossCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_AvatarTossCta> createState() => _AvatarTossCtaState();
}

class _AvatarTossCtaState extends State<_AvatarTossCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _press,
      builder: (_, _) => Transform.scale(
        scale: _scale.value,
        child: GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapUp: (_) {
            _press.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _press.reverse(),
          child: ClipPath(
            clipper: const _AvatarCtaClipper(),
            child: Container(
              width: double.infinity,
              height: 52,
              color: _avatarCtaCyan,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 36,
                    child: CustomPaint(painter: _AvatarCtaStripePainter()),
                  ),
                  Text(
                    widget.label,
                    style: Cyber.display(
                      15,
                      color: _avatarCtaInk,
                      letterSpacing: 3,
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

class _AvatarCtaClipper extends CustomClipper<Path> {
  const _AvatarCtaClipper();

  static const _cut = 10.0;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(_cut, 0)
    ..lineTo(size.width - _cut, 0)
    ..lineTo(size.width, _cut)
    ..lineTo(size.width, size.height - _cut)
    ..lineTo(size.width - _cut, size.height)
    ..lineTo(_cut, size.height)
    ..lineTo(0, size.height - _cut)
    ..lineTo(0, _cut)
    ..close();

  @override
  bool shouldReclip(_AvatarCtaClipper oldClipper) => false;
}

class _AvatarCtaStripePainter extends CustomPainter {
  const _AvatarCtaStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    const spacing = 6.0;
    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x - size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AvatarCtaStripePainter oldDelegate) => false;
}

class _EditableAvatarTile extends StatelessWidget {
  const _EditableAvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Cyber.lime : Cyber.line;
    return Semantics(
      button: true,
      selected: selected,
      label: avatar.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                avatar.assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              if (selected) const _EditableAvatarSelectedCorner(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableAvatarSelectedCorner extends StatelessWidget {
  const _EditableAvatarSelectedCorner();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Cyber.lime),
        child: const Icon(Icons.check, color: Cyber.bg, size: 20),
      ),
    );
  }
}

// ─── Following band ───────────────────────────────────────────────────────────

/// Compact "FOLLOWING" strip under the hero: the favourite-team badges picked
/// during profile setup, with their league code. Static chrome — no glow.
/// Renders nothing until at least one favourite is set.
class _FollowingBand extends StatefulWidget {
  const _FollowingBand();

  @override
  State<_FollowingBand> createState() => _FollowingBandState();
}

class _FollowingBandState extends State<_FollowingBand> {
  final SecureGameStorage _storage = SecureGameStorage();

  /// (team, leagueCode) pairs for each followed league with a favourite team.
  List<(SportTeam, String)> _favourites = const [];
  List<String> _followedLeagueIds = const [];
  Map<String, String> _favoriteTeams = const {};
  Sport _primarySport = Sport.football;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final primarySport = sportFromStorage(
      await _storage.loadPrimarySportName(),
    );
    final followed = await _storage.loadFollowedLeagueIds();
    final teams = await _storage.loadFavoriteTeams();
    final result = <(SportTeam, String)>[];
    for (final leagueId in followed) {
      final entry = followableLeagueById(leagueId);
      final teamId = teams[leagueId];
      if (entry == null || teamId == null) continue;
      final team = followableTeam(leagueId, teamId);
      if (team != null) result.add((team, entry.league.shortCode));
    }
    if (!mounted) return;
    setState(() {
      _favourites = result;
      _followedLeagueIds = followed;
      _favoriteTeams = teams;
      _primarySport = primarySport;
    });
  }

  Future<void> _openEditor() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FollowingEditorSheet(
        storage: _storage,
        primarySport: _primarySport,
        followedLeagueIds: _followedLeagueIds,
        favoriteTeams: _favoriteTeams,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = sportModuleFor(_primarySport);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ProfileCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PrimarySportChip(module: module),
            const SizedBox(width: 10),
            Expanded(
              child: _favourites.isEmpty
                  ? Text(
                      'Pick the teams and clubs you follow.',
                      style: Cyber.body(13, color: Cyber.muted),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (team, code) in _favourites)
                          _FollowedTeamChip(team: team, leagueCode: code),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            _FollowingEditButton(onTap: _openEditor),
          ],
        ),
      ),
    );
  }
}

// ─── Following editor controls ────────────────────────────────────────────────

class _PrimarySportChip extends StatelessWidget {
  const _PrimarySportChip({required this.module});

  final SportModule module;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
      decoration: BoxDecoration(
        color: module.accent.withValues(alpha: 0.12),
        border: Border.all(color: module.accent.withValues(alpha: 0.58)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(module.icon, color: module.accent, size: 20),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                module.shortLabel,
                style: Cyber.display(12, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'MODULE',
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FollowedTeamChip extends StatelessWidget {
  const _FollowedTeamChip({required this.team, required this.leagueCode});

  final SportTeam team;
  final String leagueCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.56),
        border: Border.all(color: Cyber.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TeamLogo(team: team, width: 30, height: 32),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 58),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  team.shortName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(12, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  leagueCode,
                  style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingEditButton extends StatelessWidget {
  const _FollowingEditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit followed teams',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.cyan.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.gameCtaBorder),
          ),
          child: const Icon(Icons.edit, color: Cyber.cyan, size: 16),
        ),
      ),
    );
  }
}

class _FollowingEditorSheet extends StatefulWidget {
  const _FollowingEditorSheet({
    required this.storage,
    required this.primarySport,
    required this.followedLeagueIds,
    required this.favoriteTeams,
  });

  final SecureGameStorage storage;
  final Sport primarySport;
  final List<String> followedLeagueIds;
  final Map<String, String> favoriteTeams;

  @override
  State<_FollowingEditorSheet> createState() => _FollowingEditorSheetState();
}

class _FollowingEditorSheetState extends State<_FollowingEditorSheet> {
  late Sport _primarySport = widget.primarySport;
  late final Set<String> _followedLeagueIds = widget.followedLeagueIds.toSet();
  late final Map<String, String> _favoriteTeams = Map.of(widget.favoriteTeams);
  late String _activeLeagueId = _initialActiveLeagueId();
  bool _saving = false;

  List<FollowableLeague> get _availableLeagues =>
      followableLeaguesForSport(_primarySport);

  String _initialActiveLeagueId() {
    for (final leagueId in _followedLeagueIds) {
      final entry = followableLeagueById(leagueId);
      if (entry?.sport == _primarySport) return leagueId;
    }
    return _availableLeagues.first.league.id;
  }

  FollowableLeague get _activeLeague =>
      followableLeagueById(_activeLeagueId) ?? _availableLeagues.first;

  void _selectSport(Sport sport) {
    if (_primarySport == sport) return;
    setState(() {
      _primarySport = sport;
      _followedLeagueIds.clear();
      _favoriteTeams.clear();
      _activeLeagueId = followableLeaguesForSport(sport).first.league.id;
    });
  }

  void _toggleLeague(FollowableLeague entry) {
    setState(() {
      if (_followedLeagueIds.remove(entry.league.id)) {
        _favoriteTeams.remove(entry.league.id);
        if (_activeLeagueId == entry.league.id) {
          _activeLeagueId = _followedLeagueIds.isNotEmpty
              ? _followedLeagueIds.first
              : _availableLeagues.first.league.id;
        }
      } else {
        _followedLeagueIds.add(entry.league.id);
        _favoriteTeams[entry.league.id] = entry.teams.first.id;
        _activeLeagueId = entry.league.id;
      }
    });
  }

  void _selectTeam(String teamId) {
    setState(() {
      _followedLeagueIds.add(_activeLeague.league.id);
      _favoriteTeams[_activeLeague.league.id] = teamId;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final orderedLeagueIds = [
      for (final entry in _availableLeagues)
        if (_followedLeagueIds.contains(entry.league.id)) entry.league.id,
    ];
    final teams = {
      for (final leagueId in orderedLeagueIds)
        if (_favoriteTeams[leagueId] != null)
          leagueId: _favoriteTeams[leagueId]!,
    };
    await widget.storage.savePrimarySportName(_primarySport.name);
    await widget.storage.saveFollowedLeagueIds(orderedLeagueIds);
    await widget.storage.saveFavoriteTeams(teams);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final selectedTeamId = _favoriteTeams[_activeLeague.league.id];
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Cyber.bg),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'EDIT CLUBS',
                      style: Cyber.display(16, color: Cyber.cyan),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final module = sportModules[index];
                    return _EditableSportPill(
                      module: module,
                      selected: module.sport == _primarySport,
                      onTap: () => _selectSport(module.sport),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemCount: sportModules.length,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final entry = _availableLeagues[index];
                    return _EditableLeaguePill(
                      entry: entry,
                      active: entry.league.id == _activeLeagueId,
                      selected: _followedLeagueIds.contains(entry.league.id),
                      onTap: () =>
                          setState(() => _activeLeagueId = entry.league.id),
                      onToggle: () => _toggleLeague(entry),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemCount: _availableLeagues.length,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _activeLeague.teams.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final team = _activeLeague.teams[index];
                    return _EditableFollowTeamTile(
                      team: team,
                      selected: team.id == selectedTeamId,
                      enabled: _followedLeagueIds.contains(
                        _activeLeague.league.id,
                      ),
                      onTap: () => _selectTeam(team.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Cyber.cyan,
                    foregroundColor: Cyber.bg,
                    disabledBackgroundColor: Cyber.line,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'SAVING' : 'SAVE',
                    style: Cyber.display(13, color: Cyber.bg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableSportPill extends StatelessWidget {
  const _EditableSportPill({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final SportModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Cyber.lime : module.accent;
    return Semantics(
      button: true,
      selected: selected,
      label: module.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: selected ? 0.76 : 0.48),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.9 : 0.45),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.14, blur: 12, spread: -3)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                module.label.toUpperCase(),
                style: Cyber.label(
                  10,
                  color: selected ? Colors.white : Cyber.muted,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableLeaguePill extends StatelessWidget {
  const _EditableLeaguePill({
    required this.entry,
    required this.active,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final FollowableLeague entry;
  final bool active;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? Cyber.lime : Cyber.cyan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 106,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? Cyber.panel : Cyber.panel.withValues(alpha: 0.58),
          border: Border.all(
            color: active ? accent : Cyber.line,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.league.shortCode,
                    style: Cyber.display(
                      13,
                      color: active ? accent : Cyber.muted,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: accent,
                    size: 18,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              entry.league.name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableFollowTeamTile extends StatelessWidget {
  const _EditableFollowTeamTile({
    required this.team,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SportTeam team;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Cyber.lime : Cyber.line;
    return Semantics(
      button: true,
      selected: selected,
      label: team.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? Cyber.panel.withValues(alpha: 0.72)
                : Cyber.panel.withValues(alpha: 0.38),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TeamLogo(team: team, width: 40, height: 44),
                  const SizedBox(height: 7),
                  Text(
                    team.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Cyber.label(
                      8,
                      color: selected ? Colors.white : Cyber.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              if (selected)
                const Align(
                  alignment: Alignment.topLeft,
                  child: _EditableAvatarSelectedCorner(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.5),
            border: Border.all(color: Cyber.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Cyber.cyan, size: 20),
                  const SizedBox(width: 12),
                  Text(label, style: Cyber.body(15, weight: FontWeight.w600)),
                ],
              ),
              const Icon(Icons.chevron_right, color: Cyber.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
