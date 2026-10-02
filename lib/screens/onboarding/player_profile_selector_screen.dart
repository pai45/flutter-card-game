import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';

/// The two local-player routes available after leaving Profile settings.
enum PlayerProfileChoice { firstTime, returning }

/// Keeps logout player-friendly: a fresh identity and a saved career are
/// explicit choices instead of immediately wiping the setup state.
///
/// The switchboard always knows [activeProfile] — the career the player is
/// logged into right now. That slot is badged ACTIVE and its CTA only backs
/// out of the switchboard, while the *other* slot stays tappable even when it
/// is blank (an empty slot is the "log out and start a new career" route).
/// Without this the common solo-player case dead-ends: the slot you are
/// already in is the only enabled button, and taking it drops you straight
/// back into the same career, so logging out appears to do nothing.
class PlayerProfileSelectorScreen extends StatefulWidget {
  const PlayerProfileSelectorScreen({
    required this.onSelect,
    required this.activeProfile,
    required this.firstTimeProfileReady,
    required this.returningProfileReady,
    this.firstTimeSummary,
    this.returningSummary,
    super.key,
  });

  final Future<void> Function(PlayerProfileChoice) onSelect;

  /// The save slot currently loaded into the app.
  final PlayerProfileChoice activeProfile;
  final bool firstTimeProfileReady;
  final bool returningProfileReady;
  final LocalProfileSummary? firstTimeSummary;
  final LocalProfileSummary? returningSummary;

  @override
  State<PlayerProfileSelectorScreen> createState() =>
      _PlayerProfileSelectorScreenState();
}

class _PlayerProfileSelectorScreenState
    extends State<PlayerProfileSelectorScreen> {
  bool _selecting = false;
  bool _switchFailed = false;

  Future<void> _choose(PlayerProfileChoice choice) async {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _switchFailed = false;
    });
    try {
      await widget.onSelect(choice);
    } catch (_) {
      if (!mounted) return;
      setState(() => _switchFailed = true);
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  bool _isReady(PlayerProfileChoice choice) =>
      choice == PlayerProfileChoice.firstTime
      ? widget.firstTimeProfileReady
      : widget.returningProfileReady;

  String _description(PlayerProfileChoice choice) {
    if (_switchFailed) {
      return 'Profile switch interrupted. Your current career is safe — retry.';
    }
    if (choice == widget.activeProfile) {
      return 'You are playing this career right now.';
    }
    if (_isReady(choice)) {
      final summary = choice == PlayerProfileChoice.firstTime
          ? widget.firstTimeSummary
          : widget.returningSummary;
      if (summary != null) {
        return '${summary.displayName} // LV ${summary.level} // ${summary.streak} DAY STREAK';
      }
      return choice == PlayerProfileChoice.firstTime
          ? 'Continue your saved rookie career and streak.'
          : 'Resume your saved career, collection, and progress.';
    }
    return 'Log out and build a new career on this device.';
  }

  String _ctaLabel(PlayerProfileChoice choice) {
    if (_selecting) return 'SWITCHING...';
    if (choice == widget.activeProfile) return 'STAY IN THIS PROFILE';
    if (_isReady(choice)) {
      return choice == PlayerProfileChoice.firstTime
          ? 'CONTINUE ROOKIE PROFILE'
          : 'CONTINUE CAREER';
    }
    return choice == PlayerProfileChoice.firstTime
        ? 'START FRESH'
        : 'START NEW CAREER';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CyberBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.switch_account,
                      color: Cyber.cyan,
                      size: 28,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PROFILE SELECT',
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        11,
                        color: Cyber.cyan,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'WHO\'S ON THE PITCH?',
                      textAlign: TextAlign.center,
                      style: Cyber.display(24, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose how you want to play. Your saved career stays on this device.',
                      textAlign: TextAlign.center,
                      style: Cyber.bodyFor(context, 14, color: Cyber.muted),
                    ),
                    const SizedBox(height: 28),
                    _choiceCard(
                      choice: PlayerProfileChoice.firstTime,
                      cardKey: const ValueKey('profile_selector_first_time'),
                      icon: Icons.rocket_launch_outlined,
                      title: 'FIRST-TIME PLAYER',
                      accent: Cyber.magenta,
                      ctaIcon: Icons.arrow_forward,
                    ),
                    const SizedBox(height: 12),
                    _choiceCard(
                      choice: PlayerProfileChoice.returning,
                      cardKey: const ValueKey('profile_selector_returning'),
                      icon: Icons.workspace_premium_outlined,
                      title: 'RETURNING PLAYER',
                      accent: Cyber.cyan,
                      ctaIcon: Icons.play_arrow,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'LOCAL PROFILE SWITCH // NO ACCOUNT REQUIRED',
                      textAlign: TextAlign.center,
                      style: Cyber.label(
                        8.5,
                        color: Cyber.muted,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceCard({
    required PlayerProfileChoice choice,
    required Key cardKey,
    required IconData icon,
    required String title,
    required Color accent,
    required IconData ctaIcon,
  }) {
    // THE GLOW RULE: the one focal element is the CTA that actually takes the
    // player somewhere — the slot they are not in. The active slot's "stay"
    // CTA stays a calm outlined plate.
    final isActive = choice == widget.activeProfile;
    return _ProfileChoiceCard(
      key: cardKey,
      icon: icon,
      title: title,
      description: _description(choice),
      accent: accent,
      badge: isActive ? CyberChip(label: 'Active', color: accent) : null,
      child: HudCtaButton(
        label: _ctaLabel(choice),
        icon: isActive ? Icons.close : ctaIcon,
        accent: accent,
        glow: !isActive && !_selecting,
        outlined: isActive,
        tapSound: SoundEffect.cardSelect,
        enabled: !_selecting,
        onTap: () => _choose(choice),
      ),
    );
  }
}

class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.child,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Icon(icon, color: accent, size: 21),
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
                            title,
                            style: Cyber.label(
                              13,
                              color: accent,
                              letterSpacing: 1.45,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Cyber.bodyFor(context, 13, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
