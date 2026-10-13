# Greedy Orbit — Game Design v1

## Pillars

1. Understand controls in **five seconds**: hold inward, release outward.
2. Every death is understandable; hazards are drawn before they can collide.
3. Score rewards bravery, not merely survival.
4. Restart instantly. No content grind or accounts.
5. Art is geometry, particles, screen feedback and generated sound effects.

## Mechanical rules

- Player continuously moves clockwise around fixed center.
- Holding Space or left mouse smoothly contracts orbit from 234 px to 126 px.
- Releasing smoothly expands to 234 px.
- One collision with an active red hazard ends the run.
- Enemy Drifters spawn at a radius of 340 px and move radially toward the center.
- Rogue Satellites orbit counterclockwise at a fixed radius near the player's current radius. They expire after a few seconds.
- Twin Strike spawns two nearby Drifters using the same geometry and logic.
- Hazard warning time is indicated by a translucent red appearance.
- Each surviving second = 10 points.
- A near miss requires an actual pass, not sitting near an enemy: the distance must first approach then separate beyond 55 px.
- A near miss gives 100 * current_combo. A perfect near miss gives 250 * current_combo.
- Perfect near-miss range extends 11 px beyond the lethal collision radius; normal near-miss range extends out to 49 px.
- Each earned near miss raises the combo by one up to x5; the next bonus uses the previous combo value.
- The combo decreases when the 4.5-second meter runs out, then decreases again every 1.6s if no near miss is earned.
- Best score persists locally (subject to browser storage permission).

## Difficulty plan

| Time | Tier | Spawn logic |
|---|---|---|
| 0–15s | Wave 1 | Drifters; 32% predictive angles, 68% random; interval ~2.2s |
| 15–30s | Wave 2 | Introduce counter-orbiting satellites; predictive aim rises to 55%; spawn interval decreases |
| 30–45s | Wave 3 | Twin Strike combination joins |
| 45–60s | Wave 4 | Hazard speed and frequency accelerate |
| 60s+ | Wave 5 | Endless difficulty, capped to protect fairness |

Aim prediction is intentionally imprecise and uses the radius at spawn time; moving in or out avoids it. It prevents a player who never touches the controls from staying safe indefinitely.

## Prototype scope and two-week release plan

- **Day 1:** Validate feel of orbit radius, rotation speed, Space/button input.
- **Day 2:** Tune Drifters and fixed collision rules.
- **Day 3:** Playtest near misses with slow-motion debugging toggle (development only).
- **Day 4:** Add predictive hazard logic and warmup cues; rebalance.
- **Day 5:** Satellites and Twin Strikes; test for unwinnable overlaps.
- **Day 6:** Combo, scoring, high score; prevent award exploits.
- **Day 7:** Menus, pause, game-over and instant restart.
- **Day 8:** Sound effects and visible near-miss/combo feedback.
- **Day 9:** Focused difficulty ramp balancing with five testers.
- **Day 10:** Add optional keyboard accessibility, motion/flash options and mute.
- **Day 11:** Full browser export; Chrome/Firefox testing at different aspect ratios.
- **Day 12:** Performance and bug fixes, desktop and touch-device tests.
- **Day 13:** Instructions, thumbnail/cover, itch.io page and release candidate.
- **Day 14:** Release and collect feedback.

### Must ship

One arena; single button; three obstacle patterns; score/combo/high score; menu/death/retry; HTML5 export.

### Nice-to-have, only if on schedule

Mute, slight screen shake, alternative palette, achievement-like badges, near-miss statistics, accessibility options.

### Cut from v1

Character skins, progression economy, leaderboard back end, achievements server, multiple arenas, accounts, story and online multiplayer.

## First playtest checklist

1. Can a new player correctly learn the control in five seconds?
2. Is contracting and releasing both useful, and is staying outside always safe? (It shouldn't be.)
3. Can the player understand why each collision happened?
4. Do near misses feel rewarded, and can a good player reliably build a x3 combo?
5. Is early difficulty survivable but tense, and do wave 3+ hazards remain readable?
6. Is R-to-restart immediate and does the local high score persist after restarting?
7. Can the Web version begin with mouse click to unlock audio in common browsers?

Target median first-run length ~20–40s, practiced run ~60–120s. Tune from playtests rather than assuming these are already achieved.
