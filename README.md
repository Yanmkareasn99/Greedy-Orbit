# GREEDY ORBIT — Godot browser-game prototype

A minimalist, single-player arcade game. **Click hazards** to destroy them, earn money and points, and climb to a **x5 combo**.
Every run starts with **$0 and no orbiting guard**. Open the **shop with B** or the HUD button to buy a backup guard, upgrades, and shield support.
The guard orbits and intercepts hazards automatically once purchased. Buy **manual controls** separately to unlock Space and D.
Destroy **green Rogue Satellites** to recharge the planet's shield; intercept red Drifters before they reach it.

## Open and play

The default game window is **1440 x 1080**, with the same 4:3 layout. Canvas items render at the window's native resolution, and the browser version adapts to its available screen size. Resizing preserves the aspect ratio and scales mouse targeting with the interface.

1. Install Godot **4.4 or newer** (standard edition / GDScript; 4.5 or 4.6 is fine).
2. Unzip this project anywhere.
3. Open Godot > **Import** > browse to `project.godot`.
4. Click **Run Project** (F6 if editing the scene, F5 for whole project).
5. Press **Space** or click to start, then click incoming hazards to earn money. Press **B** to shop; the action pauses while the shop is open.

## Controls

| Input | Action |
|---|---|
| Space (hold, after buying manual controls) | Contract the guard's orbit |
| Left mouse click on a hazard | Destroy that hazard |
| Release Space (with manual controls) | Expand the guard's orbit |
| D (after buying manual controls) | Reverse the guard's orbit direction |
| B / HUD Shop button | Open the shop; B / Esc / X closes it |
| Click shop row / 1–6 (in shop) | Buy the selected item |
| Space / click / Enter | Start from title or retry after the game-over delay |
| R | Restart; blocked during the game-over delay |
| P or Esc / HUD pause button | Pause / resume; the pause screen also has a Resume button |
| Return to title (pause / results) | End the current run and open the title screen; results buttons unlock after the 2-second delay |

## Included in prototype

- A neon space-arcade interface with cyan/magenta accents, glowing orbit rings and panel borders, and an animated orbital title screen. The grouped score/credits/shield HUD, segmented shield meter, wave and guard status, and matching upgrade, pause, and results panels share the same theme. Buttons and shop rows highlight on hover.
- A textured, rotating planet with detailed continents, oceans, polar ice, directional sunlight, ocean reflections, atmospheric scattering, and an independently drifting cloud layer. Planet motion freezes during pause, shopping, and game over. The title-screen satellites orbit continuously.
- A spherical sci-fi shield made of neon-blue hexagonal glass plates, about 80% transparent, with bright connected edges, a soft glow inside each hex, faceted reflections, a blue atmospheric rim, independent random brightness pulses, and localized impact ripples. The dome weakens and changes to amber/red as energy drops, disappears when depleted, and returns when recharged. Shield animation pauses with gameplay.
- Orbit rings have traveling energy streaks, directional chevrons, counter-rotating segments, gentle brightness pulses, and rotating boundary ticks with a light sweep. These effects appear during gameplay and on the title screen, and freeze when gameplay pauses.
- Click a visible hazard, including its glow or warmup warning, to destroy it. One click destroys one target; missed clicks do not score.
- Each click shows a brief expanding ring and sparks at the cursor. Successful hazard hits and purchases turn the pulse green; feedback also works while paused, shopping, or viewing results.
- A purchasable orbiting backup destroys hazards on contact. It is absent until bought, and its controls are a separate paid unlock. Clicking never moves it.
- Incoming **Drifters**, **Spirals**, and **Zigzags** use three detailed asteroid sprites: cratered gray rock, jagged rust-colored rock, and fractured charcoal rock. Each gets a random 80%-170% size, sprite, initial rotation, and tumble speed. Click, guard, shield, and planet collisions use its actual scaled radius. Red, purple, and gold halos/trails identify movement types; green energy **Satellites** retain their recharge symbol.
- Spirals appear from wave one; Zigzags join at 15 seconds. Motion trails reveal their paths, and Zigzags flash a ring just before turning.
- Spawn prediction with random aim errors (hazards pressure rather than strictly track the player).
- A planet shield that spends **25 energy per blocked incoming hazard**, with no passive drain. Drifters, Spirals, and Zigzags all threaten the planet.
- Click destruction and backup collisions are the only sources of points: **100 per Drifter**, **150 per Spiral**, **200 per Zigzag**, **250 per Satellite**, multiplied by the current combo.
- Destroying a **green Satellite** restores **35 shield energy**, up to 100, even when the shield is empty. Satellites appear from the first wave.
- Green energy Satellites have a **10% chance per spawn pattern** in every wave. Each gets its own random **2.5–6 second** collection window when it spawns; its countdown ring follows that timer and turns gold for the final second. Missed energy flies outward, becomes uncollectable, and disappears off-screen without rewards.
- Near misses, survival, expired hazards, and shield blocks award no points.
- Destruction pays **$10 per Drifter**, **$15 per Spiral**, **$20 per Zigzag**, and **$25 per Satellite**, from clicks or guard interceptions. Money rewards are fixed and do not use the score combo. Only green Satellites recharge the shield. Other events award no money.
- Planet-impact game over, x1–x5 destruction combo, elapsed time, and wave progression.
- Game over shows score, best score, time, destruction counts, and remaining cash. All restart inputs are ignored for **2 seconds**; retry then requires a fresh click or key press.
- Best score saved locally to `user://greedy_orbit_best.txt`.
- Neon graphics drawn with `Node2D._draw()`, a shaded planet rendered to a small 2D viewport, and 3 tiny generated WAV effects.

## Shop and upgrades

Money and purchases last for the **current run only**. Restarting resets them; the best score still persists.
The shop pauses hazards, the guard, spawning, and the combo timer. Unaffordable, locked, owned, and maxed items cannot charge money.

| Item | Price | Effect |
|---|---|---|
| Orbiting guard | $60 | Adds an automatic backup on the outer orbit |
| Guard speed | $50 / $100 / $150 | Adds 25% of base orbit speed per level, up to +75% |
| Guard size | $50 / $100 / $150 | Adds 4 px of interception radius per level, up to +12 px |
| Manual guard controls | $75 | Unlocks Space for orbit movement and D for direction reversal |
| Shield armor | $60 / $120 / $180 | Reduces shield hit cost by 5 per level, down to 10 energy |
| Repair shield | $30 each | Restores 40 energy, capped at 100; unavailable when full |

Guard speed, size, and controls require the guard first. Shield purchases are available without a guard.

## Browser export

Godot 4.x requires the **Compatibility** renderer for Web export; the project already selects it.

1. Godot > **Editor > Manage Export Templates** > install export templates for your installed Godot version.
2. Godot > **Project > Export** > **Add > Web**.
3. Leave **Thread Support** disabled (single-threaded web export, best for straightforward hosting).
4. Export as `index.html` to a new `web/` directory.
5. Upload all generated files together to itch.io (HTML game) or any HTTPS static host.
6. Test in Chrome or Firefox; Web exports require WebGL 2 and WebAssembly.

Note: browsers may disable persistent high scores in private-browsing mode or when storage is blocked.

## Vercel deployment

The `web/` folder contains the deployable Web export, and `vercel.json` tells Vercel to serve that folder without running build or install commands.
Push the project (including `web/` and `vercel.json`) to GitHub, import the repository in Vercel with Framework Preset **Other**, and deploy. Keep Vercel's Root Directory at the repository root.
After gameplay changes, export again to `web/index.html` before pushing so the browser build includes the changes. Play and test the browser game through its Vercel deployment URL.

## Project files

```text
project.godot
scenes/game.tscn
scripts/game.gd
assets/start.wav
assets/near.wav
assets/hit.wav
DESIGN.md
```

## How to tune the prototype

Most game constants are at the top of `scripts/game.gd`:

- `ORBIT_SPEED`: how fast the player automatically rotates.
- `RADIUS_CHANGE_SPEED`: how quickly the orbit contracts/expands.
- `GAMEPLAY_SCALE`: scales the gameplay planet, shield, orbit rings, and boundary decorations to 85% of their original size. Hazards retain their spawn distance and speed, giving more time before impact.
- `PLANET_SCALE`: an additional 0.5 multiplier for the gameplay planet, shield, and atmospheric glow, keeping the surrounding orbit rings at their existing size.
- `ARENA_SCALE`: orbit and boundary scale, calculated as `0.75 * GAMEPLAY_SCALE`.
- `PLANET_RADIUS` / `SHIELD_RADIUS`: gameplay planet and shield radii (30.6 / 32.3 px), with matching collision boundaries. The title screen uses their unscaled 72 / 76 px base radii.
- `INNER_RADIUS` / `OUTER_RADIUS`: playable orbital limits.
- `CLICK_PADDING`: extra click target radius around each hazard, matching its glow.
- `DRIFTER_SCORE` / `SATELLITE_SCORE`: points awarded for player destruction before the combo multiplier.
- `DRIFTER_MONEY` / `SATELLITE_MONEY`: fixed money rewards per destruction.
- `GUARD_COST` / `GUARD_CONTROLS_COST` / `GUARD_UPGRADE_COST`: guard and upgrade prices.
- `SHIELD_ARMOR_COST` / `SHIELD_REPAIR_COST`: shield support prices.
- `SPIRAL_SCORE` / `SPIRAL_MONEY` / `ZIGZAG_SCORE` / `ZIGZAG_MONEY`: rewards for the new moving hazards.
- `HAZARD_TRAIL_LENGTH`: maximum trail history for curving and turning hazards.
- `SHIELD_HIT_COST`: energy spent blocking an incoming hazard.
- `SHIELD_REFILL_SATELLITE`: energy restored by destroying a green Satellite.
- `ENERGY_SPAWN_CHANCE`: chance for a green energy Satellite in each spawn pattern.
- `ENERGY_ORBIT_MIN_DURATION` / `ENERGY_ORBIT_MAX_DURATION`: bounds for each satellite's random collection window.
- `ENERGY_ESCAPE_SPEED`: outward escape speed.
- `COMBO_DURATION`: how long a combo remains before decaying.
- `GAME_OVER_RETRY_DELAY`: how long game-over results stay protected from restart inputs.

Spawn cadence is in `_physics_process()`; hazard patterns are in `spawn_pattern()`.

## Validation status

Run the gameplay checks with `godot --headless --path . --script res://tests/gameplay_test.gd`.
Run the planet and shield rendering checks with `godot --path . --script res://tests/planet_render_test.gd` using a graphical renderer.
They cover mouse targeting, scoring and money rewards, absent and purchased guards, paid controls, shop input and pausing, purchase prerequisites and prices, upgrade effects and caps, shield repairs and damage, energy spawn frequency and escape deadlines, and restart resets.

Run `godot --path . --resolution 1440x1080 --script res://tests/performance_probe.gd` for an uncapped desktop rendering benchmark. It warms up each scene, then reports mean and 95th-percentile frame time and average draw calls for the title screen, 32 asteroids with a guard, and the shop. Compare runs on the same hardware and window size; this is a benchmark, with no hardware-dependent pass threshold.

The static background is cached, orbit streaks use batched colored lines, and planet/shield render buffers scale with their displayed size (128–320 px). Rotation, shield reflections, and moving orbit effects continue to animate.
