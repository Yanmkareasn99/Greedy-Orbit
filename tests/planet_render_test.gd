extends SceneTree
## Requires a graphical renderer; run with --path . --script res://tests/planet_render_test.gd.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func capture(game: Node2D, shield: bool = false) -> Image:
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport: SubViewport = game.shield_viewport if shield else game.planet_viewport
	var frame := viewport.get_texture().get_image()
	# Keep the sampling coordinates consistent across adaptive render resolutions.
	if frame.get_size() != Vector2i(320, 320):
		frame.resize(320, 320, Image.INTERPOLATE_BILINEAR)
	return frame


func shield_totals(frame: Image) -> Vector4:
	var totals := Vector4.ZERO
	for y in range(0, frame.get_height(), 4):
		for x in range(0, frame.get_width(), 4):
			var pixel := frame.get_pixel(x, y)
			totals += Vector4(pixel.r * pixel.a, pixel.g * pixel.a, pixel.b * pixel.a, pixel.a)
	return totals


func run_checks() -> void:
	var game := load("res://scenes/game.tscn").instantiate() as Node2D
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stream = null
	var initial := await capture(game)
	check(initial.get_pixel(160, 160).a > 0.95, "The planet must render as an opaque globe.")
	check(initial.get_pixel(0, 0).a < 0.01, "The atmosphere must fade to a transparent background.")
	var brightest := 0.0
	var darkest := 1.0
	for y in range(80, 241, 8):
		for x in range(80, 241, 8):
			var luminance := initial.get_pixel(x, y).get_luminance()
			brightest = maxf(brightest, luminance)
			darkest = minf(darkest, luminance)
	check(brightest - darkest > 0.25, "Surface detail and directional lighting must be visible.")
	game._process(4.0)
	var rotated := await capture(game)
	check(initial.get_data() != rotated.get_data(), "The globe must visibly rotate on the title screen.")
	game.state = "playing"
	game._process(4.0)
	var playing := await capture(game)
	check(rotated.get_data() != playing.get_data(), "The planet and clouds must animate during gameplay.")
	for frozen_state in ["paused", "shop", "dead"]:
		game.state = frozen_state
		game._process(1.0)
		var frozen := await capture(game)
		check(playing.get_data() == frozen.get_data(), "Planet motion must freeze in state: " + frozen_state)
	game.state = "playing"
	game._process(2.0)
	var resumed := await capture(game)
	check(playing.get_data() != resumed.get_data(), "Planet motion must resume after returning to gameplay.")
	game.shield_energy = 100.0
	var full_shield := await capture(game, true)
	var full_totals := shield_totals(full_shield)
	check(full_totals.w > 100.0, "An energized shield must render a visible hexagonal membrane.")
	check(full_shield.get_pixel(0, 0).a < 0.01, "The shield must stay transparent outside its dome.")
	var translucent := 0
	var opaque := 0
	var samples := 0
	for y in range(64, 257, 4):
		for x in range(64, 257, 4):
			var pixel := full_shield.get_pixel(x, y)
			samples += 1
			if pixel.a >= 0.15 and pixel.a < 0.35: translucent += 1
			if pixel.a > 0.75: opaque += 1
	check(translucent > samples * 0.5 and opaque < samples * 0.05, "Most plate faces must remain about 80 percent transparent, with no opaque armor panels.")
	check(full_totals.z > full_totals.y and full_totals.y > full_totals.x, "The healthy shield and its reflections must retain a neon-blue tint.")
	game._process(1.0)
	var swept := await capture(game, true)
	check(full_shield.get_data() != swept.get_data(), "Random plate brightness and reflections must animate across the glass shield.")
	for frozen_state in ["paused", "shop", "dead"]:
		game.state = frozen_state
		game._process(1.0)
		var frozen_shield := await capture(game, true)
		check(swept.get_data() == frozen_shield.get_data(), "Shield animation must freeze in state: " + frozen_state)
	game.state = "playing"
	game.shield_energy = 20.0
	var low_shield := await capture(game, true)
	var low_totals := shield_totals(low_shield)
	check(low_totals.x > low_totals.y, "A critically depleted shield must turn red.")
	check(low_totals.w < full_totals.w, "Low shield energy must weaken the membrane's glow.")
	game.shield_energy = 0.0
	var empty_shield := await capture(game, true)
	check(shield_totals(empty_shield).w < 0.01, "A depleted shield must disappear completely.")
	game.shield_energy = 100.0
	var restored_shield := await capture(game, true)
	check(shield_totals(restored_shield).w > 100.0, "Recharging must restore the hex shield.")
	game.absorb_debris(game.CENTER + Vector2.RIGHT * (game.SHIELD_RADIUS + 10.0))
	var impacted_shield := await capture(game, true)
	game.shield_impact_age = 10.0
	var settled_shield := await capture(game, true)
	var impact_area := Rect2i(240, 112, 64, 96)
	check(shield_totals(impacted_shield.get_region(impact_area)).w > shield_totals(settled_shield.get_region(impact_area)).w + 1.0, "A blocked hit must light up the plates around its impact location.")
	game.start_game()
	var restarted_shield := await capture(game, true)
	check(restarted_shield.get_data() == restored_shield.get_data(), "Restarting must clear the previous shield impact ripple.")
	print("Planet and shield rendering checks: %d passed, %d failed." % [checks - failures, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
