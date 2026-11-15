class_name VenomHook
extends Node3D
## Venom-style hookshot: four writhing neon tendrils lash out from the jet's
## nose, wingtips and belly, latch onto the target, pull taut like a rubber
## band, then SNAP - flinging the target backwards and slingshotting the owner
## forward - and whip back in. Misses lash forward and recoil.

signal finished

enum Phase { SHOOT, STRETCH, RETRACT }

@export var shoot_time := 0.22
@export var stretch_time := 0.5
@export var retract_time := 0.32
@export var miss_reach := 45.0
@export var target_kick := 22.0     ## m/s the target is flung back at the snap
@export var owner_kick := 16.0      ## m/s the owner is slung forward
@export var stretch_pull := 9.0     ## m/s^2 tension while stretching
@export var snap_damage := 12.0

var owner_jet: HoverJet
var target: HoverJet
var color := Color(0.2, 1.0, 0.6)
## Fired out of the tail at a rival behind.
var backward := false

var _phase := Phase.SHOOT
var _t := 0.0
var _imesh := ImmediateMesh.new()
var _outer: StandardMaterial3D
var _core: StandardMaterial3D
var _strands: Array = []   # per strand: {anchor: Vector3 local, grab: Vector3 local, side: float, arch: float, phase: float}
var _miss_tips: Array = []
var _snapped := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var mi := MeshInstance3D.new()
	mi.mesh = _imesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	_outer = Effects.hdr_mat(color, 1.5)
	_core = Effects.hdr_mat(color.lerp(Color.WHITE, 0.45), 2.6)

	var s := owner_jet.spec
	var anchors := [
		Vector3(0, 0.15, -s.length * 0.5),
		Vector3(-s.wing_span * 0.45, 0.05, s.wing_z + 0.3),
		Vector3(s.wing_span * 0.45, 0.05, s.wing_z + 0.3),
		Vector3(0, -0.35, -s.length * 0.15),
	]
	if backward:
		anchors = [
			Vector3(0, 0.2, s.length * 0.5),
			Vector3(-s.wing_span * 0.45, 0.05, s.wing_z + 0.8),
			Vector3(s.wing_span * 0.45, 0.05, s.wing_z + 0.8),
			Vector3(0, -0.35, s.length * 0.3),
		]
	var grabs := [Vector3(0, 0.45, -0.8), Vector3(-0.9, 0.1, 0.2), Vector3(0.9, 0.1, 0.2), Vector3(0, -0.2, 1.0)]
	for i in anchors.size():
		_strands.append({
			"anchor": anchors[i], "grab": grabs[i],
			"side": [-1.0, -1.0, 1.0, 1.0][i] * randf_range(1.5, 3.0),
			"arch": randf_range(0.8, 2.0),
			"phase": randf() * TAU,
		})
	if target == null:
		var fwd := owner_jet.global_basis.z if backward else -owner_jet.global_basis.z
		for st in _strands:
			var spread := owner_jet.global_basis.x * randf_range(-6, 6) + Vector3.UP * randf_range(0, 4)
			_miss_tips.append(owner_jet.global_position + fwd * miss_reach + spread)


func _physics_process(delta: float) -> void:
	_t += delta
	if owner_jet == null or not is_instance_valid(owner_jet) or owner_jet.is_destroyed:
		_finish()
		return
	if target and (not is_instance_valid(target) or target.is_destroyed) and _phase != Phase.RETRACT:
		target = null
		_enter(Phase.RETRACT)

	match _phase:
		Phase.SHOOT:
			if _t >= shoot_time:
				if target:
					_latch()
					_enter(Phase.STRETCH)
				else:
					_enter(Phase.RETRACT)
		Phase.STRETCH:
			# Rubber band loading: both ends lean in as tension builds.
			var dir := _dir()
			var k := clampf(_t / stretch_time, 0.0, 1.0)
			target.apply_central_force(-dir * stretch_pull * k * target.mass)
			if not backward:
				# Firing backward never tugs on you.
				owner_jet.apply_central_force(dir * stretch_pull * k * owner_jet.mass)
			target.grip_factor = minf(target.grip_factor, 0.6)
			if _t >= stretch_time:
				_snap()
				_enter(Phase.RETRACT)
		Phase.RETRACT:
			if _t >= retract_time:
				_finish()


func _process(_delta: float) -> void:
	if owner_jet == null or not is_instance_valid(owner_jet):
		return
	_draw_strands()


func _enter(p: Phase) -> void:
	_phase = p
	_t = 0.0


func _dir() -> Vector3:
	var d := target.global_position - owner_jet.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else -owner_jet.global_basis.z


func _latch() -> void:
	Sound.play_at("hook_attach", target.global_position, 2.0, 1.0, 16.0)
	Effects.flash(owner_jet.get_parent(), target.global_position, color, 2.2, 0.2)
	Effects.sparks(owner_jet.get_parent(), target.global_position, color, 20, 12.0, 0.4)


func _snap() -> void:
	if _snapped or target == null:
		return
	_snapped = true
	var dir := _dir()
	var world := owner_jet.get_parent()
	var fwd := -owner_jet.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if backward:
		_reel_in(fwd, world)
		return
	# Forward: rubber band release - rival flung back, you slung forward.
	target.apply_central_impulse(-fwd * target_kick * target.mass * target.knockback_mult)
	target.apply_torque_impulse(Vector3.UP * randf_range(-1, 1) * target.mass * 6.0)
	target.grip_factor = 0.3
	target.apply_damage(snap_damage, owner_jet)
	owner_jet.apply_central_impulse(fwd * owner_kick * owner_jet.mass)
	owner_jet.start_boost(0.8)
	owner_jet._sfx("hook_snap", owner_jet.global_position)
	Effects.explosion(world, target.global_position, color, 3.0, 0.4)
	Effects.shockwave(world, target.global_position, Color.WHITE, 6.0, 0.35, dir)
	Effects.ring_burst(world, owner_jet.global_position, color, 4.0, 2, -dir)


## Backward hook: yank the rival behind you up to your level (alongside you).
## Your own jet is untouched - no boost, no kick.
func _reel_in(fwd: Vector3, world: Node) -> void:
	var gap := (owner_jet.global_position - target.global_position).dot(fwd)
	var catch_up := clampf(gap * 1.7, 0.0, 45.0)
	var v := owner_jet.linear_velocity
	target.linear_velocity = Vector3(v.x, target.linear_velocity.y, v.z) + fwd * catch_up
	target.grip_factor = 0.5
	target.apply_damage(snap_damage * 0.5, owner_jet)
	owner_jet._sfx("hook_snap", owner_jet.global_position, -3.0, 1.2)
	Effects.explosion(world, target.global_position, color, 2.4, 0.35)
	Effects.shockwave(world, target.global_position, Color.WHITE, 4.0, 0.3, fwd)


func _finish() -> void:
	set_physics_process(false)
	set_process(false)
	finished.emit()
	queue_free()


## How far along the tendrils reach (0..1) and how much they writhe.
func _reach_and_wiggle() -> Vector2:
	match _phase:
		Phase.SHOOT:
			var e := clampf(_t / shoot_time, 0.0, 1.0)
			return Vector2(1.0 - pow(1.0 - e, 3.0), 1.4)
		Phase.STRETCH:
			var k := clampf(_t / stretch_time, 0.0, 1.0)
			return Vector2(1.0, lerpf(0.9, 0.08, k))   # Pulls taut.
		_:
			var e := clampf(_t / retract_time, 0.0, 1.0)
			return Vector2(1.0 - e * e, 1.8 * (1.0 - e))  # Whips back.


func _draw_strands() -> void:
	_imesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var rw := _reach_and_wiggle()
	var reach := rw.x
	if reach <= 0.01:
		return
	var tension := clampf(_t / stretch_time, 0.0, 1.0) if _phase == Phase.STRETCH else 0.0
	var time := Time.get_ticks_msec() / 1000.0
	var ot := owner_jet.get_global_transform_interpolated()
	for i in _strands.size():
		var st: Dictionary = _strands[i]
		var p0 := ot * (st.anchor as Vector3)
		var p2: Vector3
		if target and is_instance_valid(target):
			p2 = target.get_global_transform_interpolated() * (st.grab as Vector3)
		elif i < _miss_tips.size():
			p2 = _miss_tips[i]
		else:
			p2 = p0 + (ot.basis.z if backward else -ot.basis.z) * miss_reach
		var mid := (p0 + p2) * 0.5
		var slack := 1.0 - tension
		var p1: Vector3 = mid + ot.basis.x * (st.side as float) * slack + Vector3.UP * (st.arch as float) * (0.4 + slack)
		var pts: Array[Vector3] = []
		var n := 28
		for k in n + 1:
			var s := reach * float(k) / n
			var p := _bezier(p0, p1, p2, s)
			# Writhing: travelling sine wave, fixed at both ends.
			var env := sin(PI * s / maxf(reach, 0.001))
			var wob := sin(s * 16.0 + time * 18.0 + (st.phase as float)) * rw.y * 0.7 * env
			var wob2 := cos(s * 11.0 - time * 13.0 + (st.phase as float)) * rw.y * 0.45 * env
			p += ot.basis.x * wob + ot.basis.y * wob2
			pts.append(p)
		var pulse := 1.0 + tension * 0.6 * (0.5 + 0.5 * sin(time * 40.0))
		_ribbon(pts, cam.global_position, 0.2 * pulse, _outer)
		_ribbon(pts, cam.global_position, 0.06 * pulse, _core)


func _ribbon(pts: Array[Vector3], cam_pos: Vector3, width: float, mat: Material) -> void:
	if pts.size() < 2:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for k in pts.size():
		var p := pts[k]
		var tan := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := tan.cross(cam_pos - p).normalized()
		# Thick at the jet, tapering to a barbed tip.
		var f := float(k) / (pts.size() - 1)
		var w := width * (1.0 - 0.65 * f) * 0.5
		_imesh.surface_add_vertex(p + side * w)
		_imesh.surface_add_vertex(p - side * w)
	_imesh.surface_end()


static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)
