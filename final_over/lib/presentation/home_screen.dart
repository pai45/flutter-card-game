import 'package:flutter/material.dart';

import 'package:final_over/app/theme.dart';
import 'package:final_over/services/services.dart';
import 'widgets/arcade_button.dart';
import 'widgets/stadium_backdrop.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.onPlay,
    required this.onSoundChanged,
    required this.onVibrationChanged,
    this.assetPackage,
  });

  final FinalOverSettings settings;
  final VoidCallback onPlay;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onVibrationChanged;
  final String? assetPackage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StadiumBackdrop(
        dim: .28,
        assetPackage: assetPackage,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ToggleIcon(
                          tooltip: settings.soundEnabled
                              ? 'Sound on'
                              : 'Sound off',
                          icon: settings.soundEnabled
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          active: settings.soundEnabled,
                          onTap: () => onSoundChanged(!settings.soundEnabled),
                        ),
                        const SizedBox(width: 10),
                        _ToggleIcon(
                          tooltip: settings.vibrationEnabled
                              ? 'Vibration on'
                              : 'Vibration off',
                          icon: settings.vibrationEnabled
                              ? Icons.vibration_rounded
                              : Icons.phone_android_rounded,
                          active: settings.vibrationEnabled,
                          onTap: () =>
                              onVibrationChanged(!settings.vibrationEnabled),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.sports_cricket,
                      color: FinalOverPalette.cyan,
                      size: 54,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'FINAL',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: compact ? 42 : 54,
                      ),
                    ),
                    Text(
                      'OVER',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: compact ? 54 : 72,
                        color: FinalOverPalette.cyan,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'CHASE THE TARGET IN SIX LEGAL BALLS',
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 1.3),
                    ),
                    const Spacer(),
                    if (settings.bestScore > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: arcadePanel(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: FinalOverPalette.yellow,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'BEST ${settings.bestScore}  •  ${settings.bestStars}★',
                            ),
                          ],
                        ),
                      ),
                    ArcadeButton(
                      label: 'PLAY FINAL OVER',
                      icon: Icons.play_arrow_rounded,
                      onPressed: onPlay,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const HowToPlayDialog(),
                      ),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('HOW TO PLAY'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: FinalOverPalette.white,
                        side: const BorderSide(color: FinalOverPalette.cyan),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon),
        color: active ? FinalOverPalette.cyan : FinalOverPalette.muted,
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}

class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('HOW TO PLAY'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HowStep(
            number: '1',
            icon: Icons.swap_vert_circle_rounded,
            text: 'Choose GROUND for safety or LOFT for aerial power.',
          ),
          _HowStep(
            number: '2',
            icon: Icons.touch_app_rounded,
            text: 'Tap OFF, STRAIGHT, or LEG as the ball reaches the batter.',
          ),
          _HowStep(
            number: '3',
            icon: Icons.directions_run_rounded,
            text:
                'After contact, RUN only when the risk indicator is favorable.',
          ),
          _HowStep(
            number: '6',
            icon: Icons.sports_cricket_rounded,
            text:
                'Reach the target before six legal balls or two wickets are used.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('GOT IT'),
        ),
      ],
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.icon,
    required this.text,
  });
  final String number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: FinalOverPalette.deepBlue,
                foregroundColor: FinalOverPalette.cyan,
                child: Icon(icon, size: 21),
              ),
              Positioned(
                left: -4,
                top: -4,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: FinalOverPalette.yellow,
                  foregroundColor: FinalOverPalette.night,
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
