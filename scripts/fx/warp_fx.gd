class_name WarpFX
extends Node3D
## "Light speed" boost effect for the player's camera (GTA SA nitro meets the
## Interstellar wormhole): neon light streaks rushing past the camera, plus a
## screen-space radial blur / chromatic warp overlay and an FOV punch.
## Add as a child of the Camera3D and set `jet`.

@export var streak_count := 260
@export var streak_speed := 260.0
@export var tunnel_radius := 7.0

var jet: HoverJet
var intensity := 0.0

var _streaks: GPUParticles3D
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _layer: CanvasLayer


func _ready() -> void:
	_build_streaks()
	_build_overlay()


func _build_streaks() -> void:
	_streaks = GPUParticles3D.new()
	_streaks.amount = streak_count
	_streaks.lifetime = 0.45
	_streaks.local_coords = true          # Ride with the camera.
	_streaks.emitting = false
	_streaks.visibility_aabb = AABB(Vector3(-30, -30, -150), Vector3(60, 60, 180))
	_streaks.position = Vector3(0, 0, -110)  # Spawn far ahead, fly back past us.
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = tunnel_radius
	pm.emission_ring_inner_radius = tunnel_radius * 0.35
	pm.emission_ring_height = 20.0
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 0.0
	pm.initial_velocity_min = streak_speed * 0.8
	pm.initial_velocity_max = streak_speed * 1.2
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color = Color(0.3, 0.9, 1.0)
	pm.hue_variation_min = -0.35
	pm.hue_variation_max = 0.35
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.add_point(0.25, Color.WHITE)
	grad.set_color(grad.get_point_count() - 1, Color.WHITE)
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	_streaks.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 9.0, 0.05)   # Y is stretched along the velocity.
	mesh.material = Effects.hdr_mat(Color.WHITE, 3.5, true)
	_streaks.draw_pass_1 = mesh
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streaks)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = -1  # Under the HUD.
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = preload("res://shaders/warp_screen.gdshader")
	_overlay.material = _overlay_mat
	_overlay.visible = false
	_layer.add_child(_overlay)


func _process(delta: float) -> void:
	if jet == null or not is_instance_valid(jet):
		return
	var boosting := jet.boost_time > 0.0 and not jet.is_destroyed
	var target := 1.0 if boosting else 0.0
	intensity = move_toward(intensity, target, delta * (3.5 if boosting else 1.8))

	_streaks.emitting = intensity > 0.05
	_streaks.amount_ratio = clampf(intensity, 0.05, 1.0)
	_overlay.visible = intensity > 0.01
	if _overlay.visible:
		_overlay_mat.set_shader_parameter("intensity", intensity)
		_overlay_mat.set_shader_parameter("tint_a", jet.spec.color)
		_overlay_mat.set_shader_parameter("tint_b", jet.spec.accent)
