import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/followable_leagues.dart';
import '../../models/avatar_option.dart';
import '../../models/profile_banner_option.dart';
import '../../models/sport_match.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
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
                  child: Center(
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
            Positioned.fill(
              child: _ProfileLockedReveal(
                avatarId: _avatarId,
                bannerId: _bannerId,
                followed: _followed,
                favoriteTeams: _favoriteTeams,
                onEnter: _emit,
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
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: 1.18,
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

/// A league pick — no panel/border. Just the picks-page-style league mark and
/// name; selection glows and brightens, unselected reads dim.
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
    return PressableScale(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: selected ? 1 : 0.55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: selected ? 1.06 : 1,
              child: _LeagueMark(
                code: league.shortCode,
                color: league.accent,
                selected: selected,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              league.name.toUpperCase(),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Cyber.display(
                12,
                color: selected ? Colors.white : Cyber.muted,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${entry.teams.length} TEAMS',
              style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Angled-cut, hard-base league badge — the picks-page `_LeagueMark` look,
/// scaled up for selection. Selected adds a lime check + glow.
class _LeagueMark extends StatelessWidget {
  const _LeagueMark({
    required this.code,
    required this.color,
    required this.selected,
  });

  final String code;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.48
        ? const Color(0xff07111e)
        : Colors.white;
    return SizedBox(
      width: 64,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: selected
                  ? Cyber.glow(Cyber.lime, alpha: 0.3, blur: 16, spread: -2)
                  : null,
            ),
            child: CustomPaint(
              size: const Size(64, 56),
              painter: _LeagueMarkPainter(color: color),
              child: Center(
                child: Text(
                  code,
                  style: Cyber.display(20, color: ink, letterSpacing: 0.5)
                      .copyWith(
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
          ),
          if (selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Cyber.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Cyber.bg, size: 15),
              ),
            ),
        ],
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
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 14,
          childAspectRatio: 0.84,
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

/// A team pick — no panel/border. Just the team badge + name; selection glows,
/// scales up and adds a check, unselected reads dim.
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
    return Semantics(
      button: true,
      selected: selected,
      label: team.name,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: selected ? 1 : 0.58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: selected ? 1.1 : 1,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: selected
                            ? Cyber.glow(
                                Cyber.lime,
                                alpha: 0.32,
                                blur: 16,
                                spread: -3,
                              )
                            : null,
                      ),
                      child: TeamLogo(team: team, width: 52, height: 56),
                    ),
                    if (selected)
                      Positioned(
                        top: -6,
                        right: -8,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Cyber.lime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Cyber.bg,
                            size: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                team.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Cyber.label(
                  9,
                  color: selected ? Colors.white : Cyber.muted,
                  letterSpacing: 0.8,
                ),
              ),
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
class _ProfileLockedReveal extends StatefulWidget {
  const _ProfileLockedReveal({
    required this.avatarId,
    required this.bannerId,
    required this.followed,
    required this.favoriteTeams,
    required this.onEnter,
  });

  final String avatarId;
  final String bannerId;
  final List<FollowableLeague> followed;
  final Map<String, String> favoriteTeams;
  final VoidCallback onEnter;

  @override
  State<_ProfileLockedReveal> createState() => _ProfileLockedRevealState();
}

class _ProfileLockedRevealState extends State<_ProfileLockedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  late final Animation<double> _cardScale = Tween<double>(
    begin: 1.55,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.5, curve: Curves.elasticOut)),
  );
  late final Animation<double> _cardOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.12),
  );
  late final Animation<double> _shock = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _titleOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.16, 0.42),
  );
  late final Animation<double> _titleSlide = Tween<double>(
    begin: -22,
    end: 0,
  ).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.16, 0.5, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _ctaOpacity = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.72, 1),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<SportTeam> get _favTeams => [
    for (final entry in widget.followed)
      if (widget.favoriteTeams[entry.league.id] != null)
        followableTeam(entry.league.id, widget.favoriteTeams[entry.league.id]!)!,
  ];

  @override
  Widget build(BuildContext context) {
    final avatar = avatarOptionById(widget.avatarId);
    final banner = profileBannerOptionById(widget.bannerId);
    final teams = _favTeams;
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, _) => Transform.translate(
                      offset: Offset(0, _titleSlide.value),
                      child: Opacity(
                        opacity: _titleOpacity.value.clamp(0.0, 1.0),
                        child: Text(
                          'PROFILE LOCKED IN',
                          textAlign: TextAlign.center,
                          style: Cyber.display(
                            26,
                            color: Cyber.lime,
                            letterSpacing: 1.6,
                          ).copyWith(
                            shadows: [
                              const Shadow(color: Cyber.lime, blurRadius: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  // Shockwave ring + the slamming identity card.
                  SizedBox(
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shock,
                            builder: (_, _) => CustomPaint(
                              painter: _RevealShockwavePainter(
                                progress: _shock.value,
                                color: Cyber.lime,
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (_, child) => Opacity(
                            opacity: _cardOpacity.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _cardScale.value,
                              child: child,
                            ),
                          ),
                          child: _IdentityCard(avatar: avatar, banner: banner),
                        ),
                      ],
                    ),
                  ),
                  if (teams.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'FOLLOWING',
                      style: Cyber.label(
                        11,
                        color: Cyber.muted,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < teams.length; i++)
                          CyberDealtCard(
                            index: i,
                            initialDelay: const Duration(milliseconds: 620),
                            child: TeamLogo(
                              team: teams[i],
                              width: 44,
                              height: 48,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _ctaOpacity,
                    child: HudCtaButton(
                      label: 'ENTER PITCH DUEL',
                      icon: Icons.sports_soccer,
                      glow: false,
                      onTap: widget.onEnter,
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

class _RevealShockwavePainter extends CustomPainter {
  const _RevealShockwavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final maxR = size.longestSide * 0.62;
    final radius = maxR * progress;
    final alpha = (1 - progress) * 0.5;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - progress) + 0.6
        ..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _RevealShockwavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.avatar, required this.banner});

  final AvatarOption avatar;
  final ProfileBannerOption banner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Cyber.cyan, width: 1.4),
                boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.3, blur: 22),
              ),
              child: ProfileBannerVisual(option: banner),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Cyber.panel,
                border: Border.all(color: Cyber.cyan, width: 2),
                boxShadow: Cyber.glow(Cyber.cyan, alpha: 0.35),
              ),
              child: ClipRect(
                child: Image.asset(
                  avatar.assetPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
