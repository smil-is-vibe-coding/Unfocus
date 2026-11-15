extends CanvasLayer
## Neon race HUD: position/lap/timer, minimap, analog speedometer, hull + shield,
## hex item slot, countdown, event feed and the results board.

@export var car: HoverJet:
	set(v):
		car = v
		if car and is_node_ready():
			_connect_car()

var race: Node   ## RaceManager (position / lap / timer queries)

var _pos_num: Label
var _pos_suffix: Label
var _pos_total: Label
var _lap: Label
var _timer: Label
var _hint: Label
var _status: Label
var _feed: Label
var _countdown: Label
var _hit_flash: ColorRect
var _speedo: NeonSpeedometer
var _minimap: NeonMinimap
var _panel: NeonStatusPanel
var _slot: NeonItemSlot
var _mirror: RearMirror
var _show_widgets := true
var _mirror_enabled := true
var _results: PanelContainer
var _results_list: VBoxContainer
var _results_title: Label
var _feed_time := 0.0
var _hint_time := 12.0
var _connected: HoverJet
var _inverted := false
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _card_title: Label
var _card_sub: Label
var _widgets: Array[CanvasItem] = []


func _ready() -> void:
	_build()
	if car:
		_connect_car()


func _connect_car() -> void:
	if _connected == car:
		return
	_connected = car
	car.destroyed.connect(_on_destroyed)
	car.damaged.connect(_on_damaged)
	car.shield_hit.connect(_on_shield_hit)
	car.shield_refilled.connect(func() -> void: show_message("FORCEFIELD RESTORED", 1.5, NeonStyle.CYAN))
	car.fell.connect(func() -> void: show_message("FELL INTO THE VOID", 2.0, NeonStyle.RED))


## Training ground: no position / lap / timer.
func hide_race_info() -> void:
	for l in [_pos_num, _pos_suffix, _pos_total, _lap, _timer]:
		l.visible = false
	_hint.text = "1-7 give · ←→ select · ↑ fire front · ↓ fire back · C look back"
	_hint.position = Vector2(26, 500)
	_hint.size = Vector2(250, 90)
	_hint.custom_minimum_size = Vector2(250, 0)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_time = 9999.0


## Letterbox bars + hide the gameplay HUD for cutscenes.
func set_cinematic(on: bool) -> void:
	_show_widgets = not on
	if _mirror:
		_mirror.visible = not on
	var h := 86.0 if on else 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bar_top, "offset_bottom", h, 0.5)
	tw.tween_property(_bar_bottom, "offset_top", -h, 0.5)
	for w in _widgets:
		if on:
			w.visible = false
		else:
			w.visible = true
			w.modulate.a = 0.0
			tw.tween_property(w, "modulate:a", 1.0, 0.6)
	if not on:
		_card_title.modulate.a = 0.0
		_card_sub.modulate.a = 0.0


func show_intro_card(title: String, subtitle: String) -> void:
	_card_title.text = title
	_card_sub.text = subtitle
	_card_title.modulate.a = 0.0
	_card_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_card_title, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(_card_sub, "modulate:a", 1.0, 0.9)
	tw.tween_interval(3.0)
	tw.tween_property(_card_title, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_card_sub, "modulate:a", 0.0, 0.6)


## LOW: no mirror. MEDIUM: mirror at half rate. HIGH: full mirror.
func apply_quality(q: int) -> void:
	_mirror_enabled = q != 0
	if _mirror:
		_mirror.set_quality(q)


func set_world_inverted(on: bool, desaturate: float) -> void:
	_inverted = on
	if _mirror:
		_mirror.set_inverted(on, desaturate)
	if not on:
		return
	# Bright world: give HUD text dark backing plates so contrast stays high.
	_backplate(Control.PRESET_TOP_LEFT, Rect2(16, 6, 200, 128))
	_backplate(Control.PRESET_BOTTOM_LEFT, Rect2(20, -142, 360, 132))
	for l in [_status, _feed, _countdown, _card_title, _card_sub]:
		_darken(l)


func _backplate(preset: int, r: Rect2) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.06, 0.62)
	sb.set_corner_radius_all(14)
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(preset)
	p.offset_left = r.position.x
	p.offset_top = r.position.y
	p.offset_right = r.position.x + r.size.x
	p.offset_bottom = r.position.y + r.size.y
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	move_child(p, 1)  # Behind everything except the hit flash.
	_widgets.append(p)


func _darken(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))


func setup_minimap(track: RaceTrack, jets: Array, player: HoverJet) -> void:
	_minimap.setup(track, jets, player)


## Lets any car's events show in the feed (called by the race manager).
func watch_car(c: HoverJet) -> void:
	c.destroyed.connect(func(attacker: HoverJet) -> void:
		if c != car:
			var who := attacker.driver_name if attacker else "The void"
			show_message("%s wrecked %s" % [who, c.driver_name], 2.5, NeonStyle.AMBER))


func show_message(text: String, seconds := 2.5, color := NeonStyle.CYAN) -> void:
	_feed.text = text
	NeonStyle.set_label_color(_feed, color)
	if _inverted:
		_darken(_feed)
	_feed_time = seconds
	_feed.scale = Vector2.ONE * 1.25
	create_tween().tween_property(_feed, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_countdown(text: String, color: Color) -> void:
	_countdown.text = text
	NeonStyle.set_label_color(_countdown, color)
	if _inverted:
		_darken(_countdown)
	_countdown.modulate.a = 1.0
	_countdown.scale = Vector2.ONE * 1.8
	var tw := create_tween()
	tw.tween_property(_countdown, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45 if text != "GO!" else 0.6)
	tw.tween_property(_countdown, "modulate:a", 0.0, 0.25)


func show_results(rows: Array, title: String, title_color: Color) -> void:
	_results.visible = true
	_results_title.text = title
	NeonStyle.set_label_color(_results_title, title_color)
	for ch in _results_list.get_children():
		ch.queue_free()
	for row in rows:
		_results_list.add_child(NeonStyle.label(row.text, 22, row.color))
	_results_list.add_child(NeonStyle.label("ENTER  -  back to hangar", 16, Color(0.7, 0.75, 1.0)))


func _process(delta: float) -> void:
	if car == null:
		return
	# --- speedometer ---
	_speedo.kmh = car.get_speed_kmh()
	_speedo.max_kmh = ceilf(car.spec.top_speed * 3.6 * 1.35 / 50.0) * 50.0
	_speedo.boost = clampf(car.boost_time / 3.0, 0.0, 1.0)

	# --- hull & shield ---
	_panel.health = car.health / car.max_health
	_panel.shield = car.shield_charges
	_panel.max_shield = car.max_shield_charges
	_panel.shield_color = car.shield_color()

	# --- item slot ---
	var items := car.items
	_slot.slots = items.slots
	_slot.selected = items.selected
	_slot.ammo_frac = float(items.gun_ammo) / float(items.gun_rounds) if items.gun_ammo > 0 else 0.0
	if items.gun_ammo > 0:
		_slot.caption = "FIRING %s" % ("BACK" if items._gun_backward else "FORWARD")
	elif items.hook_target != null:
		_slot.caption = "HOOKED " + items.hook_target.driver_name.to_upper()
	elif items.held != PowerUp.Type.NONE:
		_slot.caption = PowerUp.name_of(items.held)
	elif items.count() > 0:
		_slot.caption = ""
	else:
		_slot.caption = ""

	# --- mirror (hidden while looking back with C) ---
	if _mirror:
		_mirror.jet = car
		_mirror.visible = _mirror_enabled and _show_widgets and not _looking_back()

	# --- position / lap / timer ---
	if race:
		var place: int = race.position_of(car)
		_pos_num.text = str(place)
		_pos_suffix.text = _ordinal(place)
		_pos_total.text = "/ %d" % race.jets.size()
		var col := NeonStyle.AMBER if place == 1 else (NeonStyle.CYAN if place <= 3 else NeonStyle.MAGENTA)
		NeonStyle.set_label_color(_pos_num, col)
		NeonStyle.set_label_color(_pos_suffix, col)
		_lap.text = "LAP  %d / %d" % [race.lap_of(car), race.race_laps]
		_timer.text = _fmt_time(race.race_time)

	# --- status line ---
	if car.is_destroyed:
		_set_status("WRECKED", NeonStyle.RED)
	elif car.stall_time > 0.0:
		_set_status("ENGINE FLOODED", NeonStyle.RED)
	elif car.boost_time > 0.0:
		_set_status("»  LIGHTSPEED  «", car.spec.accent)
	elif car.is_drifting:
		var c := NeonStyle.AMBER if car.drift_time >= car.boost_min_drift_time else Color.WHITE
		_set_status("DRIFT  %.1fs" % car.drift_time, c)
	elif car.is_invisible:
		_set_status("PHASED  %.1fs" % car.items.invis_time, PowerUp.color_of(PowerUp.Type.INVISIBILITY))
	else:
		_status.text = ""

	_feed_time -= delta
	_feed.modulate.a = clampf(_feed_time * 2.0, 0.0, 1.0)
	_hint_time -= delta
	_hint.modulate.a = clampf(_hint_time / 2.0, 0.0, 0.8)
	_hit_flash.color.a = maxf(_hit_flash.color.a - delta * 1.5, 0.0)


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	NeonStyle.set_label_color(_status, color)
	if _inverted:
		_darken(_status)


func _on_damaged(amount: float, _attacker: HoverJet) -> void:
	_hit_flash.color.a = clampf(_hit_flash.color.a + amount / 80.0, 0.0, 0.4)
	_panel.pulse()


func _on_destroyed(attacker: HoverJet) -> void:
	show_message("WRECKED BY %s" % (attacker.driver_name.to_upper() if attacker else "THE VOID"), 2.5, NeonStyle.RED)


func _on_shield_hit(left: int) -> void:
	if left > 0:
		show_message("SHIELD  %d / %d" % [left, car.max_shield_charges], 1.2, car.shield_color())
	else:
		show_message("SHIELD DEPLETED - NEXT EDGE HIT = FALL", 3.0, NeonStyle.RED)


func _looking_back() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.get("looking_back") == true


static func _ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "TH"
	match n % 10:
		1: return "ST"
		2: return "ND"
		3: return "RD"
	return "TH"


static func _fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]


# --- Layout ---------------------------------------------------------------------

func _build() -> void:
	_hit_flash = ColorRect.new()
	_hit_flash.color = Color(1, 0, 0.2, 0)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hit_flash)

	# Position / lap / time (top-left).
	_pos_num = NeonStyle.label("1", 58, NeonStyle.AMBER)
	_pos_num.position = Vector2(28, 10)
	add_child(_pos_num)
	_pos_suffix = NeonStyle.label("ST", 22, NeonStyle.AMBER)
	_pos_suffix.position = Vector2(72, 20)
	add_child(_pos_suffix)
	_pos_total = NeonStyle.label("/ 6", 18, Color(0.75, 0.8, 1.0))
	_pos_total.position = Vector2(74, 46)
	add_child(_pos_total)
	_lap = NeonStyle.label("LAP 1 / 3", 18, NeonStyle.CYAN)
	_lap.position = Vector2(32, 84)
	add_child(_lap)
	_timer = NeonStyle.label("0:00.00", 15, Color(0.8, 0.85, 1.0))
	_timer.position = Vector2(32, 108)
	add_child(_timer)
	_hint = NeonStyle.label("WASD fly · SPACE airbrake · ←→ pick ability · ↑ fire front · ↓ fire back · C look back · ESC pause", 14, Color(0.7, 0.8, 1.0))
	_hint.position = Vector2(32, 172)
	_hint.visible = false  # Controls are listed in the pause menu.
	add_child(_hint)

	# Minimap (top-right).
	_minimap = NeonMinimap.new()
	_place(_minimap, Control.PRESET_TOP_RIGHT, Rect2(-206, 18, 188, 188))

	# Speedometer (bottom-right).
	_speedo = NeonSpeedometer.new()
	_place(_speedo, Control.PRESET_BOTTOM_RIGHT, Rect2(-272, -158, 252, 134))

	# Hull + shield (bottom-left).
	_panel = NeonStatusPanel.new()
	_place(_panel, Control.PRESET_BOTTOM_LEFT, Rect2(32, -130, 328, 110))

	# Item slot (bottom-centre).
	_slot = NeonItemSlot.new()
	_place(_slot, Control.PRESET_CENTER_BOTTOM, Rect2(-190, -150, 380, 140))

	# Rear-view mirror (top-centre).
	_mirror = RearMirror.new()
	_place(_mirror, Control.PRESET_CENTER_TOP, Rect2(-150, 12, 300, 70))

	# Status + feed (top-centre).
	_status = NeonStyle.label("", 26, NeonStyle.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_center_top(_status, 96, 50)
	_feed = NeonStyle.label("", 18, NeonStyle.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_center_top(_feed, 142, 36)

	# Countdown (centre).
	_countdown = NeonStyle.label("", 170, NeonStyle.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.offset_left = -400
	_countdown.offset_right = 400
	_countdown.offset_top = -170
	_countdown.offset_bottom = 30
	_countdown.pivot_offset = Vector2(400, 100)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_countdown)

	# Cinematic letterbox + title card.
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = 0.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bottom)
	_card_title = NeonStyle.label("", 72, NeonStyle.MAGENTA)
	_card_title.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card_title.offset_left = 70
	_card_title.offset_right = 1200
	_card_title.offset_top = -230
	_card_title.offset_bottom = -140
	_card_title.modulate.a = 0.0
	add_child(_card_title)
	_card_sub = NeonStyle.label("", 22, NeonStyle.CYAN)
	_card_sub.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_card_sub.offset_left = 76
	_card_sub.offset_right = 1200
	_card_sub.offset_top = -138
	_card_sub.offset_bottom = -104
	_card_sub.modulate.a = 0.0
	add_child(_card_sub)
	_widgets = [_pos_num, _pos_suffix, _pos_total, _lap, _timer, _minimap, _speedo, _panel, _slot, _status]

	# Results board.
	_results = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.05, 0.82)
	style.border_color = NeonStyle.MAGENTA
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(NeonStyle.MAGENTA, 0.35)
	style.shadow_size = 18
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_results.add_theme_stylebox_override("panel", style)
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.offset_left = -300
	_results.offset_right = 300
	_results.offset_top = -220
	_results.offset_bottom = 220
	_results.visible = false
	add_child(_results)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_results.add_child(box)
	_results_title = NeonStyle.label("FINISHED", 48, NeonStyle.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_results_title)
	_results_list = VBoxContainer.new()
	_results_list.add_theme_constant_override("separation", 6)
	box.add_child(_results_list)


func _place(c: Control, preset: int, r: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)


func _center_top(l: Label, top: float, h: float) -> void:
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = top
	l.offset_bottom = top + h
	l.pivot_offset = Vector2(400, h * 0.5)
	add_child(l)
