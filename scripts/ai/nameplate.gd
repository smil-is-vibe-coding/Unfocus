class_name Nameplate
extends Label3D
## Floating name + health + held item above a car. Hidden while it is invisible.

var car: HoverJet
var _icon: Sprite3D
var _icon_type := -2


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Constant on-screen size so it never fills the view up close.
	fixed_size = true
	pixel_size = 0.0007
	font_size = 26
	outline_size = 8
	position = Vector3.UP * 1.8
	top_level = false
	# Held item as a small glowing symbol next to the name.
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.fixed_size = true
	_icon.pixel_size = 0.00028
	_icon.position = Vector3(0, 0.0, 0)
	_icon.offset = Vector2(0, 230)
	_icon.no_depth_test = false
	add_child(_icon)


func _process(_delta: float) -> void:
	if car == null:
		return
	visible = not car.is_invisible
	if car.is_destroyed:
		text = "%s\nWRECKED" % car.driver_name
		modulate = Color(1, 0.3, 0.2)
		_icon.visible = false
		return
	# Only label rivals near enough to matter: keeps the screen calm.
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(car.global_position) > 90.0:
		visible = false
		return
	var held: int = car.items.held if car.items else PowerUp.Type.NONE
	if held != _icon_type:
		_icon_type = held
		_icon.texture = PowerUp.icon_texture(held)
		_icon.modulate = PowerUp.color_of(held)
	_icon.visible = held != PowerUp.Type.NONE
	text = car.driver_name
	# Name tints from green (healthy) to red (nearly wrecked).
	modulate = Color(1, 0.35, 0.3).lerp(Color(0.75, 1, 0.8), car.health / car.max_health)
