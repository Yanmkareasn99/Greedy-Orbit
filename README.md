# GREEDY ORBIT — Godot browser-game prototype

A minimalist, single-player arcade game. Your player orbits a planet automatically.
**Hold Space or the left mouse button** to pull inward; **release** to push outward.
Almost collide with hazards to earn near-miss scores, refill the planet's shield, and climb to a **x5 combo**.

## Open and play

1. Install Godot **4.4 or newer** (standard edition / GDScript; 4.5 or 4.6 is fine).
2. Unzip this project anywhere.
3. Open Godot > **Import** > browse to `project.godot`.
4. Click **Run Project** (F6 if editing the scene, F5 for whole project).
5. Press **Space** to start, then hold/release Space to change orbit.

## Controls

| Input | Action |
|---|---|
| Space (hold) | Contract orbit |
| Left mouse (hold) | Contract orbit |
| Release | Expand orbit |
| D | Reverse orbit direction |
| Space / click | Start from title or retry after death |
| R | Restart immediately |
| P or Esc | Pause / resume |

## Included in prototype

- Smooth one-button orbit movement with selectable direction; collision ends the run.
- Radial **Drifters**, counterclockwise **Rogue Satellites**, and **Twin Strike** patterns.
- Spawn prediction with random aim errors (hazards pressure rather than strictly track the player).
- A planet shield that steadily loses energy over time and absorbs incoming Drifters without additional energy loss.
- Near misses are the only source of points and shield energy; Perfect near misses refill more.
- Planet-impact and player-collision game overs, x1–x5 combo, elapsed time, and wave progression.
- Best score saved locally to `user://greedy_orbit_best.txt`.
- Geometric graphics drawn with `Node2D._draw()`; 3 tiny generated WAV effects.

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
- `NEAR_RANGE`: how close you must pass to get a bonus.
- `COMBO_DURATION`: how long a combo remains before decaying.

Spawn cadence is in `_physics_process()`; hazard patterns are in `spawn_pattern()`.

## Validation status

This project was assembled and checked for complete files and consistent references, but could not be run inside the author's environment because a Godot executable is not installed there. Please use Godot's Run Project action for an engine-level smoke test.
