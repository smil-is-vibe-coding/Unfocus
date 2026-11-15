class_name HoverJet
extends RigidBody3D
## Hovering racing jet.
##
## - Four repulsor rays (one per corner) push off the ROAD ONLY (physics layer 2).
##   Leave the road and nothing holds you up: you fall and respawn.
## - Thrust, braking and yaw are applied in the plane of the road under you.
## - Lateral grip bleeds sideways drift; the airbrake (handbrake key) lowers grip
##   and sharpens the turn for drifts that charge a boost.
## - Health, an item slot (CarItems), invisibility and respawning for combat.
## Everything (model, collision, rays) is built from `spec` in _ready().

signal drift_started
signal drift_ended(duration: float, boost_awarded: float)
signal damaged(amount: float, attacker: HoverJet)
signal destroyed(attacker: HoverJet)
signal respawned
signal fell
signal shield_hit(charges_left: int)
signal shield_refilled
signal item_changed(item: int)

const ROAD_LAYER := 2   ## Physics layer bit (value 2 = layer 2) the hover rays look for.

@export var spec: JetSpec
@export var player_controlled := true
@export var driver_name := "Player"

@export_group("Hover")
@export var hover_stiffness := 45.0       ## Spring (1/s^2).
@export var hover_damping := 9.0
@export var hover_range_mult := 2.6       ## Rays support up to hover_height * this.
@export var ray_length := 7.0
@export var max_hover_accel := 70.0
@export var align_strength := 14.0
@export var align_damping := 6.0
@export var air_gravity_mult := 1.5
## Extra pull toward the road when it is under you but out of hover range
## (keeps jets glued over crests; does nothing once you're off the road).
@export var track_magnet := 22.0
@export var fall_respawn_delay := 1.0

@export_group("Drive")
@export var coast_decel := 4.0            ## Slowdown off-throttle (m/s^2).
@export var brake_decel := 26.0
@export var reverse_speed := 15.0
@export var air_drag := 0.0006            ## Quadratic drag (1/m).
@export var yaw_response := 9.0
@export var max_yaw_accel := 30.0

@export_group("Drift")
@export var drift_min_speed := 15.0
@export_range(0.0, 1.0) var drift_grip_mult := 0.3
@export var drift_turn_mult := 1.45

@export_group("Boost")
@export var boost_accel := 16.0
@export var boost_top_speed_mult := 1.3
@export var boost_min_drift_time := 1.0
@export var boost_per_drift_second := 0.6
@export var boost_max_time := 2.5

@export_group("Visual")
@export var bank_angle_deg := 22.0
@export var hover_bob := 0.06

@export_group("Edge Shield")
## Force field at the road edge: blocks this many hard hits, then you can fall.
@export var max_shield_charges := 5
@export var shield_restitution := 0.35     ## Bounce off the field (0 = stick, 1 = full bounce).
@export var shield_hit_speed := 1.5        ## Outward speed (m/s) that counts as a hit.
@export var shield_hit_cooldown := 0.8     ## A continuous scrape only costs one charge.
@export var shield_warn_distance := 4.0    ## Player-only: field glows faintly this close to the edge.

@export_group("Combat")
@export var respawn_delay := 2.5
@export var respawn_grace := 2.0

# Inputs (from the player or an AIDriver).
var throttle_input := 0.0
var brake_input := 0.0
var steer_input := 0.0   ## +1 = left, -1 = right
var handbrake := false

# Runtime state for HUD / camera / AI / items.
var forward_speed := 0.0
var slip_angle := 0.0
var grounded_count := 0
var track_normal := Vector3.UP
var is_drifting := false
var drift_time := 0.0
var boost_time := 0.0
var grip_factor := 1.0   ## Temporarily lowered by hookshots.
var top_speed := 60.0
var max_health := 100.0
var health := 100.0
var knockback_mult := 1.0
var is_destroyed := false
var is_invisible := false
var grace_time := 0.0
var items: CarItems
var shield_charges := 5
## Held on the grid during the countdown (engine can rev, jet can't move).
var race_locked := false
## Engine flooded by a jumped start: no thrust while > 0.
var stall_time := 0.0
var _boost_ring_t := 0.0
var _glitch_t := 0.0

var _shield_cooldown := 0.0
var _shield_fx_cooldown := 0.0
var _hurt_sfx_cooldown := 0.0

var _rays: Array[RayCast3D] = []
var _model: Node3D
var _exhaust_mat: StandardMaterial3D
var _underglow: OmniLight3D
var _visual_steer := 0.0
var _bob_t := 0.0
var _air_time := 0.0
var _fall_time := 0.0
var _flip_time := 0.0
var _respawn_timer := 0.0
var _reset_requested := false
var _yaw_inertia := 1000.0
var _tilt_inertia := 1000.0
var _gravity := 9.8
var _track: RaceTrack


func _ready() -> void:
	if spec == null:
		spec = JetCatalog.get_spec(0)
	add_to_group("cars")
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	mass = spec.mass
	top_speed = spec.top_speed
	max_health = spec.max_health
	health = max_health
	shield_charges = max_shield_charges
	knockback_mult = spec.knockback_mult
	can_sleep = false
	continuous_cd = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 1.5
	collision_layer = 1
	collision_mask = 1
	var pm := PhysicsMaterial.new()
	pm.friction = 0.1
	pm.bounce = 0.2
	physics_material_override = pm

	# Collision box roughly the hull (wings stick out a little past it).
	var size := Vector3(minf(spec.wing_span * 0.65, 3.0), 0.7, spec.length * 0.92)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	inertia = Vector3(
		mass * (size.y * size.y + size.z * size.z) / 12.0,
		mass * (size.x * size.x + size.z * size.z) / 12.0,
		mass * (size.x * size.x + size.y * size.y) / 12.0)
	_yaw_inertia = inertia.y
	_tilt_inertia = (inertia.x + inertia.z) * 0.5

	# Repulsor rays at the four corners of the hull.
	var rx := clampf(spec.wing_span * 0.25, 0.7, 1.3)
	var rz := spec.length * 0.36
	for p in [Vector3(-rx, 0, -rz), Vector3(rx, 0, -rz), Vector3(-rx, 0, rz), Vector3(rx, 0, rz)]:
		var ray := RayCast3D.new()
		ray.position = p
		ray.target_position = Vector3(0, -ray_length, 0)
		ray.collision_mask = ROAD_LAYER
		ray.enabled = true
		add_child(ray)
		_rays.append(ray)

	var built := JetModel.build(spec)
	_model = built.root
	_exhaust_mat = built.exhaust_material
	add_child(_model)

	_underglow = OmniLight3D.new()
	_underglow.name = "Underglow"
	_underglow.light_color = spec.color
	_underglow.light_energy = 3.0
	_underglow.omni_range = 7.0
	_underglow.position = Vector3(0, -0.8, 0)
	_underglow.visible = Game.quality != Game.Quality.LOW
	add_child(_underglow)

	for ex: Vector3 in built.exhausts:
		var anchor := Node3D.new()
		anchor.position = ex
		add_child(anchor)
		var trail := LightTrail.new()
		trail.source = anchor
		trail.color = spec.accent
		trail.width = 0.1 + spec.engine_radius * 0.25
		trail.intensity = 0.8
		add_child(trail)

	items = CarItems.new()
	items.name = "Items"
	add_child(items)

	var engine := EngineAudio.new()
	engine.name = "EngineAudio"
	add_child(engine)


# --- Public API (items, HUD, AI) ------------------------------------------------

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func is_targetable() -> bool:
	return not is_destroyed and not is_invisible


func reset_car() -> void:
	_reset_requested = true


func get_track() -> RaceTrack:
	if _track == null or not is_instance_valid(_track):
		_track = get_tree().get_first_node_in_group("track") as RaceTrack
	return _track


## World-space point at the tail (for firing backward).
func tail_point(side := 0.0, up := 0.15) -> Vector3:
	return global_transform * Vector3(side * spec.body_width * 0.8, up, spec.length * 0.6)


## World-space point at the nose (side = -1 left, 0 centre, 1 right).
func nose_point(side := 0.0, up := 0.15) -> Vector3:
	return global_transform * Vector3(side * spec.body_width * 0.8, up, -spec.length * 0.55)


func apply_damage(amount: float, attacker: HoverJet = null) -> void:
	if is_destroyed or grace_time > 0.0 or amount <= 0.0:
		return
	amount *= spec.damage_taken_mult
	health = maxf(health - amount, 0.0)
	if player_controlled and _hurt_sfx_cooldown <= 0.0:
		Sound.play("hit_player", 0.0, randf_range(0.9, 1.1))
		_hurt_sfx_cooldown = 0.09
	damaged.emit(amount, attacker)
	if health <= 0.0:
		_destroy(attacker)


## Forcefield pickup. Returns false if the shield is already full.
func refill_shield() -> bool:
	if is_destroyed or shield_charges >= max_shield_charges:
		return false
	shield_charges = max_shield_charges
	Effects.ring_burst(get_parent(), global_position, PowerUp.color_of(PowerUp.Type.FORCEFIELD), 6.0, 3)
	shield_refilled.emit()
	return true


func shield_color() -> Color:
	# Cyan when full, through amber, to red on the last charge.
	var t := float(shield_charges) / float(maxi(max_shield_charges, 1))
	return Color(1.0, 0.15, 0.1).lerp(Color(1.0, 0.75, 0.1), clampf(t * 2.0, 0.0, 1.0)).lerp(
		Color(0.3, 0.9, 1.0), clampf(t * 2.0 - 1.0, 0.0, 1.0))


func repair(amount: float) -> void:
	if not is_destroyed:
		health = minf(health + amount, max_health)


func start_boost(duration: float) -> void:
	boost_time = maxf(boost_time, duration)


func set_invisible(on: bool) -> void:
	is_invisible = on
	_set_visual_transparency(0.82 if on else 0.0)
	if _model and not on:
		_model.position.x = 0.0
	if _underglow:
		_underglow.visible = not on


func _set_visual_transparency(value: float) -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).transparency = value
		stack.append_array(n.get_children())


func _destroy(attacker: HoverJet) -> void:
	is_destroyed = true
	is_drifting = false
	boost_time = 0.0
	_respawn_timer = respawn_delay
	if items:
		items.clear()
	Effects.explosion(get_parent(), global_position, spec.color, 6.0, 0.8)
	Effects.explosion(get_parent(), global_position + Vector3.UP, Color(1.0, 0.5, 0.1), 3.5, 0.6)
	Sound.play_at("explosion_big", global_position, 0.0, randf_range(0.9, 1.05), 18.0)
	apply_central_impulse(Vector3.UP * mass * 6.0 * knockback_mult)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _yaw_inertia * 3.0)
	_set_visual_transparency(0.5)
	destroyed.emit(attacker)


func _respawn() -> void:
	is_destroyed = false
	health = max_health
	grace_time = respawn_grace
	_set_visual_transparency(0.82 if is_invisible else 0.0)
	_do_reset()
	respawned.emit()


# --- Simulation -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	grace_time = maxf(grace_time - delta, 0.0)
	_hurt_sfx_cooldown -= delta
	grip_factor = move_toward(grip_factor, 1.0, delta * 1.5)

	if is_destroyed:
		throttle_input = 0.0
		brake_input = 0.0
		steer_input = 0.0
		handbrake = false
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
			return
	elif player_controlled:
		_read_player_input()

	if _reset_requested:
		_do_reset()
		return

	_update_hover()
	var up := global_basis.y
	var plane_n := track_normal if grounded_count >= 2 else Vector3.UP
	var fwd := -global_basis.z
	fwd = (fwd - plane_n * fwd.dot(plane_n)).normalized()
	var right := fwd.cross(plane_n).normalized()
	var v := linear_velocity
	forward_speed = v.dot(fwd)
	var lateral := v.dot(right)
	slip_angle = atan2(lateral, absf(forward_speed)) if Vector2(lateral, forward_speed).length() > 2.0 else 0.0

	_update_drift(delta)
	var grounded := grounded_count >= 2

	# Quadratic drag always applies.
	apply_central_force(-v * v.length() * air_drag * mass)

	if grounded:
		_drive(delta, fwd, right, plane_n, lateral)
	else:
		apply_central_force(Vector3.DOWN * _gravity * (air_gravity_mult - 1.0) * mass)
		apply_torque(Vector3.UP * steer_input * deg_to_rad(spec.turn_rate_high) * 2.0 * _yaw_inertia)

	_align(delta, up, grounded)
	_edge_shield(delta)
	_check_fall(delta, grounded)
	_update_visuals(delta)


func _read_player_input() -> void:
	throttle_input = Input.get_action_strength("accelerate")
	brake_input = Input.get_action_strength("brake")
	steer_input = Input.get_axis("steer_right", "steer_left")
	handbrake = Input.is_action_pressed("handbrake")
	if Input.is_action_just_pressed("reset_car"):
		_reset_requested = true
	if items and not race_locked:
		if Input.is_action_just_pressed("use_item"):
			items.use(false)
		elif Input.is_action_just_pressed("use_item_back"):
			items.use(true)
		if Input.is_action_just_pressed("item_next"):
			items.cycle(1)
			Sound.play("ui_move")
		elif Input.is_action_just_pressed("item_prev"):
			items.cycle(-1)
			Sound.play("ui_move")


func _update_hover() -> void:
	grounded_count = 0
	var seen := 0
	var seen_normal := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	var up := global_basis.y
	var max_range := spec.hover_height * hover_range_mult
	var share := mass / float(_rays.size())
	var com := global_transform * center_of_mass
	for ray in _rays:
		ray.force_raycast_update()
		if not ray.is_colliding():
			continue
		var origin := ray.global_position
		var dist := origin.distance_to(ray.get_collision_point())
		seen += 1
		seen_normal += ray.get_collision_normal()
		if dist > max_range:
			continue
		grounded_count += 1
		normal_sum += ray.get_collision_normal()
		var point_vel := linear_velocity + angular_velocity.cross(origin - com)
		# Gravity compensation + spring toward hover height + damping. Push only.
		var accel := _gravity * up.y + (spec.hover_height - dist) * hover_stiffness - point_vel.dot(up) * hover_damping
		accel = clampf(accel, 0.0, max_hover_accel)
		apply_force(up * accel * share, origin - global_position)
	track_normal = normal_sum.normalized() if grounded_count > 0 else Vector3.UP
	if grounded_count < 2 and seen >= 2 and track_magnet > 0.0:
		apply_central_force(-seen_normal.normalized() * track_magnet * mass)


func _drive(delta: float, fwd: Vector3, right: Vector3, plane_n: Vector3, lateral: float) -> void:
	var a_long := 0.0
	var top := top_speed * (boost_top_speed_mult if boost_time > 0.0 else 1.0)
	if race_locked:
		# Clamped to the grid: kill any creep.
		apply_central_force((-linear_velocity * 6.0) * mass)
		return
	if throttle_input > 0.0 and forward_speed < top and not is_destroyed and stall_time <= 0.0:
		var t := clampf(forward_speed / top, 0.0, 1.0)
		a_long += throttle_input * spec.accel * (1.0 - pow(t, spec.power_falloff))
	if brake_input > 0.0:
		if forward_speed > 0.5:
			a_long -= minf(brake_input * brake_decel, forward_speed / delta)
		elif forward_speed > -reverse_speed:
			a_long -= brake_input * spec.accel * 0.5
	if throttle_input <= 0.0 and brake_input <= 0.0:
		a_long -= signf(forward_speed) * minf(coast_decel, absf(forward_speed) / delta)
	if boost_time > 0.0 and not is_destroyed:
		var fade := clampf((top_speed * boost_top_speed_mult - forward_speed) / 8.0, 0.0, 1.0)
		a_long += boost_accel * fade
	apply_central_force(fwd * a_long * mass)

	# Lateral grip.
	var grip := spec.grip * grip_factor
	var lat_cap := spec.max_lateral_accel * grip_factor
	if is_drifting or handbrake:
		grip *= drift_grip_mult
		lat_cap *= 0.6
	var a_lat := clampf(-lateral * grip, -lat_cap, lat_cap)
	apply_central_force(right * a_lat * mass)

	# Yaw: drive the turn rate toward what the stick asks for.
	var speed := absf(forward_speed)
	var speed_t := clampf(speed / spec.top_speed, 0.0, 1.0)
	var rate := deg_to_rad(lerpf(spec.turn_rate_low, spec.turn_rate_high, speed_t))
	rate *= clampf(speed / 6.0, 0.3, 1.0)
	if is_drifting:
		rate *= drift_turn_mult
	var dir_sign := -1.0 if forward_speed < -0.5 else 1.0
	var target_rate := steer_input * rate * dir_sign
	var current := angular_velocity.dot(plane_n)
	var yaw_acc := clampf((target_rate - current) * yaw_response, -max_yaw_accel, max_yaw_accel)
	apply_torque(plane_n * yaw_acc * _yaw_inertia)


## Keeps the hull parallel to the road (or level in the air) without touching yaw.
func _align(_delta: float, up: Vector3, grounded: bool) -> void:
	var target_up := track_normal if grounded else Vector3.UP
	var axis := up.cross(target_up)
	var tilt_vel := angular_velocity - up * angular_velocity.dot(up)
	var strength := align_strength if grounded else align_strength * 0.4
	var acc := axis * strength - tilt_vel * align_damping
	apply_torque(acc * _tilt_inertia)


func _update_drift(delta: float) -> void:
	var speed := linear_velocity.length()
	var grounded := grounded_count >= 2
	if not is_drifting:
		if handbrake and absf(steer_input) > 0.2 and grounded and speed > drift_min_speed \
				and forward_speed > 0.0 and not is_destroyed:
			is_drifting = true
			drift_time = 0.0
			drift_started.emit()
	else:
		drift_time += delta * spec.drift_boost_mult
		if not handbrake or speed < drift_min_speed * 0.6 or is_destroyed or absf(slip_angle) > deg_to_rad(80.0):
			var clean := not is_destroyed and absf(slip_angle) < deg_to_rad(80.0) and speed >= drift_min_speed * 0.6
			_end_drift(clean)
	boost_time = maxf(boost_time - delta, 0.0)


func _end_drift(clean: bool) -> void:
	is_drifting = false
	var awarded := 0.0
	if clean and drift_time >= boost_min_drift_time:
		awarded = minf(drift_time * boost_per_drift_second, boost_max_time) * spec.boost_mult
		boost_time = maxf(boost_time, awarded)
	drift_ended.emit(drift_time, awarded)


## Invisible force field along both road edges. While charges remain it stops the
## jet leaving the road (bounce + shimmering hex flash); at 0 charges you fall.
func _edge_shield(delta: float) -> void:
	_shield_cooldown -= delta
	_shield_fx_cooldown -= delta
	var track := get_track()
	if track == null:
		return
	var info := track.lateral_info(global_position)
	var centre: Vector3 = info.centre
	if global_position.y < centre.y - 3.0:
		return  # Already below the road: too late.
	var lateral: float = info.lateral
	var right: Vector3 = info.right
	var half_w := minf(spec.wing_span * 0.65, 3.0) * 0.5
	var limit := track.width * 0.5 - half_w * 0.8
	var side := signf(lateral)

	if player_controlled:
		var near := clampf(1.0 - (limit - absf(lateral)) / shield_warn_distance, 0.0, 1.0)
		var edge_pt := centre + right * side * track.width * 0.5 + Vector3.UP * 1.5
		track.set_shield_focus(edge_pt if near > 0.0 else Vector3(0, -10000, 0), shield_color(), near * 0.6 if shield_charges > 0 else 0.0)

	if absf(lateral) <= limit:
		return
	# Wrecks are always caught (they respawn anyway) but never spend charges.
	if shield_charges <= 0 and not is_destroyed:
		return

	var inward := -right * side
	var v_out := linear_velocity.dot(-inward)
	if v_out > 0.0:
		linear_velocity += inward * v_out * (1.0 + shield_restitution)
	# Push back inside if we overlapped (no teleport: corrective velocity).
	var excess := absf(lateral) - limit
	linear_velocity += inward * minf(excess * 8.0, 6.0) * delta * 10.0
	linear_velocity *= 0.985  # A little scrape drag.

	var contact := centre + right * side * track.width * 0.5 + Vector3.UP * clampf(global_position.y - centre.y, 0.5, 4.0)
	var hard := v_out > shield_hit_speed
	if hard and _shield_cooldown <= 0.0 and not is_destroyed:
		shield_charges -= 1
		_shield_cooldown = shield_hit_cooldown
		shield_hit.emit(shield_charges)
		if shield_charges == 0:
			_sfx("shield_break", contact)
		else:
			_sfx("shield_hit", contact, 0.0, 1.0 + (max_shield_charges - shield_charges) * 0.07)
		track.shield_impact(contact, shield_color(), 1.0)
		_shield_fx_cooldown = 0.12
	elif _shield_fx_cooldown <= 0.0:
		track.shield_impact(contact, shield_color(), 0.45 if hard else 0.25)
		_sfx("shield_scrape", contact, 0.0, randf_range(0.85, 1.2))
		_shield_fx_cooldown = 0.12


## Player hears their own events up close (non-positional); rivals are positional.
func _sfx(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if player_controlled:
		Sound.play(sound, volume_db, pitch)
	else:
		Sound.play_at(sound, pos, volume_db, pitch)


func _check_fall(delta: float, grounded: bool) -> void:
	var track := get_track()
	if track == null:
		return
	if track.is_below_track(global_position):
		_fall_out()
		return
	if grounded:
		_air_time = 0.0
		_fall_time = 0.0
	else:
		_air_time += delta
		if _air_time > 0.3:
			var road_y := track.get_point(track.get_closest_offset(global_position)).y
			if global_position.y < road_y - 2.0:
				_fall_time += delta
				if _fall_time > fall_respawn_delay:
					_fall_out()
			else:
				_fall_time = 0.0
	# Stuck upside down on the road.
	if global_basis.y.y < 0.2 and linear_velocity.length() < 3.0 and not is_destroyed:
		_flip_time += delta
		if _flip_time > 2.0:
			_reset_requested = true
	else:
		_flip_time = 0.0


func _fall_out() -> void:
	_fall_time = 0.0
	_air_time = 0.0
	fell.emit()
	if player_controlled:
		Sound.play("fall")
	if is_destroyed:
		_respawn_timer = 0.0
	else:
		_reset_requested = true


func _do_reset() -> void:
	_reset_requested = false
	_flip_time = 0.0
	var track := get_track()
	if track:
		global_transform = track.get_respawn_transform(global_position)
		global_position += Vector3.UP * spec.hover_height
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	is_drifting = false
	boost_time = 0.0
	grip_factor = 1.0
	reset_physics_interpolation()
	if player_controlled:
		Sound.play("respawn")
	else:
		Sound.play_at("respawn", global_position)


## Race start result from the countdown: "perfect", "good", "stall" or "".
func apply_launch(result: String) -> void:
	match result:
		"perfect":
			start_boost(2.2)
			# Rings trail behind the jet (kept small so they never swallow the camera).
			Effects.ring_burst(get_parent(), global_transform * Vector3(0, 0, spec.length * 0.6), spec.accent, 3.0, 2, global_basis.z)
		"good":
			start_boost(1.0)
			Effects.ring_burst(get_parent(), global_transform * Vector3(0, 0, spec.length * 0.6), spec.color, 2.5, 1, global_basis.z)
		"stall":
			stall_time = 1.4


func _update_visuals(delta: float) -> void:
	if stall_time > 0.0:
		stall_time -= delta
		_glitch_t -= delta
		if _glitch_t <= 0.0:
			_glitch_t = randf_range(0.08, 0.25)
			var tail := global_transform * Vector3(0, 0.2, spec.length * 0.55)
			Effects.sparks(get_parent(), tail, Color(1.0, 0.35, 0.1), 6, 6.0, 0.4, Vector3.UP, 50.0, 4.0, 0.3)
			Effects.flash(get_parent(), tail, Color(1.0, 0.3, 0.1), 0.6, 0.12, 3.0)
	# Neon rings peel off the tail while boosting.
	if boost_time > 0.0 and not is_destroyed:
		_boost_ring_t -= delta
		if _boost_ring_t <= 0.0:
			_boost_ring_t = 0.12
			var tail := global_transform * Vector3(0, 0.1, spec.length * 0.6)
			Effects.shockwave(get_parent(), tail, spec.accent, 2.2, 0.35, global_basis.z, 0.08)
	# Invisible: flickering, glitching hologram.
	if is_invisible and _model:
		_glitch_t -= delta
		if _glitch_t <= 0.0:
			_glitch_t = randf_range(0.04, 0.12)
			_set_visual_transparency(randf_range(0.7, 0.95))
			_model.position.x = randf_range(-0.12, 0.12) if randf() < 0.3 else 0.0
	if _model == null:
		return
	_visual_steer = lerpf(_visual_steer, steer_input, 1.0 - exp(-6.0 * delta))
	_bob_t += delta
	var bank := _visual_steer * deg_to_rad(bank_angle_deg) * clampf(absf(forward_speed) / 20.0, 0.2, 1.0)
	if is_drifting:
		bank *= 1.4
	_model.rotation = Vector3(-throttle_input * 0.03 + brake_input * 0.05, 0.0, bank)
	_model.position.y = sin(_bob_t * 3.0) * hover_bob
	if _exhaust_mat:
		var heat := 0.35 + throttle_input * 0.65 + (0.8 if boost_time > 0.0 else 0.0)
		var c := spec.accent * (1.0 + heat * 2.0)
		_exhaust_mat.albedo_color = Color(c.r, c.g, c.b)
