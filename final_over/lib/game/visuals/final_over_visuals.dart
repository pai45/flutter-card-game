/// Clean-room, domain-independent Canvas artwork for Final Over.
///
/// All animated components accept a normalized progress value supplied by the
/// caller. They intentionally create no timers or controllers, which keeps
/// rendering deterministic and straightforward to drive from Flame or Flutter.
library;

export 'artifacts.dart';
export 'backgrounds.dart';
export 'branding.dart';
export 'characters.dart';
export 'effects.dart';
export 'final_over_palette.dart';
