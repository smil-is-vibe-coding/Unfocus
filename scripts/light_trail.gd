class_name LightTrail
extends MeshInstance3D
## Fading neon ribbon left behind a moving point (e.g. a car's tail light).
## Lies flat (width along the source's right axis) so the chase cam sees it.

@export var max_points := 36
@export var sample_distance := 1.2   ## Metres travelled between stored points.
@export var width := 0.22
@export var color := Color(0, 1, 1)
@export var min_speed := 8.0         ## Fades out below this speed (m/s).

var source: Node3D

var _points: Array[Vector3] = []
var _rights: Array[Vector3] = []
@export var intensity := 1.3         ## HDR multiplier so the bloom picks it up.

const TRAIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float intensity = 1.3;
void fragment() {
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = COLOR.a;
}
"""

static var _shader: Shader

var _imesh := ImmediateMesh.new()
var _mat := ShaderMaterial.new()
var _alpha := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game and game.quality == 0:
		set_process(false)
		visible = false
		return
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = TRAIL_SHADER
	_mat.shader = _shader
	_mat.set_shader_parameter("intensity", intensity)
	material_override = _mat
	extra_cull_margin = 16384.0


func clear() -> void:
	_points.clear()
	_rights.clear()


func _process(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var t := source.get_global_transform_interpolated()
	var pos := t.origin
	if not _points.is_empty() and pos.distance_to(_last_pos) > 25.0:
		clear()  # Teleported (respawn): don't draw a streak across the map.

	var speed := 0.0
	var body := source.get_parent() as RigidBody3D
	if body:
		speed = body.linear_velocity.length()
	elif delta > 0.0 and not _points.is_empty():
		speed = pos.distance_to(_last_pos) / delta
	var target_alpha := 1.0 if min_speed <= 0.0 else clampf((speed - min_speed) / 15.0, 0.0, 1.0)
	_alpha = move_toward(_alpha, target_alpha, delta * 3.0)

	if _points.is_empty() or pos.distance_to(_points[0]) > sample_distance:
		_points.push_front(pos)
		_rights.push_front(t.basis.x)
		if _points.size() > max_points:
			_points.pop_back()
			_rights.pop_back()
	_last_pos = pos

	_imesh.clear_surfaces()
	if _points.size() < 2 or _alpha <= 0.01:
		return
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _points.size()
	for i in n:
		# Head of the ribbon tracks the live position.
		var p := pos if i == 0 else _points[i]
		var f := 1.0 - float(i) / float(n - 1)
		var c := Color(color, f * f * _alpha)
		var half := _rights[i] * width * 0.5 * (0.4 + 0.6 * f)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(p - half)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(p + half)
	_imesh.surface_end()
