import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';

/// The two local-player routes available after leaving Profile settings.
enum PlayerProfileChoice { firstTime, returning }

/// Keeps logout player-friendly: a fresh identity and a saved career are
/// explicit choices instead of immediately wiping the setup state.
class PlayerProfileSelectorScreen extends StatelessWidget {
  const PlayerProfileSelectorScreen({
    required this.onSelect,
    required this.firstTimeProfileReady,
    required this.returningProfileReady,
    super.key,
  });

  final ValueChanged<PlayerProfileChoice> onSelect;
  final bool firstTimeProfileReady;
  final bool returningProfileReady;

  void _choose(PlayerProfileChoice choice) => onSelect(choice);

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
                      style: Cyber.body(14, color: Cyber.muted),
                    ),
                    const SizedBox(height: 28),
                    _ProfileChoiceCard(
                      key: const ValueKey('profile_selector_first_time'),
                      icon: Icons.rocket_launch_outlined,
                      title: 'FIRST-TIME PLAYER',
                      description: firstTimeProfileReady
                          ? 'Continue your saved rookie career and streak.'
                          : 'Build a fresh identity and choose your home sport.',
                      accent: Cyber.magenta,
                      child: HudCtaButton(
                        label: firstTimeProfileReady
                            ? 'CONTINUE ROOKIE PROFILE'
                            : 'START FRESH',
                        icon: Icons.arrow_forward,
                        accent: Cyber.magenta,
                        glow: false,
                        outlined: true,
                        tapSound: SoundEffect.cardSelect,
                        onTap: () => _choose(PlayerProfileChoice.firstTime),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ProfileChoiceCard(
                      key: const ValueKey('profile_selector_returning'),
                      icon: Icons.workspace_premium_outlined,
                      title: 'RETURNING PLAYER',
                      description: returningProfileReady
                          ? 'Resume your saved career, collection, and progress.'
                          : 'No saved career is available on this device yet.',
                      accent: Cyber.cyan,
                      child: HudCtaButton(
                        label: returningProfileReady
                            ? 'CONTINUE CAREER'
                            : 'NO SAVED CAREER',
                        icon: Icons.play_arrow,
                        accent: Cyber.cyan,
                        tapSound: SoundEffect.cardSelect,
                        enabled: returningProfileReady,
                        onTap: () => _choose(PlayerProfileChoice.returning),
                      ),
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
}

class _ProfileChoiceCard extends StatelessWidget {
  const _ProfileChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final Widget child;

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
                    Text(
                      title,
                      style: Cyber.label(
                        13,
                        color: accent,
                        letterSpacing: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Cyber.body(13, color: Cyber.muted),
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
