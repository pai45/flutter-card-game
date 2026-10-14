import 'package:card_game/design_system/typography.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/meta.dart';
import 'cyber/cyber_widgets.dart';

class UseCasesPanel extends StatelessWidget {
  const UseCasesPanel({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            label: compact ? 'Use Cases // Quick Read' : 'Use Cases',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < commonUseCases.length; i++) ...[
            AppInfoTile(item: commonUseCases[i], compact: compact),
            if (i < commonUseCases.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}


class FeaturesPanel extends StatelessWidget {
  const FeaturesPanel({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(
            label: compact ? 'Features // React Match' : 'Core Features',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < coreFeatures.length; i++) ...[
            AppInfoTile(item: coreFeatures[i], compact: compact),
            if (i < coreFeatures.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}


class AppInfoTile extends StatelessWidget {
  const AppInfoTile({required this.item, this.compact = false, super.key});

  final AppInfoItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: Border.all(color: item.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.12),
              border: Border.all(color: item.accent.withValues(alpha: 0.34)),
            ),
            child: Icon(item.icon, color: item.accent, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: StatOzTypography.displayFont,
                    fontSize: compact ? 12 : 13,
                    fontWeight: StatOzTypography.black,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(
                    color: Cyber.muted,
                    fontSize: compact ? 11 : 12,
                    fontWeight: StatOzTypography.semibold,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class ProcedureStepTile extends StatelessWidget {
  const ProcedureStepTile({required this.index, required this.body, super.key});

  final int index;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Cyber.cyan.withValues(alpha: 0.14),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.4)),
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: Cyber.cyan,
              fontFamily: StatOzTypography.displayFont,
              fontWeight: StatOzTypography.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xffd1d5db),
                fontSize: StatOzTypography.p12,
                fontWeight: StatOzTypography.semibold,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class MiniStat extends StatelessWidget {
  const MiniStat(this.label, this.value, this.ok, {super.key});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: StatOzTypography.p9,
            fontWeight: StatOzTypography.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: ok ? Cyber.cyan : Cyber.amber,
            fontFamily: StatOzTypography.displayFont,
            fontSize: StatOzTypography.p18,
            fontWeight: StatOzTypography.black,
          ),
        ),
      ],
    );
  }
}

