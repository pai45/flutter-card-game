import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../models/avatar_option.dart';
import '../../models/picks.dart';
import '../../models/player_stats.dart';
import '../../models/sport_match.dart';
import '../../models/profile_banner_option.dart';
import '../../models/progression.dart';
import '../../services/achievement_progress.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/profile_banner_visual.dart';
import '../../widgets/team_logo.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../how_to_play/how_to_play_hub_screen.dart';
import '../match_history/match_history_pages.dart';
import '../predictions/prediction_match_history_screen.dart';
import '../predictions/prediction_picks_history_screen.dart';
import '../predictions/widgets/history_hud.dart' show CutChipBorder;
import 'achievements_screen.dart';
import 'oz_coin_history_screen.dart';
import 'widgets/achievement_grid.dart';
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
  const ProfileScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

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
                        _ProfileHeroCard(progression: game.progression),
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
                                  ProfileStat.text(
                                    'STREAK',
                                    '${record.currentStreak}',
                                    valueColor: record.currentStreak > 0
                                        ? Cyber.amber
                                        : null,
                                  ),
                                ],
                                onViewHistory: () => showMatchHistoryArchive(
                                  context,
                                  game.matchHistory,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _NavRow(
                                icon: Icons.dashboard_customize,
                                label: 'Deck Builder',
                                onTap: () => _push(
                                  context,
                                  (nav) => DeckBuilderScreen(onNavigate: nav),
                                ),
                              ),
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
                                onTap: () {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text('Settings coming soon'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                },
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
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.progression});

  final PlayerProgression progression;

  @override
  Widget build(BuildContext context) {
    final level = progression.playerLevel;
    return SizedBox(
      height: 300,
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
                height: 172,
                child: Stack(
                  children: [
                    Positioned(
                      right: 16,
                      top: 18,
                      child: _LevelChip(level: level),
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
                          _XpMeter(progression: progression),
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

/// Glowing level chip — the one focal element on the profile (it's "you" and
/// primary, so it earns the glow).
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: ShapeDecoration(
        color: Cyber.card,
        shape: CutChipBorder(
          cut: 7,
          side: BorderSide(
            color: Cyber.cyan.withValues(alpha: 0.85),
            width: 1.4,
          ),
        ),
        shadows: Cyber.glow(Cyber.cyan, alpha: 0.45, blur: 16, spread: 0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LVL',
            style: Cyber.label(
              9,
              color: Cyber.cyan.withValues(alpha: 0.85),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$level',
            style: Cyber.display(
              20,
              color: Cyber.cyan,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _XpMeter extends StatelessWidget {
  const _XpMeter({required this.progression});

  final PlayerProgression progression;

  @override
  Widget build(BuildContext context) {
    final p = levelProgress(progression.totalXP);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'XP',
              style: Cyber.label(10, color: Cyber.muted, letterSpacing: 1.4),
            ),
            const Spacer(),
            Text(
              '${p.intoLevel} / ${p.levelSpan}',
              style: Cyber.label(
                10,
                color: Cyber.muted,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        CyberProgressBar(
          value: p.pct,
          accent: Cyber.cyan,
          trackColor: Cyber.bg,
        ),
      ],
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
                      border: Border.all(color: Cyber.cyan),
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
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Cyber.panel,
                border: Border.all(color: Cyber.cyan, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0xff04060b), offset: Offset(0, 4)),
                ],
              ),
              child: Image.asset(
                avatar.assetPath,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Edit avatar',
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
                      border: Border.all(color: Cyber.cyan),
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

// Avatar editing screen.
class _AvatarEditScreen extends StatefulWidget {
  const _AvatarEditScreen({required this.initialAvatarId});

  final String? initialAvatarId;

  @override
  State<_AvatarEditScreen> createState() => _AvatarEditScreenState();
}

class _AvatarEditScreenState extends State<_AvatarEditScreen> {
  late String _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _selectedAvatarId = avatarOptionById(widget.initialAvatarId).id;
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
                          'CHOOSE YOUR AVATAR',
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
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 104),
                        child: GridView.builder(
                          itemCount: avatarOptions.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
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
                              onTap: () =>
                                  setState(() => _selectedAvatarId = avatar.id),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    setState(() => _favourites = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_favourites.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(label: 'FOLLOWING'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                for (final (team, code) in _favourites)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TeamLogo(team: team, width: 40, height: 44),
                      const SizedBox(height: 6),
                      Text(
                        code,
                        style: Cyber.label(
                          9,
                          color: Cyber.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── HUD navigation rows ──────────────────────────────────────────────────────

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

