/// Football-specific match metadata supplied by the normalized match package.
class FootballMatchDetails {
  const FootballMatchDetails({
    required this.league,
    required this.season,
    required this.status,
    required this.completed,
    required this.venue,
    required this.city,
    required this.country,
    required this.neutralSite,
    required this.attendance,
    required this.scoreDisplay,
    required this.winner,
    required this.scorers,
    this.shots = const [],
    this.espnEventId,
  });

  final String league;
  final String season;
  final String status;
  final bool completed;
  final String venue;
  final String city;
  final String country;
  final bool neutralSite;
  final int attendance;
  final String scoreDisplay;
  final String? winner;
  final List<FootballScorer> scorers;

  /// Tracked shot positions for the match, in play order. Empty when the feed
  /// supplies no coordinates.
  final List<FootballShot> shots;

  /// The ESPN event this package was extracted from. Used to build per-event
  /// asset URLs (the jersey renders), so it is null for any match that did not
  /// come from ESPN.
  final String? espnEventId;
}

class FootballScorer {
  const FootballScorer({
    required this.id,
    required this.name,
    required this.team,
    required this.teamId,
    required this.minute,
    required this.period,
    required this.type,
    required this.shootout,
    this.assist,
  });

  final String id;
  final String name;
  final String team;
  final String teamId;
  final String minute;
  final int period;
  final String type;
  final String? assist;
  final bool shootout;
}

/// One signed sample in the match-pressure trace. Positive [value] favours the
/// home side, negative favours the away side.
class FootballMomentumPoint {
  const FootballMomentumPoint({
    required this.minute,
    required this.home,
    required this.away,
    required this.value,
  });

  final int minute;
  final double home;
  final double away;
  final double value;
}

class FootballMomentumGoal {
  const FootballMomentumGoal({
    required this.minute,
    required this.axis,
    required this.clock,
    required this.isHomeTeam,
    required this.team,
    required this.player,
  });

  final int minute;
  final int axis;
  final String clock;
  final bool isHomeTeam;
  final String team;
  final String player;
}

class FootballMomentum {
  const FootballMomentum({
    required this.totalMinutes,
    required this.halftimeMinute,
    required this.homeTeam,
    required this.awayTeam,
    required this.series,
    required this.goals,
  });

  final int totalMinutes;
  final int halftimeMinute;
  final String homeTeam;
  final String awayTeam;
  final List<FootballMomentumPoint> series;
  final List<FootballMomentumGoal> goals;

  FootballMomentumPoint? get homePeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value >= b.value ? a : b);
  }

  FootballMomentumPoint? get awayPeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value <= b.value ? a : b);
  }
}

enum FootballShotOutcome { goal, onTarget, offTarget, blocked }

/// One attempt with a tracked pitch position.
///
/// [fieldX] and [fieldY] are the feed's own normalised frame, rescaled to 0..1
/// and always expressed from the shooting side's point of view:
///
/// * [fieldX] is progress towards the goal being attacked — `1` is the goal
///   line, the penalty-area edge sits near `0.83` and six-yard-box efforts land
///   above `0.94`.
/// * [fieldY] runs across the pitch with the attacker's **left** as the high
///   value — left-of-goal attempts sit near `0.68`, central ones near `0.49`
///   and right-of-goal ones near `0.32`.
///
/// Both sides arrive in that same attacking frame and it does not flip at half
/// time, so drawing a full pitch means mirroring one team. Use [pitchOffset]
/// rather than reading the raw fields, so that mirroring stays in one place.
class FootballShot {
  const FootballShot({
    required this.playId,
    required this.minuteLabel,
    required this.minute,
    required this.period,
    required this.isHomeTeam,
    required this.team,
    required this.shooter,
    required this.outcome,
    required this.fieldX,
    required this.fieldY,
    required this.isHeader,
    this.zone,
    this.assist,
    this.netPlacement,
  });

  final String playId;
  final String minuteLabel;
  final int minute;
  final int period;
  final bool isHomeTeam;
  final String team;
  final String shooter;
  final String? assist;
  final FootballShotOutcome outcome;
  final String? zone;
  final double fieldX;
  final double fieldY;
  final bool isHeader;

  /// Where the attempt crossed the goal line, as the viewer faces the goal:
  /// `x` 0 at the left post and 1 at the right, `y` 0 at the crossbar and 1 at
  /// the ground. Values outside 0..1 are misses placed beyond the frame.
  ///
  /// Null when the attempt never reached the goal — every blocked shot, and any
  /// wording the feed uses that we do not recognise. A missing placement is
  /// left missing rather than defaulted to the centre.
  ///
  /// The feed describes placement in prose ("to the bottom left corner") without
  /// saying whose left. Broadcast convention is the viewer's, so that is what
  /// this uses; the feed cannot settle it either way.
  final (double, double)? netPlacement;

  bool get isGoal => outcome == FootballShotOutcome.goal;

  /// Whether the attempt has a placement inside the frame — true for goals and
  /// saves, false for misses (which sit outside it) and blocks (which have none).
  bool get reachedGoalFrame {
    final placement = netPlacement;
    if (placement == null) return false;
    final (x, y) = placement;
    return x >= 0 && x <= 1 && y >= 0 && y <= 1;
  }

  /// Whether the attempt made the goal frame (a goal counts).
  bool get isOnTarget =>
      outcome == FootballShotOutcome.goal ||
      outcome == FootballShotOutcome.onTarget;

  String get outcomeLabel => switch (outcome) {
    FootballShotOutcome.goal => 'GOAL',
    FootballShotOutcome.onTarget => 'ON TARGET',
    FootballShotOutcome.offTarget => 'OFF TARGET',
    FootballShotOutcome.blocked => 'BLOCKED',
  };

  /// The attempt placed on a full pitch measured `0..length` by `0..width`,
  /// with the home side attacking to the right and the away side to the left.
  (double, double) pitchOffset(double length, double width) =>
      footballAttackingOffset(
        fieldX,
        fieldY,
        length,
        width,
        attackingRight: isHomeTeam,
      );
}

/// Places a point given in the acting side's own attacking frame onto a pitch
/// measured `0..length` by `0..width`.
///
/// Both shots and touches arrive from the feed in that same frame — `x` is
/// progress towards the goal being attacked and `y` runs across the pitch with
/// the attacker's left as the high value — so one side has to be mirrored to
/// draw them together, and this is the single place that happens.
///
/// Screen `y` grows downwards, so a side facing right has its left hand at the
/// top of the pitch while a side facing left has it at the bottom — which is
/// why the two cases invert different axes.
(double, double) footballAttackingOffset(
  double fieldX,
  double fieldY,
  double length,
  double width, {
  required bool attackingRight,
}) => attackingRight
    ? (fieldX * length, (1 - fieldY) * width)
    : ((1 - fieldX) * length, fieldY * width);

/// Which board a per-player match stat belongs on.
enum FootballStatGroup { attack, duels, discipline, goalkeeping }

/// Semantic weight of a stat, mapped to a palette colour by the UI. Kept as an
/// enum so this file stays import-free and purely a model.
enum FootballStatTone { neutral, caution, danger }

/// One entry on the per-player match sheet, with our own label copy.
///
/// ESPN ships a `displayName` per stat, but it is inconsistent for this feed
/// ("Total Goals", "Goals Against") and the live path has no dictionary to read
/// from, so labels live here instead of in the bundled asset.
class FootballStatDescriptor {
  const FootballStatDescriptor(
    this.key,
    this.label,
    this.group, {
    this.tone = FootballStatTone.neutral,
  });

  final String key;
  final String label;
  final FootballStatGroup group;
  final FootballStatTone tone;
}

/// The 15 stats ESPN publishes per player on a soccer match summary.
///
/// `saves`/`shotsFaced` come back only for goalkeepers and `offsides` only for
/// outfielders, so a null value means "not applicable here", not "zero".
const kFootballPlayerStatCatalog = <FootballStatDescriptor>[
  FootballStatDescriptor('totalGoals', 'GOALS', FootballStatGroup.attack),
  FootballStatDescriptor('goalAssists', 'ASSISTS', FootballStatGroup.attack),
  FootballStatDescriptor('totalShots', 'SHOTS', FootballStatGroup.attack),
  FootballStatDescriptor('shotsOnTarget', 'ON TARGET', FootballStatGroup.attack),
  FootballStatDescriptor('offsides', 'OFFSIDES', FootballStatGroup.attack),
  FootballStatDescriptor('foulsSuffered', 'FOULS WON', FootballStatGroup.duels),
  FootballStatDescriptor(
    'foulsCommitted',
    'FOULS MADE',
    FootballStatGroup.duels,
  ),
  FootballStatDescriptor('appearances', 'APPS', FootballStatGroup.duels),
  FootballStatDescriptor('subIns', 'SUB ON', FootballStatGroup.duels),
  FootballStatDescriptor(
    'yellowCards',
    'YELLOW',
    FootballStatGroup.discipline,
    tone: FootballStatTone.caution,
  ),
  FootballStatDescriptor(
    'redCards',
    'RED',
    FootballStatGroup.discipline,
    tone: FootballStatTone.danger,
  ),
  FootballStatDescriptor(
    'ownGoals',
    'OWN GOALS',
    FootballStatGroup.discipline,
    tone: FootballStatTone.danger,
  ),
  FootballStatDescriptor('saves', 'SAVES', FootballStatGroup.goalkeeping),
  FootballStatDescriptor(
    'shotsFaced',
    'SHOTS FACED',
    FootballStatGroup.goalkeeping,
  ),
  FootballStatDescriptor(
    'goalsConceded',
    'CONCEDED',
    FootballStatGroup.goalkeeping,
    tone: FootballStatTone.caution,
  ),
];

/// Falls back to a humanised label so a stat ESPN adds later renders as
/// something readable instead of crashing or vanishing.
FootballStatDescriptor footballStatDescriptor(String key) {
  for (final entry in kFootballPlayerStatCatalog) {
    if (entry.key == key) return entry;
  }
  final spaced = key
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .toUpperCase();
  return FootballStatDescriptor(key, spaced, FootballStatGroup.duels);
}

/// One player's record of a single match: ESPN's stat sheet plus the positional
/// tracking the plays feed attributes to them.
///
/// Touch coordinates use the same attacking frame as [FootballShot] — `x` is
/// progress towards the goal being attacked, `y` runs across the pitch with the
/// attacker's left as the high value — and are already normalised to 0..1 and
/// clamped by the parser. Route them through [footballAttackingOffset] rather
/// than reading them raw.
class FootballPlayerMatchStats {
  const FootballPlayerMatchStats({
    required this.values,
    this.firstHalfTouches = const [],
    this.secondHalfTouches = const [],
    this.subInMinute,
    this.subOutMinute,
    this.starter = false,
    this.expectedGoals,
    this.expectedGoalsOnTarget,
  });

  /// ESPN stat name to value. A missing key means the stat does not apply to
  /// this player's position, which is not the same as zero.
  final Map<String, num> values;

  final List<(double, double)> firstHalfTouches;
  final List<(double, double)> secondHalfTouches;
  final int? subInMinute;
  final int? subOutMinute;
  final bool starter;
  final double? expectedGoals;
  final double? expectedGoalsOnTarget;

  num? stat(String key) => values[key];

  int intStat(String key) => values[key]?.round() ?? 0;

  /// [period] 1 or 2 selects a half; null returns the whole match.
  List<(double, double)> touches({int? period}) => switch (period) {
    1 => firstHalfTouches,
    2 => secondHalfTouches,
    _ => [...firstHalfTouches, ...secondHalfTouches],
  };

  int get touchCount => firstHalfTouches.length + secondHalfTouches.length;

  bool get hasTracking => touchCount > 0;

  /// Whether the player took any part in the match. An unused substitute has no
  /// appearance and no touches.
  bool get played => intStat('appearances') > 0 || hasTracking;

  /// Minutes on the pitch, as far as the feed can tell. Null when the player
  /// did not appear. Stoppage time is not modelled — ESPN reports substitutions
  /// on the broadcast clock, so a 90th-minute change reads as 90.
  int? get minutesPlayed {
    if (!played) return null;
    final on = subInMinute ?? 0;
    final off = subOutMinute ?? 90;
    final span = off - on;
    return span <= 0 ? 0 : span;
  }

  String get minutesLabel {
    final minutes = minutesPlayed;
    if (minutes == null) return '—';
    return "$minutes'";
  }

  String get roleLabel {
    if (!played) return 'UNUSED';
    if (starter) return subOutMinute == null ? 'STARTER' : 'SUBBED OFF';
    return 'SUBSTITUTE';
  }

  /// Touches in the attacking third — the cheapest read on how high a player
  /// operated, and one ESPN does not publish.
  int get finalThirdTouches =>
      touches().where((t) => t.$1 >= 2 / 3).length;

  /// Touches inside the penalty area. The box starts at 16.5 m of a 105 m pitch
  /// (x >= 0.843) and spans 40.32 m of a 68 m width (0.296 either side of
  /// centre) — the same dimensions `PitchFrame` draws.
  int get boxTouches => touches()
      .where((t) => t.$1 >= 0.843 && (t.$2 - 0.5).abs() <= 0.297)
      .length;

  /// Mean distance up the pitch, 0..1. Null without tracking.
  double? get territory {
    final all = touches();
    if (all.isEmpty) return null;
    return all.fold<double>(0, (sum, t) => sum + t.$1) / all.length;
  }

  /// Average position in the attacking frame, for the heatmap crosshair.
  (double, double)? get averagePosition {
    final all = touches();
    if (all.isEmpty) return null;
    var x = 0.0;
    var y = 0.0;
    for (final touch in all) {
      x += touch.$1;
      y += touch.$2;
    }
    return (x / all.length, y / all.length);
  }
}
