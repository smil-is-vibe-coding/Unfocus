class_name LevelTheme
extends RefCounted
## Applies a LevelDef's vibe to a race scene. Call from the scene root's
## _enter_tree() so the track and scenery build with the new values.


static func apply(level: LevelDef, scene: Node) -> void:
	var track := scene.get_node_or_null("Track") as RaceTrack
	if track:
		track.width = level.width
		track.control_points = level.points
		track.hue_offset = level.hue_offset
		track.hue_range = level.hue_range
		track.hue_scale = level.hue_scale
		track.gate_colors = level.gate_colors

	var decor := scene.get_node_or_null("Decor")
	if decor:
		decor.palette = level.decor_palette
		decor.planet_a = level.planet_a
		decor.planet_b = level.planet_b

	var light := scene.get_node_or_null("KeyLight") as DirectionalLight3D
	if light:
		light.light_color = level.key_light

	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		# Private copy so other scenes keep the default look.
		var env := we.environment.duplicate(true) as Environment
		env.ambient_light_color = level.ambient
		env.fog_light_color = level.fog
		env.fog_density = level.fog_density
		if level.invert:
			env.glow_intensity = 0.45   # Halos turn into dark smudges when inverted; keep them subtle.
		var sky_mat := env.sky.sky_material as ShaderMaterial if env.sky else null
		if sky_mat:
			sky_mat.set_shader_parameter("aurora_low", level.aurora_low)
			sky_mat.set_shader_parameter("aurora_mid", level.aurora_mid)
			sky_mat.set_shader_parameter("aurora_high", level.aurora_high)
			sky_mat.set_shader_parameter("under_low", level.under_low)
			sky_mat.set_shader_parameter("under_high", level.under_high)
			sky_mat.set_shader_parameter("nebula_a", level.nebula_a)
			sky_mat.set_shader_parameter("nebula_b", level.nebula_b)
			sky_mat.set_shader_parameter("aurora_strength", level.aurora_strength)
			sky_mat.set_shader_parameter("nebula_strength", level.nebula_strength)
		we.environment = env

	if level.invert:
		var layer := CanvasLayer.new()
		layer.name = "NegativePost"
		layer.layer = -3   # Under the warp overlay and the HUD.
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/negative_screen.gdshader")
		mat.set_shader_parameter("desaturate", level.desaturate)
		rect.material = mat
		layer.add_child(rect)
		scene.add_child.call_deferred(layer)
