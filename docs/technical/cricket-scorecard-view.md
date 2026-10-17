# Cricket Scorecard — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-09
> **Scope:** The SCORECARD tab of the cricket match report — the host
> `_CricketScorecard` in
> [`cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
> and the whole of
> [`lib/widgets/cricket_scorecard_view.dart`](../../lib/widgets/cricket_scorecard_view.dart),
> plus the models, shared widgets and tap-through it needs.

**Written to be portable.** Every widget involved is reproduced *exactly as
implemented*, in the section that explains it, with a flattened drop-in copy of
the design tokens and stand-ins for the two things that cannot travel. Build the
sections in order and you have a working scorecard.

---

## 0. Port map

| # | Layer | Source | Lines | Required? | Here |
| --- | --- | --- | --- | --- | --- |
| 1 | Design tokens | `lib/config/theme.dart` (`Cyber`) | subset | yes | §9.2 — flattened |
| 2 | Models | `lib/models/cricket_scorecard.dart` | 153 | yes | §7 — verbatim, whole file |
| 3 | HUD leaves | `lib/widgets/cyber/cyber_widgets.dart` | 6 classes | yes | App. A.1 — verbatim |
| 4 | Innings switch | `lib/widgets/cyber/cyber_filter_chips.dart` | 139 | only for multi-innings | App. A.2 — verbatim |
| 5 | Tap feedback + sheet chrome | `lib/widgets/cyber/player_match_sheet.dart` | 240 | `TapPunch` yes, rest only for the dossier | App. A.3 — verbatim |
| 6 | **The scorecard** | `lib/widgets/cricket_scorecard_view.dart` | 720 | yes | §3–§6 — verbatim |
| 7 | The host | `_CricketScorecard` | ~60 | adapt | §2 — verbatim |
| 8 | Player dossier | `cricket_player_match_sheet.dart` (+ tape, portraits) | 472+ | optional | App. B — contract |

**Toolchain:** Dart 3, Flutter 3.27+ (`Color.withValues`), fonts Orbitron +
Onest. No third-party packages.

**One symbol to swap:** the batting/extras rows reference `AppTheme.whiteColor`,
which is literally `Color(0xFFFFFFFF)` — use `Colors.white` in the port, or add
`static const Color whiteColor = Colors.white;` to your token class.

---

## 1. Shape of the feature

```
_CricketScorecard(match)                      ← the STATS tab host (§2)
  ├─ CyberNoDataState                         ← no scorecard / no innings
  └─ ListView
       └─ CricketScorecardView(scorecard, accent, onTapPlayer?)   (§3)
            ├─ CyberSectionHeading + CyberStatPill   INNINGS CONTROL  n/N
            ├─ CyberFilterChips                      one chip per innings
            └─ AnimatedSwitcher → _InningsScorecard  (§4)
                 ├─ innings header  CyberPanel + 3 × CyberMiniMetric
                 ├─ BATTING CARD    _ScorecardTable → tappable batter rows + EXTRAS
                 ├─ innings notes   YET TO BAT / FALL OF WICKETS
                 ├─ PARTNERSHIPS    stand list
                 └─ BOWLING CARD    _ScorecardTable → tappable bowler rows
```

Two decisions define the whole feature:

1. **The view owns no data.** It takes a `CricketScorecard`, an accent colour and
   an optional tap callback. Nothing else. That is why the same widget serves a
   bundled fixture and a live feed.
2. **Tappability is a capability, not a mode.** `onTapPlayer == null` means rows
   render flat — no key, no gesture, no punch animation. The host decides.

---

## 2. The host — `_CricketScorecard`

Lives in the cricket STATS view. Three jobs: guard, resolve squads, open a
dossier.

**Squad resolution is the subtle part.** The bundled match package carries squads
on `cricketDetails.teams`; the live ESPN path produces no `cricketDetails` at all
but does carry `match.cricketSquads`. Both are tried, and when neither exists
`onTapPlayer` is passed as `null` so rows stay flat rather than opening an empty
card.

`_openPlayer` walks the squads for the athlete id the tapped row reported, then
opens that player's dossier accented by **that player's own side** — not the
scorecard's accent.

**Full source:**

```dart
class _CricketScorecard extends StatelessWidget {
  const _CricketScorecard({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final scorecard = match.cricketScorecard;
    if (scorecard == null || scorecard.innings.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.table_chart_outlined,
        title: 'Scorecard unavailable',
        message: 'Batting and bowling figures have not been published.',
      );
    }
    // The bundled package carries squads on cricketDetails; the live ESPN path
    // produces no cricketDetails at all but does carry cricketSquads.
    final squads =
        match.cricketDetails?.teams ??
        match.cricketSquads ??
        const <CricketTeamSquad>[];
    return ListView(
      key: const ValueKey('cricket-stats-scorecard'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        CricketScorecardView(
          scorecard: scorecard,
          accent: Cyber.cyan,
          // Only tappable when there are squads to resolve an id against.
          onTapPlayer: squads.isEmpty
              ? null
              : (playerId) => _openPlayer(context, squads, playerId),
        ),
      ],
    );
  }

  /// Resolves a scorecard row's athlete id to the squad player it belongs to,
  /// then opens that player's dossier paging their own side.
  void _openPlayer(
    BuildContext context,
    List<CricketTeamSquad> squads,
    String playerId,
  ) {
    for (final squad in squads) {
      for (final player in squad.players) {
        if (player.id != playerId) continue;
        showCricketPlayerMatchSheet(
          context: context,
          squad: squad,
          player: player,
          accent: paletteForTeam(
            squad.isHome ? match.home : match.away,
            sport: match.sport,
            competition: match.leagueId,
          ).secondaryTextColor,
        );
        return;
      }
    }
  }
}
```

Porting it is a rewrite of about ten lines: keep the empty state, keep the
`squads.isEmpty ? null : …` rule, and point `_openPlayer` at whatever dossier you
have (or delete it and pass `null`).

---

## 3. `CricketScorecardView` — public API and innings switch

```dart
CricketScorecardView({
  required CricketScorecard scorecard,
  required Color accent,
  void Function(String playerId)? onTapPlayer,
})
```

State is one `int _selectedIndex`. Three behaviours worth keeping:

- **`didUpdateWidget` clamps the selection.** If a new scorecard arrives with
  fewer innings, the index resets to 0 instead of throwing on the next build.
- **The innings switch only appears for more than one innings.** A single-innings
  card goes straight to the table with no chrome above it.
- **`_selectInnings` matches on the uppercased team name**, because that is what
  the chips display. It no-ops on an unknown label or a repeat tap, and fires a
  selection haptic otherwise.

The body is an `AnimatedSwitcher` (240 ms, `easeOutCubic` / `easeInCubic`)
whose transition is a fade **plus** a 2.5% slide from the right — so switching
innings reads as a lateral move, not a crossfade. Its child is keyed
`scorecard-innings-<number>`, so the whole card rebuilds per innings.

**Full source:**

```dart
class CricketScorecardView extends StatefulWidget {
  const CricketScorecardView({
    super.key,
    required this.scorecard,
    required this.accent,
    this.onTapPlayer,
  });

  final CricketScorecard scorecard;
  final Color accent;

  /// Opens a player's match dossier. Null when the caller has no squad data to
  /// resolve an id against — a live scorecard, for instance — in which case the
  /// rows stay untappable rather than opening an empty card.
  final void Function(String playerId)? onTapPlayer;

  @override
  State<CricketScorecardView> createState() => _CricketScorecardViewState();
}

class _CricketScorecardViewState extends State<CricketScorecardView> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(covariant CricketScorecardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.scorecard.innings.length) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scorecard.innings.isEmpty) {
      return Center(
        child: Text(
          'No scorecard data available',
          style: Cyber.body(13, color: Cyber.muted),
        ),
      );
    }

    final innings = widget.scorecard.innings[_selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.scorecard.innings.length > 1) ...[
          CyberSectionHeading(
            label: 'INNINGS CONTROL',
            trailing: CyberStatPill(
              label: '${_selectedIndex + 1}/${widget.scorecard.innings.length}',
              color: widget.accent,
            ),
          ),
          const SizedBox(height: 10),
          CyberFilterChips(
            key: const ValueKey('scorecard-innings-selector'),
            labels: [
              for (final item in widget.scorecard.innings)
                item.teamName.toUpperCase(),
            ],
            selected: innings.teamName.toUpperCase(),
            accent: widget.accent,
            padding: EdgeInsets.zero,
            onSelect: _selectInnings,
          ),
          const SizedBox(height: 16),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.025, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _InningsScorecard(
            onTapPlayer: widget.onTapPlayer,
            key: ValueKey(
              'scorecard-innings-${innings.number ?? _selectedIndex}',
            ),
            innings: innings,
            accent: widget.accent,
            fallbackNumber: _selectedIndex + 1,
          ),
        ),
      ],
    );
  }

  void _selectInnings(String teamName) {
    final index = widget.scorecard.innings.indexWhere(
      (innings) => innings.teamName.toUpperCase() == teamName,
    );
    if (index < 0 || index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }
}
```

---

## 4. `_InningsScorecard` — one innings, five blocks

Every block is conditional on its data (`batters`, `didNotBat`/`fow`,
`partnerships`, `bowlers`), so a partial feed renders fewer sections rather than
empty headings.

### 4.1 Innings header

A `CyberPanel` keyed `scorecard-innings-header` with a 2 px accent bar across the
top, then:

- `'INNINGS NN // SCORECARD'` (zero-padded, `innings.number ?? fallbackNumber`)
- `'<team> Innings'` in display type
- either `'MATCH DATA // VERIFIED FIGURES'` or `'CHASE TARGET // <n>'`
- the score at 25 pt in the accent — `'<runs>/<wickets>'` when both are known,
  else the feed's `scoreText` — over `'<overs> OVERS'`
- three `CyberMiniMetric`s: **Run rate**, **Boundaries** (summed from every
  batter's `fours + sixes`, not taken from the feed), and a third cell that
  **swaps label and value**: `Wickets` in the first innings, `Target` in a chase.

### 4.2 Batting card

`_ScorecardTable` keyed `scorecard-batting-table`, header `BATTER R B 4 6 SR`.

| Rule | Effect |
| --- | --- |
| top score (`runs == best && best > 0`) | runs cell in `Cyber.gold`, weight 900 |
| not out (`notOut \|\| dismissal.isEmpty`) | name in the accent, 2 px accent rail, weight 800 |
| out | name white, rail `Cyber.line`, dismissal line beneath |
| details greeble | `'POS n // n MIN // NOT OUT // <milestone>'`, joined with `//`, only the parts that exist |
| row striping | `index.isEven ? Cyber.chartSurface : Cyber.panel` |
| extras | appended as a final accent-tinted row when `innings.extras` is non-empty |

### 4.3 Innings notes

One `CyberPanel` carrying `YET TO BAT` (names joined by `  •  `) and
`FALL OF WICKETS` (joined by `  //  `), with a hairline between them only when
both exist.

### 4.4 Partnerships

A stand per row: the wicket label in a fixed 34 px column, both batters as
`'<name> <runs>'` joined by `+`, and `'<runs> / <overs> OV'` in gold on the right.
Rows are separated by hairlines drawn between items, not around them.

### 4.5 Bowling card

`_ScorecardTable` keyed `scorecard-bowling-table`, header `BOWLER O M R W ER`.
The strike bowler (`wickets == best && best > 0`) takes a gold rail and a gold
wickets cell; everyone else's wickets cell is the accent. Every bowler carries a
`'DOT n // WD n // NB n'` greeble line, with `—` for missing values.

### 4.6 Table shell and cells

`_ScorecardTable` is a zero-padding `CyberPanel` with a `Cyber.line` accent: a
tinted header strip, a 45%-alpha accent rule beneath it, rows separated by
28%-alpha hairlines, and a trailing `SizedBox(height: CyberClipper.cut)` so the
last row never collides with the panel's chamfer.

`_tableRow` and `_numberCell` share the column geometry — name at `flex: 4`,
four numeric columns at `flex: 1`, the last (SR / ER) at `flex: 2`, all
right-aligned with tabular figures. `_formatNumber` trims a trailing `.0` so
`20.0` overs print as `20`.

**Full source — the whole innings card, including every builder:**

```dart
class _InningsScorecard extends StatelessWidget {
  const _InningsScorecard({
    required this.innings,
    required this.accent,
    required this.fallbackNumber,
    this.onTapPlayer,
    super.key,
  });

  final CricketInnings innings;
  final Color accent;
  final int fallbackNumber;
  final void Function(String playerId)? onTapPlayer;

  /// Makes a scorecard row open its player's dossier.
  ///
  /// The join key was already decoded and unused: `CricketBatter.id` and
  /// `CricketBowler.id` have shipped since the package landed but nothing read
  /// them. A row without an id, or a caller without squads, simply stays flat.
  Widget _tappable({
    required String? playerId,
    required String keyPrefix,
    required Widget child,
  }) {
    final handler = onTapPlayer;
    if (handler == null || playerId == null || playerId.isEmpty) return child;
    return TapPunch(
      key: ValueKey('scorecard-$keyPrefix-$playerId'),
      onTap: () {
        HapticFeedback.selectionClick();
        handler(playerId);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInningsHeader(),
        if (innings.batters.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'BATTING CARD',
            trailing: Text(
              '${innings.batters.length} BATTERS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildBattingTable(),
        ],
        if (innings.didNotBat.isNotEmpty || innings.fow.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInningsNotes(),
        ],
        if (innings.partnerships.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'PARTNERSHIPS',
            trailing: Text(
              '${innings.partnerships.length} STANDS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildPartnerships(),
        ],
        if (innings.bowlers.isNotEmpty) ...[
          const SizedBox(height: 20),
          CyberSectionHeading(
            label: 'BOWLING CARD',
            trailing: Text(
              '${innings.bowlers.length} BOWLERS',
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 8),
          _buildBowlingTable(),
        ],
      ],
    );
  }

  Widget _buildInningsHeader() {
    final score = innings.runs != null && innings.wickets != null
        ? '${innings.runs}/${innings.wickets}'
        : innings.scoreText;
    final inningsNumber = innings.number ?? fallbackNumber;
    final boundaryCount = innings.batters.fold<int>(
      0,
      (total, batter) => total + batter.fours + batter.sixes,
    );

    return CyberPanel(
      key: const ValueKey('scorecard-innings-header'),
      accent: accent,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 2, color: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INNINGS ${inningsNumber.toString().padLeft(2, '0')} // SCORECARD',
                        style: Cyber.label(
                          8,
                          color: accent,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${innings.teamName} Innings',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(14, letterSpacing: 0.35),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        innings.target == null
                            ? 'MATCH DATA // VERIFIED FIGURES'
                            : 'CHASE TARGET // ${innings.target}',
                        style: Cyber.label(
                          7,
                          color: Cyber.muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score,
                      textAlign: TextAlign.right,
                      style: Cyber.display(25, color: accent, letterSpacing: 0)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    if (innings.overs != null)
                      Text(
                        '${_formatNumber(innings.overs!)} OVERS',
                        style: Cyber.label(
                          8,
                          color: Cyber.muted,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                CyberMiniMetric(
                  label: 'Run rate',
                  value: innings.runRate == null
                      ? '—'
                      : innings.runRate!.toStringAsFixed(2),
                  accent: accent,
                ),
                const SizedBox(width: 6),
                CyberMiniMetric(label: 'Boundaries', value: '$boundaryCount'),
                const SizedBox(width: 6),
                CyberMiniMetric(
                  label: innings.target == null ? 'Wickets' : 'Target',
                  value: '${innings.target ?? innings.wickets ?? '—'}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattingTable() {
    final best = innings.batters.fold<int>(
      0,
      (value, batter) => batter.runs > value ? batter.runs : value,
    );
    return _ScorecardTable(
      key: const ValueKey('scorecard-batting-table'),
      accent: accent,
      header: _tableRow(
        name: 'BATTER',
        values: const ['R', 'B', '4', '6', 'SR'],
      ),
      rows: [
        for (var index = 0; index < innings.batters.length; index++)
          _tappable(
            playerId: innings.batters[index].id,
            keyPrefix: 'batter',
            child: _batterRow(
              innings.batters[index],
              index: index,
              best: best,
            ),
          ),
        if (innings.extras.isNotEmpty) _extrasRow(),
      ],
    );
  }

  Widget _batterRow(
    CricketBatter batter, {
    required int index,
    required int best,
  }) {
    final dismissal = batter.dismissalText?.trim() ?? '';
    final notOut = batter.notOut || dismissal.isEmpty;
    final isTopScore = batter.runs == best && best > 0;
    final details = <String>[
      if (batter.position != null) 'POS ${batter.position}',
      if (batter.minutes != null) '${batter.minutes} MIN',
      if (notOut) 'NOT OUT',
      if (batter.milestone != null && batter.milestone!.isNotEmpty)
        batter.milestone!.toUpperCase(),
    ];

    return Container(
      color: index.isEven ? Cyber.chartSurface : Cyber.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 32,
                  color: notOut ? accent : Cyber.line,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          12,
                          color: notOut ? accent : AppTheme.whiteColor,
                          weight: notOut ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (dismissal.isNotEmpty)
                        Text(
                          dismissal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.body(8.5, color: Cyber.muted),
                        ),
                      if (details.isNotEmpty)
                        Text(
                          details.join(' // '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Cyber.label(
                            6.5,
                            color: Cyber.muted.withValues(alpha: 0.82),
                            letterSpacing: 0.7,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _numberCell(
            '${batter.runs}',
            color: isTopScore ? Cyber.gold : AppTheme.whiteColor,
            weight: FontWeight.w900,
          ),
          _numberCell('${batter.balls}'),
          _numberCell('${batter.fours}'),
          _numberCell('${batter.sixes}'),
          _numberCell(batter.strikeRate.toStringAsFixed(1), flex: 2),
        ],
      ),
    );
  }

  Widget _extrasRow() {
    return Container(
      color: accent.withValues(alpha: 0.055),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'EXTRAS',
              style: Cyber.label(9, color: accent, letterSpacing: 1.1),
            ),
          ),
          Flexible(
            child: Text(
              innings.extras,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Cyber.body(
                11,
                color: AppTheme.whiteColor,
                weight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInningsNotes() {
    return CyberPanel(
      accent: Cyber.line,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (innings.didNotBat.isNotEmpty)
            _telemetryLine(
              label: 'YET TO BAT',
              value: innings.didNotBat.join('  •  '),
            ),
          if (innings.didNotBat.isNotEmpty && innings.fow.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                height: 1,
                color: Cyber.line.withValues(alpha: 0.35),
              ),
            ),
          if (innings.fow.isNotEmpty)
            _telemetryLine(
              label: 'FALL OF WICKETS',
              value: innings.fow.join('  //  '),
            ),
        ],
      ),
    );
  }

  Widget _telemetryLine({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(8, color: accent, letterSpacing: 1.1)),
        const SizedBox(height: 5),
        Text(value, style: Cyber.body(10.5, color: Cyber.muted)),
      ],
    );
  }

  Widget _buildPartnerships() {
    return CyberPanel(
      accent: Cyber.line,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        children: [
          for (var index = 0; index < innings.partnerships.length; index++) ...[
            if (index > 0)
              Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      innings.partnerships[index].wicket.toUpperCase(),
                      style: Cyber.label(8, color: accent),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      innings.partnerships[index].batters
                          .map((batter) => '${batter.name} ${batter.runs}')
                          .join(' + '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.body(10.5, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${innings.partnerships[index].runs} / ${_formatNumber(innings.partnerships[index].overs)} OV',
                    style: Cyber.label(
                      8,
                      color: Cyber.gold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBowlingTable() {
    final best = innings.bowlers.fold<int>(
      0,
      (value, bowler) => bowler.wickets > value ? bowler.wickets : value,
    );
    return _ScorecardTable(
      key: const ValueKey('scorecard-bowling-table'),
      accent: accent,
      header: _tableRow(
        name: 'BOWLER',
        values: const ['O', 'M', 'R', 'W', 'ER'],
      ),
      rows: [
        for (var index = 0; index < innings.bowlers.length; index++)
          _tappable(
            playerId: innings.bowlers[index].id,
            keyPrefix: 'bowler',
            child: _bowlerRow(
              innings.bowlers[index],
              index: index,
              best: best,
            ),
          ),
      ],
    );
  }

  Widget _bowlerRow(
    CricketBowler bowler, {
    required int index,
    required int best,
  }) {
    final isStrikeBowler = bowler.wickets == best && best > 0;
    return Container(
      color: index.isEven ? Cyber.chartSurface : Cyber.panel,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2,
                  height: 30,
                  color: isStrikeBowler ? Cyber.gold : Cyber.line,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bowler.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.body(
                          12,
                          weight: isStrikeBowler
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      Text(
                        'DOT ${bowler.dots ?? '—'} // WD ${bowler.wides ?? '—'} // NB ${bowler.noBalls ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.label(
                          6.5,
                          color: Cyber.muted.withValues(alpha: 0.82),
                          letterSpacing: 0.65,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _numberCell(_formatNumber(bowler.overs)),
          _numberCell('${bowler.maidens}'),
          _numberCell('${bowler.runs}'),
          _numberCell(
            '${bowler.wickets}',
            color: isStrikeBowler ? Cyber.gold : accent,
            weight: FontWeight.w900,
          ),
          _numberCell(bowler.economyRate.toStringAsFixed(1), flex: 2),
        ],
      ),
    );
  }

  Widget _tableRow({required String name, required List<String> values}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              name,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1),
            ),
          ),
          for (var index = 0; index < values.length; index++)
            Expanded(
              flex: index == values.length - 1 ? 2 : 1,
              child: Text(
                values[index],
                textAlign: TextAlign.right,
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _numberCell(
    String value, {
    int flex = 1,
    Color? color,
    FontWeight weight = FontWeight.w600,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        textAlign: TextAlign.right,
        style: Cyber.body(
          10.5,
          color: color ?? Cyber.muted,
          weight: weight,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _formatNumber(double value) =>
      value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}
```

**Full source — the table shell:**

```dart
class _ScorecardTable extends StatelessWidget {
  const _ScorecardTable({
    required this.accent,
    required this.header,
    required this.rows,
    super.key,
  });

  final Color accent;
  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: Cyber.line,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ColoredBox(color: accent.withValues(alpha: 0.065), child: header),
          Container(height: 1, color: accent.withValues(alpha: 0.45)),
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index != rows.length - 1)
              Container(height: 1, color: Cyber.line.withValues(alpha: 0.28)),
          ],
          const SizedBox(height: CyberClipper.cut),
        ],
      ),
    );
  }
}
```

---

## 5. Tap-through

`_tappable` is the single place row interactivity is decided:

```dart
final handler = onTapPlayer;
if (handler == null || playerId == null || playerId.isEmpty) return child;
return TapPunch(key: ValueKey('scorecard-$keyPrefix-$playerId'), …);
```

Three ways a row stays flat — no callback, no id on the row, or an empty id — and
all of them degrade silently. `CricketBatter.id` and `CricketBowler.id` had
shipped in the package decoder long before anything read them; this is the join
key that turned the table into a set of tap targets.

`TapPunch` (App. A.3) is the shared press feedback: `AnimatedScale` to 0.92 over
110 ms on tap-down, released on tap or cancel. Keys are `scorecard-batter-<athleteId>` and
`scorecard-bowler-<athleteId>` — the widget tests address rows by exactly these.

What opens is the host's business (§2). In this app it is
`showCricketPlayerMatchSheet`, which pages the whole squad through the shared
`showPlayerMatchSheet` chrome (App. B).

---

## 6. Design rules to keep

- **Nothing here glows.** A scorecard is a reference surface: flat
  `Cyber.chartSurface` / `Cyber.panel` fills, hairline borders, accent used as
  tint and rail only. `CyberPanel` is left at its `glow: false` default
  throughout.
- **Gold marks achievement** — the top score, the strike bowler, the partnership
  runs. The team accent marks *identity and state* — innings chrome, not-out
  batters, the wickets column.
- **Every number is tabular** (`FontFeature.tabularFigures()`), so columns line
  up down the table; that is why the cells go through `_numberCell` rather than
  raw `Text`.
- **Greeble carries the secondary data** — `POS 3 // 41 MIN // NOT OUT`,
  `DOT 9 // WD 1 // NB 0` — instead of extra columns. It keeps the table to six
  columns on a phone.
- **Striped rows, no card-per-row.** The table is one panel; rows are separated
  by fills and hairlines.

---

## 7. Models — `cricket_scorecard.dart`, in full

`CricketScorecard` is a list of `CricketInnings`; everything the view reads hangs
off that. Note how much is nullable: `number`, `runs`, `wickets`, `overs`,
`runRate`, `target`, and every id. The view is written against that — it always
has a `scoreText` and a `teamName` to fall back on.

```dart
class CricketScorecard {
  const CricketScorecard({required this.innings});
  final List<CricketInnings> innings;
}

class CricketInnings {
  const CricketInnings({
    required this.teamName,
    required this.scoreText, // e.g. "171 (20 ov)"
    required this.batters,
    required this.bowlers,
    this.didNotBat = const [],
    this.extras = '',
    this.fow = const [],
    this.number,
    this.runs,
    this.wickets,
    this.overs,
    this.runRate,
    this.target,
    this.extrasBreakdown,
    this.fallOfWickets = const [],
    this.partnerships = const [],
  });
  final String teamName;
  final String scoreText;
  final List<CricketBatter> batters;
  final List<CricketBowler> bowlers;
  final List<String> didNotBat;
  final String extras;
  final List<String> fow;
  final int? number;
  final int? runs;
  final int? wickets;
  final double? overs;
  final double? runRate;
  final int? target;
  final CricketExtras? extrasBreakdown;
  final List<CricketFallOfWicket> fallOfWickets;
  final List<CricketPartnership> partnerships;
}

class CricketBatter {
  const CricketBatter({
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    this.dismissalText,
    this.id,
    this.position,
    this.minutes,
    this.notOut = false,
    this.milestone,
  });
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final String?
  dismissalText; // e.g. "c Arshdeep Singh b Patel", null means not out
  final String? id;
  final int? position;
  final int? minutes;
  final bool notOut;
  final String? milestone;
}

class CricketBowler {
  const CricketBowler({
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economyRate,
    this.id,
    this.position,
    this.balls,
    this.dots,
    this.wides,
    this.noBalls,
    this.foursConceded,
    this.sixesConceded,
  });
  final String name;
  final double overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economyRate;
  final String? id;
  final int? position;
  final int? balls;
  final int? dots;
  final int? wides;
  final int? noBalls;
  final int? foursConceded;
  final int? sixesConceded;
}

class CricketExtras {
  const CricketExtras({
    required this.total,
    required this.wides,
    required this.noBalls,
    required this.byes,
    required this.legByes,
  });
  final int total;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
}

class CricketFallOfWicket {
  const CricketFallOfWicket({
    required this.wicket,
    required this.score,
    required this.runs,
    required this.overs,
    required this.batter,
  });
  final int wicket;
  final String score;
  final int runs;
  final double overs;
  final String batter;
}

class CricketPartnershipBatter {
  const CricketPartnershipBatter({required this.name, required this.runs});
  final String name;
  final int runs;
}

class CricketPartnership {
  const CricketPartnership({
    required this.wicket,
    required this.runs,
    required this.overs,
    required this.batters,
  });
  final String wicket;
  final int runs;
  final double overs;
  final List<CricketPartnershipBatter> batters;
}
```

---

## 8. Test hooks

| Key | Where |
| --- | --- |
| `scorecard-innings-selector` | the innings chip strip |
| `scorecard-innings-<number>` | the switched innings card |
| `scorecard-innings-header` | the header panel |
| `scorecard-batting-table` | batting `_ScorecardTable` |
| `scorecard-bowling-table` | bowling `_ScorecardTable` |
| `scorecard-batter-<athleteId>` | a tappable batter row |
| `scorecard-bowler-<athleteId>` | a tappable bowler row |

[`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart)
drives them through the full STATS view: *cricket HUD exposes four sections with
both race charts* asserts the selector, header and both tables;
*tapping a scorecard row opens that player dossier* scrolls to
`scorecard-batter-253802` (Kohli, 75\* off 42), taps, and asserts the sheet,
his figures and the innings tape; *a bowler opens on their spell, not an empty
tape* does the same for `scorecard-bowler-326016`.

---

## 9. Porting guide

### 9.1 Order of work

1. `Cyber` tokens (§9.2) and the two fonts.
2. `cricket_scorecard.dart` models (§7) — or your own, matching the field names.
3. App. A.1 cyber leaves, then A.2 chips (skip if you only ever show one
   innings), then `TapPunch` from A.3.
4. `CricketScorecardView` + `_InningsScorecard` + `_ScorecardTable` (§3–§4).
5. A host modelled on §2, deciding `onTapPlayer`.
6. Optional: the dossier (App. B), or pass `null` and stop here.

### 9.2 The design tokens — flattened, drop-in

```dart
import 'package:flutter/material.dart';

/// Flattened copy of the design tokens this scorecard needs. In the source
/// project each value is an alias onto `AppTheme` in lib/config/theme.dart.
class Cyber {
  // Surfaces
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color card = Color.fromRGBO(15, 23, 43, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);
  static const Color panel2 = Color.fromRGBO(15, 23, 43, 1);
  static const Color chartSurface = Color(0xFF10192D);

  // Accents
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color magenta = Color.fromRGBO(194, 122, 255, 1);

  // Lines and text
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color line = Color.fromRGBO(69, 85, 108, 1);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.35,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );
}
```

Plus `Colors.white` wherever the source says `AppTheme.whiteColor`.

### 9.3 Stand-ins

`CyberFilterChips` plays a UI sound. Either wire your own audio or stub it:

```dart
// Port stand-in for lib/utils/sound_effects.dart.
enum SoundEffect { uiTap }
void playSound(SoundEffect effect) {}
```

Haptics come from `flutter/services.dart` and need no adaptation. There is **no**
team-palette dependency in the scorecard itself — the accent arrives as a
parameter, so the host is the only place that needs a colour source.

### 9.4 Checklist

- [ ] Fonts declared; §9.2 `Cyber` compiles
- [ ] `AppTheme.whiteColor` → `Colors.white`
- [ ] `playSound` stub in place (only if you took the chips)
- [ ] Models compile — the view reads `teamName`, `scoreText`, `number`, `runs`,
      `wickets`, `overs`, `runRate`, `target`, `extras`, `didNotBat`, `fow`,
      `batters`, `bowlers`, `partnerships`, and on rows `id`, `name`, `runs`,
      `balls`, `fours`, `sixes`, `strikeRate`, `dismissalText`, `notOut`,
      `position`, `minutes`, `milestone`, `overs`, `maidens`, `wickets`,
      `economyRate`, `dots`, `wides`, `noBalls`
- [ ] `CyberClipper.cut` exists (the table's trailing spacer references it)
- [ ] Decide tappability: pass `onTapPlayer` or `null`

---

## Implementation References

- [`lib/widgets/cricket_scorecard_view.dart`](../../lib/widgets/cricket_scorecard_view.dart)
- [`lib/models/cricket_scorecard.dart`](../../lib/models/cricket_scorecard.dart)
- [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
- [`lib/screens/predictions/widgets/cricket_player_match_sheet.dart`](../../lib/screens/predictions/widgets/cricket_player_match_sheet.dart)
- [`lib/widgets/cyber/player_match_sheet.dart`](../../lib/widgets/cyber/player_match_sheet.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart)
- [`lib/widgets/cyber/cyber_filter_chips.dart`](../../lib/widgets/cyber/cyber_filter_chips.dart)
- [`lib/config/theme.dart`](../../lib/config/theme.dart)

## Tests

- [`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart)

---

## Appendix A — shared widgets, in full

### A.1 `cyber_widgets.dart` — the leaves the scorecard uses

`CyberPanel` (with its border painter and `CyberClipper`) is every surface here;
`CyberSectionHeading` heads each block; `CyberStatPill` is the `n/N` innings
counter; `CyberMiniMetric` is the three-cell strip in the header. Note
`CyberMiniMetric` returns an `Expanded`, which is why the header places the cells
directly in a `Row`.

```dart
class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  /// Whether this is a focal / active surface that should glow. Off by default:
  /// most panels are plain surfaces and rely on the fill + border for depth.
  /// Reserve [glow] for the panel the user should look at first on a screen.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _CyberPanelBorderPainter(color: borderColor),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Cyber.panel,
            boxShadow: glow
                ? Cyber.glow(accent, alpha: 0.18, blur: 18, spread: 1)
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _CyberPanelBorderPainter extends CustomPainter {
  const _CyberPanelBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CyberPanelBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CyberClipper extends CustomClipper<Path> {
  static const double cut = 12;

  static Path buildPath(Size size, {double cut = cut}) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A [SectionLabel] with a hairline rule running out to the right edge. The
/// standard separator between the stacked sections of a data page (market
/// detail, match stats) — quieter than a panel header, so a page can carry many.
class CyberSectionHeading extends StatelessWidget {
  const CyberSectionHeading({required this.label, this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label: label),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Tinted outline pill for a status/type/telemetry token. Never glows — pills
/// are secondary chrome.
class CyberStatPill extends StatelessWidget {
  const CyberStatPill({
    required this.label,
    required this.color,
    this.value,
    super.key,
  });

  final String label;
  final Color color;

  /// When set the pill reads `LABEL value`, with the value in white.
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: value == null
          ? Text(label.toUpperCase(), style: Cyber.label(9, color: color))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: Cyber.label(9, color: color)),
                const SizedBox(width: 6),
                Text(
                  value!,
                  style: Cyber.label(
                    9,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Small labelled KPI cell — a muted caption over a tabular value. Sits in a
/// [Row] of two or three; expands to share the width.
class CyberMiniMetric extends StatelessWidget {
  const CyberMiniMetric({
    required this.label,
    required this.value,
    this.accent,
    super.key,
  });

  final String label;
  final String value;

  /// Tints the value only. Left null the value stays white — most cells are
  /// context, not emphasis.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.42),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(9, color: Cyber.muted),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                11,
                color: accent ?? Colors.white,
                weight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`CyberSectionHeading` composes `SectionLabel`:

```dart
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
```

### A.2 `cyber_filter_chips.dart` — the innings switch

The whole file. Only needed when a scorecard can hold more than one innings.

```dart
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// A horizontal, scrollable strip of cut-corner filter chips — the leaderboard
/// sport-filter look, reused on the shop catalogue tabs (nation on AVATAR, sport
/// on BORDER / BANNER). The active chip is the single tinted/outlined element;
/// per the glow rule it doesn't glow — the rest stay calm muted outlines.
class CyberFilterChips extends StatelessWidget {
  const CyberFilterChips({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 12, 10),
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: CyberFilterChip(
                label: label,
                active: label == selected,
                accent: accent,
                onTap: () {
                  if (label == selected) return;
                  playSound(SoundEffect.uiTap);
                  onSelect(label);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CyberFilterChip extends StatelessWidget {
  const CyberFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent = Cyber.cyan,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: ShapeDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          shape: _CutCornerBorder(
            cut: 8,
            side: BorderSide(
              color: active
                  ? accent.withValues(alpha: 0.72)
                  : Cyber.line.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: Cyber.displayFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Diagonal corner-cut (top-left + bottom-right) border — the cyber chip
/// silhouette, matching the leaderboard's filter chips.
class _CutCornerBorder extends ShapeBorder {
  const _CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      _CutCornerBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final safeCut = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + safeCut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - safeCut)
      ..lineTo(rect.right - safeCut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + safeCut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = side.toPaint()..style = PaintingStyle.stroke;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }
}
```

### A.3 `player_match_sheet.dart` — `TapPunch` and the dossier chrome

`TapPunch` is **required** — it is what makes a row a tap target. The rest of the
file (`showPlayerMatchSheet`, `PlayerMatchSheetScaffold`, `CountUpMetric`) is the
squad-paging bottom sheet the rows open, shared with the football dossier; take
it only if you are porting the tap-through too.

```dart
import '../../config/theme.dart';
import 'cyber_widgets.dart';

/// Opens a squad-paging player dossier.
///
/// Shared by the football and cricket match cards. The paging is the point: a
/// dossier you can swipe through turns comparing two team-mates into one
/// gesture instead of a close, a scroll and another tap.
Future<void> showPlayerMatchSheet({
  required BuildContext context,
  required Color accent,
  required int itemCount,
  required int initialIndex,
  required Widget Function(BuildContext, int) itemBuilder,
  String title = 'MATCH DOSSIER',
  String pagerNoun = 'PLAYER',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => PlayerMatchSheetScaffold(
      accent: accent,
      itemCount: itemCount,
      initialIndex: initialIndex,
      itemBuilder: itemBuilder,
      title: title,
      pagerNoun: pagerNoun,
    ),
  );
}

/// The chrome around a player dossier: header, lazy pager, footer hint.
class PlayerMatchSheetScaffold extends StatefulWidget {
  const PlayerMatchSheetScaffold({
    required this.accent,
    required this.itemCount,
    required this.initialIndex,
    required this.itemBuilder,
    this.title = 'MATCH DOSSIER',
    this.pagerNoun = 'PLAYER',
    super.key,
  });

  final Color accent;
  final int itemCount;
  final int initialIndex;

  /// Built lazily — a squad of 40 must never be constructed at once.
  final Widget Function(BuildContext, int) itemBuilder;

  final String title;
  final String pagerNoun;

  @override
  State<PlayerMatchSheetScaffold> createState() =>
      _PlayerMatchSheetScaffoldState();
}

class _PlayerMatchSheetScaffoldState extends State<PlayerMatchSheetScaffold> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ClipPath(
        clipper: CyberClipper(),
        child: Container(
          decoration: BoxDecoration(
            color: Cyber.bg,
            border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              _SheetGrip(accent: widget.accent, title: widget.title),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.itemCount,
                  onPageChanged: (page) {
                    HapticFeedback.selectionClick();
                    setState(() => _index = page);
                  },
                  itemBuilder: widget.itemBuilder,
                ),
              ),
              _SquadPager(
                count: widget.itemCount,
                index: _index,
                noun: widget.pagerNoun,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The drag handle plus the sheet's only always-on chrome.
class _SheetGrip extends StatelessWidget {
  const _SheetGrip({required this.accent, required this.title});

  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.8),
          ),
          const Spacer(),
          Container(width: 36, height: 3, color: accent.withValues(alpha: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.close, size: 16, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

/// Position in the squad, and the hint that the card is swipeable at all.
class _SquadPager extends StatelessWidget {
  const _SquadPager({
    required this.count,
    required this.index,
    required this.noun,
  });

  final int count;
  final int index;
  final String noun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left, size: 13, color: Cyber.muted),
          const SizedBox(width: 8),
          Text(
            'SWIPE FOR NEXT $noun  //  ${index + 1} OF $count',
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1.4),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 13, color: Cyber.muted),
        ],
      ),
    );
  }
}

/// A [CyberMiniMetric] whose number counts up on entry — the small
/// gratification beat that fires again on every swipe.
class CountUpMetric extends StatelessWidget {
  const CountUpMetric({
    required this.label,
    required this.value,
    required this.format,
    this.accent,
    super.key,
  });

  final String label;
  final double value;
  final String Function(double) format;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) =>
          CyberMiniMetric(label: label, value: format(animated), accent: accent),
    );
  }
}

/// A tap target that punches inward, so a row or node feels pressed rather than
/// merely navigating.
class TapPunch extends StatefulWidget {
  const TapPunch({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<TapPunch> createState() => _TapPunchState();
}

class _TapPunchState extends State<TapPunch> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

---

## Appendix B — the player dossier, by contract

Optional. The scorecard is complete without it — pass `onTapPlayer: null`.

The cricket implementation seeds the shared sheet at the tapped player and pages
their own squad:

```dart
/// Opens the per-player match card, seeded at [player] and paging that
/// player's own squad.
Future<void> showCricketPlayerMatchSheet({
  required BuildContext context,
  required CricketTeamSquad squad,
  required CricketSquadPlayer player,
  required Color accent,
}) {
  final index = squad.players.indexWhere((p) => p.id == player.id);
  return showPlayerMatchSheet(
    context: context,
    accent: accent,
    itemCount: squad.players.length,
    initialIndex: index < 0 ? 0 : index,
    itemBuilder: (context, page) => CricketPlayerMatchCard(
      player: squad.players[page],
      squad: squad,
      accent: accent,
    ),
  );
}
```

`CricketPlayerMatchCard` (in the same 472-line file) draws one player's page and
pulls in two more files —
[`cricket_innings_tape.dart`](../../lib/screens/predictions/widgets/cricket_innings_tape.dart)
(377 lines, the ball-by-ball tape and its POWERPLAY/DEATH phase strip) and
[`cricket_match_portraits.dart`](../../lib/data/cricket_match_portraits.dart)
(156 lines of portrait ids) — plus `cyber_chart.dart` for its charts. To port the
tap-through with less: keep `_tappable` and `TapPunch`, and open whatever card
you already have, seeded by `playerId`.
