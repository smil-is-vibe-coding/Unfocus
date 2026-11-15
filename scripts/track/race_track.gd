@tool
class_name RaceTrack
extends Node3D
## Procedural closed-loop circuit floating in space.
##
## `control_points` are (x, height, z), driven in order. The road is a thin
## floating slab with neon barriers, auto-banked through corners. Offset 0 along
## the curve is the start/finish line. The default layout is a figure-8 whose
## second half crosses over the first on an 18 m high overpass.

@export var control_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, 0, 120),       # start / finish
	Vector3(0, 0, 0),         # under the overpass
	Vector3(0, 3, -110),
	Vector3(35, 8, -200),     # long right-hand climb
	Vector3(130, 16, -245),
	Vector3(225, 24, -205),
	Vector3(255, 30, -110),
	Vector3(205, 34, -35),    # summit
	Vector3(110, 24, 0),
	Vector3(0, 18, 0),        # overpass
	Vector3(-110, 14, 0),
	Vector3(-210, 8, 40),     # left sweeper down
	Vector3(-245, 4, 140),
	Vector3(-195, 2, 230),    # hairpin exit
	Vector3(-100, 14, 265),   # jump crest
	Vector3(-30, 4, 270),
	Vector3(15, 0, 215),
]):
	set(v):
		control_points = v
		_rebuild_if_ready()
@export var width := 24.0:
	set(v):
		width = v
		_rebuild_if_ready()
## Off by default: jets fall if they leave the road. On = solid walls.
@export var solid_barriers := false:
	set(v):
		solid_barriers = v
		_rebuild_if_ready()
@export var wall_height := 1.4
@export var curb_height := 0.35            ## Visual-only edge glow when barriers are off.
@export var slab_thickness := 1.2
@export var sample_spacing := 2.0
@export_range(0.0, 25.0) var max_bank_deg := 11.0
@export var bank_per_curvature := 450.0   ## degrees of bank per (rad/m) of curvature
@export var kill_depth := 40.0

@export_group("Theme")
@export var hue_offset := 0.0
@export_range(0.0, 1.0) var hue_range := 1.0
@export var hue_scale := 900.0
@export var gate_colors: Array[Color] = [Color(0.0, 0.85, 1.0), Color(0.75, 0.3, 1.0), Color(1.0, 0.2, 0.75)]            ## Cars this far below the lowest road point respawn.

@export_group("Gates")
@export var gate_spacing := 150.0
@export var gate_lights := true

@export_group("Pickups")
@export var spawn_pickups := true
@export var pickup_row_spacing := 170.0
@export var pickup_row_start := 90.0
@export var pickup_lanes := PackedFloat32Array([-6.5, 0.0, 6.5])

var curve := Curve3D.new()
var length := 0.0
var kill_y := -100.0
var bounds_center := Vector3.ZERO
var bounds_radius := 300.0

var _road_shader := preload("res://shaders/road.gdshader")
var _barrier_shader := preload("res://shaders/barrier.gdshader")
var _under_shader := preload("res://shaders/road_underside.gdshader")
var _glow_shader := preload("res://shaders/neon_glow.gdshader")
var _built: Array[Node] = []

@export_group("Force Field")
@export var shield_height := 5.0
const MAX_IMPACTS := 16
var _field_mat: ShaderMaterial
var _impacts := PackedVector4Array()
var _impact_colors := PackedVector4Array()
var _impact_next := 0
var _now := 0.0
var _field_shader := preload("res://shaders/force_field.gdshader")


func _ready() -> void:
	add_to_group("track")
	_rebuild()


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for n in _built:
		if is_instance_valid(n):
			n.queue_free()
	_built.clear()
	_build_curve()
	_build_geometry()
	_build_gates()
	if spawn_pickups and not Engine.is_editor_hint():
		_spawn_pickups()


# --- Queries (AI, respawn, spawning) ---------------------------------------------

func wrap_offset(offset: float) -> float:
	return fposmod(offset, length)


func get_closest_offset(world_pos: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_pos))


func get_point(offset: float) -> Vector3:
	return to_global(curve.sample_baked(wrap_offset(offset), true))


## Horizontal race direction at an offset.
func get_direction(offset: float) -> Vector3:
	var a := get_point(offset - 1.5)
	var b := get_point(offset + 1.5)
	var d := b - a
	d.y = 0.0
	return d.normalized()


## Transform on the track centre (optionally shifted sideways), facing the race direction.
func get_transform_at(offset: float, lateral := 0.0, height := 0.0) -> Transform3D:
	var dir := get_direction(offset)
	var b := Basis.looking_at(dir, Vector3.UP)
	return Transform3D(b, get_point(offset) + b.x * lateral + Vector3.UP * height)


func get_respawn_transform(near: Vector3) -> Transform3D:
	var off := get_closest_offset(near)
	var t := get_transform_at(off)
	# Keep roughly the same lane, clamped inside the barriers.
	var lateral := clampf((near - t.origin).dot(t.basis.x), -width * 0.15, width * 0.15)
	return get_transform_at(off, lateral, 1.2)


## Starting grid: rows of two behind the start line.
func get_grid_transforms(count: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for i in count:
		var row := i / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		result.append(get_transform_at(-12.0 - row * 10.0 - (i % 2) * 4.0, side * width * 0.22, 1.0))
	return result


## Heading change (radians, + = left) between two offsets.
func heading_change(from_offset: float, to_offset: float) -> float:
	var a := get_direction(from_offset)
	var b := get_direction(to_offset)
	return a.signed_angle_to(b, Vector3.UP)


## Lights up the edge force field around `pos` (called by jets on impact).
func shield_impact(pos: Vector3, color: Color, strength := 1.0) -> void:
	if _field_mat == null:
		return
	_impacts[_impact_next] = Vector4(pos.x, pos.y, pos.z, _now)
	_impact_colors[_impact_next] = Vector4(color.r, color.g, color.b, strength)
	_impact_next = (_impact_next + 1) % MAX_IMPACTS
	_push_impacts()


## Faint warning glow on the field near `pos` (the player), 0..1 strength.
func set_shield_focus(pos: Vector3, color: Color, strength: float) -> void:
	if _field_mat:
		_field_mat.set_shader_parameter("focus_pos", pos)
		_field_mat.set_shader_parameter("focus_color", color)
		_field_mat.set_shader_parameter("focus_strength", strength)


## Signed distance from the track centre line (+ = right of the race direction)
## and the horizontal right vector there.
func lateral_info(world_pos: Vector3) -> Dictionary:
	var off := get_closest_offset(world_pos)
	var centre := get_point(off)
	var right := get_direction(off).cross(Vector3.UP).normalized()
	return {"offset": off, "centre": centre, "right": right, "lateral": (world_pos - centre).dot(right)}


func _push_impacts() -> void:
	_field_mat.set_shader_parameter("impacts", _impacts)
	_field_mat.set_shader_parameter("impact_colors", _impact_colors)


func _process(delta: float) -> void:
	_now += delta
	if _field_mat:
		_field_mat.set_shader_parameter("now", _now)


func is_below_track(world_pos: Vector3) -> bool:
	return world_pos.y < kill_y


# --- Building ---------------------------------------------------------------------

func _build_curve() -> void:
	curve = Curve3D.new()
	curve.bake_interval = sample_spacing
	var n := control_points.size()
	if n < 3:
		return
	# Catmull-Rom -> Bezier handles for a smooth closed loop.
	for i in n + 1:
		var p := control_points[i % n]
		var prev := control_points[(i - 1 + n) % n]
		var next := control_points[(i + 1) % n]
		var handle := (next - prev) / 6.0
		curve.add_point(p, -handle, handle)
	length = curve.get_baked_length()


func _build_geometry() -> void:
	var baked := curve.get_baked_points()
	if baked.size() < 8:
		return
	var count := baked.size() - 1  # Last baked point duplicates the first.
	var hw := width * 0.5

	# Frames (tangent / right / normal) with smoothed banking.
	var tangents: Array[Vector3] = []
	var flat_right: Array[Vector3] = []
	var raw_bank := PackedFloat32Array()
	raw_bank.resize(count)
	var min_y := INF
	var centre := Vector3.ZERO
	for i in count:
		var t := (baked[(i + 1) % count] - baked[(i - 1 + count) % count]).normalized()
		tangents.append(t)
		flat_right.append(t.cross(Vector3.UP).normalized())
		min_y = minf(min_y, baked[i].y)
		centre += baked[i]
	centre /= count
	var k := 6
	for i in count:
		var a := tangents[(i - k + count) % count]
		var b := tangents[(i + k) % count]
		a.y = 0.0
		b.y = 0.0
		var turn := a.signed_angle_to(b, Vector3.UP)
		var curvature := turn / (2.0 * k * sample_spacing)
		raw_bank[i] = clampf(curvature * bank_per_curvature, -max_bank_deg, max_bank_deg)
	var bank := PackedFloat32Array()
	bank.resize(count)
	var smooth := 10
	for i in count:
		var s := 0.0
		for j in range(-smooth, smooth + 1):
			s += raw_bank[(i + j + count) % count]
		bank[i] = s / float(2 * smooth + 1)

	kill_y = to_global(Vector3(0, min_y, 0)).y - kill_depth
	bounds_center = to_global(centre)
	bounds_radius = 0.0
	for i in range(0, count, 10):
		bounds_radius = maxf(bounds_radius, Vector2(baked[i].x - centre.x, baked[i].z - centre.z).length())

	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var under := SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)
	var field := SurfaceTool.new()
	field.begin(Mesh.PRIMITIVE_TRIANGLES)

	var dist := 0.0
	for i in count + 1:
		var idx := i % count
		var p := baked[idx]
		if i > 0:
			dist += p.distance_to(baked[(i - 1) % count])
		var t := tangents[idx]
		# Left turn (+bank) lifts the right (outer) edge.
		var right := flat_right[idx].rotated(t, -deg_to_rad(bank[idx]))
		var n := right.cross(t).normalized()

		var l := p - right * hw
		var r := p + right * hw
		var lb := l - n * slab_thickness
		var rb := r - n * slab_thickness

		road.set_uv(Vector2(0, dist)); road.add_vertex(l)
		road.set_uv(Vector2(1, dist)); road.add_vertex(r)

		var up := n * (wall_height if solid_barriers else curb_height)
		var v := dist / 4.0
		walls.set_uv(Vector2(v, 0)); walls.add_vertex(l)
		walls.set_uv(Vector2(v, 1)); walls.add_vertex(l + up)
		walls.set_uv(Vector2(v, 0)); walls.add_vertex(r)
		walls.set_uv(Vector2(v, 1)); walls.add_vertex(r + up)

		# Slab: left side, right side, bottom.
		under.set_uv(Vector2(dist, 0)); under.add_vertex(l)
		under.set_uv(Vector2(dist, 1)); under.add_vertex(lb)
		under.set_uv(Vector2(dist, 0)); under.add_vertex(r)
		under.set_uv(Vector2(dist, 1)); under.add_vertex(rb)
		under.set_uv(Vector2(dist, 0.5)); under.add_vertex(lb)
		under.set_uv(Vector2(dist, 0.5)); under.add_vertex(rb)

		# Force-field walls: from just below the road up to shield_height.
		var fh := n * shield_height
		field.set_uv(Vector2(dist, 0.0)); field.add_vertex(l)
		field.set_uv(Vector2(dist, shield_height)); field.add_vertex(l + fh)
		field.set_uv(Vector2(dist, 0.0)); field.add_vertex(r)
		field.set_uv(Vector2(dist, shield_height)); field.add_vertex(r + fh)

	_strip_indices(road, count, 2, [0])
	_strip_indices(walls, count, 4, [0, 2])
	_strip_indices(under, count, 6, [0, 2, 4])
	_strip_indices(field, count, 4, [0, 2])

	road.generate_normals()
	walls.generate_normals()
	under.generate_normals()

	var road_mat := ShaderMaterial.new()
	road_mat.shader = _road_shader
	road_mat.set_shader_parameter("track_length", length)
	_theme(road_mat)
	_add_mesh(road.commit(), road_mat, "Road", true, 3)  # layers 1 + 2 (hover rays)

	var wall_mat := ShaderMaterial.new()
	wall_mat.shader = _barrier_shader
	_theme(wall_mat)
	_add_mesh(walls.commit(), wall_mat, "Barriers", solid_barriers, 1)

	var under_mat := ShaderMaterial.new()
	under_mat.shader = _under_shader
	_theme(under_mat)
	_add_mesh(under.commit(), under_mat, "Underside", false, 0)

	_field_mat = ShaderMaterial.new()
	_field_mat.shader = _field_shader
	_field_mat.set_shader_parameter("wall_height", shield_height)
	_impacts.resize(MAX_IMPACTS)
	_impact_colors.resize(MAX_IMPACTS)
	for i in MAX_IMPACTS:
		_impacts[i] = Vector4(0, 0, 0, -1)
		_impact_colors[i] = Vector4.ZERO
	_push_impacts()
	_add_mesh(field.commit(), _field_mat, "ForceField", false, 0)


## Connects vertex pairs between consecutive rings of `ring_size` vertices.
func _strip_indices(st: SurfaceTool, rings: int, ring_size: int, pairs: Array) -> void:
	for i in rings:
		var a := i * ring_size
		var b := (i + 1) * ring_size
		for p: int in pairs:
			st.add_index(a + p); st.add_index(b + p); st.add_index(a + p + 1)
			st.add_index(a + p + 1); st.add_index(b + p); st.add_index(b + p + 1)


func _add_mesh(mesh: ArrayMesh, mat: Material, node_name: String, collide: bool, layers: int) -> void:
	var body: Node3D = StaticBody3D.new() if collide else Node3D.new()
	if collide:
		(body as StaticBody3D).collision_layer = layers
	body.name = node_name
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	if collide:
		var shape := CollisionShape3D.new()
		var trimesh := mesh.create_trimesh_shape()
		trimesh.backface_collision = true
		shape.shape = trimesh
		body.add_child(shape)
	add_child(body)
	_built.append(body)


func _build_gates() -> void:
	if gate_spacing <= 0.0 or length <= 0.0:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader
	mat.set_shader_parameter("rim_power", 1.2)
	mat.set_shader_parameter("rim_strength", 4.0)
	var torus := TorusMesh.new()
	torus.inner_radius = width * 0.62
	torus.outer_radius = width * 0.62 + 0.9
	torus.rings = 48
	torus.ring_segments = 8

	var gate_count := int(length / gate_spacing)
	for i in gate_count:
		var off := i * length / gate_count
		var t := get_transform_at(off, 0.0, 3.0)
		var gate := MeshInstance3D.new()
		gate.name = "Gate%d" % i
		gate.mesh = torus
		gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Torus axis is Y: tip it so the ring faces along the track.
		gate.transform = Transform3D(t.basis * Basis(Vector3.RIGHT, PI / 2.0), t.origin)
		gate.material_override = NeonGlow.mat(_gate_color(i), 0.0, 0.0, 0.0, 1.2, 4.0)
		add_child(gate)
		_built.append(gate)
		var game := get_node_or_null("/root/Game") if not Engine.is_editor_hint() else null
		if gate_lights and not (game and game.quality == 0):
			var light := OmniLight3D.new()
			light.light_color = PowerUp.color_of(i % PowerUp.COUNT) if not Engine.is_editor_hint() else Color(0.5, 0.8, 1)
			light.light_energy = 2.5
			light.omni_range = 28.0
			light.position = t.origin + t.basis.y * 9.0
			add_child(light)
			_built.append(light)


func _gate_color(i: int) -> Color:
	return gate_colors[i % gate_colors.size()] if not gate_colors.is_empty() else Color.CYAN


func _theme(m: ShaderMaterial) -> void:
	m.set_shader_parameter("hue_offset", hue_offset)
	m.set_shader_parameter("hue_range", hue_range)
	m.set_shader_parameter("hue_scale", hue_scale)


func _spawn_pickups() -> void:
	var row := 0
	var off := pickup_row_start
	while off < length - 40.0:
		for lane in pickup_lanes.size():
			var p := ItemPickup.new()
			p.type = (row * pickup_lanes.size() + lane) % PowerUp.COUNT
			add_child(p)
			p.global_transform = get_transform_at(off, pickup_lanes[lane])
			_built.append(p)
		row += 1
		off += pickup_row_spacing
