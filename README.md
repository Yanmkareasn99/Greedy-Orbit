# GREEDY ORBIT — Godot browser-game prototype

A minimalist, single-player arcade game. **Click hazards** to destroy them, earn money and points, and climb to a **x5 combo**.
Every run starts with **$0 and no orbiting guard**. Open the **shop with B** or the HUD button to buy a backup guard, upgrades, and shield support.
The guard orbits and intercepts hazards automatically once purchased. Buy **manual controls** separately to unlock Space and D.
Destroy **green Rogue Satellites** to recharge the planet's shield; intercept red Drifters before they reach it.

## Open and play

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
| P or Esc | Pause / resume |

## Included in prototype

- Click a visible hazard, including its glow or warmup warning, to destroy it. One click destroys one target; missed clicks do not score.
- Each click shows a brief expanding ring and sparks at the cursor. Successful hazard hits and purchases turn the pulse green; feedback also works while paused, shopping, or viewing results.
- A purchasable orbiting backup destroys hazards on contact. It is absent until bought, and its controls are a separate paid unlock. Clicking never moves it.
- Radial **Drifters**, counterclockwise **Rogue Satellites**, and **Twin Strike** patterns.
- Spawn prediction with random aim errors (hazards pressure rather than strictly track the player).
- A planet shield that spends **25 energy per blocked Drifter**, with no passive drain.
- Click destruction and backup collisions are the only sources of points: **100 per Drifter**, **250 per Satellite**, multiplied by the current combo.
- Destroying a **green Satellite** restores **35 shield energy**, up to 100, even when the shield is empty. Satellites appear from the first wave.
- Green energy Satellites have a **10% chance per spawn pattern** in every wave. Each gets its own random **2.5–6 second** collection window when it spawns; its countdown ring follows that timer and turns gold for the final second. Missed energy flies outward, becomes uncollectable, and disappears off-screen without rewards.
- Near misses, survival, expired hazards, and shield blocks award no points.
- Destroyed Drifters pay **$10** and destroyed Satellites pay **$25**, from clicks or guard interceptions. Money rewards are fixed and do not use the score combo. Other events award no money.
- Planet-impact game over, x1–x5 destruction combo, elapsed time, and wave progression.
- Game over shows score, best score, time, destruction counts, and remaining cash. All restart inputs are ignored for **2 seconds**; retry then requires a fresh click or key press.
- Best score saved locally to `user://greedy_orbit_best.txt`.
- Geometric graphics drawn with `Node2D._draw()`; 3 tiny generated WAV effects.

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

Do not double-click `index.html` as a `file://` page. Use a local HTTP server or upload to a host.

Note: browsers may disable persistent high scores in private-browsing mode or when storage is blocked.

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
- `INNER_RADIUS` / `OUTER_RADIUS`: playable orbital limits.
- `CLICK_PADDING`: extra click target radius around each hazard, matching its glow.
- `DRIFTER_SCORE` / `SATELLITE_SCORE`: points awarded for player destruction before the combo multiplier.
- `DRIFTER_MONEY` / `SATELLITE_MONEY`: fixed money rewards per destruction.
- `GUARD_COST` / `GUARD_CONTROLS_COST` / `GUARD_UPGRADE_COST`: guard and upgrade prices.
- `SHIELD_ARMOR_COST` / `SHIELD_REPAIR_COST`: shield support prices.
- `SHIELD_HIT_COST`: energy spent blocking a Drifter.
- `SHIELD_REFILL_SATELLITE`: energy restored by destroying a green Satellite.
- `ENERGY_SPAWN_CHANCE`: chance for a green energy Satellite in each spawn pattern.
- `ENERGY_ORBIT_MIN_DURATION` / `ENERGY_ORBIT_MAX_DURATION`: bounds for each satellite's random collection window.
- `ENERGY_ESCAPE_SPEED`: outward escape speed.
- `COMBO_DURATION`: how long a combo remains before decaying.
- `GAME_OVER_RETRY_DELAY`: how long game-over results stay protected from restart inputs.

Spawn cadence is in `_physics_process()`; hazard patterns are in `spawn_pattern()`.

## Validation status

Run the gameplay checks with `godot --headless --path . --script res://tests/gameplay_test.gd`.
They cover mouse targeting, scoring and money rewards, absent and purchased guards, paid controls, shop input and pausing, purchase prerequisites and prices, upgrade effects and caps, shield repairs and damage, energy spawn frequency and escape deadlines, and restart resets.
