# Match Timeline Panel — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-12
> **Scope:** `_MatchTimelinePanel` and its seven supporting widgets in
> [`lib/screens/predictions/widgets/football_match_stats_view.dart`](../../lib/screens/predictions/widgets/football_match_stats_view.dart)
> — the event spine on a football match's **STATS → OVERVIEW** tab.

**Written to be portable.** Every widget, clipper, painter, helper and model the
panel touches is reproduced *exactly as implemented*, in the section that
explains it. The appendices add a flattened drop-in copy of the design tokens
and a stand-in for the one thing that cannot travel (team brand palettes).

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | The panel | `_MatchTimelinePanel` | §3 — verbatim |
| 2 | One moment | `_kSpineWidth`, `_TimelineRow` + state | §4 — verbatim |
| 3 | Centre column | `_MinuteSpine` | §5 — verbatim |
| 4 | Event copy | `_EventBody` | §6 — verbatim |
| 5 | Event mark | `_EventGlyph` | §7 — verbatim |
| 6 | Tap reveal | `_EventReport` | §8 — verbatim |
| 7 | Period divider | `_PeriodMarker` | §9 — verbatim |
| 8 | Helpers + header | `_eventTone`, `_eventIcon`, `_LogHeader`, `_isPeriodMarker`, `_eventLabel` | §10 — verbatim |
| 9 | Models | `MatchEventType`, `MatchEvent` | App. A — verbatim |
| 10 | Shared widgets | `SectionLabel`, `CyberSectionHeading`, `CyberNoDataState`, `PressableScale`, `HudChamferClipper`, `ChamferedActionSurface`, `ChamferedActionBorderPainter` | App. B — verbatim |
| 11 | Tokens + stand-ins | `Cyber`, `paletteForTeam` | App. C |

**Toolchain**

- **Dart 3** — switch *expressions* with `||` patterns (`_isPeriodMarker`,
  `_eventTone`, `_eventIcon`, `_eventLabel`).
- **Flutter 3.27+** — `Color.withValues(alpha:)` throughout. On older Flutter
  swap every call for `withOpacity(...)`; nothing else changes.
- **Fonts** — Orbitron (display/labels/numbers) and Onest (body). Declare both in
  `pubspec.yaml` or retarget `Cyber.displayFont` / `Cyber.bodyFont` in App. C.
- **No third-party packages.** `dart:ui` (`FontFeature`) plus
  `flutter/material.dart` and `flutter/services.dart` (`HapticFeedback`) are the
  only imports the panel needs.

---

## 1. What it is

A chronological event log for a football match, drawn as a **centre spine**
rather than a list. Minutes run down the middle of the panel and every moment is
pushed out to the side of the team that made it, so *who did what, when* reads in
a single pass without a legend or a repeated team label. Tapping a moment that
carries prose from the feed expands the report beneath it.

```
_MatchTimelinePanel(match)
  ├─ events.isEmpty → CyberNoDataState(icon: timeline, spark: sports_soccer)
  └─ Column
       ├─ _LogHeader('MATCH TIMELINE', count, 'EVENTS')   → "022 EVENTS"
       └─ for each event:
            ├─ period marker?  → _PeriodMarker            rule ── ◎ LABEL SCORE ── rule
            └─ otherwise       → _TimelineRow(accent: home/away identity)
                 └─ PressableScale(enabled: description != null)
                      └─ AnimatedSize(220ms, easeOutCubic)
                           └─ Column
                                ├─ IntrinsicHeight → Row
                                │    ├─ Expanded(home ? _EventBody : empty)
                                │    ├─ _MinuteSpine      60px, hairline + minute plate
                                │    └─ Expanded(home ? empty : _EventBody)
                                └─ [_open] _EventReport    indented past the spine
```

The mirroring is the whole trick: `_TimelineRow` fills exactly one of the two
`Expanded` slots and leaves the other a `SizedBox.shrink()`, so a home event
occupies the left half and an away event the right half while the spine stays
pinned dead centre at a fixed width.

---

## 2. The inputs

The panel reads one `SportMatch` and pulls four things from it:

| Read | Used for |
| --- | --- |
| `match.timelineEvents` (`List<MatchEvent>?`) | the rows; `null` or empty → the no-data state |
| `match.home` / `match.away` (`SportTeam`) | resolving each side's identity colour |
| `match.sport`, `match.leagueId` | palette lookup keys (see App. C) |

Per `MatchEvent`, the panel reads: `type`, `isHomeTeam`, `minuteLabel`
(`displayMinute ?? "$minute'"`), `playerName`, `secondaryPlayerName`, `label`,
`scoreDisplay` and `description`. Nothing else on the model is touched, so a port
can supply a much smaller event class — see App. A for the exact contract.

**Colour comes from the team, not the event.** Both accents are
`paletteForTeam(...).secondaryTextColor` — the brand colour already vetted for
4.5:1 contrast against dark surfaces. The accent is then overridden per event
*type* by `_eventTone` (§10): yellow cards are amber, reds are danger, subs are
lime, and only goals and generic events wear the club colour.

---

## 3. The panel — `_MatchTimelinePanel`

Verbatim:

```dart
/// MATCH TIMELINE: the event spine. Minutes run down the middle and every
/// moment sits on the side of the team that made it, so who-did-what-when
/// reads in a single pass. Tap a moment to unpack the feed's report on it.
class _MatchTimelinePanel extends StatelessWidget {
  const _MatchTimelinePanel({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final events = match.timelineEvents ?? const <MatchEvent>[];
    if (events.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-timeline-empty'),
        icon: Icons.timeline,
        title: 'Event log pending',
        message: 'Goals, cards and substitutions will be tracked here.',
        accent: Cyber.cyan,
        spark: Icons.sports_soccer,
      );
    }
    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    return Column(
      key: const ValueKey('football-match-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LogHeader(
          title: 'MATCH TIMELINE',
          count: events.length,
          suffix: 'EVENTS',
        ),
        const SizedBox(height: 12),
        for (final event in events)
          if (_isPeriodMarker(event.type))
            _PeriodMarker(event: event)
          else
            _TimelineRow(
              event: event,
              accent: event.isHomeTeam ? homeColor : awayColor,
            ),
      ],
    );
  }
}
```

Three decisions worth keeping:

- **The empty state is a first-class branch**, not a `SizedBox`. An upcoming
  fixture has no events and the panel still has to say something — so it shows
  `CyberNoDataState` with a `timeline` icon and a football spark, and promises
  what will appear ("Goals, cards and substitutions will be tracked here.").
- **Period markers are filtered out of the spine** by `_isPeriodMarker`. Kickoff,
  halftime, second half and full time are not one team's moment, so they get the
  full-width divider treatment instead of a side.
- **Both accents are resolved once**, above the loop, not per row.

---

## 4. One moment — `_kSpineWidth` and `_TimelineRow`

Verbatim:

```dart
/// Width of the centre column. Sized for the longest stoppage-time label
/// ("90'+5'") so the spine never shifts sideways between rows.
const double _kSpineWidth = 60;

/// One moment on the spine: the minute in the centre, the event pushed out to
/// its own team's side. Tapping expands the feed's own report on the moment.
class _TimelineRow extends StatefulWidget {
  const _TimelineRow({required this.event, required this.accent});

  final MatchEvent event;
  final Color accent;

  @override
  State<_TimelineRow> createState() => _TimelineRowState();
}

class _TimelineRowState extends State<_TimelineRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isHome = event.isHomeTeam;
    final report = event.description?.trim() ?? '';
    final body = _EventBody(
      event: event,
      accent: widget.accent,
      alignEnd: isHome,
    );
    return PressableScale(
      enabled: report.isNotEmpty,
      onTap: report.isEmpty
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
            },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: isHome ? body : const SizedBox.shrink()),
                  _MinuteSpine(event: event, accent: widget.accent),
                  Expanded(child: isHome ? const SizedBox.shrink() : body),
                ],
              ),
            ),
            if (_open && report.isNotEmpty)
              _EventReport(
                text: report,
                accent: widget.accent,
                alignEnd: isHome,
              ),
          ],
        ),
      ),
    );
  }
}
```

- **`_kSpineWidth = 60` is load-bearing.** It is sized for the longest
  stoppage-time label the feed can produce (`90'+5'`), so the spine never shifts
  sideways between rows. Change it and the centre column wanders; if your feed
  emits longer minute labels, widen this constant rather than letting the plate
  size itself.
- **Interactivity is conditional on content.** `report.isNotEmpty` gates both the
  `PressableScale` (`enabled:`) and the callback (`onTap: null`), so a moment with
  no prose from the feed does not scale, does not fire a haptic, and cannot be
  opened. A row that cannot do anything must not *look* tappable.
- **`IntrinsicHeight` is what lets the spine's hairline span the row.** The
  hairline is a `Positioned.fill` inside the spine; without `IntrinsicHeight` the
  `Row` children do not know the tallest child's height and
  `CrossAxisAlignment.stretch` has nothing to stretch to.
- **`AnimatedSize` wraps the whole row**, not just the report, so the expand reads
  as the row growing rather than a panel appearing under it.
- `alignEnd: isHome` — the home side sits on the **left**, so its copy is
  right-aligned *toward* the spine. Away is the mirror.

---

## 5. The centre column — `_MinuteSpine`

Verbatim:

```dart
/// The centre column: a continuous hairline with the minute plate riding it.
/// Only a goal plate glows — a goal is the one event class that moved the
/// score, so it stays the scarce focal mark down the whole spine.
class _MinuteSpine extends StatelessWidget {
  const _MinuteSpine({required this.event, required this.accent});

  final MatchEvent event;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isGoal = event.type == MatchEventType.goal;
    return SizedBox(
      width: _kSpineWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: 1,
                color: Cyber.line.withValues(alpha: 0.32),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 7, smallCut: 0),
              borderColor: accent.withValues(alpha: isGoal ? 0.72 : 0.3),
              glowColor: accent,
              glow: isGoal ? 1 : 0,
              child: Container(
                width: 48,
                height: 26,
                alignment: Alignment.center,
                color: isGoal ? accent.withValues(alpha: 0.12) : Cyber.panel,
                child: Text(
                  event.minuteLabel,
                  maxLines: 1,
                  style:
                      Cyber.display(
                        10.5,
                        color: isGoal ? accent : Cyber.muted,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**This is where the glow rule lands.** Down a spine of twenty-odd events, exactly
one class of event moved the score — so `isGoal` is the only thing that earns a
glow (`glow: isGoal ? 1 : 0`), a brighter border (`0.72` vs `0.3`), an
accent-tinted fill (`alpha: 0.12` vs flat `Cyber.panel`) and accent-coloured text
(vs `Cyber.muted`). Every other minute plate is calm. Glow nothing else here; if
every plate glows the spine carries no information.

Other details:

- The hairline is `Cyber.line` at `alpha: 0.32` and **1 logical pixel wide** —
  continuous behind the plate, which sits above it in the `Stack`.
- The plate is a fixed `48 × 26` on a `HudChamferClipper(bigCut: 7, smallCut: 0)`
  — the two-corner diagonal cut, the app's signature silhouette.
- `FontFeature.tabularFigures()` via `.copyWith` — `Cyber.display` does not take
  `fontFeatures`, so it is applied afterwards. Without it, `11'` and `88'` have
  different widths and the plate text visibly jitters down the column.
- `maxLines: 1` — a wrapped minute label would break the fixed plate height.

---

## 6. The event copy — `_EventBody`

Verbatim:

```dart
/// The copy for one moment, mirrored so the glyph always hugs the spine and
/// the text reads outward from it.
class _EventBody extends StatelessWidget {
  const _EventBody({
    required this.event,
    required this.accent,
    required this.alignEnd,
  });

  final MatchEvent event;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? TextAlign.right : TextAlign.left;
    final lines = <Widget>[];

    if (event.type == MatchEventType.substitution &&
        event.secondaryPlayerName != null) {
      // A swap reads as two names, not one: who came on, then who came off.
      lines.add(
        Text(
          event.playerName.toUpperCase(),
          textAlign: align,
          style: Cyber.display(11, color: Cyber.lime, letterSpacing: 0.4),
        ),
      );
      lines.add(const SizedBox(height: 2));
      lines.add(
        Text(
          event.secondaryPlayerName!.toUpperCase(),
          textAlign: align,
          style: Cyber.display(11, color: Cyber.danger, letterSpacing: 0.4),
        ),
      );
    } else {
      lines.add(
        Text(
          (event.playerName.isEmpty
                  ? event.label ?? 'MATCH EVENT'
                  : event.playerName)
              .toUpperCase(),
          textAlign: align,
          style: Cyber.display(11.5, letterSpacing: 0.4),
        ),
      );
      if (event.type == MatchEventType.goal && event.scoreDisplay != null) {
        lines.add(const SizedBox(height: 3));
        lines.add(
          Text(
            event.scoreDisplay!,
            textAlign: align,
            style: Cyber.display(11, color: accent).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      }
      if (event.secondaryPlayerName != null) {
        lines.add(const SizedBox(height: 3));
        lines.add(
          Text(
            'ASSIST ${event.secondaryPlayerName!.toUpperCase()}',
            textAlign: align,
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.6),
          ),
        );
      }
    }

    final copy = Flexible(
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: lines,
      ),
    );
    final glyph = _EventGlyph(
      type: event.type,
      color: _eventTone(event.type, accent),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alignEnd
            ? [copy, const SizedBox(width: 8), glyph]
            : [glyph, const SizedBox(width: 8), copy],
      ),
    );
  }
}
```

The body composes its lines conditionally, and there are two distinct shapes:

**A substitution** is two names, not one — `Cyber.lime` for the player coming on,
`Cyber.danger` for the one going off — and this branch ignores the accent
entirely, because the colours *are* the meaning. It requires
`secondaryPlayerName != null`; a substitution with only one name falls through to
the generic branch.

**Everything else** is a headline name, plus up to two optional lines:

| Line | Condition | Style |
| --- | --- | --- |
| Name (or `label`, or `'MATCH EVENT'`) | always | `Cyber.display(11.5)`, white |
| `scoreDisplay` | goals only, when present | `Cyber.display(11, accent)`, tabular |
| `ASSIST <name>` | `secondaryPlayerName != null` | `Cyber.label(8, muted)` |

Note the three-level fallback on the headline: `playerName`, then `label`, then
the literal `'MATCH EVENT'` — the row never renders blank, whatever the feed
omits.

**Mirroring lives here too.** `alignEnd` drives three things at once: the
`TextAlign` of every line, the `CrossAxisAlignment` of the column, and the order
of `[copy, gap, glyph]` vs `[glyph, gap, copy]`. The result is that the glyph
always hugs the spine and the text always reads outward from it. `Flexible` on the
copy column is what keeps a long name from overflowing its half.

---

## 7. The event mark — `_EventGlyph`

Verbatim:

```dart
/// The event mark. Cards are drawn as actual cards rather than borrowed from
/// the icon set — the shape carries the meaning faster than any glyph does.
class _EventGlyph extends StatelessWidget {
  const _EventGlyph({required this.type, required this.color});

  final MatchEventType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isCard =
        type == MatchEventType.yellowCard || type == MatchEventType.redCard;
    final mark = isCard
        ? Transform.rotate(
            angle: 0.18,
            child: Container(
              width: 9,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                border: Border.all(
                  color: Cyber.bg.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
            ),
          )
        : Icon(_eventIcon(type), size: 15, color: color);
    return ChamferedActionSurface(
      clipper: const HudChamferClipper(bigCut: 7, smallCut: 0),
      borderColor: color.withValues(alpha: 0.42),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        color: color.withValues(alpha: 0.1),
        child: mark,
      ),
    );
  }
}
```

**Cards are drawn, not iconised.** A yellow or red card is a `9 × 13` rectangle
rotated `0.18` rad with a dark hairline border — the shape carries the meaning
faster than any glyph from the Material set, and it is the detail that stops the
timeline reading as generic. Everything else uses an icon: a football for a goal,
`swap_horiz` for a substitution, `bolt` as the catch-all.

The container is a fixed `28 × 28` on the same `HudChamferClipper(7, 0)` as the
minute plate, filled with the tone at `alpha: 0.1` and bordered at `0.42`. **It
never glows** — only the goal minute plate does.

---

## 8. The tap reveal — `_EventReport`

Verbatim:

```dart
/// The feed's own prose on a moment, revealed on tap and pinned to the side of
/// the team it belongs to.
class _EventReport extends StatelessWidget {
  const _EventReport({
    required this.text,
    required this.accent,
    required this.alignEnd,
  });

  final String text;
  final Color accent;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final edge = BorderSide(color: accent.withValues(alpha: 0.7), width: 2);
    return Padding(
      padding: EdgeInsets.only(
        left: alignEnd ? 0 : _kSpineWidth + 8,
        right: alignEnd ? _kSpineWidth + 8 : 0,
        bottom: 10,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border(
            left: alignEnd ? BorderSide.none : edge,
            right: alignEnd ? edge : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Text(
            text,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Cyber.body(11.5, color: Cyber.muted),
          ),
        ),
      ),
    );
  }
}
```

The report is indented by `_kSpineWidth + 8` on the side *away* from its team, so
it occupies the same half as the moment it belongs to and clears the spine
exactly. The 2px accent rail sits on the outer edge — left rail for an away
(right-side) event, right rail for a home (left-side) event — which is the mirror
of where the text aligns. Body copy is Onest (`Cyber.body`) in `Cyber.muted`: this
is the feed's prose, not a HUD label, and it should not compete with the event
name above it.

---

## 9. The period divider — `_PeriodMarker`

Verbatim:

```dart
class _PeriodMarker extends StatelessWidget {
  const _PeriodMarker({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
          const SizedBox(width: 10),
          Icon(Icons.adjust, size: 12, color: Cyber.cyan),
          const SizedBox(width: 7),
          Text(
            '${event.label ?? _eventLabel(event.type)} ${event.scoreDisplay ?? ''}'
                .trim()
                .toUpperCase(),
            style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 1),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
        ],
      ),
    );
  }
}
```

Full-width, cyan, centred between two hairline dividers — structurally different
from every other row, because a period boundary belongs to the match rather than
to a team. It prints `label` (falling back to `_eventLabel`) followed by
`scoreDisplay` when the feed attaches one, so halftime reads `HALFTIME 1-1`. The
`.trim()` is what keeps a missing score from leaving a trailing space.

---

## 10. Helpers and the log header

Verbatim:

```dart
Color _eventTone(MatchEventType type, Color accent) => switch (type) {
  MatchEventType.yellowCard => Cyber.amber,
  MatchEventType.redCard => Cyber.danger,
  MatchEventType.substitution => Cyber.lime,
  _ => accent,
};

IconData _eventIcon(MatchEventType type) => switch (type) {
  MatchEventType.goal => Icons.sports_soccer,
  MatchEventType.substitution => Icons.swap_horiz,
  _ => Icons.bolt,
};
class _LogHeader extends StatelessWidget {
  const _LogHeader({
    required this.title,
    required this.count,
    required this.suffix,
  });

  final String title;
  final int count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return CyberSectionHeading(
      label: title,
      trailing: Text(
        '${count.toString().padLeft(3, '0')} $suffix',
        style: Cyber.label(
          8.5,
          color: Cyber.muted,
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

bool _isPeriodMarker(MatchEventType type) => switch (type) {
  MatchEventType.kickoff ||
  MatchEventType.halftime ||
  MatchEventType.secondHalf ||
  MatchEventType.fullTime => true,
  _ => false,
};

String _eventLabel(MatchEventType type) => switch (type) {
  MatchEventType.kickoff => 'Kickoff',
  MatchEventType.halftime => 'Halftime',
  MatchEventType.secondHalf => 'Second half',
  MatchEventType.fullTime => 'Full time',
  MatchEventType.goal => 'Goal',
  MatchEventType.yellowCard => 'Yellow card',
  MatchEventType.redCard => 'Red card',
  MatchEventType.substitution => 'Substitution',
};
```

- **`_eventTone`** is the single place where event type beats team identity. Amber
  / danger / lime are semantic (caution, dismissal, swap) and must not be
  club-coloured; goals and generic events keep the accent.
- **`_LogHeader`** is a `CyberSectionHeading` with a zero-padded tabular count in
  the trailing slot — `022 EVENTS`. The zero padding is deliberate HUD greeble:
  fixed-width counters read as telemetry. It is shared with the COMMENTARY tab
  (`'LIVE MATCH COMMS' / 'ENTRIES'`), so port it once.
- **`_eventLabel`** is only reached by `_PeriodMarker` as a fallback; the spine
  rows never call it.

---

## 11. Every layout value in one place

| Element | Value |
| --- | --- |
| Spine column width | `60` (`_kSpineWidth`) — sized for `90'+5'` |
| Minute plate | `48 × 26`, chamfer `bigCut: 7, smallCut: 0` |
| Minute plate text | `Cyber.display(10.5)` + tabular, `maxLines: 1` |
| Hairline | `1` wide, `Cyber.line` @ `alpha: 0.32` |
| Goal plate | border `alpha: 0.72`, fill accent @ `0.12`, `glow: 1` |
| Non-goal plate | border `alpha: 0.3`, fill `Cyber.panel`, `glow: 0` |
| Glyph | `28 × 28`, chamfer `7 / 0`, fill tone @ `0.1`, border @ `0.42` |
| Card glyph | `9 × 13`, `Transform.rotate(0.18)`, border `Cyber.bg` @ `0.6`, `0.8` wide |
| Icon glyph | `size: 15` |
| Glyph ↔ copy gap | `8` |
| Row vertical padding | `10` (both the spine and the body) |
| Event name | `Cyber.display(11.5, letterSpacing: 0.4)` |
| Sub names | `Cyber.display(11, letterSpacing: 0.4)`, lime on / danger off |
| Score line | `Cyber.display(11, accent)` + tabular |
| Assist line | `Cyber.label(8, muted, letterSpacing: 0.6)` |
| Report indent | `_kSpineWidth + 8` = `68`, `bottom: 10` |
| Report rail | `2` wide, accent @ `alpha: 0.7`, outer edge |
| Report text | `Cyber.body(11.5, muted)` |
| Period marker | vertical padding `12`, `Icons.adjust` @ `12`, `Cyber.label(9, cyan, letterSpacing: 1)`, dividers cyan @ `0.24` |
| Header → first row gap | `12` |
| Header count | `Cyber.label(8.5, muted, letterSpacing: 0.8)` + tabular, zero-padded to 3 |
| Expand animation | `AnimatedSize` `220 ms`, `Curves.easeOutCubic`, `alignment: topCenter` |
| Press animation | `PressableScale` → `0.97` over `90 ms`, `Curves.easeOut` |

At the call site the panel sits in a `ListView` with
`padding: EdgeInsets.fromLTRB(16, 14, 16, 28)` and an `18` gap above it. The panel
itself adds no horizontal padding — it stretches to the list's content width.

---

## 12. Design rules to keep

1. **One glow on the whole spine class: the goal minute plate.** This is the
   app-wide glow rule (glow = live / selected / primary, and it is scarce) applied
   locally. Glyphs, report panels, non-goal plates and period markers are all flat
   fill + border.
2. **The spine replaces the legend.** Do not add a `MIN` column header, a repeated
   team label per row, or a "tap a moment for the full report" caption — the widget
   test asserts all three are absent. Side *is* the team; the plate *is* the
   minute; the press scale *is* the affordance.
3. **Identity colour comes from the team, semantic colour from the event.** Club
   accents only on goals and generic events; amber/danger/lime always win for
   cards and subs.
4. **Every number is tabular.** Minute plates, score lines and the event count —
   otherwise the fixed-width plate and the counter jitter.
5. **Labels are uppercase Orbitron with generous tracking; prose is Onest.** The
   report body is the only running text in the panel and the only `Cyber.body`.
6. **The chamfer is the shape language.** `HudChamferClipper(bigCut: 7,
   smallCut: 0)` on both the plate and the glyph; no rounded rects anywhere in the
   panel.
7. **Degrade, never blank.** Missing player name → `label` → `'MATCH EVENT'`;
   missing description → a non-interactive row; no events at all → the promise
   state.

---

## 13. Tests and keys

Covered by [`test/football_match_stats_view_test.dart`](../../test/football_match_stats_view_test.dart)
(lines 66–110), which asserts:

| Assertion | What it pins |
| --- | --- |
| `find.text('MATCH TIMELINE')` | the header renders |
| `ValueKey('football-match-timeline')` | the populated panel |
| `'022 EVENTS'` (zero-padded from `timelineEvents.length`) | the `_LogHeader` count format |
| `find.text('MIN')` → nothing | no minute column header |
| `'TAP A MOMENT FOR THE FULL REPORT'` → nothing | no instructional caption |
| home/away `shortName` → nothing inside the panel | no per-row team labels |
| a home scorer's `Rect.right < screen centre` | home events stay left of the spine |
| an away scorer's `Rect.left > screen centre` | away events stay right of the spine |

Keys to port: `ValueKey('football-timeline-block')` (on the panel at the call
site), `ValueKey('football-match-timeline')` (the populated `Column`) and
`ValueKey('football-timeline-empty')` (the no-data state).

Not covered today, worth adding in a port: the tap-to-expand reveal, the
substitution two-name branch, the `_PeriodMarker` branch, and that only a goal
plate carries a glow.

---

## 14. Port checklist

1. **Tokens.** Drop in the flattened `Cyber` class from App. C, or map each token
   onto your own theme. Declare Orbitron + Onest, or retarget `displayFont` /
   `bodyFont`.
2. **Model.** Add `MatchEventType` and `MatchEvent` from App. A — or map your own
   event type onto the eight-case enum and the nine fields the panel reads
   (§2). The `minuteLabel` getter must exist.
3. **Shared widgets.** Add the seven classes in App. B: `SectionLabel`,
   `CyberSectionHeading`, `CyberNoDataState`, `PressableScale`,
   `HudChamferClipper`, `ChamferedActionSurface`, `ChamferedActionBorderPainter`.
   `CyberNoDataState` is only needed for the empty branch; `ChamferedActionSurface`
   and its painter are what draw the diagonal border, and cannot be replaced by a
   `BoxDecoration.border` (a rectangular border is clipped away with the child —
   see the note in its doc comment).
4. **Accents.** Replace `paletteForTeam(...).secondaryTextColor` with your own
   per-team colour, or the stand-in in App. C. It must clear 4.5:1 against
   `Cyber.panel` and `Cyber.bg`, or the minute plates and score lines will fail
   contrast.
5. **Panel + widgets.** Paste §3 through §10. Rename `_MatchTimelinePanel` to a
   public `MatchTimelinePanel` if it will live in its own file, and make `match`
   whatever type carries your events — the panel only needs the four reads in §2.
6. **Host it** in a `ListView`/`Column` that gives it horizontal padding; the panel
   stretches and adds none.
7. **Haptics.** `HapticFeedback.selectionClick()` on expand. Drop it on web, or
   gate it behind a platform check if your target does not support it.
8. **Verify.** `flutter analyze` clean, then check in the running app: the spine
   stays centred across stoppage-time labels, only goal plates glow, and home/away
   events land on the correct sides.

---

## Implementation References

- [`lib/screens/predictions/widgets/football_match_stats_view.dart`](../../lib/screens/predictions/widgets/football_match_stats_view.dart)
  — `_MatchTimelinePanel` (565), `_kSpineWidth` (618), `_TimelineRow` (622),
  `_MinuteSpine` (686), `_EventBody` (742), `_EventGlyph` (840), `_EventReport`
  (882), `_PeriodMarker` (923), `_eventTone` (952), `_eventIcon` (959),
  `_LogHeader` (1095), `_isPeriodMarker` (1123), `_eventLabel` (1131); call site in
  `_OverviewSection` (106).
- [`lib/models/sport_match.dart`](../../lib/models/sport_match.dart) —
  `MatchEventType` (13), `MatchEvent` (24).
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart)
  — `SectionLabel` (651), `CyberSectionHeading` (674), `CyberNoDataState` (921),
  `HudChamferClipper` (1920), `ChamferedActionSurface` (1954),
  `ChamferedActionBorderPainter` (1985), `PressableScale` (3140).
- [`lib/config/theme.dart`](../../lib/config/theme.dart) — `Cyber` (558).
- [`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart) —
  `paletteForTeam` (4526), `TeamPalette.secondaryTextColor` (44).
- [`test/football_match_stats_view_test.dart`](../../test/football_match_stats_view_test.dart)
  — timeline assertions at 66–110.
- Product context: [`docs/product/systems/predictions.md`](../product/systems/predictions.md).

---

## Appendix A — models, verbatim

From `lib/models/sport_match.dart`. Only `MatchEventType` and `MatchEvent` are
required; `MatchStatus` is included because it sits in the same block and the
surrounding stats view uses it.

```dart
enum MatchStatus { upcoming, live, finished }

enum MatchEventType {
  kickoff,
  goal,
  yellowCard,
  redCard,
  substitution,
  halftime,
  secondHalf,
  fullTime,
}

class MatchEvent {
  const MatchEvent({
    required this.minute,
    required this.isHomeTeam,
    required this.playerName,
    required this.type,
    this.secondaryPlayerName,
    this.displayMinute,
    this.clockSeconds,
    this.period,
    this.label,
    this.teamName,
    this.scoreDisplay,
    this.description,
  });

  final int minute;
  final bool isHomeTeam;
  final String playerName;
  final MatchEventType type;
  final String?
  secondaryPlayerName; // Used for substitution (e.g. player subbed off)
  final String? displayMinute;
  final int? clockSeconds;
  final int? period;
  final String? label;
  final String? teamName;
  final String? scoreDisplay;
  final String? description;

  String get minuteLabel => displayMinute ?? "$minute'";
}
```

The panel reads `type`, `isHomeTeam`, `playerName`, `secondaryPlayerName`,
`label`, `scoreDisplay`, `description` and the `minuteLabel` getter. `minute`
matters only as `minuteLabel`'s fallback. `clockSeconds`, `period`, `teamName`
and `displayMinute` (directly) are unused here — a port can drop them.

---

## Appendix B — shared widgets, verbatim

### B.1 `SectionLabel` and `CyberSectionHeading`

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

```

### B.2 `CyberNoDataState`

Needed only for the empty branch. It carries an optional action the timeline does
not use — keep or trim.

```dart
class CyberNoDataState extends StatelessWidget {
  const CyberNoDataState({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = Cyber.cyan,
    this.spark = Icons.auto_awesome,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final IconData spark;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel == null || onAction == null
        ? null
        : PressableScale(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, color: accent, size: 16),
                  const SizedBox(width: 7),
                  Text(
                    actionLabel!,
                    style: Cyber.label(9, color: accent, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 118,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: accent.withValues(alpha: 0.86), size: 78),
                    Positioned(
                      right: 12,
                      bottom: 6,
                      child: Icon(
                        spark,
                        color: Colors.white.withValues(alpha: 0.82),
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.display(
                  14,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  13,
                  color: Cyber.muted,
                  weight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      ),
    );
  }
}
```

### B.3 `PressableScale`

```dart
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _active ? widget.onTap : null,
      onTapDown: _active ? (_) => _setPressed(true) : null,
      onTapUp: _active ? (_) => _setPressed(false) : null,
      onTapCancel: _active ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

### B.4 `HudChamferClipper`, `ChamferedActionSurface`, `ChamferedActionBorderPainter`

The silhouette and its border painter. Both the minute plate and the glyph use
`HudChamferClipper(bigCut: 7, smallCut: 0)` — a diagonal cut at the top-left and
bottom-right only. `ChamferedActionSurface` exists because a rectangular
`BoxDecoration.border` is clipped away along with its child and cannot paint the
diagonal segments, so the path is stroked in the foreground instead; the optional
glow is the goal plate's.

```dart
class HudChamferClipper extends CustomClipper<Path> {
  const HudChamferClipper({required this.bigCut, required this.smallCut});

  final double bigCut;
  final double smallCut;

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant HudChamferClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Clips an interactive surface and strokes that exact path in the foreground.
///
/// A rectangular [BoxDecoration.border] is clipped along with its child and
/// therefore cannot paint the diagonal chamfer segments. CTA implementations
/// use this shell so every straight and cut edge receives the same border.
class ChamferedActionSurface extends StatelessWidget {
  const ChamferedActionSurface({
    required this.clipper,
    required this.borderColor,
    required this.child,
    this.borderWidth = 1,
    this.glowColor,
    this.glow = 0,
    super.key,
  });

  final CustomClipper<Path> clipper;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glow;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: ChamferedActionBorderPainter(
      clipper: clipper,
      color: borderColor,
      width: borderWidth,
      glowColor: glowColor,
      glow: glow,
    ),
    child: ClipPath(clipper: clipper, child: child),
  );
}

/// Border painter shared by app CTAs that use a clipped action silhouette.
class ChamferedActionBorderPainter extends CustomPainter {
  const ChamferedActionBorderPainter({
    required this.clipper,
    required this.color,
    required this.width,
    this.glowColor,
    this.glow = 0,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final double width;
  final Color? glowColor;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (glow > 0 && glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!.withValues(alpha: 0.22 * glow.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 1.5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * glow),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant ChamferedActionBorderPainter oldDelegate) =>
      oldDelegate.clipper != clipper ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.glow != glow;
}
```

---

## Appendix C — tokens and stand-ins

### C.1 Flattened `Cyber`

The real `Cyber` ([`lib/config/theme.dart`](../../lib/config/theme.dart):558) is a
facade over `AppTheme` and carries the whole app's palette. The panel touches
**eight colours and three text helpers** — this is a drop-in replacement with every
alias resolved to a literal, and nothing else:

```dart
import 'package:flutter/material.dart'; // re-exports FontFeature

/// Only the tokens the match timeline panel uses. Values are the resolved
/// AppTheme literals from the source app.
class Cyber {
  // Surfaces
  static const bg = Color(0xFF0D111A); // page ground
  static const panel = Color(0xFF1D293D); // plate / report fill

  // Lines and muted text
  static const line = Color(0xFF45556C); // the spine hairline
  static const muted = Color(0xFF90A1B9); // non-goal minutes, assist, prose

  // Accents
  static const cyan = Color(0xFF5CDFFF); // period markers, section labels
  static const lime = Color(0xFF51FF94); // substitution: coming on
  static const danger = Color(0xFFFF4D4D); // red card, substitution: going off
  static const amber = Color(0xFFFF8904); // yellow card

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

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

Two things to notice if you retarget these:

- **`display` deliberately takes no `fontFeatures`.** That is why the minute plate
  and the score line apply `.copyWith(fontFeatures: const [FontFeature.tabularFigures()])`
  instead. Keep the signature or the call sites stop compiling.
- **`height: 1` on `display`** is what makes the `48 × 26` plate and the `28 × 28`
  glyph hold their size. A default line height overflows both.

Declare the fonts in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Orbitron
      fonts:
        - asset: assets/fonts/Orbitron-Black.ttf
          weight: 900
        - asset: assets/fonts/Orbitron-ExtraBold.ttf
          weight: 800
    - family: Onest
      fonts:
        - asset: assets/fonts/Onest-Medium.ttf
          weight: 500
```

Or set `displayFont` / `bodyFont` to fonts you already ship. A condensed
geometric face for display and a neutral sans for body is the shape of the
system; anything rounded or humanist for the display face loses the HUD read.

### C.2 Team accents — `paletteForTeam` stand-in

The real lookup ([`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart):4526)
resolves a sport- and competition-namespaced table of ~thousands of generated club
palettes, then falls back to deriving one from the team's colour.
`secondaryTextColor` is specifically the *accessible* member of that palette — the
closest chromatic brand colour that clears 4.5:1 against every standard dark
surface in the app. None of that needs to travel. The panel needs one `Color` per
side; this is the minimum that preserves the contrast guarantee:

```dart
/// Returns a team's accent, lightened until it clears 4.5:1 on the dark
/// surfaces the timeline draws on. Replace the brand lookup with your own.
Color timelineAccent(Color brand, {Color on = Cyber.panel}) {
  var candidate = HSLColor.fromColor(brand);
  while (_contrast(candidate.toColor(), on) < 4.5 && candidate.lightness < 0.95) {
    candidate = candidate.withLightness(
      (candidate.lightness + 0.04).clamp(0.0, 1.0),
    );
  }
  return candidate.toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
```

If you have no brand colours at all, `Cyber.cyan` for home and `Cyber.amber` for
away reads correctly — the sides are already distinguished by position, so the
colours only have to differ, not identify. Whatever you choose, check it against
both `Cyber.panel` (the goal plate fill) and `Cyber.bg`; a dark navy club colour
used raw makes the goal minute illegible, which is exactly what
`secondaryTextColor` exists to prevent.

### C.3 Haptics

`HapticFeedback.selectionClick()` from `package:flutter/services.dart` fires on
expand and collapse. It is a no-op on web and desktop — safe to leave in — but if
your port has a "reduce feedback" setting, gate it there rather than removing it;
the press scale alone reads as less responsive on a phone.
