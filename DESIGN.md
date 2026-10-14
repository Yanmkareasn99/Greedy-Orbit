# Greedy Orbit — Game Design v1

## Pillars

1. Understand controls in **five seconds**: click hazards, earn money, and buy backup defenses.
2. Every death is understandable; hazards are drawn before they can collide.
3. Score rewards bravery, not merely survival.
4. Restart quickly after a brief protected results screen. No content grind or accounts.
5. Art is geometry, particles, screen feedback and generated sound effects.

## Mechanical rules

- Every run starts with $0 and no guard. An unpurchased guard is absent from rendering, movement, and collisions.
- Left-clicking a visible hazard destroys it immediately, including during its warmup warning. The click target includes the 7 px glow; overlapping targets resolve topmost first, one hazard per click.
- A $60 guard purchase adds an automatic backup that orbits clockwise and destroys hazards on contact.
- The central planet, shield, orbit guides, and boundary decorations use a 0.75 arena scale, making them 25% smaller.
- Manual controls cost $75 and require the guard. Until purchased, Space and D cannot control it. After purchase, Space contracts its orbit from 175.5 px to 94.5 px, release expands it, and D reverses direction. Mouse clicks do not change its orbit.
- Colliding with an active hazard destroys it, awards points once, and keeps the player alive.
- The planet's shield starts with 100 energy and spends 25 energy per blocked incoming hazard, with no passive drain. Its final energy can block one hit.
- At zero energy the shield disappears; a Drifter, Spiral, or Zigzag that reaches the unshielded planet ends the run.
- Destroying a green Rogue Satellite restores 35 shield energy, capped at 100, and can reactivate an empty shield. Destroying red Drifters does not recharge it.
- Enemy Drifters spawn at a radius of 340 px and move radially toward the center.
- Purple Spirals also start at 340 px, then curve clockwise or counterclockwise while moving inward. They pay 150 * combo points and $15 on destruction.
- Gold diamond Zigzags start at 340 px, moving inward while repeatedly reversing angular steering. Their period and angular range vary per hazard. They pay 200 * combo points and $20 on destruction.
- Both new types have 0.45-second warmups and short motion trails. A warning ring appears 0.15 seconds before a Zigzag turns. They can be destroyed by clicks or a purchased guard and never recharge shield energy.
- Green energy Satellites orbit counterclockwise at a fixed radius near the guard's current orbit. They have a 10% spawn chance in every wave, including waves with Twin Strike.
- Each energy Satellite gets an independent random collection window between 2.5 and 6 seconds at spawn; the duration stays fixed for that satellite. Its countdown ring follows its own timer and turns gold for the final second. At its deadline it becomes uncollectable by clicks or guards, flies radially outward at 240 px/s, and disappears once its body and glow leave the viewport. Escape awards no points, money, or shield energy and causes no damage.
- Collection and escape timers freeze during pause and shopping, alongside the rest of the simulation.
- Twin Strike spawns two nearby Drifters using the same geometry and logic.
- Hazard warning time is indicated by a translucent appearance. Green Satellites also carry a plus symbol to identify the recharge type.
- All score comes from clicking hazards or backup collisions. Near misses, survival, missed clicks, expiration, and shield blocks give no points or energy rewards.
- A destroyed Drifter gives 100 * current_combo; a destroyed Satellite gives 250 * current_combo.
- Each destroyed hazard raises the combo by one up to x5; the award uses the combo value before the increase.
- The combo decreases when the 4.5-second meter runs out, then decreases again every 1.6s if no hazard is destroyed.
- Click and guard destruction also pay fixed rewards: $10 per Drifter, $25 per Satellite. The score combo does not multiply money; shield blocks, survival, near misses, and expiration pay nothing.
- B or the HUD Shop button opens a shop that pauses all simulation and combo timers. Click a row or press 1–6 to buy; B, Esc, P, or X resumes play. Shop clicks never reach hazards behind it.
- Guard speed and size each have three levels priced $50/$100/$150 and require a guard. Each level adds 25% of base orbit speed or 4 px of interception radius.
- Shield armor has three levels priced $60/$120/$180, each reducing shield impact cost by 5, down to 10 energy. It does not require a guard.
- A $30 shield repair restores 40 energy, capped at 100, and can be bought repeatedly while the shield is damaged.
- Purchases require sufficient funds and cannot repeat an owned unlock or exceed an upgrade cap. Money and all upgrades reset on restart.
- Best score persists locally (subject to browser storage permission).
- Game over displays score, best score, elapsed time, destruction counts, and remaining cash. Restart inputs (click, Space, Enter, R) are discarded for 2 seconds. The retry prompt appears when the delay ends; a fresh input is required to restart.

## Difficulty plan

| Time | Tier | Spawn logic |
|---|---|---|
| 0–15s | Wave 1 | 10% green energy; remaining patterns choose 25% Spirals or 75% Drifters, with 32% predictive angles; interval ~2.2s |
| 15–30s | Wave 2 | Energy remains at 10%; remaining patterns choose 25% Spirals, 20% Zigzags, or 55% Drifters; predictive aim rises to 55% |
| 30–45s | Wave 3 | Twin Strike joins at 25%; energy remains at 10%; other patterns retain the Spiral/Zigzag/Drifter mix |
| 45–60s | Wave 4 | Hazard speed and frequency accelerate |
| 60s+ | Wave 5 | Endless difficulty, capped to protect fairness |

Aim prediction is intentionally imprecise and uses the radius at spawn time. Changing orbit and direction helps intercept Drifters before they reach the shield and collect Satellites to restore its energy.

## Prototype scope and two-week release plan

- **Day 1:** Validate feel of orbit radius, rotation speed, Space/button input.
- **Day 2:** Tune Drifters and fixed collision rules.
- **Day 3:** Playtest hazard interception and shield recharge with slow-motion debugging toggle (development only).
- **Day 4:** Add predictive hazard logic and warmup cues; rebalance.
- **Day 5:** Satellites and Twin Strikes; test for unwinnable overlaps.
- **Day 6:** Combo, scoring, high score; prevent award exploits.
- **Day 7:** Menus, pause, game-over results and protected restart.
- **Day 8:** Sound effects and visible destruction/combo/shield feedback.
- **Day 9:** Focused difficulty ramp balancing with five testers.
- **Day 10:** Add optional keyboard accessibility, motion/flash options and mute.
- **Day 11:** Full browser export; Chrome/Firefox testing at different aspect ratios.
- **Day 12:** Performance and bug fixes, desktop and touch-device tests.
- **Day 13:** Instructions, thumbnail/cover, itch.io page and release candidate.
- **Day 14:** Release and collect feedback.

### Must ship

One arena; click-to-destroy controls and an orbiting backup; three obstacle patterns; score/combo/high score; menu/death/retry; HTML5 export.

### Nice-to-have, only if on schedule

Mute, slight screen shake, alternative palette, achievement-like badges, destruction statistics, accessibility options.

### Cut from v1

Character skins, persistent progression between runs, leaderboard back end, achievements server, multiple arenas, accounts, story and online multiplayer.

## First playtest checklist

1. Can a new player correctly learn the control in five seconds?
2. Can the player earn and buy the first guard through clicks, and are the guard's upgrades and paid controls useful?
3. Can the player understand why each collision happened?
4. Does intercepting hazards feel rewarding, can a good player reliably build a x3 combo, and are green recharge Satellites clear?
5. Is early difficulty survivable but tense, and do wave 3+ hazards remain readable?
6. Do accidental clicks and restart keys leave results visible for 2 seconds, does a fresh input then restart, and does the local high score persist?
7. Can the Web version begin with mouse click to unlock audio in common browsers?

Target median first-run length ~20–40s, practiced run ~60–120s. Tune from playtests rather than assuming these are already achieved.
