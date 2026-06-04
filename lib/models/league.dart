import 'package:flutter/material.dart';

/// A competition that groups fixtures on the prediction home (e.g. IPL, EPL).
///
/// Pure presentation data for now — sourced from [MockPredictionRepository].
/// When the app goes live this is populated from the backend/sports feed.
class League {
  const League({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.accent,
  });

  final String id;
  final String name;

  /// Compact code shown in section headers (e.g. "IPL", "EPL").
  final String shortCode;

  /// Section accent colour used for headers and dividers.
  final Color accent;
}
