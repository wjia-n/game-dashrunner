# Dash Runner — RULES.md

The authoritative rules for Dash Runner. If the implementation conflicts with
this document, the implementation is wrong and must be fixed.

## 1. Objective
Run as far as you can. Score = distance (m) + 10 per coin + 5 per near miss
+ 25 per 500 m milestone. One crash ends the run. In Score Attack the run
ends at 90 seconds instead.

## 2. Setup
- Choose a mode: Chill Dash (easy), Trail Run (normal), Extreme Dash (hard,
  PRO only), or Score Attack (90 s).
- Tap START. A 3-2-1 countdown runs, then the runner dashes automatically.

## 3. Turn order
There are no turns: the world scrolls continuously and the runner moves on
its own. The player only reacts.

## 4. Legal moves
- JUMP: tap anywhere while grounded. Clears crates, boulders and cacti.
- SLIDE: swipe down while grounded. Slides under flyers (birds) and low
  branches. A slide lasts 0.65 s.
- Jump then slide (or slide then jump) in sequence is legal; jumping cancels
  a slide.

## 5. Illegal moves
- No double jump: tapping mid-air does nothing.
- No sliding mid-air: swiping down while airborne does nothing.
- No input during countdown, pause, crash animation, or game over.
- A slide cannot be extended by swiping again while sliding.

## 6. Captures
Not applicable — there are no opponents or captures.

## 7. Special rules
- Speed rises with distance, capped per mode (Chill 620, Trail/Score 900,
  Extreme 1080 px/s).
- Obstacle spawn rate quickens with distance (min gaps per mode).
- Flyers only appear after 250 m (any mode) or immediately in Extreme.
- Coins spawn in arcs of 5, sometimes high (jump arcs) sometimes low
  (slide lines).
- A near miss is scored when an obstacle passes the runner with less than
  ~30 px of vertical clearance.

## 8. Scoring
- +1 per meter traveled.
- +10 per coin collected.
- +5 per near miss.
- +25 per 500 m milestone (500 m, 1000 m, …).
- All four components are shown separately on the results screen.

## 9. Winning conditions
There is no final win: the goal is a personal best per mode. A new best
score or distance is celebrated and saved.

## 10. Draw conditions
Not applicable.

## 11. AI strategy
Not applicable — single-player only, no bots.

## 12. Edge cases
- App backgrounded mid-run: the run pauses (engine phase `paused`) and the
  music pauses; both resume exactly where they left off.
- Ticker stalls: the engine watchdog resyncs the clock so the world never
  freezes or teleports.
- Crash during slide: the death tumble plays; input is locked.
- Score Attack timer hits 0 mid-jump: the run ends cleanly with "TIME'S UP!",
  not a crash.
- Two obstacles overlapping on spawn: spawn timer spacing plus the minimum
  gap prevents impossible walls; a jump always clears a single obstacle.

## 13. Test cases
1. Tap START → countdown 3-2-1 ticks audibly → world moves.
2. Tap while grounded → runner jumps, whoosh plays, lands with a thud.
3. Tap mid-air → nothing happens (no double jump).
4. Swipe down grounded → slide for 0.65 s with swoosh + dust.
5. Swipe down mid-air → nothing happens.
6. Run into a crate → crash thud, death tumble, results panel with the
   four score components.
7. Collect a coin → ding, +10, coin toast.
8. Thread a crate tightly → "Close one! +5", +5.
9. Reach 500 m → chime, "500 m! +25" toast, +25.
10. Score Attack → 90 s countdown in HUD, "TIME'S UP!" at 0.
11. Pause button / background app → run freezes, resumes cleanly.
12. New best → fanfare, NEW BEST badge, best saved per mode.
13. Extreme mode locked for free players; PRO unlocks it.
14. App restart → profile (name, theme, gear, bests) intact.
