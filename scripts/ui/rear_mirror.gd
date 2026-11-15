class_name RearMirror
extends Control
## Live rear-view mirror: a small second camera behind the player renders into
## a SubViewport, shown (mirrored) inside a rounded neon frame. Shares the main
## world, so rivals, effects and missiles all appear in it.

@export var render_size := Vector2i(330, 78)
@export var frame_color := NeonStyle.CYAN

var jet: HoverJet

var _viewport: SubViewport
var _cam: Camera3D
var _clip: Control
var _frame: Control
var _view: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.size = render_size
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 1500.0
	_cam.current = true
	_viewport.add_child(_cam)

	# Rounded mask: this control draws the shape, its children are clipped to it.
	_clip = Control.new()
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_clip.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(int(size.y * 0.45))
		_clip.draw_style_box(sb, Rect2(Vector2.ZERO, size)))
	add_child(_clip)

	var view := TextureRect.new()
	_view = view
	view.texture = _viewport.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.flip_h = true   # It's a mirror.
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(view)

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)


## Match the world's negative look (Negative level).
func set_inverted(on: bool, desaturate: float) -> void:
	if not on:
		_view.material = null
		return
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float desaturate = 0.8;
void fragment() {
	vec3 inv = vec3(1.0) - clamp(texture(TEXTURE, UV).rgb, 0.0, 1.0);
	float l = dot(inv, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(inv, vec3(l), desaturate), 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("desaturate", desaturate)
	_view.material = m


var _half_rate := false
var _frame_n := 0


func set_quality(q: int) -> void:
	_half_rate = q == 1
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if q == 0 else SubViewport.UPDATE_ALWAYS
	_viewport.size = render_size if q == 2 else Vector2i(render_size.x * 2 / 3, render_size.y * 2 / 3)


func _process(_delta: float) -> void:
	if _half_rate:
		_frame_n += 1
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if _frame_n % 2 == 0 else SubViewport.UPDATE_DISABLED
	if jet == null or not is_instance_valid(jet):
		return
	var t := jet.get_global_transform_interpolated()
	var fwd := -t.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Sit just above and ahead of the canopy, looking back over the tail.
	var eye := t.origin + Vector3.UP * 2.2 + fwd * 1.0
	_cam.global_position = eye
	_cam.look_at(eye - fwd * 30.0 + Vector3.DOWN * 3.0, Vector3.UP)
	_frame.queue_redraw()


func _draw_frame() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = frame_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(size.y * 0.45))
	sb.shadow_color = Color(frame_color, 0.45)
	sb.shadow_size = 4
	_frame.draw_style_box(sb, r)
	# Glass sheen + label.
	_frame.draw_line(Vector2(size.x * 0.2, 6), Vector2(size.x * 0.8, 6), Color(1, 1, 1, 0.12), 2.0, true)
