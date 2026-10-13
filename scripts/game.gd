extends Node2D
## Greedy Orbit: no sprites, no plugins, one arena, one-button gameplay.
## The game is drawn in _draw() and updated on fixed physics ticks.

const CENTER := Vector2(480.0, 364.0)
const WORLD := Vector2(960.0, 720.0)
const INNER_RADIUS := 126.0
const OUTER_RADIUS := 234.0
const PLAYER_SIZE := 9.0
const ORBIT_SPEED := 2.65                 # radians per second (clockwise)
const RADIUS_CHANGE_SPEED := 235.0        # px per second
const NEAR_RANGE := 49.0                 # outer limit for an eligible near miss
const COMBO_DURATION := 4.5              # seconds before combo starts decaying
const PLANET_RADIUS := 31.0
const SHIELD_RADIUS := 56.0
const SHIELD_MAX_ENERGY := 100.0
const SHIELD_DECAY_RATE := 3.2            # energy lost per second
const SHIELD_REFILL_NEAR := 28.0
const SHIELD_REFILL_PERFECT := 45.0
const SAVE_FILE := "user://greedy_orbit_best.txt"

const BACK := Color("#0b1221")
const PALE := Color("#d9e8f7")
const MUTED := Color("#8192ae")
const CYAN := Color("#61e4ff")
const RED := Color("#ff5f75")
const GOLD := Color("#ffc857")
const GREEN := Color("#64e9a7")

var rng := RandomNumberGenerator.new()
var state := "menu"                       # menu, playing, paused, dead
var elapsed := 0.0
var angle := -PI / 2.0
var orbit_direction := 1.0                # 1.0 = clockwise, -1.0 = counterclockwise
var orbit_radius := OUTER_RADIUS
var player_pos := CENTER + Vector2.UP * OUTER_RADIUS
var spawn_clock := 0.0
var points := 0.0
var best_score := 0
var shield_energy := SHIELD_MAX_ENERGY
var combo := 1
var combo_clock := 0.0
var total_near_misses := 0
var perfect_misses := 0
var next_wave := 2
var time_to_wave_message := 0.0
var flash := 0.0
var shake := 0.0
var death_reason := "player"
var hazards: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var trail: Array[Vector2] = []
var stars: Array[Vector2] = []


func _ready() -> void:
	rng.randomize()
	best_score = load_best_score()
	for i in range(90):
		stars.append(Vector2(rng.randf_range(16.0, 944.0), rng.randf_range(12.0, 705.0)))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D:
			reverse_orbit_direction()
		elif event.keycode == KEY_R:
			start_game()
		elif event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if state == "playing":
				state = "paused"
			elif state == "paused":
				state = "playing"
			queue_redraw()
		elif (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER) and (state == "menu" or state == "dead"):
			start_game()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "menu" or state == "dead":
			start_game()


func reverse_orbit_direction() -> void:
	orbit_direction *= -1.0
	queue_redraw()


func _process(delta: float) -> void:
	# Let collision particles finish even after the simulation stops.
	if state == "dead" and (not particles.is_empty() or shake > 0.0):
		update_effects(delta)
		shake = maxf(0.0, shake - 10.0 * delta)
		queue_redraw()


func start_game() -> void:
	state = "playing"
	elapsed = 0.0
	angle = -PI / 2.0
	orbit_radius = OUTER_RADIUS
	player_pos = CENTER + Vector2.UP * orbit_radius
	points = 0.0
	shield_energy = SHIELD_MAX_ENERGY
	combo = 1
	combo_clock = 0.0
	total_near_misses = 0
	perfect_misses = 0
	hazards.clear()
	particles.clear()
	popups.clear()
	trail.clear()
	spawn_clock = 0.0
	next_wave = 2
	time_to_wave_message = 2.0
	flash = 0.0
	shake = 0.0
	death_reason = "player"
	$StartSound.play()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if state != "playing":
		return

	elapsed += delta
	shield_energy = maxf(0.0, shield_energy - SHIELD_DECAY_RATE * delta)
	flash = maxf(0.0, flash - 2.0 * delta)
	shake = maxf(0.0, shake - 10.0 * delta)
	time_to_wave_message = maxf(0.0, time_to_wave_message - delta)

	var contract := Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var desired_radius := INNER_RADIUS if contract else OUTER_RADIUS
	orbit_radius = move_toward(orbit_radius, desired_radius, RADIUS_CHANGE_SPEED * delta)
	angle = wrapf(angle + ORBIT_SPEED * orbit_direction * delta, -PI, PI)
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
	if elapsed >= 30.0 and pattern_roll < 0.25:
		# Twin strike: two drifting hazards aimed near the predicted player path.
		var base_angle := predicted_drifter_angle()
		spawn_drifter(base_angle - 0.20)
		spawn_drifter(base_angle + 0.20)
	elif elapsed >= 15.0 and pattern_roll < 0.43:
		spawn_satellite()
	else:
		var aim_chance := 0.32 if elapsed < 15.0 else 0.55
		var planned_angle := predicted_drifter_angle() if rng.randf() < aim_chance else rng.randf_range(-PI, PI)
		spawn_drifter(planned_angle)


func predicted_drifter_angle() -> float:
	# Smart but forgiving: predictions ignore later changes of orbital radius.
	# Hazards pressure a stationary strategy but never have perfect aim.
	var radial_speed := minf(300.0, 195.0 + elapsed * 1.2)
	var impact_delay := (340.0 - orbit_radius) / radial_speed
	return angle + ORBIT_SPEED * orbit_direction * impact_delay + rng.randf_range(-1.70, 1.70)


func spawn_drifter(hazard_angle: float) -> void:
	hazards.append({
		"kind": "drifter",
		"angle": hazard_angle,
		"radius": 340.0,
		"size": 10.0,
		"speed": minf(300.0, 195.0 + elapsed * 1.2),
		"age": 0.0,
		"warmup": 0.35,
		"min_separation": 99999.0,
		"awarded": false,
	})


func spawn_satellite() -> void:
	var player_angular_speed := ORBIT_SPEED * orbit_direction
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
		"min_separation": 99999.0,
		"awarded": false,
	})


func update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h["age"] = float(h["age"]) + delta
		if h["kind"] == "drifter":
			h["radius"] = float(h["radius"]) - float(h["speed"]) * delta
		else:
			h["angle"] = float(h["angle"]) + float(h["speed"]) * delta

		var old_enough: bool = float(h["age"]) >= float(h["warmup"])
		var p: Vector2 = hazard_position(h)
		var distance := p.distance_to(player_pos)
		var collision_distance: float = PLAYER_SIZE + float(h["size"])
		if old_enough:
			if distance <= collision_distance:
				die("player")
				return
			h["min_separation"] = minf(float(h["min_separation"]), distance)
			# Score after leaving the danger zone, never merely for being near.
			if not bool(h["awarded"]) and distance > NEAR_RANGE + 6.0:
				var closest: float = float(h["min_separation"])
				if closest >= collision_distance + 1.0 and closest <= NEAR_RANGE:
					award_near_miss(closest, collision_distance, p)
					h["awarded"] = true
		if h["kind"] == "drifter":
			var debris_radius := float(h["radius"])
			var debris_size := float(h["size"])
			if shield_energy > 0.0 and debris_radius <= SHIELD_RADIUS + debris_size:
				absorb_debris(p)
				hazards.remove_at(i)
				continue
			if debris_radius <= PLANET_RADIUS + debris_size:
				die("planet")
				return
		var expired: bool = (h["kind"] == "drifter" and float(h["radius"]) < 38.0)
		expired = expired or (h["kind"] == "satellite" and float(h["age"]) > 4.3)
		if expired:
			hazards.remove_at(i)


func hazard_position(h: Dictionary) -> Vector2:
	var a: float = float(h["angle"])
	return CENTER + Vector2(cos(a), sin(a)) * float(h["radius"])


func award_near_miss(closest: float, collision_distance: float, where: Vector2) -> void:
	var perfect := closest <= collision_distance + 11.0
	var base := 250 if perfect else 100
	var gained: int = base * combo
	var shield_refill := SHIELD_REFILL_PERFECT if perfect else SHIELD_REFILL_NEAR
	points += float(gained)
	shield_energy = minf(SHIELD_MAX_ENERGY, shield_energy + shield_refill)
	total_near_misses += 1
	if perfect:
		perfect_misses += 1
	popups.append({"position": where, "label": ("PERFECT! " if perfect else "NEAR! ") + "+" + str(gained), "age": 0.0, "perfect": perfect})
	spawn_burst(GOLD if perfect else CYAN, where, 13 if perfect else 8)
	flash = 0.25 if perfect else 0.11
	shake = 1.7 if perfect else 0.65
	combo = mini(5, combo + 1)
	combo_clock = COMBO_DURATION
	$NearSound.pitch_scale = 1.0 + float(combo - 1) * 0.08
	$NearSound.play()


func absorb_debris(where: Vector2) -> void:
	shake = maxf(shake, 1.1)
	spawn_burst(GREEN, where, 9)


func die(reason: String) -> void:
	state = "dead"
	death_reason = reason
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
	var jolt := Vector2.ZERO
	if shake > 0.0:
		jolt = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake
	draw_set_transform(jolt)
	draw_arena()
	draw_hazards()
	draw_trail_and_player()
	draw_effects()
	draw_set_transform(Vector2.ZERO)
	draw_hud()

	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, WORLD), Color(CYAN.r, CYAN.g, CYAN.b, flash * 0.13))
	if state == "menu":
		draw_overlay("GREEDY ORBIT", "NEAR MISS TO POWER THE SHIELD", "HOLD SPACE / CLICK  =  MOVE IN", "RELEASE = MOVE OUT   |   DIRECTION = " + orbit_direction_label() + " [D]", "PRESS SPACE OR CLICK TO START")
	elif state == "dead":
		var death_title := "PLANET LOST" if death_reason == "planet" else "ORBIT BROKEN"
		draw_overlay(death_title, "SCORE  " + str(int(points)) + "     BEST  " + str(best_score), "NEAR MISSES  " + str(total_near_misses), "PERFECT DODGES  " + str(perfect_misses), "D = REVERSE   |   SPACE / CLICK / R = RETRY")
	elif state == "paused":
		draw_overlay("PAUSED", "DIRECTION  " + orbit_direction_label(), "", "", "PRESS P / ESC TO RESUME   |   D TO REVERSE")


func draw_stars() -> void:
	for i in range(stars.size()):
		var p: Vector2 = stars[i]
		var lum := 0.14 + float(i % 5) * 0.035
		draw_circle(p, 1.0 if i % 3 > 0 else 1.6, Color(0.62, 0.72, 0.9, lum))


func draw_arena() -> void:
	# Light orbit guides and a visually distinct risk zone.
	draw_arc(CENTER, INNER_RADIUS, 0.0, TAU, 112, Color(0.19, 0.62, 0.78, 0.24), 1.2, true)
	draw_arc(CENTER, OUTER_RADIUS, 0.0, TAU, 128, Color(0.20, 0.50, 0.69, 0.35), 1.4, true)
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
		var col := Color(1.0, 0.39, 0.46, 0.28 if warming else 1.0)
		if h["kind"] == "drifter":
			var unit := (p - CENTER).normalized()
			draw_line(p + unit * 17.0, p + unit * 36.0, Color(1.0, 0.31, 0.40, 0.22), 3.0, true)
		else:
			draw_arc(CENTER, float(h["radius"]), 0.0, TAU, 120, Color(1.0, 0.22, 0.35, 0.13), 1.0, true)
		draw_circle(p, float(h["size"]) + 7.0, Color(1.0, 0.22, 0.34, 0.08 if warming else 0.15))
		draw_circle(p, float(h["size"]), col)
		draw_circle(p + Vector2(-3.0, -3.0), 2.8, Color(1.0, 0.86, 0.86, 0.32 if warming else 0.9))


func draw_trail_and_player() -> void:
	for i in range(trail.size()):
		var fraction := float(i + 1) / float(trail.size())
		draw_circle(trail[i], 2.0 + 4.0 * fraction, Color(0.32, 0.86, 1.0, 0.20 * fraction))
	if state != "dead":
		draw_circle(player_pos, PLAYER_SIZE + 10.0, Color(0.26, 0.78, 1.0, 0.15))
		draw_circle(player_pos, PLAYER_SIZE + 3.0, Color(0.26, 0.78, 1.0, 0.19))
		draw_circle(player_pos, PLAYER_SIZE, CYAN)
		draw_circle(player_pos + Vector2(-2.5, -2.5), 3.0, Color("#ffffff"))


func draw_effects() -> void:
	for p in particles:
		var opacity: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var tint: Color = p["color"]
		draw_circle(p["position"], 2.5 * opacity + 0.8, Color(tint.r, tint.g, tint.b, opacity))
	for popup in popups:
		var opacity := clampf(1.0 - float(popup["age"]) / 0.75, 0.0, 1.0)
		var tint := GOLD if bool(popup["perfect"]) else CYAN
		var color := Color(tint.r, tint.g, tint.b, opacity)
		draw_text_center_at(str(popup["label"]), Vector2(popup["position"]).x, Vector2(popup["position"]).y, 17, color)


func draw_hud() -> void:
	draw_text("SCORE", Vector2(28, 36), 16, MUTED)
	draw_text(str(int(points)).pad_zeros(6), Vector2(28, 73), 30, PALE)
	draw_text("BEST  " + str(best_score), Vector2(28, 101), 16, MUTED)
	var energy_fraction := shield_fraction()
	var energy_color := shield_color(energy_fraction)
	draw_text_center("SHIELD  " + str(roundi(shield_energy)) + "%", 35, 16, energy_color)
	draw_rect(Rect2(Vector2(348, 45), Vector2(264, 12)), Color(0.12, 0.20, 0.29, 0.95))
	draw_rect(Rect2(Vector2(351, 48), Vector2(258.0 * energy_fraction, 6)), energy_color)
	var combo_color := GOLD if combo >= 3 else CYAN
	draw_text("COMBO", Vector2(780, 36), 16, MUTED)
	draw_text("x" + str(combo), Vector2(780, 76), 35, combo_color)
	draw_text("DIR  " + orbit_direction_label(), Vector2(780, 116), 16, MUTED)
	draw_text("WAVE " + str(mini(5, int(floor(elapsed / 15.0)) + 1)), Vector2(28, 686), 17, MUTED)
	draw_text("TIME " + ("%.1f" % elapsed) + "s", Vector2(784, 686), 17, MUTED)
	draw_text("HOLD = IN   |   RELEASE = OUT   |   D = REVERSE   |   P = PAUSE", Vector2(250, 688), 13, MUTED)
	if combo > 1:
		draw_rect(Rect2(Vector2(780, 90), Vector2(133, 5)), Color(0.19, 0.31, 0.44))
		draw_rect(Rect2(Vector2(780, 90), Vector2(133.0 * clampf(combo_clock / COMBO_DURATION, 0.0, 1.0), 5)), combo_color)
	if time_to_wave_message > 0.0 and state == "playing":
		var announce_color := Color(CYAN.r, CYAN.g, CYAN.b, minf(1.0, time_to_wave_message))
		draw_text_center("WAVE " + str(mini(5, int(floor(elapsed / 15.0)) + 1)), 164, 26, announce_color)


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
