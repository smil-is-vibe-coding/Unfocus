extends Camera3D
## Smooth third-person chase camera. Lags behind the car's heading so drift
## angle is visible, pulls back and widens FOV with speed.

@export var target: Node3D
@export var distance := 6.0
@export var height := 2.1
@export var look_height := 0.9
@export var speed_pull_back := 0.04        ## Extra distance per m/s.
@export var yaw_smoothing := 4.5
@export_range(0.0, 1.0) var velocity_follow := 0.35  ## Blend heading toward travel direction.
@export var base_fov := 70.0
@export var max_fov := 92.0
@export var fov_full_speed := 60.0
@export var boost_fov_bonus := 18.0
@export var boost_shake := 0.07

var _yaw := 0.0
var looking_back := false
var _dist := 0.0


func _ready() -> void:
	top_level = true
	doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dist = distance
	if target:
		_yaw = target.global_rotation.y


## Jump straight behind the target (e.g. after spawning on the grid).
func snap_to_target() -> void:
	if target == null:
		return
	_yaw = target.global_rotation.y
	_process(0.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var t := target.get_global_transform_interpolated()
	var heading := -t.basis.z
	heading.y = 0.0

	var speed := 0.0
	var boosting := false
	if target is RigidBody3D:
		var v: Vector3 = (target as RigidBody3D).linear_velocity
		speed = v.length()
		var flat := Vector3(v.x, 0.0, v.z)
		if flat.length() > 5.0 and flat.dot(heading) > 0.0:
			heading = heading.normalized().lerp(flat.normalized(), velocity_follow)
	if target is HoverJet:
		boosting = (target as HoverJet).boost_time > 0.0

	if heading.length() > 0.01:
		var target_yaw := atan2(-heading.x, -heading.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-yaw_smoothing * delta))

	_dist = lerpf(_dist, distance + speed * speed_pull_back, 1.0 - exp(-3.0 * delta))
	# Hold "look_back" (C): swing round in front of the jet and look behind it.
	looking_back = target is HoverJet and (target as HoverJet).player_controlled \
		and Input.is_action_pressed("look_back")
	var yaw := _yaw + (PI if looking_back else 0.0)
	var back := Vector3(sin(yaw), 0.0, cos(yaw))
	var d := _dist * (0.85 if looking_back else 1.0)
	global_position = t.origin + back * d + Vector3.UP * (height + (0.4 if looking_back else 0.0))
	look_at(t.origin + Vector3.UP * look_height, Vector3.UP)
	if boosting and boost_shake > 0.0:
		# Light-speed rumble.
		var tt := Time.get_ticks_msec() / 1000.0
		h_offset = sin(tt * 47.0) * boost_shake
		v_offset = sin(tt * 61.0 + 1.3) * boost_shake
	else:
		h_offset = lerpf(h_offset, 0.0, 0.2)
		v_offset = lerpf(v_offset, 0.0, 0.2)

	var target_fov := lerpf(base_fov, max_fov, clampf(speed / fov_full_speed, 0.0, 1.0))
	if boosting:
		target_fov += boost_fov_bonus
	fov = lerpf(fov, target_fov, 1.0 - exp(-(7.0 if boosting else 3.0) * delta))
