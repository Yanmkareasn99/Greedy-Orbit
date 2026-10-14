extends SceneTree
## Run with Godot --headless --path . --script res://tests/gameplay_test.gd.

const GAME_SCENE = preload("res://scenes/game.tscn")
const TEST_ENERGY_DURATION := 4.3
var game: Node2D
var failures := 0
var checks := 0
var redraws := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func reset_game(with_guard: bool = true, with_controls: bool = true) -> void:
	game.start_game()
	# Keep tests independent of the user's saved best score.
	game.best_score = 9999999
	# Existing collision checks run with a purchased guard and controls.
	if with_guard:
		game.money = game.GUARD_COST + (game.GUARD_CONTROLS_COST if with_controls else 0)
		game.toggle_shop()
		game.buy_upgrade("guard")
		if with_controls:
			game.buy_upgrade("controls")
		game.toggle_shop()
	game.player_pos = game.CENTER + Vector2.RIGHT * game.OUTER_RADIUS


func add_hazard(kind: String, radius: float, hazard_angle: float = 0.0, age: float = 1.0, duration: float = TEST_ENERGY_DURATION) -> void:
	match kind:
		"drifter": game.spawn_drifter(hazard_angle)
		"spiral": game.spawn_spiral(hazard_angle)
		"zigzag": game.spawn_zigzag(hazard_angle)
		"satellite": game.spawn_satellite()
	var hazard: Dictionary = game.hazards.back()
	hazard["angle"] = hazard_angle
	hazard["radius"] = radius
	hazard["speed"] = 0.0
	hazard["age"] = age
	if hazard.has("base_angle"):
		hazard["base_angle"] = hazard_angle
	if kind == "satellite":
		# Fix fixture lifetimes so boundary checks stay deterministic.
		hazard["orbit_duration"] = duration


func mouse_at(position: Vector2, pressed: bool = true, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = game.get_global_transform_with_canvas() * (position + game.arena_offset)
	game._input(event)


func key_at(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._input(event)


func shop_mouse_at(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.get_global_transform_with_canvas() * position
	game._input(event)


func record_draw() -> void:
	redraws += 1


func run_checks() -> void:
	game = GAME_SCENE.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	# Headless checks exercise gameplay without starting audio playback.
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stream = null

	reset_game()
	game.shield_energy = 50.0
	add_hazard("drifter", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.state == "playing", "Ramming a Drifter must keep the player alive.")
	check(game.hazards.is_empty(), "Ramming must remove the hazard immediately.")
	check(game.points == 100.0 and game.hazards_destroyed == 1, "A destroyed Drifter must award 100 points at x1.")
	check(game.money == 10, "A guard-destroyed Drifter must award $10.")
	check(game.shield_energy == 50.0, "Destroying a Drifter must not recharge or drain the shield.")
	game.update_hazards(0.0)
	check(game.points == 100.0, "A removed hazard must never award points again.")

	reset_game()
	game.shield_energy = 20.0
	add_hazard("satellite", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.state == "playing" and game.hazards.is_empty(), "Ramming a Satellite must destroy it safely.")
	check(game.points == 250.0 and game.satellites_destroyed == 1, "A destroyed Satellite must award 250 points at x1.")
	check(game.money == 25, "A guard-destroyed Satellite must award $25.")
	check(game.shield_energy == 55.0, "Destroying a Satellite must recharge 35 energy.")
	game.shield_energy = 90.0
	add_hazard("satellite", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.shield_energy == 100.0, "Recharge must cap at maximum energy.")
	check(game.points == 750.0, "Destruction combos must apply to the next collision.")
	check(game.money == 50, "Money rewards must remain fixed even when the score combo grows.")
	game.shield_energy = 0.0
	add_hazard("satellite", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.shield_energy == 35.0, "A Satellite must restore a depleted shield.")

	reset_game()
	game.shield_energy = 50.0
	add_hazard("drifter", game.OUTER_RADIUS, 0.13)
	game.update_hazards(0.0)
	game.hazards[0]["angle"] = 0.50
	game.update_hazards(0.0)
	check(game.points == 0.0 and game.combo == 1, "A near miss must not award points or a combo.")
	check(game.money == 0, "Near misses must not award money.")
	check(game.shield_energy == 50.0, "A near miss must not recharge the shield.")
	game.hazards.clear()
	game._physics_process(1.0)
	check(game.points == 0.0 and game.shield_energy == 50.0, "Survival must not award points or passively drain shield energy.")

	reset_game()
	add_hazard("drifter", game.SHIELD_RADIUS + 10.0)
	game.update_hazards(0.0)
	check(game.shield_energy == 75.0 and game.hazards.is_empty(), "A shield collision must absorb the Drifter and cost 25 energy.")
	check(game.points == 0.0 and game.hazards_destroyed == 0 and game.combo == 1, "Shield blocks must not award player points, kills, or combos.")
	check(game.money == 0, "Shield blocks must not award money.")
	game.shield_energy = 10.0
	add_hazard("drifter", game.SHIELD_RADIUS + 10.0)
	game.update_hazards(0.0)
	check(game.shield_energy == 0.0 and game.state == "playing" and game.hazards.is_empty(), "The last shield energy must block one hit without becoming negative.")
	add_hazard("drifter", game.SHIELD_RADIUS + 10.0)
	game.update_hazards(0.0)
	check(game.hazards.size() == 1, "A depleted shield must let incoming hazards through.")
	game.hazards[0]["radius"] = game.PLANET_RADIUS + 10.0
	game.update_hazards(0.0)
	check(game.state == "dead" and game.death_reason == "planet", "An unshielded planet impact must end the run.")
	check(game.points == 0.0, "A planet impact must not award points.")

	reset_game()
	add_hazard("drifter", game.OUTER_RADIUS, 0.0, 0.0)
	game.update_hazards(0.0)
	check(game.points == 0.0 and game.hazards.size() == 1, "Warmup warnings must stay inactive.")
	game.hazards[0]["age"] = 1.0
	add_hazard("drifter", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.hazards.is_empty() and game.hazards_destroyed == 2 and game.points == 300.0, "Simultaneous collisions must each resolve once without skipping hazards.")

	reset_game()
	add_hazard("satellite", game.OUTER_RADIUS, 1.0, 4.4)
	game.update_hazards(0.0)
	check(game.hazards.size() == 1 and game.points == 0.0, "Timed-out energy must remain visible while escaping without awarding points.")
	game.update_hazards(2.0)
	check(game.hazards.is_empty() and game.points == 0.0 and game.money == 0, "Energy that escapes off-screen must disappear without awarding points or money.")
	game.hazards_destroyed = 10
	game.satellites_destroyed = 3
	game.shield_energy = 2.0
	game.points = 999.0
	game.start_game()
	check(game.points == 0.0 and game.hazards_destroyed == 0 and game.satellites_destroyed == 0 and game.shield_energy == 100.0, "Restart must reset score, destruction counts, and shield energy.")

	reset_game()
	game.shield_energy = 50.0
	add_hazard("drifter", 300.0)
	var target: Vector2 = game.hazard_position(game.hazards[0])
	mouse_at(target)
	check(game.hazards.is_empty() and game.points == 100.0 and game.hazards_destroyed == 1, "A left-click must destroy a distant Drifter and award points.")
	check(game.money == 10, "Click destruction must award $10 for a Drifter.")
	check(game.state == "playing" and game.shield_energy == 50.0, "Clicking a Drifter must preserve shield energy and keep playing.")
	mouse_at(target)
	game.update_hazards(0.0)
	check(game.points == 100.0 and game.hazards_destroyed == 1, "Repeated clicks and backup collision checks must not score a destroyed hazard twice.")

	reset_game()
	game.shield_energy = 20.0
	add_hazard("satellite", 300.0)
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.is_empty() and game.points == 250.0 and game.shield_energy == 55.0, "Clicking a green Satellite must score and recharge 35 energy.")
	check(game.money == 25, "Click destruction must award $25 for a Satellite.")

	reset_game()
	add_hazard("drifter", 300.0)
	target = game.hazard_position(game.hazards[0])
	mouse_at(target + Vector2(0.0, 18.0))
	check(game.hazards.size() == 1 and game.points == 0.0 and game.combo == 1, "Clicks outside the hazard and its glow must not award points or combos.")
	mouse_at(target, false)
	mouse_at(target, true, MOUSE_BUTTON_RIGHT)
	check(game.hazards.size() == 1 and game.points == 0.0, "Mouse releases and right-clicks must not destroy hazards.")
	game.state = "paused"
	mouse_at(target)
	check(game.state == "paused" and game.hazards.size() == 1 and game.points == 0.0, "Clicking while paused must not destroy hazards or resume play.")
	game.state = "playing"
	mouse_at(target + Vector2(0.0, 16.0))
	check(game.hazards.is_empty() and game.points == 100.0, "The visible glow must be included in the click target.")

	reset_game()
	add_hazard("drifter", 300.0, 0.0, 0.0)
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.is_empty() and game.points == 100.0, "Visible warmup hazards must be clickable before backup collisions activate.")

	reset_game()
	add_hazard("drifter", 300.0)
	add_hazard("satellite", 300.0)
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.size() == 1 and game.hazards[0]["kind"] == "drifter" and game.points == 250.0, "An overlap must destroy only the topmost hazard per click.")
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.is_empty() and game.points == 450.0, "A second click must destroy the remaining hazard with the current combo.")

	reset_game()
	game.position = Vector2(17.0, 43.0)
	game.scale = Vector2(1.5, 1.5)
	game.arena_offset = Vector2(2.0, -1.0)
	add_hazard("drifter", 300.0)
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.is_empty() and game.points == 100.0, "Mouse targeting must account for canvas transforms and the visible shake offset.")
	game.position = Vector2.ZERO
	game.scale = Vector2.ONE

	reset_game()
	var held_click := InputEventMouseButton.new()
	held_click.button_index = MOUSE_BUTTON_LEFT
	held_click.pressed = true
	held_click.position = game.CENTER
	Input.parse_input_event(held_click)
	Input.flush_buffered_events()
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "The input test must simulate a held mouse button.")
	game._physics_process(0.1)
	check(is_equal_approx(game.orbit_radius, game.OUTER_RADIUS), "Holding the mouse must not pull the backup inward.")
	var released_click: InputEventMouseButton = held_click.duplicate()
	released_click.pressed = false
	Input.parse_input_event(released_click)
	Input.flush_buffered_events()
	var held_space := InputEventKey.new()
	held_space.keycode = KEY_SPACE
	held_space.pressed = true
	Input.parse_input_event(held_space)
	Input.flush_buffered_events()
	game._physics_process(0.1)
	check(game.orbit_radius < game.OUTER_RADIUS, "Space must still pull the backup inward.")
	var released_space: InputEventKey = held_space.duplicate()
	released_space.pressed = false
	Input.parse_input_event(released_space)
	Input.flush_buffered_events()

	reset_game()
	game.state = "menu"
	mouse_at(game.CENTER)
	check(game.state == "playing" and game.points == 0.0, "A title-screen click must start the game without awarding points.")
	game.die("planet")
	mouse_at(game.CENTER)
	check(game.state == "dead", "An immediate game-over click must not restart the run.")
	game._process(game.GAME_OVER_RETRY_DELAY)
	mouse_at(game.CENTER)
	check(game.state == "playing" and game.points == 0.0, "A fresh game-over click after the delay must restart without awarding points.")

	reset_game(false, false)
	check(not game.guard_owned and not game.guard_controls_owned and game.money == 0, "A new run must start without money, a guard, or controls.")
	add_hazard("drifter", game.OUTER_RADIUS)
	game.update_hazards(0.0)
	check(game.hazards.size() == 1 and game.points == 0.0 and game.money == 0, "An unpurchased guard must never intercept a hazard.")
	var initial_angle: float = game.angle
	game.hazards.clear()
	game._physics_process(0.1)
	check(game.angle == initial_angle and game.trail.is_empty(), "An unpurchased guard must not move or leave a trail.")
	key_at(KEY_D)
	check(game.orbit_direction == 1.0, "Direction controls must be locked before buying a guard.")
	add_hazard("drifter", 300.0)
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.money == 10 and game.points == 100.0, "Clicking must earn money when no guard exists.")
	for i in range(5):
		add_hazard("drifter", 300.0)
		mouse_at(game.hazard_position(game.hazards[0]))
	check(game.money == 60, "Six Drifter kills must fund the first guard.")
	key_at(KEY_B)
	check(game.state == "shop", "B must open the shop during play.")
	var saved_elapsed: float = game.elapsed
	var saved_clock: float = game.spawn_clock
	game._physics_process(5.0)
	check(game.elapsed == saved_elapsed and game.spawn_clock == saved_clock, "The shop must freeze time and hazard spawning.")
	check(not game.buy_upgrade("controls") and game.money == 60 and not game.guard_controls_owned, "Controls must require a guard before charging money.")
	check(not game.buy_upgrade("speed") and not game.buy_upgrade("range") and game.money == 60, "Guard upgrades must require a guard before charging money.")
	key_at(KEY_1)
	check(game.guard_owned and not game.guard_controls_owned and game.money == 0, "Buying the first guard must cost $60 without unlocking controls.")
	game.money = 100
	check(not game.buy_upgrade("guard") and game.money == 100, "An owned guard must not be charged for again.")
	key_at(KEY_ESCAPE)
	check(game.state == "playing", "Esc must close the shop and resume play.")
	check(not game.buy_upgrade("controls") and game.money == 100, "Purchases must only work while the shop is open.")
	initial_angle = game.angle
	game._physics_process(0.1)
	check(not is_equal_approx(game.angle, initial_angle), "A purchased guard must automatically orbit.")
	key_at(KEY_D)
	check(game.orbit_direction == 1.0, "Direction reversal must remain locked after buying only a guard.")
	var locked_space := InputEventKey.new()
	locked_space.keycode = KEY_SPACE
	locked_space.pressed = true
	Input.parse_input_event(locked_space)
	Input.flush_buffered_events()
	game._physics_process(0.1)
	check(game.orbit_radius == game.OUTER_RADIUS, "Space must not control a guard until its controls are purchased.")
	var unlocked_space: InputEventKey = locked_space.duplicate()
	unlocked_space.pressed = false
	Input.parse_input_event(unlocked_space)
	Input.flush_buffered_events()
	game.toggle_shop()
	check(game.buy_upgrade("controls") and game.guard_controls_owned and game.money == 25, "The manual controls unlock must cost $75.")
	check(not game.buy_upgrade("controls") and game.money == 25, "Manual controls must not be sold twice.")
	game.toggle_shop()
	key_at(KEY_D)
	check(game.orbit_direction == -1.0, "Paid controls must enable direction reversal.")
	var paid_space := InputEventKey.new()
	paid_space.keycode = KEY_SPACE
	paid_space.pressed = true
	Input.parse_input_event(paid_space)
	Input.flush_buffered_events()
	game._physics_process(0.1)
	check(game.orbit_radius < game.OUTER_RADIUS, "Paid controls must enable contracting the orbit.")
	var paid_release: InputEventKey = paid_space.duplicate()
	paid_release.pressed = false
	Input.parse_input_event(paid_release)
	Input.flush_buffered_events()

	reset_game(true, false)
	game.toggle_shop()
	game.money = 49
	check(not game.buy_upgrade("speed") and game.guard_speed_level == 0 and game.money == 49, "Insufficient funds must leave both money and upgrades unchanged.")
	game.money = 300
	check(game.buy_upgrade("speed") and game.money == 250 and game.guard_speed_level == 1, "The first speed upgrade must cost $50.")
	check(is_equal_approx(game.guard_speed(), game.ORBIT_SPEED * 1.25), "A speed upgrade must increase actual orbit speed by 25 percent.")
	check(game.buy_upgrade("speed") and game.money == 150, "The second speed upgrade must cost $100.")
	check(game.buy_upgrade("speed") and game.money == 0 and game.guard_speed_level == 3, "The third speed upgrade must cost $150 and reach the cap.")
	game.money = 1000
	check(not game.buy_upgrade("speed") and game.money == 1000 and game.guard_speed_level == 3, "Maxed speed must not accept another purchase.")
	game.toggle_shop()
	game.angle = 0.0
	game._physics_process(0.1)
	check(is_equal_approx(game.angle, game.ORBIT_SPEED * 1.75 * 0.1), "Physics must apply purchased speed levels.")

	reset_game(true, false)
	add_hazard("drifter", game.OUTER_RADIUS + 22.0)
	game.update_hazards(0.0)
	check(game.hazards.size() == 1, "A base guard must not reach outside its interception radius.")
	game.money = 50
	game.toggle_shop()
	check(game.buy_upgrade("range") and game.money == 0 and game.guard_size() == game.PLAYER_SIZE + 4.0, "A size upgrade must cost $50 and enlarge the guard.")
	game.toggle_shop()
	game.update_hazards(0.0)
	check(game.hazards.is_empty() and game.money == 10, "The enlarged guard must actually intercept farther hazards and earn money.")
	game.toggle_shop()
	game.money = 250
	game.buy_upgrade("range")
	game.buy_upgrade("range")
	check(game.guard_range_level == 3 and not game.buy_upgrade("range") and game.money == 0, "Size upgrades must have increasing prices and stop at level three.")

	reset_game(false, false)
	game.money = 360
	game.toggle_shop()
	check(game.buy_upgrade("armor") and game.money == 300, "Shield armor must be purchasable without a guard for $60.")
	game.toggle_shop()
	add_hazard("drifter", game.SHIELD_RADIUS + 10.0)
	game.update_hazards(0.0)
	check(game.shield_energy == 80.0 and game.money == 300, "Armor must reduce shield damage to 20 without rewarding shield blocks.")
	game.toggle_shop()
	game.buy_upgrade("armor")
	game.buy_upgrade("armor")
	check(game.shield_armor_level == 3 and game.shield_hit_cost() == 10.0 and game.money == 0, "Three armor levels must cost $60/$120/$180 and reduce damage to 10.")
	check(not game.buy_upgrade("armor") and game.shield_armor_level == 3, "Shield armor must stop at level three.")
	game.money = 90
	game.shield_energy = 0.0
	check(game.buy_upgrade("repair") and game.shield_energy == 40.0 and game.money == 60, "A $30 shield repair must restore 40 energy, even from empty.")
	game.buy_upgrade("repair")
	game.buy_upgrade("repair")
	check(game.shield_energy == 100.0 and game.money == 0, "Repeated repairs must cap at maximum shield energy.")
	game.money = 100
	check(not game.buy_upgrade("repair") and game.money == 100, "A full shield must not accept a paid repair.")
	check(not game.buy_upgrade("unknown") and game.money == 100, "Unknown shop items must not change money.")

	reset_game(false, false)
	game.money = 60
	game.arena_offset = Vector2(2.0, -2.0)
	add_hazard("drifter", 300.0)
	shop_mouse_at(game.SHOP_BUTTON.get_center())
	check(game.state == "shop", "Clicking the HUD shop button must open the shop without using the arena shake offset.")
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.size() == 1 and game.points == 0.0 and game.money == 60, "Shop clicks must never pass through to hazards behind the panel.")
	shop_mouse_at(game.shop_row_rect(0).get_center())
	check(game.guard_owned and game.money == 0 and game.state == "shop", "Clicking a shop row must buy its item and keep the shop open.")
	shop_mouse_at(game.SHOP_CLOSE_BUTTON.get_center())
	check(game.state == "playing", "The shop close button must resume play.")
	game.money = 123
	game.guard_controls_owned = true
	game.guard_speed_level = 3
	game.guard_range_level = 2
	game.shield_armor_level = 1
	game.toggle_shop()
	key_at(KEY_R)
	check(game.state == "playing" and game.money == 0 and not game.guard_owned and not game.guard_controls_owned, "Restart from the shop must reset money, guard ownership, and controls.")
	check(game.guard_speed_level == 0 and game.guard_range_level == 0 and game.shield_armor_level == 0 and game.trail.is_empty(), "Restart must reset every upgrade and remove guard trails.")

	reset_game(false, false)
	game.shield_energy = 20.0
	add_hazard("satellite", game.OUTER_RADIUS, 0.0, TEST_ENERGY_DURATION - 0.1)
	game.update_hazards(0.05)
	check(game.hazards.size() == 1 and game.hazards[0]["radius"] == game.OUTER_RADIUS, "Energy must stay on its orbit while collection time remains.")
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.is_empty() and game.money == 25 and game.points == 250.0 and game.shield_energy == 55.0, "Energy collected just before its deadline must still give its normal rewards.")

	reset_game()
	game.shield_energy = 20.0
	add_hazard("satellite", game.OUTER_RADIUS, 0.0, TEST_ENERGY_DURATION)
	game.update_hazards(0.0)
	check(game.hazards.size() == 1 and game.money == 0 and game.shield_energy == 20.0, "The guard must not collect energy at or after its escape deadline.")
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.hazards.size() == 1 and game.points == 0.0 and game.money == 0 and game.shield_energy == 20.0, "Clicks on escaping energy must not collect it or give rewards.")
	game.update_hazards(0.25)
	check(is_equal_approx(float(game.hazards[0]["radius"]), game.OUTER_RADIUS + game.ENERGY_ESCAPE_SPEED * 0.25), "Timed-out energy must visibly fly outward from the orbit.")
	game.update_hazards(3.0)
	check(game.hazards.is_empty() and game.state == "playing" and game.shield_energy == 20.0, "Escaping energy must leave the screen without damaging the planet or shield.")

	reset_game(false, false)
	add_hazard("satellite", game.OUTER_RADIUS, 0.0, TEST_ENERGY_DURATION - 0.05)
	game.update_hazards(0.15)
	check(is_equal_approx(float(game.hazards[0]["radius"]), game.OUTER_RADIUS + game.ENERGY_ESCAPE_SPEED * 0.1), "A tick crossing the deadline must only move outward for the time after the deadline.")
	var saved_energy_age: float = game.hazards[0]["age"]
	var saved_energy_radius: float = game.hazards[0]["radius"]
	game.toggle_shop()
	game._physics_process(5.0)
	check(game.hazards[0]["age"] == saved_energy_age and game.hazards[0]["radius"] == saved_energy_radius, "Energy collection and escape timers must freeze while shopping.")
	game.toggle_shop()
	key_at(KEY_P)
	game._physics_process(5.0)
	check(game.hazards[0]["age"] == saved_energy_age and game.hazards[0]["radius"] == saved_energy_radius, "Energy collection and escape timers must freeze while paused.")

	reset_game(false, false)
	game.rng.seed = 20261014
	var sampled_durations: Array[float] = []
	var durations_in_bounds := true
	for i in range(64):
		game.spawn_satellite()
		var duration := float(game.hazards.back()["orbit_duration"])
		sampled_durations.append(duration)
		if duration < game.ENERGY_ORBIT_MIN_DURATION or duration > game.ENERGY_ORBIT_MAX_DURATION:
			durations_in_bounds = false
	check(durations_in_bounds, "Random collection windows must stay within 2.5 to 6 seconds.")
	check(sampled_durations.max() - sampled_durations.min() > 1.0, "Different satellites must receive varied collection windows.")
	game.hazards.clear()
	add_hazard("satellite", game.OUTER_RADIUS, 0.0, 2.4, game.ENERGY_ORBIT_MIN_DURATION)
	add_hazard("satellite", game.OUTER_RADIUS, 1.0, 2.4, game.ENERGY_ORBIT_MAX_DURATION)
	game.update_hazards(0.2)
	check(not game.is_hazard_collectible(game.hazards[0]) and game.is_hazard_collectible(game.hazards[1]), "At the same age, only the satellite whose individual deadline passed must escape.")
	check(is_equal_approx(float(game.hazards[0]["radius"]), game.OUTER_RADIUS + game.ENERGY_ESCAPE_SPEED * 0.1) and game.hazards[1]["radius"] == game.OUTER_RADIUS, "Escape motion must use each satellite's own deadline.")
	check(game.hazards[0]["orbit_duration"] == game.ENERGY_ORBIT_MIN_DURATION and game.hazards[1]["orbit_duration"] == game.ENERGY_ORBIT_MAX_DURATION, "A satellite's random duration must not change as it ages.")
	mouse_at(game.hazard_position(game.hazards[0]))
	check(game.money == 0 and game.hazards.size() == 2, "The short-lived satellite must not be collectable after its deadline.")
	mouse_at(game.hazard_position(game.hazards[1]))
	check(game.money == 25 and game.hazards.size() == 1, "A longer-lived satellite must remain collectable until its own deadline.")

	reset_game(false, false)
	game.points = 900.0
	game.money = 37
	game.elapsed = 12.5
	game.hazards_destroyed = 9
	game.satellites_destroyed = 2
	game.die("planet")
	check(game.game_over_clock == game.GAME_OVER_RETRY_DELAY, "Death must start the results delay.")
	for retry_key in [KEY_SPACE, KEY_ENTER, KEY_R]:
		key_at(retry_key)
	check(game.state == "dead" and game.points == 900.0 and game.money == 37, "Every restart key must preserve results during the delay.")
	for i in range(10):
		mouse_at(game.CENTER)
	check(game.state == "dead" and game.hazards_destroyed == 9 and game.satellites_destroyed == 2, "Repeated game-over clicks must preserve destruction statistics.")
	game._physics_process(5.0)
	check(game.elapsed == 12.5, "Game-over time and results must remain frozen.")
	game.particles.clear()
	game.popups.clear()
	game.shake = 0.0
	game._process(game.GAME_OVER_RETRY_DELAY * 0.5)
	check(is_equal_approx(game.game_over_clock, game.GAME_OVER_RETRY_DELAY * 0.5), "The delay must advance even after all effects finish.")
	mouse_at(game.CENTER)
	key_at(KEY_R)
	check(game.state == "dead", "Restart must remain locked throughout the full delay.")
	game._process(game.GAME_OVER_RETRY_DELAY)
	check(game.game_over_clock == 0.0 and game.state == "dead", "The timer must clamp to zero without replaying earlier restart inputs.")
	mouse_at(game.CENTER, false)
	var repeated_key := InputEventKey.new()
	repeated_key.keycode = KEY_SPACE
	repeated_key.pressed = true
	repeated_key.echo = true
	game._input(repeated_key)
	check(game.state == "dead", "Releasing the mouse or holding a repeating key must not restart automatically.")
	mouse_at(game.CENTER)
	check(game.state == "playing" and game.game_over_clock == 0.0 and game.points == 0.0 and game.money == 0, "A new click after the delay must reset the run and retry timer.")
	for retry_key in [KEY_SPACE, KEY_ENTER, KEY_R]:
		reset_game(false, false)
		game.die("planet")
		key_at(retry_key)
		check(game.state == "dead", "Restart key must be blocked before the delay: " + str(retry_key))
		game._process(game.GAME_OVER_RETRY_DELAY + 0.1)
		key_at(retry_key)
		check(game.state == "playing", "A new restart key must work after the delay: " + str(retry_key))

	for kind in ["spiral", "zigzag"]:
		var expected_score: int = game.SPIRAL_SCORE if kind == "spiral" else game.ZIGZAG_SCORE
		var expected_money: int = game.SPIRAL_MONEY if kind == "spiral" else game.ZIGZAG_MONEY
		reset_game(false, false)
		game.shield_energy = 20.0
		add_hazard(kind, 300.0, 0.0, 0.45)
		mouse_at(game.hazard_position(game.hazards[0]))
		check(game.hazards.is_empty() and game.points == expected_score and game.money == expected_money, "Clicks must destroy and reward the new hazard: " + kind)
		check(game.shield_energy == 20.0 and game.satellites_destroyed == 0, "New incoming hazards must not recharge the shield: " + kind)
		game.update_hazards(0.0)
		check(game.money == expected_money and game.hazards_destroyed == 1, "A destroyed new hazard must not award rewards twice: " + kind)
		reset_game(true, false)
		add_hazard(kind, game.OUTER_RADIUS, 0.0, 0.45)
		game.update_hazards(0.0)
		check(game.hazards.is_empty() and game.money == expected_money and game.state == "playing", "The purchased guard must intercept the new hazard: " + kind)
		reset_game(true, false)
		add_hazard(kind, game.OUTER_RADIUS, 0.0, 0.0)
		game.update_hazards(0.0)
		check(game.hazards.size() == 1 and game.money == 0, "New hazard warmup must prevent early guard collisions: " + kind)
		reset_game(false, false)
		add_hazard(kind, game.SHIELD_RADIUS + 10.0)
		game.update_hazards(0.0)
		check(game.hazards.is_empty() and game.shield_energy == 75.0 and game.money == 0 and game.points == 0.0, "A new hazard must damage the shield without awarding rewards: " + kind)
		game.shield_energy = 0.0
		add_hazard(kind, game.PLANET_RADIUS + 10.0)
		game.update_hazards(0.0)
		check(game.state == "dead" and game.death_reason == "planet", "A new hazard must destroy an unshielded planet: " + kind)
		reset_game(false, false)
		add_hazard(kind, 300.0, 0.0, 0.45)
		var frozen_hazard: Dictionary = game.hazards[0].duplicate(true)
		key_at(KEY_P)
		game._physics_process(5.0)
		check(game.hazards[0] == frozen_hazard, "Pausing must freeze the new hazard's trajectory: " + kind)
		key_at(KEY_P)
		game.toggle_shop()
		game._physics_process(5.0)
		check(game.hazards[0] == frozen_hazard, "Shopping must freeze the new hazard's trajectory: " + kind)

	reset_game(false, false)
	game.spawn_spiral(0.0)
	var spiral: Dictionary = game.hazards[0]
	spiral["curve_speed"] = 1.0
	spiral["speed"] = 100.0
	game.update_hazard_motion(spiral, 0.2)
	check(spiral["angle"] == 0.0 and spiral["radius"] == 320.0, "Spirals must preserve their readable straight warmup approach.")
	game.update_hazard_motion(spiral, 0.5)
	check(is_equal_approx(float(spiral["angle"]), 0.25) and spiral["radius"] == 270.0, "Spirals must curve while continuing inward.")
	check(game.hazard_position(spiral).y > game.CENTER.y, "A Spiral's world-space path must leave its initial straight line.")
	var reverse_spiral: Dictionary = spiral.duplicate(true)
	reverse_spiral["curve_speed"] = -1.0
	game.update_hazard_motion(reverse_spiral, 0.0)
	check(float(reverse_spiral["angle"]) < 0.0, "Spirals must support both turning directions.")

	reset_game(false, false)
	game.spawn_zigzag(0.0)
	var zigzag: Dictionary = game.hazards[0]
	zigzag["age"] = zigzag["warmup"]
	zigzag["turn_period"] = 1.0
	zigzag["turn_amplitude"] = 0.3
	zigzag["speed"] = 100.0
	game.update_hazard_motion(zigzag, 0.2)
	var before_turn := float(zigzag["angle"])
	game.update_hazard_motion(zigzag, 0.04)
	var at_turn := float(zigzag["angle"])
	var turn_position: Vector2 = game.hazard_position(zigzag)
	game.update_hazard_motion(zigzag, 0.06)
	check(before_turn < at_turn and float(zigzag["angle"]) < at_turn, "Zigzag hazards must reverse their turning direction during flight.")
	check(zigzag["radius"] == 310.0 and game.hazard_position(zigzag).distance_to(turn_position) < 30.0, "Zigzag reversals must keep moving inward without teleporting.")
	game.update_hazard_motion(zigzag, 0.7)
	check(absf(float(zigzag["angle"])) <= 0.3, "Zigzag steering must stay within its configured angular range.")

	for kind in ["spiral", "zigzag"]:
		reset_game(false, false)
		if kind == "spiral": game.spawn_spiral(0.5)
		else: game.spawn_zigzag(0.5)
		var one_step: Dictionary = game.hazards[0].duplicate(true)
		var many_steps: Dictionary = one_step.duplicate(true)
		game.update_hazard_motion(one_step, 0.8)
		for i in range(80):
			game.update_hazard_motion(many_steps, 0.01)
		check(game.hazard_position(one_step).distance_to(game.hazard_position(many_steps)) < 0.01, "New trajectories must be consistent across different tick sizes: " + kind)
		check(many_steps["trail"].size() == game.HAZARD_TRAIL_LENGTH, "New hazard trails must have bounded memory: " + kind)

	# Seeded sampling checks that energy remains rare in every wave,
	# including waves where Twin Strike competes with its spawn chance.
	for wave_elapsed in [0.0, 20.0, 40.0, 80.0]:
		reset_game(false, false)
		game.elapsed = wave_elapsed
		game.rng.seed = 20261014
		var energy_spawns := 0
		var twin_spawns := 0
		var spiral_spawns := 0
		var zigzag_spawns := 0
		for i in range(1000):
			game.hazards.clear()
			game.spawn_pattern()
			if game.hazards[0]["kind"] == "satellite":
				energy_spawns += 1
			if game.hazards.size() == 2:
				twin_spawns += 1
			if game.hazards[0]["kind"] == "spiral": spiral_spawns += 1
			if game.hazards[0]["kind"] == "zigzag": zigzag_spawns += 1
		check(energy_spawns >= 60 and energy_spawns <= 140, "Energy spawn frequency must stay around 10 percent at elapsed time " + str(wave_elapsed) + ".")
		if wave_elapsed >= 30.0:
			check(twin_spawns >= 200 and twin_spawns <= 300, "Rarer energy must preserve the Twin Strike frequency.")
		check(spiral_spawns > 0, "Spiral hazards must appear in the spawn mix at elapsed time " + str(wave_elapsed))
		check(zigzag_spawns > 0 if wave_elapsed >= 15.0 else zigzag_spawns == 0, "Zigzag hazards must enter the spawn mix from wave two.")

	reset_game(false, false)
	# Exercise the shop drawing path with both locked and owned upgrades.
	# Include energy countdown, last-second warning, and escaping visuals.
	add_hazard("satellite", game.OUTER_RADIUS, 0.0, 1.0)
	add_hazard("satellite", game.OUTER_RADIUS, 1.0, TEST_ENERGY_DURATION - 0.5)
	add_hazard("satellite", game.OUTER_RADIUS, 2.0, TEST_ENERGY_DURATION + 0.1)
	game.spawn_spiral(0.0)
	game.spawn_zigzag(1.0)
	var visible_zigzag: Dictionary = game.hazards.back()
	visible_zigzag["age"] = visible_zigzag["warmup"]
	visible_zigzag["turn_period"] = 1.0
	for i in range(12):
		game.update_hazard_motion(game.hazards[3], 1.0 / 60.0)
		game.update_hazard_motion(visible_zigzag, 1.0 / 60.0)
	game.draw.connect(record_draw)
	game.toggle_shop()
	game.queue_redraw()
	await process_frame
	await process_frame
	check(redraws > 0, "The shop with no guard must render successfully.")
	var previous_redraws := redraws
	game.money = 1000
	for item in ["guard", "controls", "speed", "range", "armor"]:
		game.buy_upgrade(item)
	game.queue_redraw()
	await process_frame
	await process_frame
	check(redraws > previous_redraws, "The shop with purchased upgrades must render successfully.")
	previous_redraws = redraws
	game.die("planet")
	await process_frame
	await process_frame
	check(redraws > previous_redraws, "Locked game-over results and progress bar must render successfully.")
	previous_redraws = redraws
	game._process(game.GAME_OVER_RETRY_DELAY)
	await process_frame
	await process_frame
	check(redraws > previous_redraws, "Game-over results must redraw with the retry prompt when the delay ends.")

	print("Gameplay checks: %d passed, %d failed." % [checks - failures, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
