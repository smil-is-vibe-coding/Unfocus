class_name TouchControls
extends CanvasLayer
## On-screen controls for phones/tablets (browser or native).
##   Left half: floating joystick (steer).
##   Right side: THRUST (big), BRAKE, DRIFT, FIRE ▲ (forward), FIRE ▼ (back).
##   Small: ◀ ▶ ability select, LOOK BACK, PAUSE.
## Every button injects the same InputEventActions the keyboard produces, so the
## game logic (pause menu, launch timing, abilities...) needs no special cases.
## Hidden until a touchscreen is detected or the first touch arrives.

## Fired once when touch controls switch on (touchscreen found / first touch).
signal activated

var player: HoverJet

var _root: Control
var _buttons: Array[Dictionary] = []   # {id, action, center, radius, label, color, touch}
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _steer := 0.0
var _rotate_hint: Label
var _active := false


func _ready() -> void:
	name = "TouchControls"
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_controls)
	add_child(_root)
	_rotate_hint = NeonStyle.label("ROTATE TO LANDSCAPE", 28, NeonStyle.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_rotate_hint.set_anchors_preset(Control.PRESET_CENTER)
	_rotate_hint.offset_left = -300
	_rotate_hint.offset_right = 300
	_rotate_hint.visible = false
	add_child(_rotate_hint)
	_set_active(DisplayServer.is_touchscreen_available())
	get_viewport().size_changed.connect(_layout)
	_layout()


func _set_active(on: bool) -> void:
	var was := _active
	_active = on
	_root.visible = on
	set_process(on)
	if on and not was:
		activated.emit.call_deferred()


func is_active() -> bool:
	return _active


func _layout() -> void:
	var vs := _root.get_viewport_rect().size
	var w := vs.x
	var h := vs.y
	var r := h * 0.075
	_buttons = [
		_b("thrust", "accelerate", Vector2(w - r * 1.6, h * 0.62), r * 1.3, "THRUST", NeonStyle.GREEN),
		_b("brake", "brake", Vector2(w - r * 4.2, h * 0.67), r * 0.95, "BRAKE", NeonStyle.RED),
		_b("drift", "handbrake", Vector2(w - r * 4.2, h * 0.47), r * 0.85, "DRIFT", NeonStyle.AMBER),
		_b("fire", "use_item", Vector2(w - r * 1.6, h * 0.37), r * 0.95, "▲", NeonStyle.CYAN),
		_b("back", "use_item_back", Vector2(w - r * 4.2, h * 0.34), r * 0.75, "▼", NeonStyle.MAGENTA),
		_b("prev", "item_prev", Vector2(w * 0.5 - r * 3.4, h - r * 1.0), r * 0.55, "◀", NeonStyle.CYAN),
		_b("next", "item_next", Vector2(w * 0.5 + r * 3.4, h - r * 1.0), r * 0.55, "▶", NeonStyle.CYAN),
		_b("look", "look_back", Vector2(w * 0.5 + r * 3.6, r * 0.9), r * 0.5, "◎", Color(0.8, 0.85, 1.0)),
		_b("pause", "ui_cancel", Vector2(w * 0.5 - r * 3.6, r * 0.9), r * 0.5, "II", Color(0.8, 0.85, 1.0)),
	]
	_stick_origin = Vector2(r * 2.4 + 20.0, h * 0.66)
	_stick_pos = _stick_origin
	_rotate_hint.visible = _active and h > w
	_root.queue_redraw()


func _b(id: String, action: String, center: Vector2, radius: float, label: String, color: Color) -> Dictionary:
	return {"id": id, "action": action, "center": center, "radius": radius, "label": label, "color": color, "touch": -1}


# --- Input ----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not _active:
			_set_active(true)
			_layout()
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
		_root.queue_redraw()
	elif event is InputEventScreenDrag and _active:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			_stick_move(d.position)
			_root.queue_redraw()


func _touch_down(index: int, pos: Vector2) -> void:
	for b in _buttons:
		if pos.distance_to(b.center) <= b.radius * 1.15:
			b.touch = index
			_send(b.action, true)
			get_viewport().set_input_as_handled()
			return
	# Left half (below the top HUD strip) = joystick, floating under the thumb.
	var vs := _root.get_viewport_rect().size
	if pos.x < vs.x * 0.45 and pos.y > vs.y * 0.3 and _stick_touch == -1:
		_stick_touch = index
		_stick_origin = pos
		_stick_move(pos)
		get_viewport().set_input_as_handled()


func _touch_up(index: int) -> void:
	for b in _buttons:
		if b.touch == index:
			b.touch = -1
			_send(b.action, false)
	if index == _stick_touch:
		_stick_touch = -1
		_set_steer(0.0)
		var h := _root.get_viewport_rect().size.y
		_stick_origin = Vector2(h * 0.075 * 2.4 + 20.0, h * 0.66)
		_stick_pos = _stick_origin


func _stick_move(pos: Vector2) -> void:
	var max_r := _root.get_viewport_rect().size.y * 0.11
	var off := (pos - _stick_origin).limit_length(max_r)
	_stick_pos = _stick_origin + off
	var x := off.x / max_r
	# Small dead-zone, then a gentle curve for fine control.
	var s := 0.0 if absf(x) < 0.08 else signf(x) * pow((absf(x) - 0.08) / 0.92, 1.3)
	_set_steer(-s)  # Left = positive steer in the jet code.


func _set_steer(v: float) -> void:
	if is_equal_approx(v, _steer):
		return
	_steer = v
	_send_strength("steer_left", maxf(v, 0.0))
	_send_strength("steer_right", maxf(-v, 0.0))


func _send(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _send_strength(action: String, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = strength > 0.0
	ev.strength = strength
	Input.parse_input_event(ev)


# --- Drawing --------------------------------------------------------------------

func _process(_delta: float) -> void:
	_root.queue_redraw()


func _draw_controls() -> void:
	# Joystick.
	var h := _root.get_viewport_rect().size.y
	var base_r := h * 0.11
	var held := _stick_touch != -1
	_root.draw_circle(_stick_origin, base_r, Color(0, 0, 0.05, 0.28 if held else 0.18))
	_root.draw_arc(_stick_origin, base_r, 0.0, TAU, 48, Color(NeonStyle.CYAN, 0.55 if held else 0.3), 2.0, true)
	_root.draw_circle(_stick_pos, base_r * 0.42, Color(NeonStyle.CYAN, 0.45 if held else 0.22))
	NeonStyle.text(_root, _stick_origin + Vector2(-60, base_r + 22), "STEER", 13, Color(NeonStyle.CYAN, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 120)

	for b in _buttons:
		var on: bool = b.touch != -1
		var c: Color = b.color
		_root.draw_circle(b.center, b.radius, Color(c.r * 0.2, c.g * 0.2, c.b * 0.2, 0.55 if on else 0.3))
		_root.draw_arc(b.center, b.radius, 0.0, TAU, 48, Color(c, 0.95 if on else 0.55), 3.0 if on else 2.0, true)
		if b.id == "fire" and player and is_instance_valid(player) and player.items.held != PowerUp.Type.NONE:
			var tex := PowerUp.icon_texture(player.items.held)
			var s: float = b.radius * 1.0
			_root.draw_texture_rect(tex, Rect2(b.center - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, PowerUp.color_of(player.items.held))
		else:
			var fs := int(clampf(b.radius * 0.42, 11.0, 26.0))
			NeonStyle.text(_root, b.center + Vector2(-b.radius, fs * 0.35), b.label, fs, c, HORIZONTAL_ALIGNMENT_CENTER, b.radius * 2.0)
