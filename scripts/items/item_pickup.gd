class_name ItemPickup
extends Area3D
## Hovering, spinning power-up. Any car that drives through it with an empty
## item slot gets the item. Respawns after a delay.

@export var type: int = PowerUp.Type.BOOST
@export var respawn_time := 6.0
@export var hover_height := 1.6
@export var bob_amount := 0.25
@export var spin_speed := 1.6

var _visual: Node3D
var _gem_mat: StandardMaterial3D
var _timer := 0.0
var _t := 0.0
var _active := true


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	shape.shape = sphere
	shape.position = Vector3.UP * hover_height
	add_child(shape)

	var color := PowerUp.color_of(type)
	_visual = Node3D.new()
	_visual.position = Vector3.UP * hover_height
	add_child(_visual)

	# Diamond-shaped gem: a cube stood on its corner.
	var gem := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.1
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = Color(color, 0.85)
	_gem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gem_mat.emission_enabled = true
	_gem_mat.emission = color
	_gem_mat.emission_energy_multiplier = 2.5
	_gem_mat.roughness = 0.1
	box.material = _gem_mat
	gem.mesh = box
	gem.rotation = Vector3(deg_to_rad(45), 0, deg_to_rad(35.26))
	gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(gem)

	# Glowing symbol card floating above the gem (always faces the camera).
	for layer in [[1.5, 3.2], [2.1, 0.6]]:
		var icon := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * layer[0]
		var m := Effects.hdr_mat(color, layer[1])
		m.albedo_texture = PowerUp.icon_texture(type)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		quad.material = m
		icon.mesh = quad
		icon.position = Vector3.UP * 1.45
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(icon)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 5.0
	_visual.add_child(light)


func _process(delta: float) -> void:
	_t += delta
	if not _active:
		_timer -= delta
		if _timer <= 0.0:
			_set_active(true)
		return
	_visual.rotation.y += spin_speed * delta
	_visual.position.y = hover_height + sin(_t * 2.5) * bob_amount


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	var car := body as HoverJet
	if car == null or car.items == null:
		return
	var taken := car.refill_shield() if type == PowerUp.Type.FORCEFIELD else car.items.give(type)
	if taken:
		Sound.pickup(type, _visual.global_position, car.player_controlled)
		Effects.ring_burst(get_parent(), _visual.global_position, PowerUp.color_of(type), 4.5, 2)
		Effects.flash(get_parent(), _visual.global_position, PowerUp.color_of(type), 2.0, 0.2)
		_set_active(false)


func _set_active(on: bool) -> void:
	_active = on
	_visual.visible = on
	_timer = respawn_time
	if on:
		# Catch a car that is parked inside the pickup when it reappears.
		for body in get_overlapping_bodies():
			_on_body_entered.call_deferred(body)
