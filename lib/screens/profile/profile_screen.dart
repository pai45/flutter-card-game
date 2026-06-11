import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import '../../blocs/picks/picks_cubit.dart';
import '../../blocs/prediction/prediction_cubit.dart';
import '../../blocs/prediction/prediction_state.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../models/avatar_option.dart';
import '../../models/picks.dart';
import '../../services/secure_storage_service.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/landing_bottom_navigation.dart';
import '../../widgets/player_level_badge.dart';
import '../deck/all_cards_screen.dart';
import '../deck/deck_builder_screen.dart';
import '../how_to_play/how_to_play_screen.dart';
import '../predictions/prediction_match_history_screen.dart';
import '../predictions/prediction_picks_history_screen.dart';

/// Flat pastel fills for profile cards — a 10% accent wash over the panel base.
abstract final class _ProfilePastel {
  static const _tint = 0.10;

  static Color _wash(Color accent, [Color base = Cyber.panel]) =>
      Color.lerp(base, accent, _tint)!;

  static final header = _wash(Cyber.cyan);
  static final headerBanner = _wash(Cyber.violet);

  static Color section(Color accent) => _wash(accent);

  static Color statTile(Color accent, int index) => _wash(accent, Cyber.panel2);
}

/// PROFILE tab — player identity over two record cards: MY MATCHES (matchday
/// prediction quiz) and MY PICKS (Oz coin markets/events/futures), followed by the
/// card-game utilities (deck builder, all cards, how to play) and settings.
///
/// The layout mirrors the shared design: a banner-headed identity card, two
/// accent-coded stat sections each with a "View History" footer, and a stack of
/// HUD navigation rows. All chrome is built from the shared `Cyber.*` tokens and
/// components so it stays on-brand with the rest of the app.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  // Mirrors the player's standing in the mock matchday leaderboard.
  static const int _matchesRank = 122;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: CyberTextureOverlay()),
          SafeArea(
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, game) {
                return BlocBuilder<PredictionCubit, PredictionState>(
                  builder: (context, pred) {
                    final totalPicks = pred.predictions.values.fold<int>(
                      0,
                      (sum, p) => sum + p.answers.length,
                    );
                    final correct = pred.correctPredictions;
                    final predAccuracy = totalPicks == 0
                        ? 0
                        : (correct / totalPicks * 100).round();
                    final picks = context.watch<PicksCubit>().state;
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

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _IdentityHeader(game: game),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Column(
                            children: [
                              _StatSection(
                                title: 'MY MATCHES',
                                accent: Cyber.violet,
                                icon: const _CrossedSwords(size: 22),
                                stats: [
                                  _Stat('MATCHES', '${pred.predictionsMade}'),
                                  _Stat('ACCURACY', '$predAccuracy%'),
                                  _Stat('CURRENT RANK', '$_matchesRank'),
                                ],
                                onViewHistory: () =>
                                    showPredictionMatchHistory(context),
                              ),
                              const SizedBox(height: 14),
                              _StatSection(
                                title: 'MY PICKS',
                                accent: Cyber.success,
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_up,
                                  color: Cyber.success,
                                  size: 22,
                                ),
                                stats: [
                                  _Stat('PICKS', '${picks.positions.length}'),
                                  _Stat('WIN RATE', '$pickAccuracy%'),
                                  _Stat(
                                    'ACTIVE',
                                    '${picks.activePositionCount}',
                                  ),
                                ],
                                onViewHistory: () =>
                                    showPredictionPicksHistory(context),
                              ),
                              const SizedBox(height: 16),
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
                                  (nav) => HowToPlayScreen(onNavigate: nav),
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

    final hasContent = report.content.isNotEmpty;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            hasContent
                ? 'Report submitted: ${report.description}'
                : 'Report submitted',
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

// ─── Identity header ──────────────────────────────────────────────────────────

/// The banner-headed identity card: soft pastel header, avatar + level badge,
/// and player name.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _ProfilePastel.header,
            border: Border(
              bottom: BorderSide(color: Cyber.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EmblemBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _Avatar(),
                        const Spacer(),
                        PlayerLevelBadge(progression: game.progression),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PLAYER ONE',
                      style: Cyber.display(24, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LVL ${game.progression.playerLevel} · ${game.progression.totalXP} XP',
                      style: Cyber.label(
                        11,
                        color: Cyber.muted,
                        letterSpacing: 1,
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

/// Decorative banner strip with a centred crest on a flat pastel wash.
class _EmblemBanner extends StatelessWidget {
  const _EmblemBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      width: double.infinity,
      child: ColoredBox(
        color: _ProfilePastel.headerBanner,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: _Crest(),
          ),
        ),
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Cyber.bg.withValues(alpha: 0.5),
        border: Border.all(color: Cyber.border),
      ),
      child: const Icon(Icons.shield_moon, color: Cyber.cyan, size: 32),
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
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Cyber.panel,
                border: Border.all(color: Cyber.border, width: 2),
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
                  customBorder: const CircleBorder(),
                  splashColor: Cyber.cyan.withValues(alpha: 0.18),
                  highlightColor: Cyber.cyan.withValues(alpha: 0.10),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Cyber.bg,
                      shape: BoxShape.circle,
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

// ─── Stat section (MY MATCHES / MY PICKS) ─────────────────────────────────────

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
                    border: Border(
                      bottom: BorderSide(color: Cyber.border),
                    ),
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

// Stat section (MY MATCHES / MY PICKS).
class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _StatSection extends StatelessWidget {
  const _StatSection({
    required this.title,
    required this.accent,
    required this.icon,
    required this.stats,
    required this.onViewHistory,
  });

  final String title;
  final Color accent;
  final Widget icon;
  final List<_Stat> stats;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CyberClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ProfilePastel.section(accent),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: 24, height: 24, child: Center(child: icon)),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Cyber.display(20, color: accent, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            // Stat tiles.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _StatTile(
                        stat: stats[i],
                        accent: accent,
                        index: i,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // View History footer.
            _ViewHistoryRow(accent: accent, onTap: onViewHistory),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.stat,
    required this.accent,
    required this.index,
  });

  final _Stat stat;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      decoration: BoxDecoration(
        color: _ProfilePastel.statTile(accent, index),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Cyber.body(
              10,
              color: Colors.white.withValues(alpha: 0.8),
              weight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              style: Cyber.display(
                24,
                letterSpacing: 0.5,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewHistoryRow extends StatelessWidget {
  const _ViewHistoryRow({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: accent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'View History',
                  style: Cyber.body(15, weight: FontWeight.w600),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Cyber.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── HUD navigation rows ──────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  static const _borderColor = Cyber.border;

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
            border: Border.all(color: _borderColor),
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

// ─── Crossed-swords glyph (MY MATCHES) ────────────────────────────────────────

/// The crossed-swords glyph used for the MATCHES tab on the prediction hub,
/// reused here so MY MATCHES carries the same icon language as the design.
class _CrossedSwords extends StatelessWidget {
  const _CrossedSwords({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CrossedSwordsPainter(Cyber.violet)),
    );
  }
}

class _CrossedSwordsPainter extends CustomPainter {
  const _CrossedSwordsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final blade = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guard = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.22, h * 0.84),
      Offset(w * 0.82, h * 0.18),
      blade,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.84),
      Offset(w * 0.18, h * 0.18),
      blade,
    );
    canvas.drawLine(
      Offset(w * 0.12, h * 0.66),
      Offset(w * 0.34, h * 0.84),
      guard,
    );
    canvas.drawLine(
      Offset(w * 0.66, h * 0.84),
      Offset(w * 0.88, h * 0.66),
      guard,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossedSwordsPainter old) => old.color != color;
}
