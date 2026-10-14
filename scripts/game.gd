extends Node2D
## Greedy Orbit: click hazards, earn money, and buy an orbiting backup guard.
## The game is drawn in _draw() and updated on fixed physics ticks.

const CENTER := Vector2(480.0, 364.0)
const WORLD := Vector2(960.0, 720.0)
const INNER_RADIUS := 126.0
const OUTER_RADIUS := 234.0
const PLAYER_SIZE := 9.0
const CLICK_PADDING := 7.0               # include the visible hazard glow in click targets
const CLICK_PULSE_DURATION := 0.32
const MAX_CLICK_PULSES := 24
const ORBIT_SPEED := 2.65                 # radians per second (clockwise)
const RADIUS_CHANGE_SPEED := 235.0        # px per second
const COMBO_DURATION := 4.5              # seconds before combo starts decaying
const GAME_OVER_RETRY_DELAY := 2.0       # keep results visible before accepting restart inputs
const PLANET_RADIUS := 31.0
const SHIELD_RADIUS := 56.0
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
const SHOP_BUTTON := Rect2(28, 114, 118, 32)
const SHOP_CLOSE_BUTTON := Rect2(730, 153, 40, 32)
const SHOP_ITEMS := [
	{"id": "guard", "name": "Guard", "description": "Auto intercept"},
	{"id": "speed", "name": "Speed", "description": "+25% speed"},
	{"id": "range", "name": "Size", "description": "+4 px reach"},
	{"id": "controls", "name": "Controls", "description": "Space: in / D: reverse"},
	{"id": "armor", "name": "Armor", "description": "-5 energy per hit"},
	{"id": "repair", "name": "Repair", "description": "+40 energy"},
]
const SAVE_FILE := "user://greedy_orbit_best.txt"

const BACK := Color("#0b1221")
const PALE := Color("#d9e8f7")
const MUTED := Color("#8192ae")
const CYAN := Color("#61e4ff")
const RED := Color("#ff5f75")
const GOLD := Color("#ffc857")
const GREEN := Color("#64e9a7")
const PURPLE := Color("#ba8cff")

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


func _ready() -> void:
	rng.randomize()
	best_score = load_best_score()
	for i in range(90):
		stars.append(Vector2(rng.randf_range(16.0, 944.0), rng.randf_range(12.0, 705.0)))
	queue_redraw()


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
		if state == "menu" or state == "dead":
			start_game()
		elif state == "playing":
			var local_event: InputEventMouseButton = make_input_local(event)
			if SHOP_BUTTON.has_point(local_event.position):
				toggle_shop()
			else:
				if destroy_hazard_at(local_event.position - arena_offset):
					click_pulse["color"] = GREEN
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
	return Rect2(190, 238 + index * 54, 580, 46)


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
	state = "playing"
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
	$StartSound.play()
	queue_redraw()


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
		var expired: bool = (h["kind"] != "satellite" and float(h["radius"]) < 38.0)
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
	draw_rect(Rect2(Vector2.ZERO, WORLD), BACK)
	draw_stars()

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
	if state == "playing":
		draw_hud()

	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, WORLD), Color(CYAN.r, CYAN.g, CYAN.b, flash * 0.13))
	if state == "menu":
		draw_overlay("GREEDY ORBIT", "Click. Earn. Upgrade.", "B: Shop   |   Green: energy", "", "Click / Space to start")
	elif state == "dead":
		var death_title := "PLANET LOST" if death_reason == "planet" else "ORBIT BROKEN"
		var retry_prompt := "Click / Space to retry" if game_over_clock <= 0.0 else ""
		draw_overlay(death_title, "SCORE  " + str(int(points)) + "     BEST  " + str(best_score), "TIME %.1fs   |   DESTROYED %d" % [elapsed, hazards_destroyed], "ENERGY %d   |   CASH $%d" % [satellites_destroyed, money], retry_prompt)
		if game_over_clock > 0.0:
			draw_rect(Rect2(390, 447, 180, 4), Color("#23435c"))
			var progress := 1.0 - game_over_clock / GAME_OVER_RETRY_DELAY
			draw_rect(Rect2(390, 447, 180.0 * progress, 4), CYAN)
	elif state == "paused":
		draw_overlay("PAUSED", "", "", "", "P / Esc to resume")
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
	for i in range(stars.size()):
		var p: Vector2 = stars[i]
		var lum := 0.14 + float(i % 5) * 0.035
		draw_circle(p, 1.0 if i % 3 > 0 else 1.6, Color(0.62, 0.72, 0.9, lum))


func draw_arena() -> void:
	# Light orbit guides and a visually distinct risk zone.
	draw_arc(CENTER, INNER_RADIUS, 0.0, TAU, 112, Color(0.19, 0.62, 0.78, 0.24), 1.2, true)
	draw_arc(CENTER, OUTER_RADIUS, 0.0, TAU, 128, Color(0.20, 0.50, 0.69, 0.35), 1.4, true)
	if guard_owned:
		draw_arc(CENTER, orbit_radius, 0.0, TAU, 128, Color(0.35, 0.84, 0.98, 0.24), 1.0, true)
	draw_circle(CENTER, 38.0, Color(0.17, 0.32, 0.49, 0.09))
	draw_circle(CENTER, PLANET_RADIUS, Color("#23435c"))
	draw_circle(CENTER, 24.0, Color("#315e79"))
	draw_circle(CENTER + Vector2(-7, -8), 9.0, Color(0.57, 0.83, 0.92, 0.28))
	draw_arc(CENTER, 33.0, 0.0, TAU, 64, Color(0.55, 0.85, 1.0, 0.72), 1.8, true)
	draw_planet_shield()
	# Dashes around the outer boundary make angular motion easier to read.
	for n in range(32):
		var a := TAU * float(n) / 32.0
		var v := Vector2(cos(a), sin(a))
		draw_line(CENTER + v * 262.0, CENTER + v * 267.0, Color(0.37, 0.62, 0.76, 0.21), 1.0, true)


func draw_planet_shield() -> void:
	var fraction := shield_fraction()
	if fraction <= 0.0:
		return
	var tint := shield_color(fraction)
	draw_circle(CENTER, SHIELD_RADIUS, Color(tint.r, tint.g, tint.b, 0.025 + fraction * 0.045))
	draw_arc(CENTER, SHIELD_RADIUS, 0.0, TAU, 96, Color(tint.r, tint.g, tint.b, 0.30 + fraction * 0.55), 2.0 + fraction * 2.0, true)
	draw_arc(CENTER, SHIELD_RADIUS + 6.0, -PI / 2.0, -PI / 2.0 + TAU * fraction, 96, tint, 2.0, true)


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
			draw_line(p + unit * 17.0, p + unit * 36.0, Color(1.0, 0.31, 0.40, 0.22), 3.0, true)
		elif h["kind"] == "satellite" and not escaping:
			draw_arc(CENTER, float(h["radius"]), 0.0, TAU, 120, Color(tint.r, tint.g, tint.b, 0.13), 1.0, true)
		elif escaping:
			var unit := (p - CENTER).normalized()
			draw_line(p - unit * 17.0, p - unit * 42.0, Color(GREEN.r, GREEN.g, GREEN.b, 0.25), 3.0, true)
		draw_circle(p, float(h["size"]) + 7.0, Color(tint.r, tint.g, tint.b, 0.08 if warming else 0.15))
		var size := float(h["size"])
		if h["kind"] == "zigzag":
			draw_colored_polygon(PackedVector2Array([p + Vector2.UP * size, p + Vector2.RIGHT * size, p + Vector2.DOWN * size, p + Vector2.LEFT * size]), col)
			draw_polyline(PackedVector2Array([p + Vector2(-4, -5), p + Vector2(3, -1), p + Vector2(-3, 1), p + Vector2(4, 5)]), PALE, 1.5, true)
			var active_age := maxf(0.0, float(h["age"]) - float(h["warmup"]))
			var period := float(h["turn_period"])
			var time_to_turn := fposmod(0.25 - active_age / period, 0.5) * period
			if not warming and time_to_turn < 0.15:
				draw_arc(p, size + 9.0, 0.0, TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 1.0 - time_to_turn / 0.15), 2.0, true)
		else:
			draw_circle(p, size, col)
		if h["kind"] == "spiral":
			draw_arc(p, size * 0.5, float(h["angle"]), float(h["angle"]) + PI * 1.5, 20, PALE, 1.5, true)
		if h["kind"] == "satellite":
			draw_line(p + Vector2(-5.0, 0.0), p + Vector2(5.0, 0.0), PALE, 2.0, true)
			draw_line(p + Vector2(0.0, -5.0), p + Vector2(0.0, 5.0), PALE, 2.0, true)
			if not escaping:
				var orbit_duration := float(h["orbit_duration"])
				var remaining := orbit_duration - float(h["age"])
				var timer_tint := GOLD if remaining <= 1.0 else GREEN
				draw_arc(p, float(h["size"]) + 4.0, -PI / 2.0, -PI / 2.0 + TAU * remaining / orbit_duration, 40, timer_tint, 2.0, true)
		elif h["kind"] == "drifter":
			draw_circle(p + Vector2(-3.0, -3.0), 2.8, Color(1.0, 0.86, 0.86, 0.32 if warming else 0.9))


func draw_trail_and_player() -> void:
	if not guard_owned:
		return
	for i in range(trail.size()):
		var fraction := float(i + 1) / float(trail.size())
		draw_circle(trail[i], 2.0 + 4.0 * fraction, Color(0.32, 0.86, 1.0, 0.20 * fraction))
	if state != "dead":
		var size := guard_size()
		draw_circle(player_pos, size + 10.0, Color(0.26, 0.78, 1.0, 0.15))
		draw_circle(player_pos, size + 3.0, Color(0.26, 0.78, 1.0, 0.19))
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
	draw_text("SCORE", Vector2(28, 34), 12, MUTED)
	draw_text(str(int(points)).pad_zeros(6), Vector2(28, 67), 30, PALE)
	draw_text("$" + str(money), Vector2(28, 98), 22, GOLD)
	draw_rect(SHOP_BUTTON, Color("#23435c"))
	draw_text("Shop [B]", SHOP_BUTTON.position + Vector2(20, 23), 16, CYAN)
	var energy_fraction := shield_fraction()
	var energy_color := shield_color(energy_fraction)
	draw_text_center("SHIELD  " + str(roundi(shield_energy)) + "%", 35, 16, energy_color)
	draw_rect(Rect2(Vector2(348, 45), Vector2(264, 12)), Color(0.12, 0.20, 0.29, 0.95))
	draw_rect(Rect2(Vector2(351, 48), Vector2(258.0 * energy_fraction, 6)), energy_color)
	var combo_color := GOLD if combo >= 3 else CYAN
	draw_text("P: Pause", Vector2(834, 688), 12, MUTED)
	if guard_owned and guard_controls_owned:
		draw_text_center("Space: in   |   D: reverse", 688, 12, MUTED)
	if combo > 1:
		draw_text("x" + str(combo), Vector2(824, 62), 32, combo_color)
		draw_rect(Rect2(Vector2(780, 90), Vector2(133, 5)), Color(0.19, 0.31, 0.44))
		draw_rect(Rect2(Vector2(780, 90), Vector2(133.0 * clampf(combo_clock / COMBO_DURATION, 0.0, 1.0), 5)), combo_color)
	if time_to_wave_message > 0.0 and state == "playing":
		var announce_color := Color(CYAN.r, CYAN.g, CYAN.b, minf(1.0, time_to_wave_message))
		draw_text_center("WAVE " + str(mini(5, int(floor(elapsed / 15.0)) + 1)), 164, 26, announce_color)


func draw_shop() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.03, 0.06, 0.11, 0.85))
	draw_rect(Rect2(168, 136, 624, 488), Color("#122138"))
	draw_rect(Rect2(168, 136, 624, 4), GOLD)
	draw_text_center("SHOP", 186, 30, PALE)
	draw_text_center("$" + str(money), 220, 20, GOLD)
	draw_rect(SHOP_CLOSE_BUTTON, Color("#23435c"))
	draw_text("X", SHOP_CLOSE_BUTTON.position + Vector2(13, 23), 20, PALE)
	for i in range(SHOP_ITEMS.size()):
		var item: Dictionary = SHOP_ITEMS[i]
		var id := str(item["id"])
		var reason := upgrade_lock_reason(id)
		var cost := upgrade_cost(id)
		var affordable := reason.is_empty() and money >= cost
		var row := shop_row_rect(i)
		draw_rect(row, Color("#23435c") if affordable else Color("#192c43"))
		var title := str(i + 1) + ". " + str(item["name"])
		if id == "speed": title += "  " + str(guard_speed_level) + "/3"
		if id == "range": title += "  " + str(guard_range_level) + "/3"
		if id == "armor": title += "  " + str(shield_armor_level) + "/3"
		draw_text(title, row.position + Vector2(12, 19), 16, PALE)
		draw_text(str(item["description"]), row.position + Vector2(12, 38), 12, MUTED)
		var button_label := reason
		if reason.is_empty():
			button_label = "$" + str(cost)
		draw_text_center_at(button_label, row.end.x - 88, row.position.y + 26, 13, GREEN if affordable else MUTED)
	draw_text_center(shop_message, 584, 15, GOLD)
	draw_text_center("This run only   |   B / Esc: close", 607, 13, MUTED)


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


func draw_overlay(title: String, sub: String, line1: String, line2: String, prompt: String) -> void:
	draw_rect(Rect2(Vector2(0, 0), WORLD), Color(0.03, 0.06, 0.11, 0.70))
	draw_rect(Rect2(Vector2(178, 205), Vector2(604, 302)), Color(0.07, 0.13, 0.22, 0.98))
	draw_rect(Rect2(Vector2(178, 205), Vector2(604, 4)), CYAN)
	draw_text_center(title, 275, 39, PALE)
	if sub != "":
		draw_text_center(sub, 319, 20, GOLD)
	if line1 != "":
		draw_text_center(line1, 368, 18, MUTED)
	if line2 != "":
		draw_text_center(line2, 399, 18, MUTED)
	draw_text_center(prompt, 465, 18, GREEN)


func draw_text(message: String, baseline: Vector2, size: int, tint: Color) -> void:
	draw_string(ThemeDB.fallback_font, baseline, message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)


func draw_text_center(message: String, baseline_y: float, size: int, tint: Color) -> void:
	draw_text_center_at(message, 480.0, baseline_y, size, tint)


func draw_text_center_at(message: String, x: float, baseline_y: float, size: int, tint: Color) -> void:
	var w := ThemeDB.fallback_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(ThemeDB.fallback_font, Vector2(x - w / 2.0, baseline_y), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)
