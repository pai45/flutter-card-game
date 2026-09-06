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
  ///
  /// Screen `y` grows downwards, so a side facing right has its left hand at
  /// the top of the pitch while a side facing left has it at the bottom —
  /// which is why the two cases invert different axes.
  (double, double) pitchOffset(double length, double width) => isHomeTeam
      ? (fieldX * length, (1 - fieldY) * width)
      : ((1 - fieldX) * length, fieldY * width);
}
