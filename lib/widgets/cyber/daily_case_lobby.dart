import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_widgets.dart';

/// Shared dossier layout for the daily mystery lobbies.
class DailyCaseLobby extends StatelessWidget {
  const DailyCaseLobby({
    required this.dayKey,
    required this.sportLabel,
    required this.sportIcon,
    required this.sportAccent,
    required this.title,
    required this.description,
    required this.status,
    required this.resourceLabel,
    this.resourceTone = CyberStatusTone.reward,
    required this.resetLabel,
    required this.ctaLabel,
    required this.metrics,
    required this.solvedCount,
    required this.playedCount,
    required this.onOpenToday,
    required this.onOpenLogs,
    this.archiveLabel = 'CAREER ARCHIVE',
    this.actionKey,
    this.archiveKey,
    super.key,
  });

  final String dayKey;
  final String sportLabel;
  final IconData sportIcon;
  final Color sportAccent;
  final String title;
  final String description;
  final String status;
  final String resourceLabel;
  final CyberStatusTone resourceTone;
  final String resetLabel;
  final String ctaLabel;
  final List<DailyCaseMetric> metrics;
  final int solvedCount;
  final int playedCount;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenLogs;
  final String archiveLabel;
  final Key? actionKey;
  final Key? archiveKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CyberKitSection(label: 'TODAY\'S CASE', count: dayKey),
                const SizedBox(height: 16),
                ChamferedActionSurface(
                  clipper: const HudChamferClipper(
                    bigCut: CyberKit.cut,
                    smallCut: 0,
                  ),
                  borderColor: Cyber.cyan.withValues(
                    alpha: CyberKit.borderAlpha,
                  ),
                  child: ColoredBox(
                    color: Cyber.panel,
                    child: Padding(
                      padding: const EdgeInsets.all(CyberKit.inset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CyberSportEmblem(
                                icon: sportIcon,
                                accent: sportAccent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$sportLabel // DAILY INTEL',
                                      style: Cyber.label(
                                        9,
                                        color: Cyber.cyan,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      title,
                                      style: Cyber.display(
                                        18,
                                        color: AppTheme.whiteColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            description,
                            style: Cyber.bodyFor(
                              context,
                              14,
                              color: Cyber.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              CyberStatusBadge(label: status),
                              CyberStatusBadge(
                                label: resourceLabel,
                                tone: resourceTone,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: Cyber.line),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: Cyber.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'NEXT CASE IN',
                                  style: Cyber.label(
                                    9,
                                    color: Cyber.muted,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Text(
                                resetLabel,
                                style: Cyber.display(12, color: Cyber.cyan)
                                    .copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                CyberActionButton(
                  key: actionKey,
                  label: ctaLabel,
                  icon: Icons.arrow_forward_rounded,
                  tapSound: SoundEffect.playMatch,
                  onPressed: onOpenToday,
                ),
                const SizedBox(height: 28),
                const CyberKitSection(label: 'YOUR RECORD'),
                const SizedBox(height: 12),
                ChamferedActionSurface(
                  clipper: const HudChamferClipper(
                    bigCut: CyberKit.smallCut,
                    smallCut: 0,
                  ),
                  borderColor: Cyber.line,
                  child: ColoredBox(
                    color: Cyber.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < metrics.length;
                            index++
                          ) ...[
                            if (index > 0) const _MetricDivider(),
                            Expanded(
                              child: _Metric(
                                label: metrics[index].label,
                                value: metrics[index].value,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CyberKitSection(label: archiveLabel),
                const SizedBox(height: 8),
                Text(
                  '$solvedCount SOLVED / $playedCount PLAYED',
                  style: Cyber.bodyFor(context, 12, color: Cyber.muted),
                ),
                const SizedBox(height: 12),
                CyberActionButton(
                  key: archiveKey,
                  label: 'OPEN 30-DAY ARCHIVE',
                  variant: CyberActionVariant.secondary,
                  icon: Icons.history_rounded,
                  onPressed: onOpenLogs,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DailyCaseMetric {
  const DailyCaseMetric(this.label, this.value);

  final String label;
  final String value;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Cyber.display(
              17,
              color: AppTheme.whiteColor,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    ],
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: Cyber.line,
  );
}
