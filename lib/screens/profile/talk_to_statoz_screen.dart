import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/game_scaffold.dart';

/// Direct-line feedback hub: pick a channel, compose a transmission, send.
class TalkToStatozScreen extends StatelessWidget {
  const TalkToStatozScreen({required this.onNavigate, super.key});

  final ValueChanged<AppSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Talk to StatOz',
      subtitle: '// 1:1 Direct Line',
      leading: IconButton(
        onPressed: () => onNavigate(AppSection.profile),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(
            'OPEN A CHANNEL',
            style: Cyber.label(11, color: Cyber.cyan, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a channel. We read every transmission.',
            style: Cyber.body(12.5, color: AppTheme.text2, height: 1.4),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < _channels.length; i++) ...[
            _ChannelCard(channel: _channels[i], index: i),
            if (i < _channels.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ── Channel card ─────────────────────────────────────────────────────────────

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.index});

  final _Channel channel;
  final int index;

  @override
  Widget build(BuildContext context) {
    final channelNo = (index + 1).toString().padLeft(2, '0');
    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ComposeTransmissionScreen(channel: channel),
          ),
        );
      },
      child: CyberPanel(
        accent: channel.accent,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _IconTile(icon: channel.icon, accent: channel.accent, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.title,
                    style: Cyber.display(15, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    channel.tagline,
                    style: Cyber.body(12, color: AppTheme.text2, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  _MetaTag(
                    label: 'CHANNEL $channelNo',
                    accent: channel.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: channel.accent.withValues(alpha: 0.8),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Cyber.label(8, color: accent, letterSpacing: 1.2),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.accent,
    required this.size,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Icon(icon, color: accent, size: size * 0.5),
    );
  }
}

// ── Compose transmission ─────────────────────────────────────────────────────

class _ComposeTransmissionScreen extends StatefulWidget {
  const _ComposeTransmissionScreen({required this.channel});

  final _Channel channel;

  @override
  State<_ComposeTransmissionScreen> createState() =>
      _ComposeTransmissionScreenState();
}

class _ComposeTransmissionScreenState extends State<_ComposeTransmissionScreen> {
  final _summary = TextEditingController();
  final _details = TextEditingController();

  bool _submittedEmpty = false;
  bool _showSentOverlay = false;

  @override
  void dispose() {
    _summary.dispose();
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    final summary = _summary.text.trim();
    final details = _details.text.trim();

    if (summary.isEmpty || details.isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _submittedEmpty = true);
      return;
    }

    HapticFeedback.mediumImpact();
    // Local stub — no backend yet.
    setState(() => _showSentOverlay = true);
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return Stack(
      children: [
        GameScaffold(
          title: channel.title,
          subtitle: channel.composeSubtitle,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  children: [
                    CyberPanel(
                      accent: channel.accent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IconTile(
                            icon: channel.icon,
                            accent: channel.accent,
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  channel.title.toUpperCase(),
                                  style: Cyber.display(16, letterSpacing: 0.6),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  channel.composeHint,
                                  style: Cyber.body(
                                    12.5,
                                    color: AppTheme.text2,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _TransmissionField(
                      controller: _summary,
                      label: 'Summary',
                      hint: channel.summaryHint,
                      error:
                          _submittedEmpty && _summary.text.trim().isEmpty,
                    ),
                    const SizedBox(height: 14),
                    _TransmissionField(
                      controller: _details,
                      label: 'Details',
                      hint: channel.detailsHint,
                      maxLines: 6,
                      error:
                          _submittedEmpty && _details.text.trim().isEmpty,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: HudCtaButton(
                  label: 'TRANSMIT',
                  icon: Icons.send,
                  accent: channel.accent,
                  height: 56,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
        if (_showSentOverlay)
          Positioned.fill(
            child: _TransmissionSentOverlay(
              accent: channel.accent,
              channelTitle: channel.title,
              onDone: () {
                if (!mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ),
      ],
    );
  }
}

class _TransmissionField extends StatelessWidget {
  const _TransmissionField({
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
    final borderColor = error ? Cyber.danger : Cyber.border;
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
              borderSide: BorderSide(
                color: error ? Cyber.danger : Cyber.cyan,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sent celebration ─────────────────────────────────────────────────────────

class _TransmissionSentOverlay extends StatefulWidget {
  const _TransmissionSentOverlay({
    required this.accent,
    required this.channelTitle,
    required this.onDone,
  });

  final Color accent;
  final String channelTitle;
  final VoidCallback onDone;

  @override
  State<_TransmissionSentOverlay> createState() =>
      _TransmissionSentOverlayState();
}

class _TransmissionSentOverlayState extends State<_TransmissionSentOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _slammed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _c.addListener(() {
      if (_slammed || _c.value < 0.08) return;
      _slammed = true;
      HapticFeedback.heavyImpact();
    });
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final pop = Curves.elasticOut.transform((t / 0.22).clamp(0.0, 1.0));
        final flash = (1 - t / 0.12).clamp(0.0, 1.0);
        final textIn = ((t - 0.16) / 0.18).clamp(0.0, 1.0);
        final scrim = (t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22)).clamp(
          0.0,
          1.0,
        );
        final accent = widget.accent;

        return Opacity(
          opacity: scrim,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Cyber.bg.withValues(alpha: 0.92)),
                const Positioned.fill(
                  child: IgnorePointer(child: CyberTextureOverlay()),
                ),
                Align(
                  alignment: const Alignment(0, -0.18),
                  child: Transform.scale(
                    scale: pop,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: flash * 0.7,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: Cyber.glow(accent, blur: 28),
                                    gradient: RadialGradient(
                                      colors: [
                                        accent.withValues(alpha: 0.65),
                                        accent.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Cyber.panel,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.85),
                                    width: 2,
                                  ),
                                  boxShadow: Cyber.glow(accent, blur: 18),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: accent,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Opacity(
                          opacity: textIn,
                          child: Column(
                            children: [
                              Text(
                                'TRANSMISSION SENT',
                                style: Cyber.display(
                                  18,
                                  letterSpacing: 1.4,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.channelTitle.toUpperCase(),
                                style: Cyber.label(
                                  11,
                                  color: Cyber.muted,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Signal locked. We\'ll take it from here.',
                                textAlign: TextAlign.center,
                                style: Cyber.body(
                                  13,
                                  color: AppTheme.text2,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _Channel {
  const _Channel({
    required this.id,
    required this.title,
    required this.tagline,
    required this.composeSubtitle,
    required this.composeHint,
    required this.summaryHint,
    required this.detailsHint,
    required this.icon,
    required this.accent,
  });

  final String id;
  final String title;
  final String tagline;
  final String composeSubtitle;
  final String composeHint;
  final String summaryHint;
  final String detailsHint;
  final IconData icon;
  final Color accent;
}

const _channels = <_Channel>[
  _Channel(
    id: 'bug',
    title: 'Bug',
    tagline: 'Something broke, crashed, or refused to load.',
    composeSubtitle: '// Channel 01 · Defect Signal',
    composeHint:
        'Tell us what you tapped, what you expected, and what actually happened.',
    summaryHint: 'Short summary of the bug',
    detailsHint: 'Steps to reproduce, screens, match IDs…',
    icon: Icons.bug_report,
    accent: Cyber.danger,
  ),
  _Channel(
    id: 'feature',
    title: 'Feature Request',
    tagline: 'A mode, tool, or unlock you want on the pitch.',
    composeSubtitle: '// Channel 02 · New Build',
    composeHint: 'Pitch the feature. What would it unlock for you?',
    summaryHint: 'Name the feature',
    detailsHint: 'How should it work? Why does it matter?',
    icon: Icons.auto_awesome,
    accent: Cyber.cyan,
  ),
  _Channel(
    id: 'feedback',
    title: 'Feedback & Enhancements',
    tagline: 'Polish, friction, or UX that could hit harder.',
    composeSubtitle: '// Channel 03 · Tuning Pass',
    composeHint: 'Call out what feels off — or what almost nails it.',
    summaryHint: 'What should we tune?',
    detailsHint: 'Where in the app? What would feel better?',
    icon: Icons.tune,
    accent: Cyber.violet,
  ),
  _Channel(
    id: 'mismatch',
    title: 'Score / Data Mismatch',
    tagline: 'Wrong score, odds, lineup, or live feed drift.',
    composeSubtitle: '// Channel 04 · Data Sync',
    composeHint:
        'Flag the fixture, market, or stat that doesn\'t match reality.',
    summaryHint: 'Match / market that looks wrong',
    detailsHint: 'What did you see vs what should it be?',
    icon: Icons.sync_problem,
    accent: Cyber.amber,
  ),
  _Channel(
    id: 'shoutout',
    title: 'Shoutout',
    tagline: 'Love a moment, mode, or beat? Send it up.',
    composeSubtitle: '// Channel 05 · Fan Signal',
    composeHint: 'Tell us what slapped. We live for these.',
    summaryHint: 'What made you cheer?',
    detailsHint: 'Share the moment — mode, card, streak, vibe…',
    icon: Icons.favorite,
    accent: Cyber.gold,
  ),
];
