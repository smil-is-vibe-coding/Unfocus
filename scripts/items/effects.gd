class_name Effects
extends RefCounted
## Neon VFX built from primitives + one-shot GPU particles. Colours are pushed
## above 1.0 (HDR) so the environment bloom makes them glow.


## Unshaded additive material. `energy` > 1 makes it bloom.
static func _detail() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	var game := tree.root.get_node_or_null("Game") if tree else null
	return game.detail_factor() if game else 1.0


static func hdr_mat(color: Color, energy := 3.0, vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = vertex_color
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	return m


## Kept for older callers: plain unshaded (non-bloom) material.
static func glow_material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := hdr_mat(color, 1.6)
	m.albedo_color.a = alpha
	return m


static func _fade_out(node: Node, mat: StandardMaterial3D, duration: float, free_node: Node = null) -> void:
	var tw := node.create_tween()
	tw.tween_property(mat, "albedo_color", Color(0, 0, 0, 0), duration).set_ease(Tween.EASE_IN)
	tw.tween_callback((free_node if free_node else node).queue_free)


static func _ok(parent: Node) -> bool:
	return parent != null and parent.is_inside_tree()


# --- Particles --------------------------------------------------------------------

## Burst of velocity-aligned neon streak sparks.
static func sparks(parent: Node, pos: Vector3, color: Color, count := 24, speed := 28.0, life := 0.55,
		dir := Vector3.UP, spread := 180.0, gravity := -14.0, length := 0.7) -> void:
	if not _ok(parent):
		return
	count = maxi(3, int(count * _detail()))
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.particle_flag_align_y = true
	pm.color = color
	pm.hue_variation_min = -0.06
	pm.hue_variation_max = 0.06
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(0, 0, 0, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	p.process_material = pm
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, length, 0.06)
	mesh.material = hdr_mat(Color.WHITE, 4.0, true)
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


## Expanding neon ring (shockwave). `normal` is the ring's axis.
static func shockwave(parent: Node, pos: Vector3, color: Color, radius := 6.0, duration := 0.45, normal := Vector3.UP, thickness := 0.12) -> void:
	if not _ok(parent):
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0 - thickness
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	var mat := hdr_mat(color, 4.0)
	torus.material = mat
	mi.mesh = torus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var up := normal.normalized()
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	mi.global_transform = Transform3D(Basis(x, up, z), pos)
	mi.scale = Vector3.ONE * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, radius * 0.6, radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color", Color(0, 0, 0, 0), duration).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Glowing sphere flash that swells and fades.
static func flash(parent: Node, pos: Vector3, color: Color, radius := 1.5, duration := 0.25, energy := 5.0) -> void:
	if not _ok(parent):
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	var mat := hdr_mat(color, energy)
	mat.cull_mode = BaseMaterial3D.CULL_BACK  # Invisible from inside: no full-screen flash.
	s.material = mat
	mi.mesh = s
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mat, "albedo_color", Color(0, 0, 0, 0), duration)
	tw.chain().tween_callback(mi.queue_free)


# --- Composite effects ------------------------------------------------------------

## Neon explosion: hot core, double shockwave, spark shower, light flash.
static func explosion(parent: Node, pos: Vector3, color: Color, radius: float, duration := 0.5) -> void:
	if not _ok(parent):
		return
	var hot := color.lerp(Color.WHITE, 0.35)
	var alt := Color.from_hsv(fposmod(color.h + 0.5, 1.0), 0.8, 1.0)
	flash(parent, pos, hot, radius * 0.7, duration * 0.7, 6.0)
	flash(parent, pos, color, radius, duration, 2.5)
	shockwave(parent, pos, color, radius * 1.6, duration * 1.1)
	if radius > 2.0:
		shockwave(parent, pos, alt, radius * 1.2, duration * 1.4, Vector3(0.3, 1, 0.5))
		sparks(parent, pos, color, int(clampf(radius * 10.0, 16, 90)), radius * 6.0, 0.7)
		sparks(parent, pos, alt, int(clampf(radius * 5.0, 8, 45)), radius * 4.0, 0.9, Vector3.UP, 60.0, -18.0)
	else:
		sparks(parent, pos, color, 10, 14.0, 0.3)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 10.0
	light.omni_range = radius * 5.0
	parent.add_child(light)
	light.global_position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, duration * 1.2)
	tw.tween_callback(light.queue_free)


## Neon bolt: white-hot core inside a coloured glow, fades fast.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color, width := 0.08, duration := 0.07) -> void:
	if not _ok(parent):
		return
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_transform = beam_transform(from, to)
	var mats: Array[StandardMaterial3D] = []
	for layer in [[width * 0.45, Color.WHITE, 5.0], [width * 1.6, color, 3.0], [width * 4.0, color, 0.8]]:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(layer[0], layer[0], length)
		var m := hdr_mat(layer[1], layer[2])
		box.material = m
		mi.mesh = box
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mats.append(m)
	var tw := root.create_tween().set_parallel(true)
	for m in mats:
		tw.tween_property(m, "albedo_color", Color(0, 0, 0, 0), duration * 1.6)
	tw.chain().tween_callback(root.queue_free)


static func muzzle_flash(parent: Node, pos: Vector3, dir: Vector3, color: Color) -> void:
	flash(parent, pos, color.lerp(Color.WHITE, 0.4), 0.45, 0.06, 6.0)
	sparks(parent, pos, color, 5, 18.0, 0.15, dir, 18.0, 0.0, 0.4)


## Ring burst used for pickups, repair, boost, shield refill.
static func ring_burst(parent: Node, pos: Vector3, color: Color, radius := 4.0, rings := 2, axis := Vector3.UP) -> void:
	for i in rings:
		shockwave(parent, pos + axis * i * 0.6, color, radius * (1.0 + i * 0.35), 0.4 + i * 0.12, axis)
	sparks(parent, pos, color, 18, 12.0, 0.6, axis, 70.0, -4.0)


## Transform for a unit-length box (along Z) stretched between two points.
static func beam_transform(from: Vector3, to: Vector3) -> Transform3D:
	var dir := to - from
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var b := Basis.looking_at(dir, up)
	return Transform3D(b, (from + to) * 0.5)
