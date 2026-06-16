# Pitch Duel — project instructions

This is **Pitch Duel**, a Flutter card/football game. The user base is **gamers**,
not enterprise users. Plan and build accordingly.

## Working agreement (read first — applies to EVERY major task)

For any non-trivial task in this project you MUST, every time:

1. **Apply the Planning rules below** when scoping the work — reuse existing UI,
   make it gamified, build in gratification, keep theme/style intact, plan for
   gamers. This holds whether or not you are formally in plan mode.
2. **Invoke BOTH the `theme` and `cyber-ui` skills** before writing or changing
   any visual code (screens, widgets, cards, dialogs, meters, buttons, layout,
   colour, type) — for ALL UI requests, not just big ones. `theme` is the build
   guide (file location, scaffold, AppTheme/Cyber tokens, BlocBuilder, verify);
   `cyber-ui` is the aesthetic guide (glow rule, shape language, components).
   `theme` assembles the screen, `cyber-ui` makes it look right. Don't rely on
   memory of the design system — load the skills.

Skip this only for genuinely trivial, non-visual edits (typo fixes, a one-line
logic tweak, answering a question). When in doubt, treat it as a major task and
follow the agreement.

## Planning rules (apply to EVERY plan — plan mode and inline)

When you plan any change here, the plan MUST satisfy all of the following. Treat
these as hard constraints, not suggestions. If a request conflicts with them,
call it out and propose a gamified alternative before planning the literal ask.

1. **Reuse the existing UI first.** Before proposing anything new, find the
   screen/widget/component that already does something similar and extend it.
   Prefer the shared cyber components (`CyberPanel`, `CyberProgressBar`,
   `HudCtaButton`, `GameScaffold`, `CyberSegmentedTabs`, etc.) over net-new
   widgets. New UI is a last resort; if a pattern repeats 2+ times, plan to
   extract it into `lib/widgets/cyber/cyber_widgets.dart` rather than duplicate.
   Every plan should name the concrete existing files/widgets it builds on.

2. **Always make it gamified.** This is a game — never plan a flat,
   utilitarian, "form + list" solution. Default to game feel: progression, XP,
   streaks, levels, unlocks, challenges, reveals, leaderboards, juice
   (animation, motion, sound, haptics). A plain CRUD/settings-style screen is a
   bug in the plan. Ask "how would a game studio ship this?"

3. **Build in gratification.** Every meaningful action should pay the player
   back with a moment: reward reveals, celebration overlays, score-impact ticks,
   stingers, cinematic settlement, level-up beats, satisfying transitions. Plan
   the *feedback*, not just the function. Reuse existing moment patterns
   (settlement reveal, pack unpack, level-up celebration, round-result beats).

4. **Keep the theme and style intact.** All visual work follows the **`theme`**
   skill (`.claude/skills/theme/SKILL.md`) — the build guide (file location,
   scaffold, tokenised `AppTheme`/`Cyber` colour/type, BlocBuilder, verify) — and
   the **`cyber-ui`** skill (`.claude/skills/cyber-ui/SKILL.md`) — the esports /
   cyberpunk HUD aesthetic. Pull colours/type from `AppTheme`/`Cyber.*` (never raw
   hex or stock `TextStyle`). Honour THE GLOW RULE (glow = live/selected/primary,
   and it's scarce). Use the diagonal corner-cut shape language. New UI must look
   like it belongs in the existing app, not like a generic template. **Invoke both
   the `theme` and `cyber-ui` skills whenever a plan touches anything visual.**

5. **Plan for gamers.** Optimize for the player's experience: speed to fun, low
   friction, clear feedback, a sense of reward and mastery. Avoid enterprise/
   admin framing. When trading off, favour delight and game feel over the
   minimal/"correct" implementation.

## Other conventions
- Run `flutter analyze <changed files>` — must be clean before a change is done.
- For visual changes, confirm in the running app (`/run`), not just analyze.
- Project history and feature context live in the memory index
  (`.claude/projects/.../memory/MEMORY.md`).
