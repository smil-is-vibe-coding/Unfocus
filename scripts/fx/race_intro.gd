class_name RaceIntro
extends Node3D
## Asphalt-style pre-race cinematic with its own camera:
##   flyover A  - high orbit revealing the whole floating circuit
##   flyover B  - fast swoop down the road toward the starting grid
##   "3" / "2"  - dramatic shots of rival jets on the grid
##   "1"        - hero shot of the player's jet
##   GO         - swoop into the chase camera, then hand over control

signal flyover_finished

@export var orbit_time := 2.6
@export var swoop_time := 2.6

var track: RaceTrack
var jets: Array[HoverJet] = []
var player: HoverJet
var chase_cam: Camera3D

var cam: Camera3D
var _shot := ""
var _t := 0.0
var _subject: HoverJet
var _handoff_from := Transform3D()
var _handoff_fov := 60.0
var _handoff_time := 0.35
var _orbit_a0 := 0.0
var _done := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.fov = 55.0
	add_child(cam)


func start() -> void:
	cam.current = true
	var start_pos := track.get_point(0.0) - track.bounds_center
	_orbit_a0 = atan2(start_pos.z, start_pos.x) + PI * 0.75
	_set_shot("orbit")


func skip_flyover() -> void:
	if _shot == "orbit" or _shot == "swoop":
		_set_shot("hold")
		flyover_finished.emit()


## Called by the race manager on each countdown number.
func show_count(n: int) -> void:
	var rivals := jets.filter(func(j): return j != player)
	match n:
		3:
			_subject = rivals[mini(1, rivals.size() - 1)] if not rivals.is_empty() else player
			_set_shot("rival_orbit")
		2:
			_subject = rivals[mini(3, rivals.size() - 1)] if not rivals.is_empty() else player
			_set_shot("rival_track")
		1:
			_subject = player
			_set_shot("hero")


## Begin swooping into the chase camera (call ~0.35 s before GO).
func begin_handoff(duration := 0.35) -> void:
	_handoff_from = cam.global_transform
	_handoff_fov = cam.fov
	_handoff_time = duration
	_set_shot("handoff")


func finish() -> void:
	if _done:
		return
	_done = true
	chase_cam.current = true
	queue_free()


func _set_shot(s: String) -> void:
	_shot = s
	_t = 0.0


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	match _shot:
		"orbit":
			_orbit()
			if _t >= orbit_time:
				_set_shot("swoop")
		"swoop":
			_swoop()
			if _t >= swoop_time:
				_set_shot("hold")
				flyover_finished.emit()
		"hold":
			pass
		"rival_orbit":
			_rival_orbit()
		"rival_track":
			_rival_track()
		"hero":
			_hero()
		"handoff":
			_handoff()


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _orbit() -> void:
	var k := _ease(clampf(_t / orbit_time, 0.0, 1.0))
	var c := track.bounds_center
	var r := track.bounds_radius * 1.15
	var a := _orbit_a0 + k * deg_to_rad(80.0)
	var h := lerpf(230.0, 150.0, k)
	cam.fov = 55.0
	cam.global_position = c + Vector3(cos(a) * r, h, sin(a) * r)
	cam.look_at(c + Vector3(0, -20, 0), Vector3.UP)


func _swoop() -> void:
	var k := _ease(clampf(_t / swoop_time, 0.0, 1.0))
	var off := lerpf(-340.0, -70.0, k)
	var side := lerpf(-14.0, -4.0, k)
	var h := lerpf(40.0, 5.0, k)
	var tr := track.get_transform_at(off, side)
	cam.fov = lerpf(60.0, 75.0, k)
	cam.global_position = tr.origin + Vector3.UP * h
	var look := track.get_point(off + 60.0 + k * 10.0) + Vector3.UP * 2.0
	cam.look_at(look, Vector3.UP)


func _basis_of(j: HoverJet) -> Basis:
	return j.get_global_transform_interpolated().basis


func _rival_orbit() -> void:
	if not is_instance_valid(_subject):
		return
	var b := _basis_of(_subject)
	var p := _subject.global_position
	var a := lerpf(-0.6, 0.15, _t)          # Slow arc around the nose.
	var dir := (-b.z * cos(a) + b.x * sin(a)).normalized()
	cam.fov = 50.0
	cam.global_position = p + dir * 6.5 + Vector3.UP * 0.5
	cam.look_at(p + Vector3.UP * 0.4, Vector3.UP)


func _rival_track() -> void:
	if not is_instance_valid(_subject):
		return
	var b := _basis_of(_subject)
	var p := _subject.global_position
	var slide := lerpf(-4.0, 3.0, _t)       # Dolly along the side.
	cam.fov = 45.0
	cam.global_position = p + b.x * 5.5 + (-b.z) * slide + Vector3.UP * 1.3
	cam.look_at(p + (-b.z) * 0.8, Vector3.UP)


func _hero() -> void:
	if not is_instance_valid(_subject):
		return
	var b := _basis_of(_subject)
	var p := _subject.global_position
	var k := clampf(_t, 0.0, 1.0)
	cam.fov = lerpf(42.0, 50.0, k)
	cam.global_position = p + (-b.z) * lerpf(8.0, 6.0, k) + b.x * -2.0 + Vector3.UP * lerpf(0.4, 1.6, k)
	cam.look_at(p + Vector3.UP * 0.5, Vector3.UP)


func _handoff() -> void:
	var k := _ease(clampf(_t / _handoff_time, 0.0, 1.0))
	var target := chase_cam.global_transform
	var q := _handoff_from.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), k)
	# Arc up and around the jet instead of flying through it.
	var arc := Vector3.UP * sin(k * PI) * 4.0 + target.basis.x * sin(k * PI) * 5.0
	cam.global_transform = Transform3D(Basis(q), _handoff_from.origin.lerp(target.origin, k) + arc)
	cam.fov = lerpf(_handoff_fov, chase_cam.fov, k)
