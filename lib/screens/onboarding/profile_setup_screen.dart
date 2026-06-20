import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../models/avatar_option.dart';
import '../../models/profile_banner_option.dart';
import '../../models/sport_match.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/profile_banner_visual.dart';
import '../../widgets/team_logo.dart';

/// Everything the player chose during profile setup, handed back to the shell
/// to persist in one shot.
class ProfileSetupResult {
  const ProfileSetupResult({
    required this.avatarId,
    required this.bannerId,
    required this.followedLeagueIds,
    required this.favoriteTeams,
  });

  final String avatarId;
  final String bannerId;
  final List<String> followedLeagueIds;
  final Map<String, String> favoriteTeams;
}

/// First-run "Setting up your profile" wizard: avatar → banner → follow leagues
/// → pick a team per followed league, capped with a card-reveal celebration.
///
/// Sits on the penalty-arena backdrop and is driven by a connected numbered
/// progress stepper (no back button — completed steps are tappable).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.onComplete,
    this.initialAvatarId,
    super.key,
  });

  /// Pre-selected avatar for existing players who already picked one.
  final String? initialAvatarId;
  final ValueChanged<ProfileSetupResult> onComplete;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const int _stepCount = 4;

  int _step = 0;

  late String _avatarId = avatarOptionById(widget.initialAvatarId).id;
  String _bannerId = profileBannerOptions.first.id;
  final List<String> _followedLeagueIds = [];
  final Map<String, String> _favoriteTeams = {};

  // Within the team step, which followed league we're picking a team for.
  int _teamLeagueIndex = 0;
  bool _completing = false;
  // First-run brand splash + WELCOME reveal, shown before the setup steps.
  bool _intro = true;

  List<FollowableLeague> get _followed => [
    for (final entry in followableLeagues)
      if (_followedLeagueIds.contains(entry.league.id)) entry,
  ];

  bool get _isLastVisibleStep {
    if (_step == 2) return _followedLeagueIds.isEmpty;
    if (_step == 3) return _teamLeagueIndex >= _followed.length - 1;
    return false;
  }

  void _next() {
    if (_step == 2 && _followedLeagueIds.isEmpty) {
      _finish();
      return;
    }
    if (_step == 3) {
      if (_teamLeagueIndex < _followed.length - 1) {
        setState(() => _teamLeagueIndex++);
        return;
      }
      _finish();
      return;
    }
    setState(() {
      _step++;
      if (_step == 3) _teamLeagueIndex = 0;
    });
  }

  bool get _canGoBack => _step > 0 || (_step == 3 && _teamLeagueIndex > 0);

  void _back() {
    if (_step == 3 && _teamLeagueIndex > 0) {
      setState(() => _teamLeagueIndex--);
      return;
    }
    if (_step > 0) setState(() => _step--);
  }

  void _skip() {
    if (_step == 2) {
      setState(() {
        _followedLeagueIds.clear();
        _favoriteTeams.clear();
      });
      _finish();
      return;
    }
    _next();
  }

  void _finish() => setState(() => _completing = true);

  void _emit() {
    widget.onComplete(
      ProfileSetupResult(
        avatarId: _avatarId,
        bannerId: _bannerId,
        followedLeagueIds: List.unmodifiable(_followedLeagueIds),
        favoriteTeams: Map.unmodifiable(_favoriteTeams),
      ),
    );
  }

  void _toggleLeague(String leagueId) {
    setState(() {
      if (_followedLeagueIds.remove(leagueId)) {
        _favoriteTeams.remove(leagueId);
      } else {
        _followedLeagueIds.add(leagueId);
      }
    });
  }

  String get _skipLabel => _step == 3 ? 'DECIDE LATER' : 'SKIP';
  String get _ctaLabel => _isLastVisibleStep ? 'FINISH SETUP' : 'NEXT';

  String get _helperText => switch (_step) {
    0 => 'STEP 1 OF 4 // CHOOSE THE FACE FOR YOUR DOSSIER',
    1 => 'STEP 2 OF 4 // SET YOUR BANNER COLOURS',
    2 => 'STEP 3 OF 4 // FOLLOW LEAGUES — OPTIONAL',
    _ => 'STEP 4 OF 4 // LEAGUE ${_teamLeagueIndex + 1} OF ${_followed.length}',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _OnboardingArenaBackground()),
          SafeArea(
            child: Column(
              children: [
                _SetupTopBar(skipLabel: _skipLabel, onSkip: _skip),
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: KeyedSubtree(
                        key: ValueKey('step_${_step}_$_teamLeagueIndex'),
                        child: CyberSlideUpFadeIn(child: _buildStepBody()),
                      ),
                    ),
                  ),
                ),
                _SetupDock(
                  activeStep: _step,
                  stepCount: _stepCount,
                  ctaLabel: _ctaLabel,
                  isNext: !_isLastVisibleStep,
                  canGoPrevious: _canGoBack,
                  helper: _helperText,
                  onPrevious: _back,
                  onNext: _next,
                ),
              ],
            ),
          ),
          if (_completing)
            Positioned.fill(child: _LaunchSequence(onEnter: _emit)),
          if (_intro)
            Positioned.fill(
              child: _LaunchIntro(
                onDone: () => setState(() => _intro = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepBody() => switch (_step) {
    0 => _AvatarStep(
      selectedId: _avatarId,
      onSelect: (id) => setState(() => _avatarId = id),
    ),
    1 => _BannerStep(
      selectedId: _bannerId,
      onSelect: (id) => setState(() => _bannerId = id),
    ),
    2 => _LeaguesStep(followedIds: _followedLeagueIds, onToggle: _toggleLeague),
    _ => _TeamsStep(
      league: _followed[_teamLeagueIndex],
      index: _teamLeagueIndex,
      total: _followed.length,
      selectedTeamId: _favoriteTeams[_followed[_teamLeagueIndex].league.id],
      onSelect: (teamId) => setState(
        () => _favoriteTeams[_followed[_teamLeagueIndex].league.id] = teamId,
      ),
    ),
  };
}

// ─── Background ───────────────────────────────────────────────────────────────

/// The penalty-arena backdrop (drifting image + gradient bed + HUD texture),
/// mirroring the shootout landing so onboarding feels part of the same arena.
class _OnboardingArenaBackground extends StatefulWidget {
  const _OnboardingArenaBackground();

  @override
  State<_OnboardingArenaBackground> createState() =>
      _OnboardingArenaBackgroundState();
}

class _OnboardingArenaBackgroundState extends State<_OnboardingArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff02060f), Color(0xff06121f), Color(0xff01040a)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final phase = _controller.value * math.pi * 2;
                return Transform.translate(
                  offset: Offset(math.sin(phase) * 6, math.cos(phase) * 4),
                  child: Transform.scale(
                    scale: 1.06 + 0.008 * math.sin(phase * 2),
                    child: child,
                  ),
                );
              },
              child: Opacity(
                opacity: 0.34,
                child: Image.asset(
                  'assets/backgrounds/penalty_arena.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Cyber.bg.withValues(alpha: 0.5),
                    Cyber.bg.withValues(alpha: 0.32),
                    Cyber.bg.withValues(alpha: 0.78),
                  ],
                  stops: const [0.0, 0.46, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CyberTextureOverlay()),
        ],
      ),
    );
  }
}

// ─── Chrome ───────────────────────────────────────────────────────────────────

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({required this.skipLabel, required this.onSkip});

  final String skipLabel;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(18, 0, 10, 0),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.55),
        border: const Border(
          bottom: BorderSide(color: Cyber.cyan, width: 1.4),
        ),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 22, color: Cyber.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROFILE SETUP',
                  style: Cyber.display(15, letterSpacing: 1.6),
                ),
                Text(
                  'SYS://OPERATIVE-INIT',
                  style: Cyber.label(
                    8,
                    color: Cyber.cyan.withValues(alpha: 0.7),
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: Cyber.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              skipLabel,
              style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom dock mirroring the prediction quiz: a row of progress segments
/// (green = passed, amber = current, slate = pending) over a PREVIOUS / NEXT
/// pair (`HudPagerButton`) and a contextual helper line.
class _SetupDock extends StatelessWidget {
  const _SetupDock({
    required this.activeStep,
    required this.stepCount,
    required this.ctaLabel,
    required this.isNext,
    required this.canGoPrevious,
    required this.helper,
    required this.onPrevious,
    required this.onNext,
  });

  final int activeStep;
  final int stepCount;
  final String ctaLabel;
  final bool isNext;
  final bool canGoPrevious;
  final String helper;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < stepCount; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: HudProgressSegment(
                          answered: i < activeStep,
                          current: i == activeStep,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (canGoPrevious) ...[
                      Expanded(
                        child: HudPagerButton(
                          label: 'PREVIOUS',
                          leadingIcon: Icons.arrow_back,
                          focal: false,
                          enabled: true,
                          onTap: onPrevious,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: HudPagerButton(
                        label: ctaLabel,
                        trailingIcon: isNext ? Icons.arrow_forward : null,
                        focal: true,
                        enabled: true,
                        onTap: onNext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  helper,
                  textAlign: TextAlign.center,
                  style: Cyber.body(12, color: const Color(0xFF90A1B9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Steps ──────────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  const _StepShell({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Cyber.display(23, letterSpacing: 1.0)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Cyber.body(13, color: Cyber.muted)),
          ],
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AvatarStep extends StatelessWidget {
  const _AvatarStep({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'CHOOSE YOUR AVATAR',
      subtitle: 'This is the face other operatives will see.',
      child: GridView.builder(
        itemCount: avatarOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final avatar = avatarOptions[index];
          return CyberDealtCard(
            index: index,
            child: _AvatarTile(
              avatar: avatar,
              selected: avatar.id == selectedId,
              onTap: () => onSelect(avatar.id),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
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
              if (selected) const SelectedCheckCorner(size: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerStep extends StatelessWidget {
  const _BannerStep({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'CHOOSE YOUR BANNER',
      subtitle: 'The colours that fly behind your dossier.',
      child: GridView.builder(
        itemCount: profileBannerOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 16,
          childAspectRatio: 2.35,
        ),
        itemBuilder: (context, index) {
          final banner = profileBannerOptions[index];
          return CyberDealtCard(
            index: index,
            child: SelectableBannerTile(
              banner: banner,
              selected: banner.id == selectedId,
              onTap: () => onSelect(banner.id),
            ),
          );
        },
      ),
    );
  }
}

class _LeaguesStep extends StatelessWidget {
  const _LeaguesStep({required this.followedIds, required this.onToggle});

  final List<String> followedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final count = followedIds.length;
    return _StepShell(
      title: 'FOLLOW LEAGUES',
      subtitle: count == 0
          ? 'Pick the competitions you follow — optional.'
          : '$count followed • pick a team for each next.',
      child: GridView.builder(
        itemCount: followableLeagues.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (context, index) {
          final entry = followableLeagues[index];
          return CyberDealtCard(
            index: index,
            child: _LeagueTile(
              entry: entry,
              selected: followedIds.contains(entry.league.id),
              onTap: () => onToggle(entry.league.id),
            ),
          );
        },
      ),
    );
  }
}

/// A league pick — an avatar-style panel tile. Unselected reads as a calm but
/// fully-enabled surface (panel fill + line border); selected gets a lime
/// border, soft glow and the corner check seal — same language as the avatar
/// and banner steps.
class _LeagueTile extends StatelessWidget {
  const _LeagueTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final FollowableLeague entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final league = entry.league;
    final borderColor = selected ? Cyber.lime : AppTheme.onboardingPanelBorder;
    return Semantics(
      button: true,
      selected: selected,
      label: league.name,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppTheme.onboardingPanelFill,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LeagueMark(code: league.shortCode, color: league.accent),
                    const SizedBox(height: 8),
                    Text(
                      league.name.toUpperCase(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(
                        10,
                        color: selected ? Colors.white : Cyber.muted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.teams.length} TEAMS',
                      style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
              if (selected) const SelectedCheckCorner(size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Angled-cut, hard-base league badge — the picks-page `_LeagueMark` look. The
/// selection affordance now lives on the surrounding panel tile, so the mark
/// itself stays neutral.
class _LeagueMark extends StatelessWidget {
  const _LeagueMark({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.48
        ? const Color(0xff07111e)
        : Colors.white;
    return CustomPaint(
      size: const Size(52, 46),
      painter: _LeagueMarkPainter(color: color),
      child: SizedBox(
        width: 52,
        height: 46,
        child: Center(
          child: Text(
            code,
            style: Cyber.display(17, color: ink, letterSpacing: 0.5).copyWith(
              height: 1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picks-page league-mark silhouette: a top-left + bottom-right chamfer,
/// a hard darker base offset down, the colour fill, and a faint white edge.
class _LeagueMarkPainter extends CustomPainter {
  const _LeagueMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cut = 10.0;
    final rect = Offset.zero & Size(size.width, size.height - 3);
    final path = Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
    canvas
      ..drawPath(
        path.shift(const Offset(0, 3)),
        Paint()..color = Color.lerp(color, Colors.black, 0.58)!,
      )
      ..drawPath(path, Paint()..color = color)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.2),
      );
  }

  @override
  bool shouldRepaint(covariant _LeagueMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TeamsStep extends StatelessWidget {
  const _TeamsStep({
    required this.league,
    required this.index,
    required this.total,
    required this.selectedTeamId,
    required this.onSelect,
  });

  final FollowableLeague league;
  final int index;
  final int total;
  final String? selectedTeamId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'PICK YOUR TEAM',
      subtitle:
          'LEAGUE ${index + 1} OF $total  //  ${league.league.name.toUpperCase()}',
      child: GridView.builder(
        itemCount: league.teams.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (context, i) {
          final team = league.teams[i];
          return CyberDealtCard(
            index: i,
            child: _TeamTile(
              team: team,
              selected: team.id == selectedTeamId,
              onTap: () => onSelect(team.id),
            ),
          );
        },
      ),
    );
  }
}

/// A team pick — an avatar-style panel tile. Unselected reads as a calm but
/// fully-enabled surface; selected gets the lime border, soft glow and corner
/// check seal — same language as the avatar and banner steps.
class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final SportTeam team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Cyber.lime : AppTheme.onboardingPanelBorder;
    return Semantics(
      button: true,
      selected: selected,
      label: team.name,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: AppTheme.onboardingPanelFill,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            boxShadow: selected
                ? Cyber.glow(Cyber.lime, alpha: 0.18, blur: 14, spread: -2)
                : null,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: Column(
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
              ),
              if (selected) const SelectedCheckCorner(size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Completion reveal (card-reveal style) ────────────────────────────────────

/// A pack/card-reveal-style celebration: the identity card slams in with a
/// glow burst + shockwave ring, the headline drops, the favourite badges deal
/// in, then the ENTER CTA fades up. Mirrors the language of
/// `CardUnpackAnimation` without its full machinery.
/// The completion cinematic: a 3·2·1 launch countdown (reusing the match-screen
/// [CountdownRing]) that auto-advances into the WELCOME TO STATOZ reveal, which
/// then drops the player into the app. No CTA — tap anywhere to skip ahead.
class _LaunchSequence extends StatefulWidget {
  const _LaunchSequence({required this.onEnter});

  final VoidCallback onEnter;

  @override
  State<_LaunchSequence> createState() => _LaunchSequenceState();
}

class _LaunchSequenceState extends State<_LaunchSequence>
    with SingleTickerProviderStateMixin {
  // Drives the sweeping radar ring on the countdown.
  late final AnimationController _scanner = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  Timer? _tick;
  int _seconds = 3;
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _cue();
    _scheduleNext();
  }

  void _cue() {
    HapticFeedback.mediumImpact();
    playSound(_seconds > 0 ? SoundEffect.commit : SoundEffect.riser);
  }

  void _scheduleNext() {
    // Hold on each number, then a shorter beat on GO before entering the app.
    _tick = Timer(Duration(milliseconds: _seconds > 0 ? 850 : 600), () {
      if (!mounted) return;
      if (_seconds <= 0) {
        _enter();
        return;
      }
      setState(() => _seconds--);
      _cue();
      _scheduleNext();
    });
  }

  // The WELCOME reveal now plays up front (see [_LaunchIntro]); the countdown
  // drops straight into the app.
  void _enter() {
    if (_entered) return;
    _entered = true;
    _tick?.cancel();
    widget.onEnter();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
        const Positioned.fill(child: _OnboardingArenaBackground()),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enter,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SYS://LAUNCH-SEQUENCE',
                      style: Cyber.label(
                        10,
                        color: Cyber.cyan,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    CountdownRing(
                      seconds: _seconds,
                      scanner: _scanner,
                      accent: Cyber.cyan,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'ENTERING STATOZ…',
                      style: Cyber.body(
                        12,
                        color: Cyber.cyan.withValues(alpha: 0.7),
                        weight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The first-run brand splash: the StatOz logo pops in (scale 0→1) and spins to
/// rest, sitting above the WELCOME TO STATOZ wordmark, which then animates in.
/// Auto-advances into profile setup when done; tap to skip straight ahead.
class _LaunchIntro extends StatefulWidget {
  const _LaunchIntro({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<_LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  bool _done = false;
  bool _settled = false;

  // ── Logo: scale pop-in + spin to rest (no opacity fade, no zoom) ──
  late final Animation<double> _appearScale =
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0, 0.22, curve: Curves.easeOutBack),
        ),
      );
  late final Animation<double> _spinTurns = Tween<double>(begin: 0, end: 3)
      .animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0, 0.55, curve: Curves.easeOut),
        ),
      );

  // ── WELCOME TO STATOZ: each line fades + slides up after the spin settles ──
  late final Animation<double> _kickerOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.52, 0.66),
  );
  late final Animation<double> _kickerSlide =
      Tween<double>(begin: 12, end: 0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.52, 0.68, curve: Curves.easeOut),
        ),
      );
  late final Animation<double> _wordOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.64, 0.80),
  );
  late final Animation<double> _wordSlide =
      Tween<double>(begin: 16, end: 0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.64, 0.82, curve: Curves.easeOut),
        ),
      );

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.riser);
    HapticFeedback.heavyImpact();
    _ctrl.forward();
    _ctrl.addListener(_maybeSettle);
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  // A light beat as the spin settles and the wordmark reveals.
  void _maybeSettle() {
    if (!_settled && _ctrl.value >= 0.55) {
      _settled = true;
      HapticFeedback.mediumImpact();
      playSound(SoundEffect.commit);
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Cyber.bg)),
          const Positioned.fill(child: _OnboardingArenaBackground()),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo: pops in and spins to rest in place (no fade, no zoom).
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => Transform.scale(
                        scale: _appearScale.value.clamp(0.0, 1.2),
                        child: Transform.rotate(
                          angle: _spinTurns.value * 2 * math.pi,
                          child: const _LogoMark(size: 150),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => Opacity(
                        opacity: _kickerOpacity.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, _kickerSlide.value),
                          child: Text(
                            'WELCOME TO',
                            style: Cyber.label(
                              13,
                              color: Cyber.muted,
                              letterSpacing: 4.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => Opacity(
                        opacity: _wordOpacity.value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, _wordSlide.value),
                          child: Text(
                            'STATOZ',
                            style:
                                Cyber.display(
                                  54,
                                  color: Cyber.cyan,
                                  letterSpacing: 4.0,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: Cyber.cyan.withValues(alpha: 0.85),
                                      blurRadius: 28,
                                    ),
                                    Shadow(
                                      color: Cyber.cyan.withValues(alpha: 0.4),
                                      blurRadius: 54,
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The StatOz brand logo with a single focal cyan glow — the lockup for the
/// launch splash and welcome reveal. Falls back to the soccer glyph if the
/// asset is missing so it never crashes.
class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.84,
            height: size * 0.84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.22),
              boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.5, blur: size * 0.3),
            ),
          ),
          Image.asset(
            'assets/icons/app_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              Icons.sports_soccer,
              size: size * 0.5,
              color: Cyber.cyan,
            ),
          ),
        ],
      ),
    );
  }
}

