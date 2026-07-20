import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/daily_mystery.dart';
import '../../utils/sound_effects.dart';
import '../game_scaffold.dart';
import 'cyber_cta_button.dart';
import 'cyber_tooltip.dart';
import 'cyber_widgets.dart';

class DailyMysteryDetail {
  const DailyMysteryDetail({required this.label, required this.value});

  final String label;
  final String value;
}

class DailyMysteryLanding extends StatefulWidget {
  const DailyMysteryLanding({
    required this.title,
    required this.subtitle,
    required this.systemLabel,
    required this.systemCode,
    required this.heroTitle,
    required this.heroDescription,
    required this.dayKey,
    required this.accent,
    required this.secondaryAccent,
    required this.icon,
    required this.backdropPainter,
    required this.streak,
    required this.winRate,
    required this.bestHearts,
    required this.wins,
    required this.played,
    required this.ctaLabel,
    required this.loadStatus,
    required this.onBack,
    required this.onOpenToday,
    required this.onOpenLogs,
    required this.onRetry,
    this.errorMessage,
    this.now,
    super.key,
  });

  final String title;
  final String subtitle;
  final String systemLabel;
  final String systemCode;
  final String heroTitle;
  final String heroDescription;
  final String dayKey;
  final Color accent;
  final Color secondaryAccent;
  final IconData icon;
  final CustomPainter backdropPainter;
  final int streak;
  final double winRate;
  final int bestHearts;
  final int wins;
  final int played;
  final String ctaLabel;
  final DailyMysteryLoadStatus loadStatus;
  final String? errorMessage;
  final DateTime Function()? now;
  final VoidCallback onBack;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;
  final VoidCallback onRetry;

  @override
  State<DailyMysteryLanding> createState() => _DailyMysteryLandingState();
}

class _DailyMysteryLandingState extends State<DailyMysteryLanding> {
  Timer? _ticker;
  Duration _untilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = widget.now?.call() ?? DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (mounted) {
      setState(() => _untilReset = tomorrow.difference(now));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: CyberTooltip(
        message: 'NAV // BACK TO GAMES',
        triggerMode: TooltipTriggerMode.longPress,
        child: IconButton(
          onPressed: () {
            playSound(SoundEffect.uiTap);
            widget.onBack();
          },
          icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
        ),
      ),
      rightSlot: Icon(widget.icon, color: widget.accent, size: 22),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (widget.loadStatus == DailyMysteryLoadStatus.loading) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: widget.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (widget.loadStatus == DailyMysteryLoadStatus.error) {
      return CyberNoDataState(
        icon: Icons.sync_problem_rounded,
        title: 'DAILY SIGNAL LOST',
        message:
            widget.errorMessage ?? 'The daily mystery could not be loaded.',
        accent: Cyber.danger,
        actionLabel: 'RETRY LINK',
        actionIcon: Icons.refresh,
        onAction: widget.onRetry,
      );
    }

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.14,
              child: CustomPaint(painter: widget.backdropPainter),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Entrance(
                      reducedMotion: reducedMotion,
                      child: _SystemStrip(
                        label: widget.systemLabel,
                        code: widget.systemCode,
                        accent: widget.accent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Entrance(
                      reducedMotion: reducedMotion,
                      delay: const Duration(milliseconds: 80),
                      child: HudCornerFrame(
                        accent: widget.accent,
                        padding: const EdgeInsets.all(16),
                        child: _LandingHero(
                          title: widget.heroTitle,
                          description: widget.heroDescription,
                          dayKey: widget.dayKey,
                          resetLabel: _formatCountdown(_untilReset),
                          icon: widget.icon,
                          accent: widget.accent,
                          secondaryAccent: widget.secondaryAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Entrance(
                      reducedMotion: reducedMotion,
                      delay: const Duration(milliseconds: 150),
                      child: Row(
                        children: [
                          Expanded(
                            child: DailyMysteryStatTile(
                              label: 'WIN STREAK',
                              value: '${widget.streak}',
                              accent: widget.streak > 0
                                  ? Cyber.success
                                  : Cyber.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DailyMysteryStatTile(
                              label: 'WIN RATE',
                              value: '${(widget.winRate * 100).round()}%',
                              accent: Cyber.cyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DailyMysteryStatTile(
                              label: 'BEST LIVES',
                              value: widget.bestHearts == 0
                                  ? '—'
                                  : '${widget.bestHearts}',
                              accent: Cyber.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Entrance(
                      reducedMotion: reducedMotion,
                      delay: const Duration(milliseconds: 220),
                      child: _AllTimeStrip(
                        wins: widget.wins,
                        played: widget.played,
                        accent: widget.accent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Entrance(
                      reducedMotion: reducedMotion,
                      delay: const Duration(milliseconds: 290),
                      child: HudCtaButton(
                        label: widget.ctaLabel,
                        icon: widget.icon,
                        accent: widget.accent,
                        tapSound: SoundEffect.playMatch,
                        onTap: widget.onOpenToday,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Entrance(
                      reducedMotion: reducedMotion,
                      delay: const Duration(milliseconds: 360),
                      child: DailyMysteryArchiveLink(
                        accent: widget.accent,
                        onTap: widget.onOpenLogs,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.reducedMotion,
    required this.child,
    this.delay = Duration.zero,
  });

  final bool reducedMotion;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion) return child;
    return CyberSlideUpFadeIn(delay: delay, offset: 22, child: child);
  }
}

class _SystemStrip extends StatelessWidget {
  const _SystemStrip({
    required this.label,
    required this.code,
    required this.accent,
  });

  final String label;
  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.84),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.45)),
          right: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Cyber.success,
              shape: BoxShape.circle,
              boxShadow: Cyber.glow(
                Cyber.success,
                alpha: 0.45,
                blur: 8,
                spread: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: Cyber.display(8.5, color: Cyber.success)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: accent.withValues(alpha: 0.2)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(code, style: Cyber.label(7.5, color: Cyber.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero({
    required this.title,
    required this.description,
    required this.dayKey,
    required this.resetLabel,
    required this.icon,
    required this.accent,
    required this.secondaryAccent,
  });

  final String title;
  final String description;
  final String dayKey;
  final String resetLabel;
  final IconData icon;
  final Color accent;
  final Color secondaryAccent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: accent.withValues(alpha: 0.58)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: accent, size: 36),
              Positioned(
                right: 7,
                bottom: 7,
                child: Icon(
                  Icons.lock_rounded,
                  color: secondaryAccent,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Cyber.display(
                  17,
                  color: AppTheme.textPrimary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: Cyber.body(11.5, color: Cyber.muted, height: 1.3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  CyberChip(label: dayKey, color: Cyber.cyan),
                  CyberChip(label: 'RESET $resetLabel', color: accent),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DailyMysteryStatTile extends StatelessWidget {
  const DailyMysteryStatTile({
    required this.label,
    required this.value,
    required this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.border,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            style: Cyber.display(
              16,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(7, color: Cyber.muted, letterSpacing: 0.7),
          ),
        ],
      ),
    );
  }
}

class _AllTimeStrip extends StatelessWidget {
  const _AllTimeStrip({
    required this.wins,
    required this.played,
    required this.accent,
  });

  final int wins;
  final int played;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.9),
        border: Border.all(color: Cyber.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: Cyber.muted, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ALL-TIME ARCHIVE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(8.5, color: Cyber.muted),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$wins WINS  //  $played PLAYED',
                style: Cyber.display(
                  8.5,
                  color: accent,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMysteryArchiveLink extends StatelessWidget {
  const DailyMysteryArchiveLink({
    required this.accent,
    required this.onTap,
    super.key,
  });

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open 30 day archive',
      child: InkWell(
        onTap: () {
          playSound(SoundEffect.uiTap);
          onTap();
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Cyber.panel,
            border: Border.all(color: Cyber.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OPEN 30-DAY ARCHIVE',
                  style: Cyber.display(10.5, color: accent),
                ),
              ),
              const Icon(Icons.chevron_right, color: Cyber.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyMysteryPlayLayout extends StatelessWidget {
  const DailyMysteryPlayLayout({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.secondaryAccent,
    required this.icon,
    required this.dossierLabel,
    required this.dossierTitle,
    required this.dossierDescription,
    required this.details,
    required this.searchLabel,
    required this.options,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.guesses,
    required this.remainingHearts,
    required this.maxHearts,
    required this.damageSerial,
    required this.lockLabel,
    required this.onBack,
    required this.onSelected,
    required this.onCleared,
    required this.onSubmit,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color secondaryAccent;
  final IconData icon;
  final String dossierLabel;
  final String dossierTitle;
  final String dossierDescription;
  final List<DailyMysteryDetail> details;
  final String searchLabel;
  final List<String> options;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? selected;
  final List<String> guesses;
  final int remainingHearts;
  final int maxHearts;
  final int damageSerial;
  final String lockLabel;
  final VoidCallback onBack;
  final ValueChanged<String> onSelected;
  final VoidCallback onCleared;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: title,
      subtitle: subtitle,
      leading: CyberTooltip(
        message: 'NAV // SAVE AND LEAVE',
        triggerMode: TooltipTriggerMode.longPress,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
        ),
      ),
      rightSlot: CyberChip(label: 'LIVE', color: secondaryAccent),
      compactHeader: MediaQuery.sizeOf(context).width < 600,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 620;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 8 : 16,
                    16,
                    compact ? 8 : 20,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DamageFeedback(
                              serial: damageSerial,
                              child: _MysteryDossier(
                                accent: accent,
                                secondaryAccent: secondaryAccent,
                                icon: icon,
                                eyebrow: dossierLabel,
                                title: dossierTitle,
                                description: dossierDescription,
                                details: details,
                                compact: compact,
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 20),
                            Text(
                              searchLabel,
                              style: Cyber.label(8, color: Cyber.muted),
                            ),
                            SizedBox(height: compact ? 4 : 8),
                            DailyMysteryAutocomplete(
                              controller: controller,
                              focusNode: focusNode,
                              options: options,
                              accent: accent,
                              hintText: searchLabel,
                              selected: selected,
                              onSelected: onSelected,
                              onCleared: onCleared,
                              onSubmitted: onSubmit,
                            ),
                            if (guesses.isNotEmpty) ...[
                              SizedBox(height: compact ? 8 : 12),
                              DailyMysteryGuessTrail(
                                guesses: guesses,
                                accent: Cyber.danger,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DailyMysteryActionDock(
                selected: selected != null,
                remainingHearts: remainingHearts,
                maxHearts: maxHearts,
                compact: compact,
                accent: accent,
                lockLabel: lockLabel,
                onSubmit: onSubmit,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DamageFeedback extends StatelessWidget {
  const _DamageFeedback({required this.serial, required this.child});

  final int serial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      key: ValueKey('daily-mystery-damage-$serial'),
      duration: serial == 0 || reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      tween: Tween(begin: serial == 0 ? 0 : 1, end: 0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        final shake = reducedMotion
            ? 0.0
            : math.sin(value * math.pi * 7) * value * 6;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Cyber.danger.withValues(alpha: value * 0.22),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _MysteryDossier extends StatelessWidget {
  const _MysteryDossier({
    required this.accent,
    required this.secondaryAccent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.details,
    required this.compact,
  });

  final Color accent;
  final Color secondaryAccent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final List<DailyMysteryDetail> details;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: secondaryAccent,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Cyber.bg2,
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: accent, size: compact ? 30 : 38),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Icon(
                        Icons.lock_rounded,
                        color: secondaryAccent,
                        size: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(eyebrow, style: Cyber.label(8, color: accent)),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: Cyber.display(
                        compact ? 13 : 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(
                        compact ? 10 : 11.5,
                        color: Cyber.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < details.length; index++) ...[
                Expanded(child: _DetailCell(detail: details[index])),
                if (index < details.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.detail});

  final DailyMysteryDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Cyber.panel2,
        border: Border.all(color: Cyber.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.label(7, color: Cyber.muted),
          ),
          const SizedBox(height: 5),
          Text(
            detail.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Cyber.body(
              10.5,
              color: AppTheme.textPrimary,
              weight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class DailyMysteryAutocomplete extends StatelessWidget {
  const DailyMysteryAutocomplete({
    required this.controller,
    required this.focusNode,
    required this.options,
    required this.accent,
    required this.hintText,
    required this.selected,
    required this.onSelected,
    required this.onCleared,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> options;
  final Color accent;
  final String hintText;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCleared;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return options
            .where((option) => option.toLowerCase().contains(query))
            .take(8);
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (context, textController, fieldFocus, onFieldSubmitted) {
            return TextField(
              controller: textController,
              focusNode: fieldFocus,
              textInputAction: TextInputAction.search,
              style: Cyber.body(
                12,
                color: AppTheme.textPrimary,
                weight: FontWeight.w700,
              ),
              onChanged: (_) {
                if (selected != null) onCleared();
              },
              onSubmitted: (_) {
                if (selected != null) {
                  onSubmitted();
                } else {
                  onFieldSubmitted();
                }
              },
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: Cyber.label(8, color: Cyber.muted),
                filled: true,
                fillColor: Cyber.panel,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: Icon(Icons.search_rounded, color: accent),
                suffixIcon: selected != null
                    ? Icon(Icons.verified_rounded, size: 18, color: accent)
                    : textController.text.isEmpty
                    ? null
                    : CyberTooltip(
                        message: 'DATABASE // CLEAR SEARCH',
                        triggerMode: TooltipTriggerMode.longPress,
                        child: IconButton(
                          onPressed: () {
                            textController.clear();
                            onCleared();
                            fieldFocus.requestFocus();
                          },
                          icon: const Icon(Icons.close, color: Cyber.muted),
                        ),
                      ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Cyber.borderSubtle),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Cyber.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
              ),
            );
          },
      optionsViewBuilder: (context, select, visibleOptions) {
        final items = visibleOptions.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Cyber.bg.withValues(alpha: 0),
            child: Container(
              width: math
                  .min(MediaQuery.sizeOf(context).width - 32, 430)
                  .toDouble(),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Cyber.panel,
                border: Border.all(color: accent.withValues(alpha: 0.6)),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: Cyber.borderSubtle),
                itemBuilder: (context, index) {
                  final option = items[index];
                  final highlighted =
                      AutocompleteHighlightedOption.of(context) == index;
                  return Semantics(
                    button: true,
                    selected: highlighted,
                    label: 'Select $option',
                    child: InkWell(
                      onTap: () => select(option),
                      child: ColoredBox(
                        color: highlighted
                            ? accent.withValues(alpha: 0.1)
                            : Cyber.bg.withValues(alpha: 0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_search_rounded,
                                color: highlighted ? accent : Cyber.muted,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option,
                                  style: Cyber.body(
                                    12,
                                    color: AppTheme.textPrimary,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class DailyMysteryGuessTrail extends StatelessWidget {
  const DailyMysteryGuessTrail({
    required this.guesses,
    required this.accent,
    super.key,
  });

  final List<String> guesses;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTEMPT LOG', style: Cyber.label(7.5, color: Cyber.muted)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < guesses.length; index++) ...[
                CyberChip(
                  label: '${index + 1} · ${guesses[index].toUpperCase()}',
                  color: accent,
                ),
                if (index < guesses.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DailyMysteryActionDock extends StatelessWidget {
  const DailyMysteryActionDock({
    required this.selected,
    required this.remainingHearts,
    required this.maxHearts,
    required this.compact,
    required this.accent,
    required this.lockLabel,
    required this.onSubmit,
    super.key,
  });

  final bool selected;
  final int remainingHearts;
  final int maxHearts;
  final bool compact;
  final Color accent;
  final String lockLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 8 : 14),
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Cyber.borderSubtle)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DailyMysteryAttemptMeter(
                remaining: remainingHearts,
                maximum: maxHearts,
              ),
              SizedBox(height: compact ? 8 : 12),
              HudCtaButton(
                label: selected ? lockLabel : 'SKIP ROUND',
                icon: selected ? Icons.lock_rounded : Icons.flag_rounded,
                height: compact ? 52 : 62,
                accent: selected ? accent : Cyber.danger,
                tapSound: SoundEffect.commit,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onSubmit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyMysteryAttemptMeter extends StatelessWidget {
  const DailyMysteryAttemptMeter({
    required this.remaining,
    required this.maximum,
    super.key,
  });

  final int remaining;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final value = remaining.clamp(0, maximum);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '$value of $maximum lives remaining',
      child: Column(
        children: [
          Row(
            children: [
              Text('LIVES', style: Cyber.label(7.5, color: Cyber.muted)),
              const Spacer(),
              Text(
                '$value / $maximum',
                style: Cyber.display(
                  9,
                  color: Cyber.cyan,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < maximum; index++)
                AnimatedContainer(
                  key: ValueKey('daily-mystery-heart-$index'),
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    index < value ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: index < value
                        ? Cyber.danger
                        : Cyber.muted.withValues(alpha: 0.32),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum DailyMysteryArchiveStatus { live, won, lost, noEntry }

class DailyMysteryArchiveEntry {
  const DailyMysteryArchiveEntry({
    required this.dayKey,
    required this.status,
    required this.prompt,
    required this.detail,
    this.answer,
    this.heartsRemaining,
  });

  final String dayKey;
  final DailyMysteryArchiveStatus status;
  final String prompt;
  final String detail;
  final String? answer;
  final int? heartsRemaining;
}

class DailyMysteryArchiveScreen extends StatelessWidget {
  const DailyMysteryArchiveScreen({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.entries,
    required this.wins,
    required this.played,
    required this.onBack,
    required this.onOpenDay,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<DailyMysteryArchiveEntry> entries;
  final int wins;
  final int played;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final rate = played == 0 ? 0.0 : wins / played;
    return GameScaffold(
      title: title,
      subtitle: subtitle,
      leading: CyberTooltip(
        message: 'NAV // MYSTERY HOME',
        triggerMode: TooltipTriggerMode.longPress,
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
        ),
      ),
      rightSlot: Icon(icon, color: accent, size: 21),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CyberPanel(
                accent: accent,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _ArchiveMetric(
                          label: 'WINS',
                          value: '$wins',
                          accent: Cyber.success,
                        ),
                        const _MetricDivider(),
                        _ArchiveMetric(
                          label: 'PLAYED',
                          value: '$played',
                          accent: Cyber.cyan,
                        ),
                        const _MetricDivider(),
                        _ArchiveMetric(
                          label: 'WIN RATE',
                          value: '${(rate * 100).round()}%',
                          accent: Cyber.gold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CyberProgressBar(
                      value: rate,
                      accent: rate > 0 ? Cyber.success : Cyber.muted,
                      height: 7,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: columns == 2 ? 1.12 : 1.08,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _ArchiveCard(
                      entry: entry,
                      accent: accent,
                      onTap: entry.status == DailyMysteryArchiveStatus.noEntry
                          ? null
                          : () {
                              playSound(SoundEffect.uiTap);
                              onOpenDay(entry.dayKey);
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveMetric extends StatelessWidget {
  const _ArchiveMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Cyber.display(
              17,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 3),
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Cyber.borderSubtle);
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.entry,
    required this.accent,
    required this.onTap,
  });

  final DailyMysteryArchiveEntry entry;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusAccent = switch (entry.status) {
      DailyMysteryArchiveStatus.live => accent,
      DailyMysteryArchiveStatus.won => Cyber.success,
      DailyMysteryArchiveStatus.lost => Cyber.danger,
      DailyMysteryArchiveStatus.noEntry => Cyber.muted,
    };
    final statusLabel = switch (entry.status) {
      DailyMysteryArchiveStatus.live => 'TODAY · LIVE',
      DailyMysteryArchiveStatus.won => 'WON',
      DailyMysteryArchiveStatus.lost => 'LOST',
      DailyMysteryArchiveStatus.noEntry => 'NO ENTRY',
    };
    final statusIcon = switch (entry.status) {
      DailyMysteryArchiveStatus.live => Icons.radar_rounded,
      DailyMysteryArchiveStatus.won => Icons.check_circle_rounded,
      DailyMysteryArchiveStatus.lost => Icons.cancel_rounded,
      DailyMysteryArchiveStatus.noEntry => Icons.lock_clock_rounded,
    };
    return Semantics(
      button: onTap != null,
      label: '${_formatDate(entry.dayKey)}, $statusLabel',
      child: InkWell(
        onTap: onTap,
        child: CyberPanel(
          accent: entry.status == DailyMysteryArchiveStatus.live
              ? accent
              : Cyber.border,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(11),
                  color: Color.alphaBlend(
                    statusAccent.withValues(alpha: 0.06),
                    Cyber.panel,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusAccent, size: 17),
                          const Spacer(),
                          Text(
                            statusLabel,
                            style: Cyber.label(7, color: statusAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _formatDate(entry.dayKey),
                        style: Cyber.display(11.5, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          10.5,
                          color: AppTheme.textPrimary,
                          weight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        entry.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(7, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                color: Cyber.bg2,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.heartsRemaining == null
                            ? 'NO SAVED RESULT'
                            : '${entry.heartsRemaining} LIVES · ${entry.answer}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(7, color: Cyber.muted),
                      ),
                    ),
                    if (onTap != null)
                      Icon(Icons.chevron_right, color: statusAccent, size: 15),
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

class DailyMysteryDebrief extends StatefulWidget {
  const DailyMysteryDebrief({
    required this.title,
    required this.subtitle,
    required this.won,
    required this.freshResult,
    required this.answer,
    required this.promptTitle,
    required this.promptDetail,
    required this.heartsRemaining,
    required this.icon,
    required this.accent,
    required this.onHome,
    required this.onLogs,
    required this.onConsumeReveal,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool won;
  final bool freshResult;
  final String answer;
  final String promptTitle;
  final String promptDetail;
  final int heartsRemaining;
  final IconData icon;
  final Color accent;
  final VoidCallback onHome;
  final VoidCallback onLogs;
  final VoidCallback onConsumeReveal;

  @override
  State<DailyMysteryDebrief> createState() => _DailyMysteryDebriefState();
}

class _DailyMysteryDebriefState extends State<DailyMysteryDebrief> {
  late final bool _fresh = widget.freshResult;

  @override
  void initState() {
    super.initState();
    if (_fresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        playSound(widget.won ? SoundEffect.matchWin : SoundEffect.matchLose);
        if (widget.won) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
        widget.onConsumeReveal();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAccent = widget.won ? Cyber.success : Cyber.danger;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final answer = Text(
      widget.answer.toUpperCase(),
      textAlign: TextAlign.center,
      style: Cyber.display(21, color: AppTheme.textPrimary),
    );
    final answerReveal = reducedMotion || !_fresh
        ? answer
        : TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 680),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, _) {
              return Text(
                value < 0.46
                    ? _encryptedAnswer(widget.answer)
                    : widget.answer.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.display(
                  21,
                  color: AppTheme.textPrimary.withValues(
                    alpha: 0.45 + value * 0.55,
                  ),
                ),
              );
            },
          );
    final livesTile = !widget.won || reducedMotion || !_fresh
        ? DailyMysteryStatTile(
            label: 'LIVES LEFT',
            value: '${widget.heartsRemaining}',
            accent: widget.heartsRemaining > 0 ? Cyber.cyan : Cyber.danger,
          )
        : TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 760),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: widget.heartsRemaining.toDouble()),
            builder: (context, value, _) {
              return DailyMysteryStatTile(
                label: 'LIVES LEFT',
                value: '${value.round()}',
                accent: Cyber.cyan,
              );
            },
          );
    final panel = CyberPanel(
      accent: resultAccent,
      glow: _fresh && widget.won,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Cyber.bg2,
              border: Border.all(color: resultAccent.withValues(alpha: 0.72)),
              boxShadow: _fresh && widget.won
                  ? Cyber.glow(resultAccent, alpha: 0.28, blur: 18)
                  : null,
            ),
            child: Icon(
              widget.won ? Icons.emoji_events_rounded : widget.icon,
              color: resultAccent,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.won ? 'IDENTITY CONFIRMED' : 'IDENTITY DECLASSIFIED',
            textAlign: TextAlign.center,
            style: Cyber.display(18, color: resultAccent),
          ),
          const SizedBox(height: 8),
          answerReveal,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Cyber.panel2,
              border: Border.all(color: Cyber.borderSubtle),
            ),
            child: Column(
              children: [
                Text(
                  widget.promptTitle,
                  textAlign: TextAlign.center,
                  style: Cyber.display(11, color: widget.accent),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.promptDetail,
                  textAlign: TextAlign.center,
                  style: Cyber.body(11, color: Cyber.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: livesTile),
              const SizedBox(width: 10),
              Expanded(
                child: DailyMysteryStatTile(
                  label: 'REWARD',
                  value: widget.won ? '+50 XP' : '—',
                  accent: widget.won ? Cyber.gold : Cyber.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          HudCtaButton(
            label: 'RETURN HOME',
            icon: Icons.home_rounded,
            accent: resultAccent,
            tapSound: SoundEffect.uiTap,
            onTap: widget.onHome,
          ),
          const SizedBox(height: 10),
          DailyMysteryArchiveLink(accent: widget.accent, onTap: widget.onLogs),
        ],
      ),
    );

    return GameScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      leading: CyberTooltip(
        message: 'NAV // MYSTERY HOME',
        triggerMode: TooltipTriggerMode.longPress,
        child: IconButton(
          onPressed: widget.onHome,
          icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
        ),
      ),
      rightSlot: CyberChip(
        label: widget.won ? 'WON' : 'LOST',
        color: resultAccent,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: reducedMotion || !_fresh
                  ? panel
                  : CyberSlideUpFadeIn(offset: 26, child: panel),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCountdown(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _encryptedAnswer(String answer) {
  return answer
      .toUpperCase()
      .split('')
      .map((character) => character.trim().isEmpty ? character : '•')
      .join();
}

String _formatDate(String key) {
  final date = DateTime.tryParse(key);
  if (date == null) return key;
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
