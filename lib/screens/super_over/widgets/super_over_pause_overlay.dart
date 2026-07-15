import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/super_over.dart';

class SuperOverPauseOverlay extends StatelessWidget {
  const SuperOverPauseOverlay({
    required this.settings,
    required this.onSettingsChanged,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    super.key,
  });

  final SuperOverSettings settings;
  final ValueChanged<SuperOverSettings> onSettingsChanged;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    required VoidCallback onConfirmed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Cyber.panel,
        title: Text(title, style: Cyber.display(17, color: Colors.white)),
        content: Text(body, style: Cyber.body(12, color: Cyber.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cyber.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cyber.bg.withValues(alpha: .94),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Cyber.panel,
                  border: Border.all(color: Cyber.cyan, width: 1.4),
                  boxShadow: Cyber.glow(Cyber.cyan, alpha: .16, blur: 26),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'MATCH PAUSED',
                        textAlign: TextAlign.center,
                        style: Cyber.display(20, color: Colors.white),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'The current delivery is frozen safely.',
                        textAlign: TextAlign.center,
                        style: Cyber.body(11, color: Cyber.muted),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: onResume,
                        style: FilledButton.styleFrom(
                          backgroundColor: Cyber.lime,
                          foregroundColor: Cyber.bg,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('RESUME', style: Cyber.display(10)),
                      ),
                      const SizedBox(height: 14),
                      _SectionLabel('CONTROLS & ACCESSIBILITY'),
                      _SwitchRow(
                        label: 'Left-handed layout',
                        value: settings.leftHandedControls,
                        onChanged: (value) => onSettingsChanged(
                          settings.copyWith(leftHandedControls: value),
                        ),
                      ),
                      _SwitchRow(
                        label: 'Large Field Radar',
                        value: settings.largerFieldRadar,
                        onChanged: (value) => onSettingsChanged(
                          settings.copyWith(largerFieldRadar: value),
                        ),
                      ),
                      _SwitchRow(
                        label: 'Reduced motion',
                        value: settings.reducedMotion,
                        onChanged: (value) => onSettingsChanged(
                          settings.copyWith(reducedMotion: value),
                        ),
                      ),
                      _SliderRow(
                        label: 'BAT size',
                        value: settings.batButtonScale,
                        min: .75,
                        max: 1.5,
                        onChanged: (value) => onSettingsChanged(
                          settings.copyWith(batButtonScale: value),
                        ),
                      ),
                      _SliderRow(
                        label: 'Control opacity',
                        value: settings.controlOpacity,
                        min: .4,
                        max: 1,
                        onChanged: (value) => onSettingsChanged(
                          settings.copyWith(controlOpacity: value),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SectionLabel('AUDIO & FEEDBACK'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ToggleChip(
                            label: 'SOUND',
                            enabled: settings.soundEnabled,
                            onTap: () => onSettingsChanged(
                              settings.copyWith(
                                soundEnabled: !settings.soundEnabled,
                              ),
                            ),
                          ),
                          _ToggleChip(
                            label: 'MUSIC',
                            enabled: settings.musicEnabled,
                            onTap: () => onSettingsChanged(
                              settings.copyWith(
                                musicEnabled: !settings.musicEnabled,
                              ),
                            ),
                          ),
                          _ToggleChip(
                            label: 'CROWD',
                            enabled: settings.crowdEnabled,
                            onTap: () => onSettingsChanged(
                              settings.copyWith(
                                crowdEnabled: !settings.crowdEnabled,
                              ),
                            ),
                          ),
                          _ToggleChip(
                            label: 'HAPTICS',
                            enabled: settings.hapticsEnabled,
                            onTap: () => onSettingsChanged(
                              settings.copyWith(
                                hapticsEnabled: !settings.hapticsEnabled,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => _confirm(
                          context,
                          title: 'RESTART OVER?',
                          body:
                              'This attempt will be abandoned. No XP, mastery, record, or history entry will be created.',
                          action: 'RESTART',
                          onConfirmed: onRestart,
                        ),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('RESTART OVER'),
                      ),
                      TextButton(
                        onPressed: () => _confirm(
                          context,
                          title: 'QUIT TO SUPER OVER?',
                          body:
                              'This unfinished over will be discarded with no rewards or history.',
                          action: 'QUIT',
                          onConfirmed: onQuit,
                        ),
                        child: Text(
                          'QUIT TO SUPER OVER',
                          style: Cyber.display(9, color: Cyber.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(label, style: Cyber.display(9, color: Cyber.cyan)),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    toggled: value,
    child: Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: Cyber.body(11, color: Colors.white)),
        value: value,
        activeThumbColor: Cyber.cyan,
        onChanged: onChanged,
      ),
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: '${(value * 100).round()} percent',
    child: Row(
      children: [
        SizedBox(
          width: 108,
          child: Text(label, style: Cyber.body(10, color: Colors.white)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Cyber.cyan,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: enabled,
    label: label,
    child: FilterChip(
      selected: enabled,
      showCheckmark: false,
      selectedColor: Cyber.cyan.withValues(alpha: .2),
      side: BorderSide(color: enabled ? Cyber.cyan : Cyber.border),
      label: Text(
        label,
        style: Cyber.display(8, color: enabled ? Cyber.cyan : Cyber.muted),
      ),
      onSelected: (_) => onTap(),
    ),
  );
}
