extends Node3D
## Scatters slowly tumbling neon hologram shapes and a ringed planet around the
## track so the void has depth. Purely visual (no collision).

@export var shape_count := 80
@export var min_track_clearance := 70.0
@export var spread := 900.0
@export var height_range := Vector2(-250.0, 220.0)
@export var decor_seed := 1337
var planet_a := Color(0.6, 0.2, 1.0)
var planet_b := Color(0.0, 0.9, 1.0)

var _glow := preload("res://shaders/neon_glow.gdshader")
var _spinners: Array[Node3D] = []
var _spin_axes: Array[Vector3] = []
var _spin_speeds: PackedFloat32Array = []

var palette: Array = [
	# Overridden per level.

	Color(0.0, 1.0, 1.0), Color(1.0, 0.1, 0.85), Color(0.55, 0.2, 1.0),
	Color(0.1, 1.0, 0.5), Color(1.0, 0.55, 0.1), Color(0.2, 0.5, 1.0),
]


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game:
		shape_count = int(shape_count * game.detail_factor())
	var rng := RandomNumberGenerator.new()
	rng.seed = decor_seed
	var track := get_tree().get_first_node_in_group("track") as RaceTrack
	var centre := track.bounds_center if track else Vector3.ZERO
	var track_pts: PackedVector3Array = []
	if track:
		var baked := track.curve.get_baked_points()
		for i in range(0, baked.size(), 8):
			track_pts.append(track.to_global(baked[i]))

	var mat := ShaderMaterial.new()
	mat.shader = _glow
	var meshes := _make_meshes()

	var placed := 0
	var attempts := 0
	while placed < shape_count and attempts < shape_count * 20:
		attempts += 1
		var pos := centre + Vector3(rng.randf_range(-spread, spread), rng.randf_range(height_range.x, height_range.y), rng.randf_range(-spread, spread))
		if _near_track(pos, track_pts, min_track_clearance):
			continue
		var mi := MeshInstance3D.new()
		var pick := rng.randi() % meshes.size()
		mi.mesh = meshes[pick]
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dist := pos.distance_to(centre)
		mi.scale = Vector3.ONE * rng.randf_range(4.0, 14.0) * (1.0 + dist / 600.0)
		mi.position = pos
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		add_child(mi)
		mi.set_instance_shader_parameter("tint", palette[rng.randi() % palette.size()])
		mi.set_instance_shader_parameter("wire", 1.0 if pick == 0 else 0.0)
		mi.set_instance_shader_parameter("pulse_phase", rng.randf())
		if rng.randf() < 0.25:
			mi.set_instance_shader_parameter("hue_cycle", rng.randf_range(0.5, 2.0))
		_spinners.append(mi)
		_spin_axes.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		_spin_speeds.append(rng.randf_range(0.05, 0.4))
		placed += 1

	_build_planet(centre + Vector3(-900, 320, -1300), 280.0, planet_a, mat)
	_build_planet(centre + Vector3(1400, -500, 700), 160.0, planet_b, mat)


func _process(delta: float) -> void:
	for i in _spinners.size():
		_spinners[i].rotate(_spin_axes[i], _spin_speeds[i] * delta)


func _near_track(pos: Vector3, pts: PackedVector3Array, clearance: float) -> bool:
	for p in pts:
		if p.distance_squared_to(pos) < clearance * clearance:
			return true
	return false


func _make_meshes() -> Array[Mesh]:
	var result: Array[Mesh] = []
	var box := BoxMesh.new()                 # index 0 = wireframe cube
	result.append(box)
	var ico := SphereMesh.new()              # low-poly orb
	ico.radial_segments = 8
	ico.rings = 4
	ico.radius = 0.6
	ico.height = 1.2
	result.append(ico)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.8
	result.append(torus)
	var cone := CylinderMesh.new()           # pyramid-ish
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.radial_segments = 4
	cone.rings = 1
	result.append(cone)
	var orb := SphereMesh.new()
	orb.radius = 0.5
	orb.height = 1.0
	result.append(orb)
	return result


func _build_planet(pos: Vector3, radius: float, color: Color, mat: Material) -> void:
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	planet.mesh = sphere
	planet.material_override = mat
	planet.position = pos
	add_child(planet)
	planet.set_instance_shader_parameter("tint", color)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 1.4
	torus.outer_radius = radius * 2.1
	torus.rings = 96
	ring.mesh = torus
	ring.material_override = mat
	ring.position = pos
	ring.scale = Vector3(1, 0.015, 1)
	ring.rotation = Vector3(deg_to_rad(18), 0, deg_to_rad(-12))
	add_child(ring)
	ring.set_instance_shader_parameter("tint", color.lerp(Color(1, 0.4, 0.8), 0.5))
	ring.set_instance_shader_parameter("hue_cycle", 0.3)
	_spinners.append(ring)
	_spin_axes.append(Vector3.UP)
	_spin_speeds.append(0.02)
