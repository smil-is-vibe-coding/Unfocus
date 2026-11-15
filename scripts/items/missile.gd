class_name Missile
extends Node3D
## Homing missile. Steers toward its target (if still targetable), sweeps a ray
## each step for hits, explodes with splash damage and knock-up.

@export var speed := 85.0
@export var acceleration := 60.0
@export var turn_rate := 3.2           ## rad/s
@export var lifetime := 6.0
@export var max_distance := 150.0      ## Self-destructs after flying this far.
@export var homing_range := 90.0       ## Loses lock if the target gets farther than this.
@export var homing_cone_deg := 75.0    ## Loses lock if the target falls outside this cone (no U-turns).
@export var direct_damage := 40.0
@export var splash_damage := 20.0
@export var splash_radius := 7.0
@export var knock_up := 7.0            ## m/s of upward velocity given to the victim.

var shooter: HoverJet
var target: HoverJet
var velocity := Vector3.ZERO
var _age := 0.0
var _travelled := 0.0
var _trail_ribbon: LightTrail
var _color := PowerUp.color_of(PowerUp.Type.MISSILE)


func _ready() -> void:
	# Dark hull with a neon outline glow.
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0
	cyl.bottom_radius = 0.2
	cyl.height = 1.4
	cyl.radial_segments = 6
	var hull := ShaderMaterial.new()
	hull.shader = preload("res://shaders/jet_body.gdshader")
	hull.set_shader_parameter("glow_color", _color)
	hull.set_shader_parameter("rim_strength", 4.0)
	cyl.material = hull
	body.mesh = cyl
	body.rotation.x = -PI / 2.0  # Tip along -Z.
	add_child(body)

	# White-hot engine core inside a coloured glow.
	for layer in [[0.16, Color.WHITE, 6.0], [0.35, _color, 3.0], [0.7, _color, 0.8]]:
		var flame := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = layer[0]
		sphere.height = layer[0] * 2.0
		sphere.material = Effects.hdr_mat(layer[1], layer[2])
		flame.mesh = sphere
		flame.scale = Vector3(1, 1, 1.8)
		flame.position = Vector3(0, 0, 0.8)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flame)

	# Neon ribbon + glowing exhaust particles that hang in the air.
	var anchor := Node3D.new()
	anchor.position = Vector3(0, 0, 0.8)
	add_child(anchor)
	var ribbon := LightTrail.new()
	ribbon.source = anchor
	ribbon.color = _color
	ribbon.width = 0.5
	ribbon.intensity = 2.5
	ribbon.min_speed = 0.0
	ribbon.max_points = 50
	add_child(ribbon)
	_trail_ribbon = ribbon

	var smoke := GPUParticles3D.new()
	smoke.amount = 90
	smoke.lifetime = 0.9
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color = _color
	pm.hue_variation_min = -0.1
	pm.hue_variation_max = 0.1
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(0, 0, 0, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	smoke.process_material = pm
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	var pmat := Effects.hdr_mat(Color.WHITE, 2.0, true)
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = pmat
	smoke.draw_pass_1 = puff
	smoke.position = Vector3(0, 0, 0.9)
	add_child(smoke)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 4.0
	light.omni_range = 8.0
	add_child(light)

	Sound.attach_loop("missile_loop", self, 0.0, 10.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime or _travelled > max_distance:
		_explode(global_position, null)
		return

	var cur_speed := minf(velocity.length() + acceleration * delta, speed)
	var dir := velocity.normalized() if velocity.length() > 0.1 else -global_basis.z
	if target and is_instance_valid(target) and target.is_targetable():
		var aim := target.global_position + Vector3.UP * 0.3
		var to_target := aim - global_position
		var want := to_target.normalized()
		var angle := dir.angle_to(want)
		if to_target.length() > homing_range or angle > deg_to_rad(homing_cone_deg):
			target = null  # Lock broken: flies straight until it hits something or runs out.
		elif angle > 0.001:
			var axis := dir.cross(want)
			if axis.length() > 0.0001:
				dir = dir.rotated(axis.normalized(), minf(angle, turn_rate * delta))
	else:
		target = null
	velocity = dir * cur_speed

	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if shooter and is_instance_valid(shooter):
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		_explode(hit.position, hit.collider as HoverJet)
		return
	# Proximity fuse so near-misses at high closing speed still connect.
	if target and to.distance_to(target.global_position) < 2.2:
		_explode(to, target)
		return

	_travelled += from.distance_to(to)
	global_position = to
	if velocity.length() > 0.1:
		look_at(to + velocity, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


func _explode(pos: Vector3, direct: HoverJet) -> void:
	var attacker := shooter if shooter and is_instance_valid(shooter) else null
	for node in get_tree().get_nodes_in_group("cars"):
		var c := node as HoverJet
		if c == null or c == attacker:
			continue
		var d := c.global_position.distance_to(pos)
		if c == direct or d < splash_radius:
			var falloff := 1.0 if c == direct else clampf(1.0 - d / splash_radius, 0.0, 1.0)
			c.apply_damage(direct_damage if c == direct else splash_damage * falloff, attacker)
			var push := (c.global_position - pos)
			push.y = 0.0
			push = push.normalized() if push.length() > 0.01 else Vector3.ZERO
			var k := c.knockback_mult
			c.apply_central_impulse((Vector3.UP * knock_up + push * 4.0) * c.mass * maxf(falloff, 0.4) * k)
			c.apply_torque_impulse(Vector3(randf_range(-1, 1), 0.3, randf_range(-1, 1)) * c.mass * 3.0 * falloff * k)
	Effects.explosion(get_parent(), pos, _color, splash_radius, 0.6)
	Sound.play_at("explosion", pos, 0.0, randf_range(0.9, 1.1), 16.0)
	queue_free()
