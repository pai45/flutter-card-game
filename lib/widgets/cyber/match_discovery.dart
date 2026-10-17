import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../design_system/match_discovery.generated.dart';
import '../../models/picks.dart';
import '../../models/prediction.dart';
import '../../models/sport_match.dart';
import '../team_logo.dart';
import 'cyber_widgets.dart';
import 'fixture_card.dart';
import 'statoz_icons.dart';

// Public compatibility library; implementation is grouped by responsibility.
part 'match_discovery/presentation.dart';
part 'match_discovery/status.dart';
part 'match_discovery/plate.dart';
part 'match_discovery/primitives.dart';
part 'match_discovery/outcome.dart';
part 'match_discovery/fixture.dart';
part 'match_discovery/events.dart';
part 'match_discovery/market.dart';
part 'match_discovery/mission.dart';
part 'match_discovery/layout.dart';
part 'match_discovery/reveal.dart';
