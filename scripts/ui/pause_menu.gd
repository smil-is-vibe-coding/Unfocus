class_name PauseMenu
extends CanvasLayer
## Esc pauses. Same layout as the other menus: options on the left, the
## controls reference on the right, key prompts along the bottom.

const CONTROLS := [
	["W / S", "Thrust / brake"],
	["A / D", "Steer"],
	["SPACE", "Airbrake (drift)"],
	["← / →", "Select ability slot"],
	["↑", "Use ability / fire forward"],
	["↓", "Fire backward (gun, missile, hook)"],
	["C", "Look back"],
	["R", "Reset onto the track"],
	["ESC", "Pause"],
	["F11", "Fullscreen"],   # Key text comes from Game.fullscreen_key().
]

var _root: Control
var _first: Button
var _open := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var title := NeonStyle.label("PAUSED", 56, NeonStyle.MAGENTA)
	title.position = Vector2(80, 50)
	_root.add_child(title)
	_root.add_child(NeonStyle.footer("↑ ↓  MOVE        ENTER  SELECT        ESC  RESUME"))

	var box := VBoxContainer.new()
	box.position = Vector2(80, 180)
	box.add_theme_constant_override("separation", 8)
	_root.add_child(box)
	_first = _add(box, "RESUME", NeonStyle.CYAN, close)
	_add(box, "RESTART", NeonStyle.CYAN, func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_add(box, "CHANGE JET", NeonStyle.CYAN, func() -> void: Game.goto(Game.HANGAR))
	_add(box, "FULLSCREEN", NeonStyle.CYAN, Game.toggle_fullscreen)
	_add(box, "MAIN MENU", NeonStyle.MAGENTA, func() -> void: Game.goto(Game.MAIN_MENU))

	var panel := NeonStyle.panel(NeonStyle.CYAN)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -520
	panel.offset_right = -60
	panel.offset_top = 180
	panel.offset_bottom = -80
	_root.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.add_child(NeonStyle.label("CONTROLS", 24, NeonStyle.CYAN))
	v.add_child(grid)
	panel.add_child(v)
	for row in CONTROLS:
		var key: String = Game.fullscreen_key() if row[1] == "Fullscreen" else row[0]
		grid.add_child(NeonStyle.label(key, 17, Color.WHITE))
		grid.add_child(NeonStyle.label(row[1], 17, Color(0.75, 0.82, 1.0)))


func _add(box: Container, text: String, color: Color, action: Callable) -> Button:
	var b := NeonStyle.button(text, color, Vector2(340, 54), 22)
	b.pressed.connect(action)
	box.add_child(b)
	return b


func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_root.visible = true
	_set_hud(false)
	get_tree().paused = true
	_first.grab_focus.call_deferred()


func close() -> void:
	_open = false
	_root.visible = false
	_set_hud(true)
	get_tree().paused = false


## Hide the race HUD behind the menu so nothing overlaps.
func _set_hud(on: bool) -> void:
	for n in ["HUD", "TrainingPanel", "TouchControls"]:
		var c := get_parent().get_node_or_null(n) as CanvasLayer
		if c:
			c.visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _open:
			close()
		else:
			open()
