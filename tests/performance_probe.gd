extends SceneTree
## Requires a graphical renderer. VSync is disabled for this process only.
## Compare the same build configuration, hardware, and window resolution.

const FRAMES := 180
const WARMUP_FRAMES := 45
var results: Dictionary = {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The performance probe requires a graphical renderer.")
		quit(2)
		return
	call_deferred("run_probe")


func tick(game: Node2D) -> void:
	# Fixed simulation steps keep each scenario comparable at different FPS.
	game._process(1.0 / 60.0)
	if game.state == "playing":
		game._physics_process(1.0 / 60.0)


func sample(game: Node2D, label: String) -> void:
	for i in range(WARMUP_FRAMES):
		tick(game)
		await process_frame
	var frame_times: Array[float] = []
	var draw_calls := 0.0
	var previous := Time.get_ticks_usec()
	for i in range(FRAMES):
		tick(game)
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	frame_times.sort()
	var total := 0.0
	for value in frame_times:
		total += value
	results[label] = {
		"mean_frame_ms": total / FRAMES,
		"p95_frame_ms": frame_times[ceili(FRAMES * 0.95) - 1],
		"draw_calls": draw_calls / FRAMES,
	}


func run_probe() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := load("res://scenes/game.tscn").instantiate() as Node2D
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stream = null
	await sample(game, "menu")
	game.start_game()
	game.rng.seed = 20261015
	game.money = 1000
	game.guard_owned = true
	game.spawn_clock = -9999.0
	for i in range(32):
		game.call(["spawn_drifter", "spawn_spiral", "spawn_zigzag"][i % 3], TAU * i / 32.0)
		game.hazards.back()["radius"] = 245.0
		game.hazards.back()["speed"] = 0.0
		game.hazards.back()["age"] = 1.0
	await sample(game, "playing_32_asteroids")
	game.state = "shop"
	await sample(game, "shop")
	results["window_size"] = str(root.size)
	results["frames_per_scene"] = FRAMES
	print(JSON.stringify(results, "  "))
	game.queue_free()
	await process_frame
	quit()
