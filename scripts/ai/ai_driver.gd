class_name AIDriver
extends Node
## Simple racing AI: follows the track centre line with a lane offset, brakes
## for corners, unsticks itself, and uses items when it makes sense.
## Add as a child of an HoverJet (sets player_controlled = false).

@export_range(0.5, 1.0) var skill := 0.9      ## Fraction of the car's top speed it will use.
@export var lane_offset := 0.0                ## Preferred lateral offset from centre (m).
@export var lookahead_base := 10.0
@export var lookahead_per_speed := 0.55
@export var min_corner_speed := 20.0
@export var item_reaction := Vector2(0.4, 1.6) ## Random delay range before using a new item.

## Training dummies turn this off so they don't fire back.
var use_items := true
var car: HoverJet
var track: RaceTrack

var _stuck_time := 0.0
var _reverse_time := 0.0
var _unstick_tries := 0
var _item_delay := 0.0
var _last_item := PowerUp.Type.NONE
var _lane_wander := 0.0


func _ready() -> void:
	car = get_parent() as HoverJet
	car.player_controlled = false
	_lane_wander = randf() * TAU


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if track == null:
		track = car.get_track()
		if track == null:
			return
	if car.is_destroyed:
		return
	if car.race_locked:
		# On the grid: blip the throttle so the engines rev.
		car.throttle_input = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * (4.0 + skill * 3.0))
		car.steer_input = 0.0
		car.brake_input = 0.0
		_stuck_time = 0.0
		return
	_drive(delta)
	if use_items:
		_handle_items(delta)


func _drive(delta: float) -> void:
	var pos := car.global_position
	var speed := car.linear_velocity.length()
	var off := track.get_closest_offset(pos)

	_lane_wander += delta * 0.3
	# Without shield charges a wide line means falling: stay tighter to the centre.
	var lane_max := track.width * (0.25 if car.shield_charges > 0 else 0.12)
	var lane := clampf(lane_offset + sin(_lane_wander) * 2.0, -lane_max, lane_max)
	# No walls: if drifting toward an edge, aim back at the centre.
	var here := track.get_transform_at(off)
	var lateral := (pos - here.origin).dot(here.basis.x)
	if absf(lateral) > track.width * 0.28:
		lane = 0.0
	var look := lookahead_base + speed * lookahead_per_speed
	var target := track.get_transform_at(off + look, lane).origin

	var local := car.global_transform.affine_inverse() * target
	var angle := atan2(-local.x, -local.z)  # + = target is to the left
	var steer := clampf(angle * 2.5, -1.0, 1.0)

	# Corner speed: the fastest this jet can take the tightest bend ahead
	# (v = sqrt(a_lat / curvature)), brought back to now via braking distance.
	var lat_acc := car.spec.max_lateral_accel * 0.75
	var target_speed := car.top_speed * skill
	var span := 20.0
	var d := 6.0
	while d < 20.0 + speed * 2.0:
		var curv := absf(track.heading_change(off + d, off + d + span)) / span
		if curv > 0.0005:
			var v_corner := sqrt(lat_acc / curv)
			var v_now := sqrt(v_corner * v_corner + 2.0 * 16.0 * maxf(d - 6.0, 0.0))
			target_speed = minf(target_speed, maxf(v_now, min_corner_speed))
		d += 10.0

	var throttle := 1.0
	var brake := 0.0
	if speed > target_speed + 4.0:
		throttle = 0.0
		brake = clampf((speed - target_speed) / 12.0, 0.2, 1.0)
	elif speed > target_speed:
		throttle = 0.3

	# Stuck against a wall / another car: back out, then reset if that fails.
	if _reverse_time > 0.0:
		_reverse_time -= delta
		throttle = 0.0
		brake = 1.0
		steer = -steer
		if _reverse_time <= 0.0:
			_stuck_time = 0.0
	elif car.forward_speed < 2.0 and throttle > 0.5 and car.stall_time <= 0.0:
		_stuck_time += delta
		if _stuck_time > 1.5:
			_stuck_time = 0.0
			_unstick_tries += 1
			if _unstick_tries >= 3:
				# Backing out didn't work: put it back on the racing line.
				car.reset_car()
				_unstick_tries = 0
			else:
				_reverse_time = 1.0
	else:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
		if car.forward_speed > 15.0:
			_unstick_tries = 0

	car.throttle_input = throttle
	car.brake_input = brake
	car.steer_input = steer
	car.handbrake = false


func _handle_items(delta: float) -> void:
	var items := car.items
	if items == null or items.count() == 0:
		_last_item = PowerUp.Type.NONE
		return
	# React a beat after getting something new.
	var newest: int = items.slots.reduce(func(acc, t): return acc + t, 0)
	if newest != _last_item:
		_last_item = newest
		_item_delay = randf_range(item_reaction.x, item_reaction.y)
	_item_delay -= delta
	if _item_delay > 0.0:
		return

	# Check every slot; fire the first one that makes sense right now.
	for i in items.SLOT_COUNT:
		var t: int = items.slots[i]
		if t == PowerUp.Type.NONE:
			continue
		var use := false
		var back := false
		match t:
			PowerUp.Type.BOOST:
				use = absf(car.steer_input) < 0.25
			PowerUp.Type.REPAIR:
				use = car.health < car.max_health * 0.7
			PowerUp.Type.INVISIBILITY:
				use = true
			PowerUp.Type.MACHINE_GUN:
				use = CarItems.find_target(car, items.gun_range * 0.8, items.gun_aim_cone_deg) != null
				if not use:
					back = CarItems.find_target(car, items.gun_range * 0.6, items.gun_aim_cone_deg, true) != null
					use = back
			PowerUp.Type.HOOKSHOT:
				use = CarItems.find_target(car, items.hook_range, items.hook_cone_deg) != null
				if not use:
					back = CarItems.find_target(car, items.hook_range * 0.7, items.hook_cone_deg, true) != null
					use = back
			PowerUp.Type.MISSILE:
				use = CarItems.find_target(car, items.missile_lock_range, items.missile_lock_cone_deg) != null
				if not use:
					back = CarItems.find_target(car, items.missile_lock_range * 0.7, items.missile_lock_cone_deg, true) != null
					use = back
		if use:
			items.selected = i
			items.use(back)
			_item_delay = randf_range(item_reaction.x, item_reaction.y) * 0.5
			return
