extends Node2D
## Greedy Orbit: click hazards, earn money, and buy an orbiting backup guard.
## The game is drawn in _draw() and updated on fixed physics ticks.

const CENTER := Vector2(480.0, 364.0)
const WORLD := Vector2(960.0, 720.0)
const GAMEPLAY_SCALE := 0.85
const PLANET_SCALE := 0.5
const ARENA_SCALE := 0.75 * GAMEPLAY_SCALE
const INNER_RADIUS := 126.0 * ARENA_SCALE
const OUTER_RADIUS := 234.0 * ARENA_SCALE
const PLAYER_SIZE := 9.0
const CLICK_PADDING := 7.0               # include the visible hazard glow in click targets
const CLICK_PULSE_DURATION := 0.32
const MAX_CLICK_PULSES := 24
const ORBIT_SPEED := 2.65                 # radians per second (clockwise)
const RADIUS_CHANGE_SPEED := 235.0        # px per second
const COMBO_DURATION := 4.5              # seconds before combo starts decaying
const GAME_OVER_RETRY_DELAY := 2.0       # keep results visible before accepting restart inputs
const PLANET_BASE_RADIUS := 72.0
const SHIELD_BASE_RADIUS := 76.0
const PLANET_RADIUS := PLANET_BASE_RADIUS * GAMEPLAY_SCALE * PLANET_SCALE
const SHIELD_RADIUS := SHIELD_BASE_RADIUS * GAMEPLAY_SCALE * PLANET_SCALE
const SHIELD_MAX_ENERGY := 100.0
const SHIELD_HIT_COST := 25.0             # energy spent blocking one incoming hazard
const SHIELD_REFILL_SATELLITE := 35.0     # energy restored by destroying a green Satellite
const DRIFTER_SCORE := 100
const SATELLITE_SCORE := 250
const DRIFTER_MONEY := 10
const SATELLITE_MONEY := 25
const SPIRAL_SCORE := 150
const SPIRAL_MONEY := 15
const ZIGZAG_SCORE := 200
const ZIGZAG_MONEY := 20
const HAZARD_TRAIL_LENGTH := 16
const ASTEROID_MIN_SCALE := 0.8
const ASTEROID_MAX_SCALE := 1.7
const ASTEROID_TEXTURE_PATHS := [
	"res://assets/asteroids/cratered.png",
	"res://assets/asteroids/jagged.png",
	"res://assets/asteroids/fractured.png",
]
# Silhouette bounds measured from the 512 px imports. Keep these with the
# sprites so startup never reads texture pixels back from the GPU.
const ASTEROID_SPRITE_BOUNDS := [
	{"center": Vector2(259.0, 254.5), "radius": 249.71897},
	{"center": Vector2(253.5, 256.0), "radius": 273.37243},
	{"center": Vector2(259.5, 259.0), "radius": 250.49596},
]
const ENERGY_SPAWN_CHANCE := 0.10
const ENERGY_ORBIT_MIN_DURATION := 2.5   # shortest random collection window
const ENERGY_ORBIT_MAX_DURATION := 6.0   # longest random collection window
const ENERGY_ESCAPE_SPEED := 240.0       # outward flight speed after collection time runs out
const GUARD_COST := 60
const GUARD_CONTROLS_COST := 75
const GUARD_UPGRADE_COST := 50
const SHIELD_ARMOR_COST := 60
const SHIELD_REPAIR_COST := 30
const SHIELD_REPAIR_ENERGY := 40.0
const MAX_UPGRADE_LEVEL := 3
const SHOP_BUTTON := Rect2(28, 126, 138, 40)
const SHOP_CLOSE_BUTTON := Rect2(746, 99, 40, 36)
const PAUSE_BUTTON := Rect2(862, 28, 70, 40)
const RESUME_BUTTON := Rect2(330, 440, 300, 52)
const PAUSE_TITLE_BUTTON := Rect2(330, 506, 300, 42)
const RESULTS_TITLE_BUTTON := Rect2(280, 570, 400, 42)
const START_BUTTON := Rect2(64, 412, 300, 56)
const SHOP_ITEMS := [
	{"id": "guard", "name": "Guard", "description": "Auto intercept"},
	{"id": "speed", "name": "Speed", "description": "+25% speed"},
	{"id": "range", "name": "Size", "description": "+4 px reach"},
	{"id": "controls", "name": "Controls", "description": "Space: in / D: reverse"},
	{"id": "armor", "name": "Armor", "description": "-5 energy per hit"},
	{"id": "repair", "name": "Repair", "description": "+40 energy"},
]
const SAVE_FILE := "user://greedy_orbit_best.txt"

const BACK := Color("#060511")
const PALE := Color("#f2efff")
const MUTED := Color("#a29cbd")
const PANEL := Color("#100d26")
const EDGE := Color("#40305e")
const CYAN := Color("#13efff")
const MAGENTA := Color("#ff38d1")
const RED := Color("#ff386c")
const GOLD := Color("#ffe44d")
const GREEN := Color("#42ffac")
const PURPLE := Color("#bd72ff")

var rng := RandomNumberGenerator.new()
var state := "menu"                       # menu, playing, paused, shop, dead
var elapsed := 0.0
var angle := -PI / 2.0
var orbit_direction := 1.0                # 1.0 = clockwise, -1.0 = counterclockwise
var orbit_radius := OUTER_RADIUS
var player_pos := CENTER + Vector2.UP * OUTER_RADIUS
var spawn_clock := 0.0
var points := 0.0
var money := 0
var guard_owned := false
var guard_controls_owned := false
var guard_speed_level := 0
var guard_range_level := 0
var shield_armor_level := 0
var shop_message := ""
var best_score := 0
var shield_energy := SHIELD_MAX_ENERGY
var combo := 1
var combo_clock := 0.0
var hazards_destroyed := 0
var satellites_destroyed := 0
var next_wave := 2
var time_to_wave_message := 0.0
var flash := 0.0
var shake := 0.0
var arena_offset := Vector2.ZERO         # last drawn shake offset, also used for click targeting
var death_reason := "player"
var game_over_clock := 0.0
var hazards: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var click_pulses: Array[Dictionary] = []
var trail: Array[Vector2] = []
var stars: Array[Vector2] = []
var ui_time := 0.0
var ui_styles: Dictionary = {}
var planet_clock := 0.0
var planet_viewport: SubViewport
var planet_material: ShaderMaterial
var shield_viewport: SubViewport
var shield_material: ShaderMaterial
var shield_visual_state: Array = []
var shield_impact_position := Vector2(0.0, -0.9)
var shield_impact_age := 10.0
var asteroid_textures: Array[Texture2D] = []
var asteroid_bounds: Array[Dictionary] = []
var background_viewport: SubViewport
var planet_surface: ColorRect
var shield_surface: ColorRect


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rng.randomize()
	best_score = load_best_score()
	setup_planet()
	setup_shield()
	setup_asteroids()
	for i in range(90):
		stars.append(Vector2(rng.randf_range(16.0, 944.0), rng.randf_range(12.0, 705.0)))
	setup_background()
	update_effect_resolution()
	queue_redraw()


func setup_planet() -> void:
	# Draw the shaded globe to a small texture, so it can sit beneath the
	# existing shield, hazards, and UI in the game's immediate drawing order.
	planet_viewport = SubViewport.new()
	planet_viewport.name = "PlanetRenderer"
	planet_viewport.size = Vector2i(320, 320)
	planet_viewport.transparent_bg = true
	planet_viewport.disable_3d = true
	planet_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(planet_viewport)
	planet_material = ShaderMaterial.new()
	planet_material.shader = load("res://assets/planet.gdshader")
	planet_material.set_shader_parameter("surface_map", load("res://assets/planet_surface.png"))
	planet_surface = ColorRect.new()
	planet_surface.size = Vector2(320, 320)
	planet_surface.color = Color.WHITE
	planet_surface.material = planet_material
	planet_viewport.add_child(planet_surface)


func setup_shield() -> void:
	shield_viewport = SubViewport.new()
	shield_viewport.name = "ShieldRenderer"
	shield_viewport.size = Vector2i(320, 320)
	shield_viewport.transparent_bg = true
	shield_viewport.disable_3d = true
	shield_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(shield_viewport)
	shield_material = ShaderMaterial.new()
	shield_material.shader = load("res://assets/shield.gdshader")
	shield_surface = ColorRect.new()
	shield_surface.size = Vector2(320, 320)
	shield_surface.color = Color.WHITE
	shield_surface.material = shield_material
	shield_viewport.add_child(shield_surface)


func update_effect_resolution() -> void:
	# Match the costly shaders to their displayed footprint, including resizing.
	var window_size := Vector2(get_window().size)
	var display_scale := minf(window_size.x / WORLD.x, window_size.y / WORLD.y)
	var planet_radius := PLANET_BASE_RADIUS if state == "menu" else PLANET_RADIUS
	var shield_radius := SHIELD_BASE_RADIUS if state == "menu" else SHIELD_RADIUS
	var extent := maxf(planet_radius * 1.2, shield_radius * 1.12)
	var side := clampi(ceili(extent * 2.0 * display_scale / 32.0) * 32, 128, 320)
	if planet_viewport.size.x == side:
		return
	planet_viewport.size = Vector2i(side, side)
	planet_surface.size = Vector2(side, side)
	planet_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	shield_viewport.size = Vector2i(side, side)
	shield_surface.size = Vector2(side, side)
	shield_visual_state.clear()
	shield_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func setup_background() -> void:
	# Bake the static nebula, grid, and stars once instead of blending dozens
	# of large translucent circles and rebuilding their geometry every frame.
	background_viewport = SubViewport.new()
	background_viewport.name = "BackgroundCache"
	background_viewport.size = Vector2i(WORLD)
	background_viewport.disable_3d = true
	background_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(background_viewport)
	var painter := Node2D.new()
	painter.draw.connect(draw_static_background.bind(painter))
	background_viewport.add_child(painter)


func setup_asteroids() -> void:
	for i in range(ASTEROID_TEXTURE_PATHS.size()):
		asteroid_textures.append(load(ASTEROID_TEXTURE_PATHS[i]))
		asteroid_bounds.append(ASTEROID_SPRITE_BOUNDS[i])


func randomize_asteroid(hazard: Dictionary) -> void:
	var scale_factor := rng.randf_range(ASTEROID_MIN_SCALE, ASTEROID_MAX_SCALE)
	hazard["size_scale"] = scale_factor
	hazard["size"] = float(hazard["size"]) * scale_factor
	hazard["sprite_index"] = rng.randi_range(0, ASTEROID_TEXTURE_PATHS.size() - 1)
	hazard["rotation"] = rng.randf_range(-PI, PI)
	hazard["spin"] = rng.randf_range(0.25, 1.0) * (-1.0 if rng.randf() < 0.5 else 1.0)


func _input(event: InputEvent) -> void:
	var click_pulse: Dictionary = {}
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor_event: InputEventMouseButton = make_input_local(event)
		click_pulse = {"position": cursor_event.position, "age": 0.0, "color": CYAN}
		click_pulses.append(click_pulse)
		if click_pulses.size() > MAX_CLICK_PULSES:
			click_pulses.pop_front()
		queue_redraw()
	# Ignore gameplay clicks and restart keys during the results delay.
	# Discard them here so they cannot restart the run when the delay ends.
	if state == "dead" and game_over_clock > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle_shop()
		elif state == "shop" and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			buy_upgrade(str(SHOP_ITEMS[event.keycode - KEY_1]["id"]))
		elif event.keycode == KEY_D:
			reverse_orbit_direction()
		elif event.keycode == KEY_R:
			start_game()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if state == "shop":
				toggle_shop()
			elif state == "playing":
				state = "paused"
			elif state == "paused":
				state = "playing"
			queue_redraw()
		elif (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and (state == "menu" or state == "dead"):
			start_game()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "dead":
			var local_event: InputEventMouseButton = make_input_local(event)
			if RESULTS_TITLE_BUTTON.has_point(local_event.position):
				return_to_title()
			else:
				start_game()
		elif state == "menu":
			start_game()
		elif state == "playing":
			var local_event: InputEventMouseButton = make_input_local(event)
			if SHOP_BUTTON.has_point(local_event.position):
				toggle_shop()
			elif PAUSE_BUTTON.has_point(local_event.position):
				state = "paused"
			else:
				if destroy_hazard_at(local_event.position - arena_offset):
					click_pulse["color"] = GREEN
		elif state == "paused":
			var local_event: InputEventMouseButton = make_input_local(event)
			if RESUME_BUTTON.has_point(local_event.position):
				state = "playing"
			elif PAUSE_TITLE_BUTTON.has_point(local_event.position):
				return_to_title()
		elif state == "shop":
			var local_event: InputEventMouseButton = make_input_local(event)
			if SHOP_CLOSE_BUTTON.has_point(local_event.position):
				toggle_shop()
			else:
				for i in range(SHOP_ITEMS.size()):
					if shop_row_rect(i).has_point(local_event.position):
						if buy_upgrade(str(SHOP_ITEMS[i]["id"])):
							click_pulse["color"] = GREEN
						break


func toggle_shop() -> void:
	if state == "playing":
		state = "shop"
		shop_message = ""
	elif state == "shop":
		state = "playing"
	queue_redraw()


func shop_row_rect(index: int) -> Rect2:
	return Rect2(174, 206 + index * 62, 612, 54)


func upgrade_cost(item: String) -> int:
	match item:
		"guard": return GUARD_COST
		"controls": return GUARD_CONTROLS_COST
		"speed": return GUARD_UPGRADE_COST * (guard_speed_level + 1)
		"range": return GUARD_UPGRADE_COST * (guard_range_level + 1)
		"armor": return SHIELD_ARMOR_COST * (shield_armor_level + 1)
		"repair": return SHIELD_REPAIR_COST
	return -1


func upgrade_lock_reason(item: String) -> String:
	match item:
		"guard":
			return "OWNED" if guard_owned else ""
		"controls":
			if not guard_owned: return "NEED GUARD"
			return "OWNED" if guard_controls_owned else ""
		"speed", "range":
			if not guard_owned: return "NEED GUARD"
			var level := guard_speed_level if item == "speed" else guard_range_level
			return "MAX" if level >= MAX_UPGRADE_LEVEL else ""
		"armor":
			return "MAX" if shield_armor_level >= MAX_UPGRADE_LEVEL else ""
		"repair":
			return "FULL" if shield_energy >= SHIELD_MAX_ENERGY else ""
	return "UNAVAILABLE"


func buy_upgrade(item: String) -> bool:
	if state != "shop":
		return false
	var reason := upgrade_lock_reason(item)
	var cost := upgrade_cost(item)
	if not reason.is_empty():
		shop_message = reason
		queue_redraw()
		return false
	if money < cost:
		shop_message = "Need $" + str(cost - money)
		queue_redraw()
		return false
	money -= cost
	match item:
		"guard":
			guard_owned = true
			angle = -PI / 2.0
			orbit_radius = OUTER_RADIUS
			orbit_direction = 1.0
			player_pos = CENTER + Vector2.UP * orbit_radius
			trail.clear()
		"controls": guard_controls_owned = true
		"speed": guard_speed_level += 1
		"range": guard_range_level += 1
		"armor": shield_armor_level += 1
		"repair": shield_energy = minf(SHIELD_MAX_ENERGY, shield_energy + SHIELD_REPAIR_ENERGY)
	shop_message = "-$" + str(cost)
	$StartSound.play()
	queue_redraw()
	return true


func guard_speed() -> float:
	return ORBIT_SPEED * (1.0 + 0.25 * guard_speed_level)


func guard_size() -> float:
	return PLAYER_SIZE + 4.0 * guard_range_level


func shield_hit_cost() -> float:
	return SHIELD_HIT_COST - 5.0 * shield_armor_level


func destroy_hazard_at(where: Vector2) -> bool:
	if state != "playing":
		return false
	# Pick the last drawn (topmost) hazard when targets overlap.
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if not is_hazard_collectible(hazard):
			continue
		var position := hazard_position(hazard)
		if where.distance_to(position) <= float(hazard["size"]) + CLICK_PADDING:
			destroy_hazard(hazard, position)
			hazards.remove_at(i)
			queue_redraw()
			return true
	return false


func reverse_orbit_direction() -> void:
	if not guard_owned or not guard_controls_owned or (state != "playing" and state != "paused"):
		return
	orbit_direction *= -1.0
	queue_redraw()


func _process(delta: float) -> void:
	ui_time += delta
	update_effect_resolution()
	if state == "menu" or state == "playing":
		planet_clock += delta
		shield_impact_age = minf(10.0, shield_impact_age + delta)
		planet_material.set_shader_parameter("animation_time", planet_clock)
		planet_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()
	# Cursor feedback uses real frame time even when gameplay is paused.
	if not click_pulses.is_empty():
		for i in range(click_pulses.size() - 1, -1, -1):
			var pulse: Dictionary = click_pulses[i]
			pulse["age"] = float(pulse["age"]) + delta
			if float(pulse["age"]) >= CLICK_PULSE_DURATION:
				click_pulses.remove_at(i)
		queue_redraw()
	if state != "dead":
		return
	var previous_clock := game_over_clock
	game_over_clock = maxf(0.0, game_over_clock - delta)
	# The results timer must keep running after collision effects finish.
	if not particles.is_empty() or not popups.is_empty() or shake > 0.0:
		update_effects(delta)
		shake = maxf(0.0, shake - 10.0 * delta)
		queue_redraw()
	if previous_clock > 0.0:
		queue_redraw()


func start_game() -> void:
	reset_run()
	state = "playing"
	update_effect_resolution()
	$StartSound.play()
	queue_redraw()


func return_to_title() -> void:
	reset_run()
	state = "menu"
	update_effect_resolution()
	queue_redraw()


func reset_run() -> void:
	shield_impact_age = 10.0
	elapsed = 0.0
	angle = -PI / 2.0
	orbit_radius = OUTER_RADIUS
	player_pos = CENTER + Vector2.UP * orbit_radius
	points = 0.0
	money = 0
	guard_owned = false
	guard_controls_owned = false
	guard_speed_level = 0
	guard_range_level = 0
	shield_armor_level = 0
	shop_message = ""
	orbit_direction = 1.0
	shield_energy = SHIELD_MAX_ENERGY
	combo = 1
	combo_clock = 0.0
	hazards_destroyed = 0
	satellites_destroyed = 0
	hazards.clear()
	particles.clear()
	popups.clear()
	trail.clear()
	spawn_clock = 0.0
	next_wave = 2
	time_to_wave_message = 2.0
	flash = 0.0
	shake = 0.0
	arena_offset = Vector2.ZERO
	death_reason = "player"
	game_over_clock = 0.0


func _physics_process(delta: float) -> void:
	if state != "playing":
		return

	elapsed += delta
	flash = maxf(0.0, flash - 2.0 * delta)
	shake = maxf(0.0, shake - 10.0 * delta)
	time_to_wave_message = maxf(0.0, time_to_wave_message - delta)

	if guard_owned:
		var contract := guard_controls_owned and Input.is_key_pressed(KEY_SPACE)
		var desired_radius := INNER_RADIUS if contract else OUTER_RADIUS
		orbit_radius = move_toward(orbit_radius, desired_radius, RADIUS_CHANGE_SPEED * delta)
		angle = wrapf(angle + guard_speed() * orbit_direction * delta, -PI, PI)
		player_pos = CENTER + Vector2(cos(angle), sin(angle)) * orbit_radius
		trail.append(player_pos)
		if trail.size() > 22:
			trail.pop_front()

	if combo > 1:
		combo_clock -= delta
		if combo_clock <= 0.0:
			combo -= 1
			combo_clock = 1.6 if combo > 1 else 0.0

	var current_wave: int = mini(5, int(floor(elapsed / 15.0)) + 1)
	if current_wave >= next_wave:
		next_wave = current_wave + 1
		time_to_wave_message = 1.6
		spawn_burst(CYAN, CENTER, 18)

	spawn_clock += delta
	var spawn_interval: float = maxf(0.56, 2.20 - elapsed * 0.016)
	if spawn_clock >= spawn_interval:
		spawn_clock -= spawn_interval
		spawn_pattern()

	update_hazards(delta)
	update_effects(delta)
	queue_redraw()


func spawn_pattern() -> void:
	var pattern_roll := rng.randf()
	if pattern_roll < ENERGY_SPAWN_CHANCE:
		spawn_satellite()
	elif elapsed >= 30.0 and pattern_roll < ENERGY_SPAWN_CHANCE + 0.25:
		# Twin strike: two drifting hazards aimed near the predicted player path.
		var base_angle := predicted_drifter_angle()
		spawn_drifter(base_angle - 0.20)
		spawn_drifter(base_angle + 0.20)
	else:
		var aim_chance := 0.32 if elapsed < 15.0 else 0.55
		var planned_angle := predicted_drifter_angle() if rng.randf() < aim_chance else rng.randf_range(-PI, PI)
		var motion_roll := rng.randf()
		if motion_roll < 0.25:
			spawn_spiral(planned_angle)
		elif elapsed >= 15.0 and motion_roll < 0.45:
			spawn_zigzag(planned_angle)
		else:
			spawn_drifter(planned_angle)


func predicted_drifter_angle() -> float:
	# Smart but forgiving: predictions ignore later changes of orbital radius.
	# Hazards pressure a stationary strategy but never have perfect aim.
	var radial_speed := minf(300.0, 195.0 + elapsed * 1.2)
	var impact_delay := (340.0 - orbit_radius) / radial_speed
	if not guard_owned:
		return rng.randf_range(-PI, PI)
	return angle + guard_speed() * orbit_direction * impact_delay + rng.randf_range(-1.70, 1.70)


func spawn_drifter(hazard_angle: float) -> void:
	hazards.append({
		"kind": "drifter",
		"angle": hazard_angle,
		"radius": 340.0,
		"size": 10.0,
		"speed": minf(300.0, 195.0 + elapsed * 1.2),
		"age": 0.0,
		"warmup": 0.35,
	})
	randomize_asteroid(hazards.back())


func spawn_spiral(hazard_angle: float) -> void:
	hazards.append({
		"kind": "spiral",
		"angle": hazard_angle,
		"base_angle": hazard_angle,
		"radius": 340.0,
		"size": 11.0,
		"speed": minf(270.0, 175.0 + elapsed),
		"curve_speed": rng.randf_range(0.65, 1.15) * (-1.0 if rng.randf() < 0.5 else 1.0),
		"age": 0.0,
		"warmup": 0.45,
		"trail": [],
	})
	randomize_asteroid(hazards.back())


func spawn_zigzag(hazard_angle: float) -> void:
	hazards.append({
		"kind": "zigzag",
		"angle": hazard_angle,
		"base_angle": hazard_angle,
		"radius": 340.0,
		"size": 12.0,
		"speed": minf(250.0, 155.0 + elapsed * 0.9),
		"turn_amplitude": rng.randf_range(0.22, 0.38),
		"turn_period": rng.randf_range(0.8, 1.3),
		"age": 0.0,
		"warmup": 0.45,
		"trail": [],
	})
	randomize_asteroid(hazards.back())


func spawn_satellite() -> void:
	var player_angular_speed := guard_speed() * orbit_direction if guard_owned else 0.0
	var enemy_speed := -1.4
	# Target a likely crossing in ~0.9 seconds, with readable lead time.
	var spawn_angle := angle + (player_angular_speed - enemy_speed) * rng.randf_range(0.88, 1.15)
	var satellite_radius := clampf(orbit_radius + rng.randf_range(-29.0, 29.0), INNER_RADIUS + 7.0, OUTER_RADIUS - 7.0)
	hazards.append({
		"kind": "satellite",
		"angle": spawn_angle,
		"radius": satellite_radius,
		"size": 11.0,
		"speed": enemy_speed,
		"age": 0.0,
		"warmup": 0.48,
		"orbit_duration": rng.randf_range(ENERGY_ORBIT_MIN_DURATION, ENERGY_ORBIT_MAX_DURATION),
	})


func update_hazard_motion(h: Dictionary, delta: float) -> void:
	var previous_age := float(h["age"])
	if h.has("trail") and delta > 0.0:
		var path: Array = h["trail"]
		path.append(hazard_position(h))
		if path.size() > HAZARD_TRAIL_LENGTH:
			path.pop_front()
	h["age"] = previous_age + delta
	if h["kind"] == "satellite":
		h["angle"] = float(h["angle"]) + float(h["speed"]) * delta
		# Only the portion of this tick after the deadline contributes to escape movement.
		var orbit_duration := float(h["orbit_duration"])
		var escape_delta := maxf(0.0, float(h["age"]) - orbit_duration) - maxf(0.0, previous_age - orbit_duration)
		h["radius"] = float(h["radius"]) + ENERGY_ESCAPE_SPEED * escape_delta
	else:
		h["radius"] = float(h["radius"]) - float(h["speed"]) * delta
		var active_age := maxf(0.0, float(h["age"]) - float(h["warmup"]))
		if h["kind"] == "spiral":
			h["angle"] = float(h["base_angle"]) + float(h["curve_speed"]) * active_age
		elif h["kind"] == "zigzag":
			# A triangle wave reverses the turning direction without jumping position.
			var phase := TAU * active_age / float(h["turn_period"])
			h["angle"] = float(h["base_angle"]) + float(h["turn_amplitude"]) * (2.0 / PI) * asin(sin(phase))


func update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		update_hazard_motion(h, delta)

		var old_enough: bool = float(h["age"]) >= float(h["warmup"])
		var p: Vector2 = hazard_position(h)
		var distance := p.distance_to(player_pos)
		var collision_distance: float = guard_size() + float(h["size"])
		if guard_owned and old_enough and is_hazard_collectible(h) and distance <= collision_distance:
			destroy_hazard(h, p)
			hazards.remove_at(i)
			continue
		if h["kind"] != "satellite":
			var debris_radius := float(h["radius"])
			var debris_size := float(h["size"])
			if shield_energy > 0.0 and debris_radius <= SHIELD_RADIUS + debris_size:
				absorb_debris(p)
				hazards.remove_at(i)
				continue
			if debris_radius <= PLANET_RADIUS + debris_size:
				die("planet")
				return
		var expired: bool = (h["kind"] != "satellite" and float(h["radius"]) < PLANET_RADIUS)
		# Escaping energy satellites remain visible until their body and glow leave the screen.
		expired = expired or (h["kind"] == "satellite" and not Rect2(Vector2.ZERO, WORLD).grow(float(h["size"]) + CLICK_PADDING).has_point(p))
		if expired:
			hazards.remove_at(i)


func hazard_position(h: Dictionary) -> Vector2:
	var a: float = float(h["angle"])
	return CENTER + Vector2(cos(a), sin(a)) * float(h["radius"])


func is_hazard_collectible(hazard: Dictionary) -> bool:
	return hazard["kind"] != "satellite" or float(hazard["age"]) < float(hazard["orbit_duration"])


func destroy_hazard(hazard: Dictionary, where: Vector2) -> void:
	var recharges_shield: bool = hazard["kind"] == "satellite"
	var base := SATELLITE_SCORE if recharges_shield else DRIFTER_SCORE
	var earned := SATELLITE_MONEY if recharges_shield else DRIFTER_MONEY
	if hazard["kind"] == "spiral":
		base = SPIRAL_SCORE
		earned = SPIRAL_MONEY
	elif hazard["kind"] == "zigzag":
		base = ZIGZAG_SCORE
		earned = ZIGZAG_MONEY
	var gained: int = base * combo
	points += float(gained)
	money += earned
	hazards_destroyed += 1
	var label := "+$" + str(earned)
	var tint := CYAN
	if hazard["kind"] == "spiral": tint = PURPLE
	if hazard["kind"] == "zigzag": tint = GOLD
	if recharges_shield:
		var previous_energy := shield_energy
		shield_energy = minf(SHIELD_MAX_ENERGY, shield_energy + SHIELD_REFILL_SATELLITE)
		satellites_destroyed += 1
		var restored := roundi(shield_energy - previous_energy)
		if restored > 0:
			label += " / +" + str(restored) + "%"
		tint = GREEN
	popups.append({"position": where, "label": label, "age": 0.0, "color": tint})
	spawn_burst(tint, where, 13)
	flash = 0.20
	shake = maxf(shake, 1.7)
	combo = mini(5, combo + 1)
	combo_clock = COMBO_DURATION
	$DestroySound.pitch_scale = 1.0 + float(combo - 1) * 0.08
	$DestroySound.play()


func absorb_debris(where: Vector2) -> void:
	var spent := minf(shield_energy, shield_hit_cost())
	shield_energy = maxf(0.0, shield_energy - spent)
	shield_impact_position = (where - CENTER).normalized() * 0.9
	shield_impact_age = 0.0
	popups.append({"position": where, "label": "-" + str(roundi(spent)) + "%", "age": 0.0, "color": RED})
	shake = maxf(shake, 1.1)
	spawn_burst(GREEN, where, 9)
	$HitSound.play()


func die(reason: String) -> void:
	state = "dead"
	death_reason = reason
	game_over_clock = GAME_OVER_RETRY_DELAY
	shake = 3.0
	spawn_burst(RED, CENTER if reason == "planet" else player_pos, 32)
	if int(points) > best_score:
		best_score = int(points)
		var save := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
		if save != null:
			save.store_string(str(best_score))
	$HitSound.play()
	queue_redraw()


func load_best_score() -> int:
	if not FileAccess.file_exists(SAVE_FILE):
		return 0
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return 0
	return file.get_as_text().to_int()


func spawn_burst(tint: Color, origin: Vector2, count: int) -> void:
	for i in range(count):
		var a := rng.randf_range(-PI, PI)
		var speed := rng.randf_range(35.0, 150.0)
		particles.append({"position": origin, "velocity": Vector2(cos(a), sin(a)) * speed, "life": rng.randf_range(0.28, 0.68), "max_life": 0.68, "color": tint})


func update_effects(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["position"] = Vector2(p["position"]) + Vector2(p["velocity"]) * delta
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(popups.size() - 1, -1, -1):
		var p: Dictionary = popups[i]
		p["position"] = Vector2(p["position"]) + Vector2.UP * 34.0 * delta
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) > 0.75:
			popups.remove_at(i)


func _draw() -> void:
	draw_background()
	if state == "menu":
		arena_offset = Vector2.ZERO
		draw_menu()
		draw_click_pulses()
		return

	# Pause/menu/death keep arena visible for continuity.
	arena_offset = Vector2.ZERO
	if shake > 0.0:
		arena_offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake
	draw_set_transform(arena_offset)
	draw_arena()
	draw_hazards()
	draw_trail_and_player()
	draw_effects()
	draw_set_transform(Vector2.ZERO)
	draw_hud()

	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, WORLD), Color(CYAN.r, CYAN.g, CYAN.b, flash * 0.13))
	if state == "dead":
		draw_results()
	elif state == "paused":
		draw_pause()
	elif state == "shop":
		draw_shop()
	# Draw over menus and outside the arena shake transform, at the actual click position.
	draw_click_pulses()


func draw_click_pulses() -> void:
	for pulse in click_pulses:
		var progress := clampf(float(pulse["age"]) / CLICK_PULSE_DURATION, 0.0, 1.0)
		var expansion := 1.0 - pow(1.0 - progress, 3.0)
		var radius := lerpf(5.0, 27.0, expansion)
		var opacity := (1.0 - progress) * (1.0 - progress)
		var position: Vector2 = pulse["position"]
		var tint: Color = pulse["color"]
		var color := Color(tint.r, tint.g, tint.b, opacity)
		draw_arc(position, radius, 0.0, TAU, 40, color, 2.5 - progress, true)
		draw_circle(position, 3.0 * (1.0 - progress), color)
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(position + direction * (radius + 4.0), position + direction * (radius + 9.0), color, 1.5, true)


func draw_stars() -> void:
	# The full star field is cached; animate only its brightest accents.
	for i in range(0, stars.size(), 17):
		var p: Vector2 = stars[i]
		var lum := 0.12 + float(i % 5) * 0.035 + sin(ui_time * 0.7 + i) * 0.035
		draw_line(p - Vector2(4, 0), p + Vector2(4, 0), Color(0.62, 0.82, 1.0, lum * 0.5), 1.0, true)
		draw_line(p - Vector2(0, 4), p + Vector2(0, 4), Color(0.62, 0.82, 1.0, lum * 0.5), 1.0, true)


func draw_static_background(painter: Node2D) -> void:
	painter.draw_rect(Rect2(Vector2.ZERO, WORLD), BACK)
	for i in range(16, 0, -1):
		painter.draw_circle(Vector2(580, 330), i * 29.0, Color(CYAN, 0.007))
		painter.draw_circle(Vector2(800, 190), i * 22.0, Color(MAGENTA, 0.012))
	for x in range(0, 961, 48):
		painter.draw_line(Vector2(x, 0), Vector2(x, 720), Color(PURPLE, 0.035), 1.0)
	for y in range(0, 721, 48):
		painter.draw_line(Vector2(0, y), Vector2(960, y), Color(CYAN, 0.025), 1.0)
	for i in range(stars.size()):
		painter.draw_circle(stars[i], 1.0 if i % 3 > 0 else 1.6, Color(0.62, 0.72, 0.9, 0.12 + float(i % 5) * 0.035))


func draw_background() -> void:
	draw_texture_rect(background_viewport.get_texture(), Rect2(Vector2.ZERO, WORLD), false)
	if state == "menu":
		# A low-contrast neon floor gives the title screen depth.
		for x in range(-960, 1921, 120):
			draw_line(Vector2(480 + (x - 480) * 0.12, 522), Vector2(x, 720), Color(PURPLE, 0.13), 1.0, true)
		for y in [522, 536, 558, 589, 631, 687]:
			draw_line(Vector2(0, y), Vector2(960, y), Color(MAGENTA, 0.09), 1.0)
	draw_stars()


func draw_arena() -> void:
	# Light orbit guides and a visually distinct risk zone.
	for i in range(5, 0, -1):
		draw_circle(CENTER, SHIELD_RADIUS + i * 12.0 * GAMEPLAY_SCALE * PLANET_SCALE, Color(0.17, 0.57, 0.72, 0.012))
	var inner_pulse := 0.36 + sin(planet_clock * 1.3) * 0.07
	var outer_pulse := 0.45 + sin(planet_clock * 1.1 + 1.5) * 0.08
	draw_neon_arc(CENTER, INNER_RADIUS, 0.0, TAU, Color(PURPLE, inner_pulse), 1.0)
	draw_neon_arc(CENTER, OUTER_RADIUS, 0.0, TAU, Color(CYAN, outer_pulse), 1.2)
	draw_orbit_motion(CENTER, INNER_RADIUS, PURPLE, -0.40, 0.6)
	draw_orbit_motion(CENTER, OUTER_RADIUS, CYAN, 0.30, -1.5)
	if guard_owned:
		draw_arc(CENTER, orbit_radius, 0.0, TAU, 128, Color(0.35, 0.84, 0.98, 0.24), 1.0, true)
	draw_planet(CENTER, PLANET_RADIUS)
	draw_planet_shield()
	# The rotating boundary ticks catch a slow sweep of light.
	for n in range(32):
		var a := TAU * float(n) / 32.0 + planet_clock * 0.09
		var v := Vector2(cos(a), sin(a))
		var sweep := pow(maxf(0.0, cos(a - planet_clock * 0.55)), 8.0)
		draw_line(CENTER + v * (262.0 * ARENA_SCALE), CENTER + v * (267.0 * ARENA_SCALE), Color(MAGENTA if n % 4 == 0 else CYAN, 0.26 + sweep * 0.48), 1.0 + sweep * 0.5, true)


func draw_orbit_motion(origin: Vector2, radius: float, tint: Color, speed: float, phase: float = 0.0) -> void:
	# Motion is purely decorative. The orbit itself stays at its actual radius,
	# and the shared animation clock freezes with gameplay.
	var clock := planet_clock
	var angle := fposmod(clock * speed + phase, TAU)
	var direction := 1.0 if speed >= 0.0 else -1.0
	for opposite in range(2):
		var head := angle + opposite * PI
		var brightness := 0.78 + sin(clock * 1.6 + opposite * PI) * 0.12
		# Tapered energy streaks travel in opposite directions on the two rings.
		var path := PackedVector2Array()
		var colors := PackedColorArray()
		var glow_colors := PackedColorArray()
		for i in range(17):
			var fraction := float(i) / 16.0
			var trail_angle := head - direction * 0.85 * (1.0 - fraction)
			var alpha := pow(fraction, 1.6) * brightness
			path.append(origin + Vector2.from_angle(trail_angle) * radius)
			colors.append(Color(tint, alpha))
			glow_colors.append(Color(tint, alpha * 0.1))
		draw_polyline_colors(path, glow_colors, 7.0, true)
		draw_polyline_colors(path, colors, 2.0, true)
		# Tiny chevrons read as direction indicators rather than target bodies.
		var radial := Vector2.from_angle(head)
		var tangent := Vector2(-radial.y, radial.x) * direction
		var tip := origin + radial * radius
		draw_polyline(PackedVector2Array([tip - tangent * 4.0 - radial * 3.0, tip, tip - tangent * 4.0 + radial * 3.0]), Color(tint, 0.8), 1.2, true)
	# A separate broken band counter-rotates just outside the guide.
	for i in range(3):
		var start := -clock * speed * 0.55 + phase + TAU * i / 3.0
		var alpha := 0.16 + (0.5 + 0.5 * sin(clock * 1.2 + i * 2.0)) * 0.14
		draw_arc(origin, radius + 4.0 * GAMEPLAY_SCALE, start, start + 0.26, 12, Color(tint, alpha), 1.0, true)


func draw_planet_shield() -> void:
	draw_hex_shield(CENTER, SHIELD_RADIUS, shield_fraction())


func draw_hex_shield(origin: Vector2, radius: float, fraction: float) -> void:
	var visual_state := [planet_clock, fraction, shield_impact_position, shield_impact_age] if fraction > 0.0 else [0.0, 0.0, Vector2.ZERO, 10.0]
	if visual_state != shield_visual_state:
		shield_visual_state = visual_state
		var tint := Color("#168bff") if fraction > 0.55 else shield_color(fraction)
		shield_material.set_shader_parameter("animation_time", planet_clock)
		shield_material.set_shader_parameter("energy", fraction)
		shield_material.set_shader_parameter("shield_tint", tint)
		shield_material.set_shader_parameter("impact_position", shield_impact_position)
		shield_material.set_shader_parameter("impact_age", shield_impact_age)
		shield_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if fraction <= 0.0:
		return
	var half_size := Vector2.ONE * radius * 1.12
	draw_texture_rect(shield_viewport.get_texture(), Rect2(origin - half_size, half_size * 2.0), false)


func draw_planet(origin: Vector2, radius: float) -> void:
	var half_size := Vector2.ONE * radius * 1.2
	draw_texture_rect(planet_viewport.get_texture(), Rect2(origin - half_size, half_size * 2.0), false)


func draw_asteroid(position: Vector2, radius: float, variant: int, rotation: float, opacity: float = 1.0) -> void:
	var texture := asteroid_textures[variant]
	var bounds := asteroid_bounds[variant]
	var sprite_scale := radius / float(bounds["radius"])
	var center: Vector2 = bounds["center"]
	draw_set_transform(position + arena_offset, rotation)
	draw_texture_rect(texture, Rect2(-center * sprite_scale, texture.get_size() * sprite_scale), false, Color(1.0, 1.0, 1.0, opacity))
	draw_set_transform(arena_offset)


func draw_hazards() -> void:
	for h in hazards:
		var p := hazard_position(h)
		var warming: bool = float(h["age"]) < float(h["warmup"])
		var escaping := not is_hazard_collectible(h)
		var tint := GREEN if h["kind"] == "satellite" else RED
		if h["kind"] == "spiral": tint = PURPLE
		if h["kind"] == "zigzag": tint = GOLD
		var col := Color(tint.r, tint.g, tint.b, 0.35 if escaping else (0.28 if warming else 1.0))
		if h.has("trail"):
			var path: Array = h["trail"]
			for i in range(1, path.size()):
				var opacity := 0.5 * float(i) / float(path.size())
				draw_line(path[i - 1], path[i], Color(tint.r, tint.g, tint.b, opacity), 2.0, true)
			if not path.is_empty():
				draw_line(path.back(), p, Color(tint.r, tint.g, tint.b, 0.5), 2.0, true)
		if h["kind"] == "drifter":
			var unit := (p - CENTER).normalized()
			draw_line(p + unit * (float(h["size"]) + 7.0), p + unit * (float(h["size"]) + 26.0), Color(1.0, 0.31, 0.40, 0.22), 3.0, true)
		elif h["kind"] == "satellite" and not escaping:
			draw_arc(CENTER, float(h["radius"]), 0.0, TAU, 120, Color(tint.r, tint.g, tint.b, 0.13), 1.0, true)
		elif escaping:
			var unit := (p - CENTER).normalized()
			draw_line(p - unit * 17.0, p - unit * 42.0, Color(GREEN.r, GREEN.g, GREEN.b, 0.25), 3.0, true)
		# Keep the visible halo within the existing clickable glow.
		for glow in [7.0, 4.0, 2.0]:
			draw_circle(p, float(h["size"]) + glow, Color(tint, (0.025 if warming or escaping else 0.08)))
		var size := float(h["size"])
		if h["kind"] == "satellite":
			draw_circle(p, size, col)
		else:
			var rotation := float(h["rotation"]) + float(h["spin"]) * float(h["age"])
			draw_asteroid(p, size, int(h["sprite_index"]), rotation, 0.5 if warming else 1.0)
		if h["kind"] == "zigzag":
			var active_age := maxf(0.0, float(h["age"]) - float(h["warmup"]))
			var period := float(h["turn_period"])
			var time_to_turn := fposmod(0.25 - active_age / period, 0.5) * period
			if not warming and time_to_turn < 0.15:
				draw_arc(p, size + 9.0, 0.0, TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 1.0 - time_to_turn / 0.15), 2.0, true)
		if h["kind"] == "satellite":
			draw_line(p + Vector2(-5.0, 0.0), p + Vector2(5.0, 0.0), PALE, 2.0, true)
			draw_line(p + Vector2(0.0, -5.0), p + Vector2(0.0, 5.0), PALE, 2.0, true)
			if not escaping:
				var orbit_duration := float(h["orbit_duration"])
				var remaining := orbit_duration - float(h["age"])
				var timer_tint := GOLD if remaining <= 1.0 else GREEN
				draw_arc(p, float(h["size"]) + 4.0, -PI / 2.0, -PI / 2.0 + TAU * remaining / orbit_duration, 40, timer_tint, 2.0, true)


func draw_trail_and_player() -> void:
	if not guard_owned:
		return
	for i in range(trail.size()):
		var fraction := float(i + 1) / float(trail.size())
		draw_circle(trail[i], 2.0 + 4.0 * fraction, Color(0.32, 0.86, 1.0, 0.20 * fraction))
	if state != "dead":
		var size := guard_size()
		draw_circle(player_pos, size + 14.0, Color(CYAN, 0.06))
		draw_circle(player_pos, size + 8.0, Color(CYAN, 0.12))
		draw_circle(player_pos, size + 3.0, Color(CYAN, 0.22))
		draw_circle(player_pos, size, CYAN)
		draw_circle(player_pos + Vector2(-2.5, -2.5), 3.0, Color("#ffffff"))


func draw_effects() -> void:
	for p in particles:
		var opacity: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var tint: Color = p["color"]
		draw_circle(p["position"], 2.5 * opacity + 0.8, Color(tint.r, tint.g, tint.b, opacity))
	for popup in popups:
		var opacity := clampf(1.0 - float(popup["age"]) / 0.75, 0.0, 1.0)
		var tint: Color = popup["color"]
		var color := Color(tint.r, tint.g, tint.b, opacity)
		draw_text_center_at(str(popup["label"]), Vector2(popup["position"]).x, Vector2(popup["position"]).y, 17, color)


func draw_hud() -> void:
	ui_panel(Rect2(28, 28, 800, 78), PANEL, EDGE, 12)
	draw_line(Vector2(42, 29), Vector2(416, 29), Color(CYAN, 0.8), 1.5, true)
	draw_line(Vector2(440, 29), Vector2(814, 29), Color(MAGENTA, 0.8), 1.5, true)
	ui_label("SCORE", Vector2(48, 51))
	draw_text(str(int(points)).pad_zeros(6), Vector2(46, 87), 30, PALE)
	draw_line(Vector2(205, 46), Vector2(205, 88), EDGE, 1.0)
	ui_label("CREDITS", Vector2(226, 51))
	draw_text("$" + str(money), Vector2(224, 85), 26, GOLD)
	var energy_fraction := shield_fraction()
	var energy_color := shield_color(energy_fraction)
	ui_label("PLANET SHIELD", Vector2(366, 51))
	draw_text(str(roundi(shield_energy)) + "%", Vector2(551, 51), 14, energy_color)
	for i in range(20):
		var lit := energy_fraction * 20.0 > i
		ui_panel(Rect2(366 + i * 12, 65, 8, 17), energy_color if lit else EDGE, Color.TRANSPARENT, 2)
	if energy_fraction <= 0.25:
		draw_text_center("SHIELD CRITICAL  /  Collect green energy or repair in the shop", 192, 13, RED)
	ui_button(SHOP_BUTTON, "Upgrades", CYAN, "B")
	ui_button(PAUSE_BUTTON, "II", MUTED, "P")
	var combo_color := GOLD if combo >= 3 else CYAN
	ui_label("COMBO", Vector2(666, 51))
	draw_text("x" + str(combo), Vector2(663, 84), 28, combo_color if combo > 1 else MUTED)
	ui_meter(Rect2(725, 68, 80, 5), clampf(combo_clock / COMBO_DURATION, 0.0, 1.0), combo_color)
	draw_line(Vector2(28, 650), Vector2(932, 650), EDGE, 1.0)
	var wave := mini(5, int(floor(elapsed / 15.0)) + 1)
	draw_circle(Vector2(36, 679), 3.5, CYAN)
	ui_label("WAVE  %02d" % wave, Vector2(49, 683), CYAN)
	draw_text("%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], Vector2(177, 684), 16, PALE)
	for i in range(5):
		ui_panel(Rect2(28 + i * 21, 698, 16, 3), CYAN if i < wave else EDGE, Color.TRANSPARENT, 1)
	var hint := "AIM + CLICK  /  Destroy hazards"
	if guard_owned and guard_controls_owned:
		hint = "SPACE  /  Inner orbit     D  /  Reverse"
	draw_text_center(hint, 684, 13, MUTED)
	draw_icon("guard", Vector2(778, 679), CYAN if guard_owned else MUTED)
	draw_text("GUARD " + ("ONLINE" if guard_owned else "OFFLINE"), Vector2(798, 683), 11, CYAN if guard_owned else MUTED)
	if time_to_wave_message > 0.0 and state == "playing":
		var announce_color := Color(CYAN.r, CYAN.g, CYAN.b, minf(1.0, time_to_wave_message))
		draw_text_center("W A V E  " + str(wave), 145, 20, announce_color)


func draw_shop() -> void:
	draw_scrim()
	ui_panel(Rect2(150, 76, 660, 566), PANEL, Color(MAGENTA, 0.65), 18)
	draw_line(Vector2(174, 77), Vector2(786, 77), MAGENTA, 2.0, true)
	ui_label("ORBITAL SUPPLY", Vector2(174, 112), MAGENTA)
	draw_text("Build your defense.", Vector2(172, 151), 30, PALE)
	draw_text("Invest in this run. The arena is paused.", Vector2(174, 177), 14, MUTED)
	ui_panel(Rect2(620, 141, 166, 38), Color("#29211c"), Color(GOLD, 0.5), 8)
	draw_text_center_at("$%d  available" % money, 703, 166, 17, GOLD)
	ui_button(SHOP_CLOSE_BUTTON, "X", MUTED)
	var names := ["Orbital guard", "Thruster boost", "Extended reach", "Manual controls", "Shield armor", "Emergency repair"]
	var descriptions := ["A backup guard that intercepts hazards for you", "+25% guard speed per level", "+4 px guard reach per level", "Space: inner orbit   /   D: reverse direction", "Block hits for 5 less energy per level", "Restore 40 shield energy instantly"]
	for i in range(SHOP_ITEMS.size()):
		var item: Dictionary = SHOP_ITEMS[i]
		var id := str(item["id"])
		var reason := upgrade_lock_reason(id)
		var cost := upgrade_cost(id)
		var affordable := reason.is_empty() and money >= cost
		var row := shop_row_rect(i)
		var hovered := row.has_point(get_local_mouse_position())
		var tint := GREEN if id == "repair" or id == "armor" else CYAN
		ui_panel(row, Color("#241c40") if hovered else Color("#17132e"), tint if hovered and affordable else EDGE, 9)
		ui_panel(Rect2(row.position + Vector2(9, 9), Vector2(36, 36)), Color("#0a091a"), Color.TRANSPARENT, 8)
		draw_icon(id, row.position + Vector2(27, 27), tint if reason.is_empty() or reason == "OWNED" else MUTED)
		draw_text(names[i], row.position + Vector2(57, 23), 16, PALE)
		draw_text(descriptions[i], row.position + Vector2(57, 42), 12, MUTED)
		var level := -1
		if id == "speed": level = guard_speed_level
		if id == "range": level = guard_range_level
		if id == "armor": level = shield_armor_level
		if level >= 0:
			for n in range(3):
				ui_panel(Rect2(row.position + Vector2(267 + n * 12, 13), Vector2(8, 5)), tint if n < level else EDGE, Color.TRANSPARENT, 2)
		var button_label := "$" + str(cost) if reason.is_empty() else reason
		var price_rect := Rect2(row.end.x - 128, row.position.y + 10, 114, 34)
		ui_panel(price_rect, Color("#0c272b") if affordable else Color("#0c0a20"), Color(tint, 0.65) if affordable else EDGE, 7)
		draw_text_center_at(button_label, price_rect.get_center().x, price_rect.position.y + 22, 13, tint if affordable or reason == "OWNED" else MUTED)
		draw_text(str(i + 1), row.position + Vector2(456, 32), 11, MUTED)
	draw_line(Vector2(174, 589), Vector2(786, 589), EDGE, 1.0)
	var message := "1 - 6  /  Quick buy" if shop_message.is_empty() else shop_message
	draw_text(message, Vector2(174, 619), 13, GOLD if not shop_message.is_empty() else MUTED)
	draw_text("B / ESC  Resume orbit", Vector2(619, 619), 12, MUTED)


func orbit_direction_label() -> String:
	return "CW" if orbit_direction > 0.0 else "CCW"


func shield_fraction() -> float:
	return clampf(shield_energy / SHIELD_MAX_ENERGY, 0.0, 1.0)


func shield_color(fraction: float) -> Color:
	if fraction <= 0.25:
		return RED
	if fraction <= 0.55:
		return GOLD
	return GREEN


func draw_menu() -> void:
	draw_icon("guard", Vector2(45, 48), CYAN)
	draw_line(Vector2(28, 80), Vector2(932, 80), EDGE, 1.0)
	draw_text("GREEDY", Vector2(60, 229), 70, PALE)
	draw_text("ORBIT", Vector2(60, 302), 70, MAGENTA)
	draw_text("Defend your planet.", Vector2(64, 353), 18, MUTED)
	ui_button(START_BUTTON, "Launch orbit", CYAN, "ENTER", true)
	draw_text("Click to destroy  /  B to upgrade", Vector2(64, 498), 12, MUTED)
	draw_menu_orbit(Vector2(696, 325))
	draw_line(Vector2(64, 606), Vector2(896, 606), EDGE, 1.0)
	ui_label("BEST", Vector2(64, 640), GOLD)
	draw_text(str(best_score).pad_zeros(6), Vector2(64, 677), 27, PALE)


func draw_menu_orbit(origin: Vector2) -> void:
	for i in range(12, 0, -1):
		draw_circle(origin, 40.0 + i * 14.0, Color(PURPLE, 0.014))
	var menu_radii := [83.0, 123.0, 165.0]
	var menu_colors := [PURPLE, CYAN, MAGENTA]
	var menu_speeds := [-0.28, 0.30, -0.19]
	for i in range(menu_radii.size()):
		draw_neon_arc(origin, menu_radii[i], 0.0, TAU, Color(menu_colors[i], 0.4), 1.0)
		draw_orbit_motion(origin, menu_radii[i], menu_colors[i], menu_speeds[i], i * 1.7)
	for n in range(60):
		var unit := Vector2.from_angle(TAU * n / 60.0 + planet_clock * 0.07)
		draw_line(origin + unit * 178, origin + unit * (186 if n % 5 == 0 else 181), Color(MAGENTA if n % 5 == 0 else CYAN, 0.65), 1.0, true)
	draw_planet(origin, PLANET_BASE_RADIUS)
	draw_hex_shield(origin, SHIELD_BASE_RADIUS, 1.0)
	var guard_angle := ui_time * 0.25 - 1.0
	for i in range(18):
		var trail_pos := origin + Vector2.from_angle(guard_angle - i * 0.022) * 123
		draw_circle(trail_pos, 4.0 - i * 0.13, Color(CYAN, 0.35 * (1.0 - i / 18.0)))
	var guard := origin + Vector2.from_angle(guard_angle) * 123
	draw_circle(guard, 14, Color(CYAN, 0.09))
	draw_circle(guard, 7, CYAN)
	draw_circle(guard + Vector2(-2, -2), 2, PALE)
	var enemy := origin + Vector2.from_angle(ui_time * 0.09 - 2.35) * 165.0
	draw_circle(enemy, 18, Color(RED, 0.1))
	draw_asteroid(enemy, 12.0, 1, planet_clock * 0.4)
	draw_line(enemy + Vector2(-11, -11), enemy + Vector2(-33, -33), Color(RED, 0.3), 2.5, true)
	var energy := origin + Vector2.from_angle(-ui_time * 0.16 + 0.89) * 123.0
	draw_circle(energy, 17, Color(GREEN, 0.1))
	draw_circle(energy, 9, GREEN)
	draw_icon("repair", energy, BACK)


func draw_pause() -> void:
	draw_scrim()
	ui_panel(Rect2(230, 178, 500, 396), PANEL, Color(CYAN, 0.65), 18)
	ui_label_center("TAKE A BREATHER", 223, CYAN)
	draw_text_center("ORBIT ON HOLD", 281, 38, PALE)
	draw_text_center("Your planet can wait a moment.", 317, 16, MUTED)
	draw_line(Vector2(270, 345), Vector2(690, 345), EDGE, 1.0)
	draw_text_center("SCORE  %s     /     CREDITS  $%d" % [str(int(points)).pad_zeros(6), money], 382, 17, PALE)
	draw_text_center("Hazards, energy timers, and combos are paused.", 410, 13, MUTED)
	ui_button(RESUME_BUTTON, "Resume orbit", CYAN, "P / ESC", true)
	ui_button(PAUSE_TITLE_BUTTON, "Return to title", MUTED)


func draw_results() -> void:
	draw_scrim()
	ui_panel(Rect2(220, 105, 520, 562), PANEL, Color(RED, 0.65), 18)
	draw_line(Vector2(244, 106), Vector2(716, 106), RED, 2.0, true)
	ui_label_center("TRANSMISSION ENDED", 150, RED)
	draw_text_center("PLANET LOST" if death_reason == "planet" else "ORBIT BROKEN", 204, 40, PALE)
	ui_label_center("FINAL SCORE", 248)
	draw_text_center(str(int(points)).pad_zeros(6), 306, 52, PALE)
	draw_text_center("PERSONAL BEST  /  " + str(best_score).pad_zeros(6), 337, 13, GOLD)
	var labels := ["TIME ALIVE", "DESTROYED", "CREDITS"]
	var values := ["%.1fs" % elapsed, str(hazards_destroyed), "$" + str(money)]
	for i in range(3):
		var rect := Rect2(244 + i * 160, 362, 152, 78)
		ui_panel(rect, Color("#19132f"), EDGE, 9)
		draw_text_center_at(labels[i], rect.get_center().x, 385, 10, MUTED)
		draw_text_center_at(values[i], rect.get_center().x, 422, 26, GOLD if i == 2 else PALE)
	draw_text_center("%d energy satellites collected" % satellites_destroyed, 471, 14, GREEN)
	var retry := Rect2(280, 504, 400, 54)
	if game_over_clock > 0.0:
		ui_panel(retry, Color("#19132f"), EDGE, 9)
		draw_text_center("Gathering flight data...", 537, 16, MUTED)
		ui_meter(Rect2(300, 548, 360, 3), 1.0 - game_over_clock / GAME_OVER_RETRY_DELAY, CYAN)
		ui_panel(RESULTS_TITLE_BUTTON, Color("#19132f"), EDGE, 9)
		draw_text_center("Return to title", RESULTS_TITLE_BUTTON.get_center().y + 6, 14, Color(MUTED, 0.45))
	else:
		ui_button(retry, "Launch again", CYAN, "ENTER", true)
		ui_button(RESULTS_TITLE_BUTTON, "Return to title", MUTED)
		draw_text_center("Click / Space / Enter to launch again", 640, 12, MUTED)


func draw_scrim() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.015, 0.005, 0.04, 0.86))


func draw_neon_arc(origin: Vector2, radius: float, start: float, end: float, tint: Color, width: float) -> void:
	# Layered strokes provide glow in the Compatibility renderer and web export.
	draw_arc(origin, radius, start, end, 128, Color(tint, tint.a * 0.06), width + 12.0, true)
	draw_arc(origin, radius, start, end, 128, Color(tint, tint.a * 0.16), width + 5.0, true)
	draw_arc(origin, radius, start, end, 128, tint, width, true)


func ui_panel(rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> void:
	var key := str([fill, border, radius])
	if not ui_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = border
		style.set_border_width_all(1 if border.a > 0.0 else 0)
		style.set_corner_radius_all(radius)
		style.corner_detail = 8
		if border.a > 0.0:
			style.shadow_color = Color(border, border.a * 0.22)
			style.shadow_size = 8
			style.shadow_offset = Vector2.ZERO
		ui_styles[key] = style
	draw_style_box(ui_styles[key], rect)


func ui_button(rect: Rect2, label: String, tint: Color, shortcut: String = "", primary: bool = false) -> void:
	var hovered := rect.has_point(get_local_mouse_position())
	var fill := tint.darkened(0.88) if primary else Color("#17132e")
	if hovered:
		fill = fill.lightened(0.12)
	ui_panel(rect, fill, tint if hovered or primary else Color(tint, 0.5), 9)
	var text_color := tint if primary else PALE
	var center_x := rect.get_center().x - (22.0 if not shortcut.is_empty() else 0.0)
	draw_text_center_at(label, center_x, rect.get_center().y + 6, 18 if primary else 14, text_color)
	if not shortcut.is_empty():
		var key_width := 58.0 if shortcut.length() > 3 else 24.0
		var key_rect := Rect2(rect.end.x - key_width - 10, rect.get_center().y - 12, key_width, 24)
		ui_panel(key_rect, Color(tint, 0.13) if primary else Color("#090819"), Color.TRANSPARENT, 4)
		draw_text_center_at(shortcut, key_rect.get_center().x, key_rect.get_center().y + 4, 10, text_color)


func ui_meter(rect: Rect2, fraction: float, tint: Color) -> void:
	ui_panel(rect, EDGE, Color.TRANSPARENT, 2)
	if fraction > 0.0:
		ui_panel(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), tint, Color.TRANSPARENT, 2)


func ui_label(message: String, baseline: Vector2, tint: Color = MUTED) -> void:
	draw_text(message, baseline, 11, tint)


func ui_label_center(message: String, baseline_y: float, tint: Color = MUTED) -> void:
	draw_text_center(message, baseline_y, 11, tint)


func draw_icon(id: String, origin: Vector2, tint: Color) -> void:
	match id:
		"guard":
			draw_arc(origin, 10, -0.5, TAU - 1.1, 32, tint, 1.4, true)
			draw_circle(origin, 3.0, tint)
			draw_circle(origin + Vector2(8, -6), 3.0, tint)
		"speed":
			for x in [-5, 3]:
				draw_polyline(PackedVector2Array([origin + Vector2(x - 3, -7), origin + Vector2(x + 4, 0), origin + Vector2(x - 3, 7)]), tint, 1.8, true)
		"range", "target":
			draw_arc(origin, 7, 0.0, TAU, 32, tint, 1.3, true)
			for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(origin + direction * 5, origin + direction * 11, tint, 1.5, true)
		"controls":
			ui_panel(Rect2(origin - Vector2(11, 7), Vector2(22, 14)), Color.TRANSPARENT, tint, 3)
			draw_line(origin - Vector2(7, 0), origin + Vector2(-1, 0), tint, 1.5, true)
			draw_line(origin - Vector2(4, 3), origin + Vector2(-4, 3), tint, 1.5, true)
			draw_circle(origin + Vector2(5, -2), 1.5, tint)
			draw_circle(origin + Vector2(8, 2), 1.5, tint)
		"armor":
			draw_polyline(PackedVector2Array([origin + Vector2(0, -10), origin + Vector2(8, -6), origin + Vector2(7, 3), origin + Vector2(0, 10), origin + Vector2(-7, 3), origin + Vector2(-8, -6), origin + Vector2(0, -10)]), tint, 1.5, true)
			draw_line(origin + Vector2(0, -5), origin + Vector2(0, 4), tint, 1.5, true)
		"repair":
			draw_line(origin - Vector2(6, 0), origin + Vector2(6, 0), tint, 2.0, true)
			draw_line(origin - Vector2(0, 6), origin + Vector2(0, 6), tint, 2.0, true)


func draw_text(message: String, baseline: Vector2, size: int, tint: Color) -> void:
	if size >= 24:
		var glow := CYAN if tint == PALE else tint
		draw_string_outline(ThemeDB.fallback_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 6, Color(glow, tint.a * 0.07))
		draw_string_outline(ThemeDB.fallback_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, 2, Color(glow, tint.a * 0.16))
	draw_string(ThemeDB.fallback_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)


func draw_text_center(message: String, baseline_y: float, size: int, tint: Color) -> void:
	draw_text_center_at(message, 480.0, baseline_y, size, tint)


func draw_text_center_at(message: String, x: float, baseline_y: float, size: int, tint: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_text(message, Vector2(x - w / 2.0, baseline_y), size, tint)
