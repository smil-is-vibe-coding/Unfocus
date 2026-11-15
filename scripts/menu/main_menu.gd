extends Node3D
## Title screen. Every screen uses the same simple layout:
##   title top-left · option list on the left · details on the right ·
##   key prompts along the bottom (↑↓ move, Enter select, Esc back).
## Screens: MAIN (Race / Training / Settings / Quit), LEVELS, SETTINGS.

const GLOW := preload("res://shaders/neon_glow.gdshader")

var _cam: Camera3D
var _jet_pivot: Node3D
var _jet_index := 0
var _swap_t := 0.0
var _t := 0.0

var _title: Label
var _subtitle: Label
var _screens := {}          # name -> Control (left column)
var _first := {}            # name -> first focusable
var _current := ""
var _detail: PanelContainer
var _preview: TrackPreview
var _lv_name: Label
var _lv_desc: Label
var _lv_stats: Label


func _ready() -> void:
	_build_stage()
	_build_ui()
	_show_jet(Game.selected_jet)
	Sound.play_music("music_hangar")
	Game.apply_graphics(self)
	_go("main")
	if not Game.quality_notified:
		Game.quality_notified = true
		_toast("GRAPHICS  %s  ·  auto-set for this device (%s)  ·  change in Settings" % [Game.quality_name(), Game.quality_reason])


func _process(delta: float) -> void:
	_t += delta
	_jet_pivot.rotate_y(delta * 0.35)
	_jet_pivot.position.y = sin(_t * 1.3) * 0.15
	_cam.position = Vector3(sin(_t * 0.1) * 1.2, 1.8 + sin(_t * 0.17) * 0.3, 10.5)
	_cam.look_at(Vector3(0.0, 0.4, 0.0))
	_swap_t += delta
	if _swap_t > 6.0:
		_swap_t = 0.0
		_show_jet((_jet_index + 1) % JetCatalog.all().size())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _current != "main":
		Sound.play("ui_move")
		_go("main")


# --- Screens ----------------------------------------------------------------------

func _go(screen: String) -> void:
	_current = screen
	for k in _screens:
		_screens[k].visible = k == screen
	_detail.visible = screen == "levels"
	_jet_pivot.visible = screen != "levels"
	match screen:
		"main":
			_subtitle.text = "HOVER COMBAT RACING"
		"levels":
			_subtitle.text = "CHOOSE A CIRCUIT"
		"settings":
			_subtitle.text = "SETTINGS"
	(_first[screen] as Control).grab_focus.call_deferred()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_title = NeonStyle.label("UNFOCUS", 72, NeonStyle.MAGENTA)
	_title.position = Vector2(80, 50)
	layer.add_child(_title)
	_subtitle = NeonStyle.label("", 20, NeonStyle.CYAN)
	_subtitle.position = Vector2(84, 140)
	layer.add_child(_subtitle)
	layer.add_child(NeonStyle.footer())

	var fs := NeonStyle.button("⛶  FULLSCREEN", NeonStyle.CYAN, Vector2(210, 44), 16)
	fs.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fs.offset_left = -270
	fs.offset_right = -60
	fs.offset_top = 56
	fs.offset_bottom = 100
	fs.focus_mode = Control.FOCUS_NONE
	fs.pressed.connect(Game.toggle_fullscreen)
	layer.add_child(fs)

	# MAIN
	var main := _column(layer, "main")
	_first["main"] = _btn(main, "RACE", NeonStyle.CYAN, func() -> void: _go("levels"))
	_btn(main, "TRAINING GROUND", NeonStyle.CYAN, func() -> void:
		Game.mode = Game.Mode.TRAINING
		Game.goto(Game.HANGAR))
	_btn(main, "SETTINGS", NeonStyle.CYAN, func() -> void: _go("settings"))
	if not OS.has_feature("web"):  # A browser tab can't quit itself.
		_btn(main, "QUIT", NeonStyle.MAGENTA, func() -> void: get_tree().quit())

	# LEVELS (list left, circuit map + info right)
	var levels := _column(layer, "levels")
	var all := LevelCatalog.all()
	for i in all.size():
		var lv := all[i]
		var b := _btn(levels, "%d   %s" % [i + 1, lv.display_name], lv.ui_color, func() -> void:
			Game.level = i
			Game.mode = Game.Mode.RACE
			Game.goto(Game.HANGAR))
		b.focus_entered.connect(_show_level.bind(lv))
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		if i == 0:
			_first["levels"] = b
	_btn(levels, "BACK", NeonStyle.MAGENTA, func() -> void: _go("main"))

	_detail = NeonStyle.panel(NeonStyle.CYAN)
	_detail.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_detail.offset_left = -560
	_detail.offset_right = -60
	_detail.offset_top = 190
	_detail.offset_bottom = -80
	layer.add_child(_detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	_detail.add_child(dv)
	_lv_name = NeonStyle.label("", 32, Color.WHITE)
	dv.add_child(_lv_name)
	_preview = TrackPreview.new()
	_preview.custom_minimum_size = Vector2(440, 250)
	dv.add_child(_preview)
	_lv_stats = NeonStyle.label("", 17, NeonStyle.CYAN)
	dv.add_child(_lv_stats)
	_lv_desc = NeonStyle.label("", 16, Color(0.8, 0.85, 1.0))
	_lv_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lv_desc.custom_minimum_size = Vector2(440, 0)
	dv.add_child(_lv_desc)

	# SETTINGS
	var settings := _column(layer, "settings")
	_first["settings"] = _slider_row(settings, "MUSIC", Game.music_volume, func(v: float) -> void:
		Game.music_volume = v
		Game.apply_volumes())
	_slider_row(settings, "SOUND FX", Game.sfx_volume, func(v: float) -> void:
		Game.sfx_volume = v
		Game.apply_volumes())
	_choice_row(settings, "GRAPHICS", ["AUTO", "LOW", "MEDIUM", "HIGH"], 0 if Game.quality_auto else Game.quality + 1, func(i: int) -> void:
		if i == 0:
			Game.set_quality(0, true)
			_toast("GRAPHICS  AUTO  →  %s  (%s)" % [Game.quality_name(), Game.quality_reason])
		else:
			Game.set_quality(i - 1, false))
	_stepper_row(settings, "LAPS", Game.race_laps, 1, 9, func(v: int) -> void: Game.race_laps = v)
	_stepper_row(settings, "OPPONENTS", Game.ai_count, 0, 7, func(v: int) -> void: Game.ai_count = v)
	_btn(settings, "BACK", NeonStyle.MAGENTA, func() -> void: _go("main"))


## Small notice panel that slides in at the bottom-right and fades away.
func _toast(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var p := NeonStyle.panel(NeonStyle.AMBER)
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -40
	p.offset_bottom = -70
	var l := NeonStyle.label(text, 15, Color(1.0, 0.9, 0.7))
	p.add_child(l)
	layer.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.4)
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)


func _choice_row(box: Container, text: String, options: Array, index: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := NeonStyle.label(text, 20, NeonStyle.CYAN)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var minus := NeonStyle.button("◀", NeonStyle.CYAN, Vector2(56, 42), 18)
	var val := NeonStyle.label(options[index], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size = Vector2(120, 0)
	var plus := NeonStyle.button("▶", NeonStyle.CYAN, Vector2(56, 42), 18)
	var current := [index]
	var apply := func(d: int) -> void:
		current[0] = posmod(current[0] + d, options.size())
		val.text = options[current[0]]
		on_change.call(current[0])
	minus.pressed.connect(apply.bind(-1))
	plus.pressed.connect(apply.bind(1))
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	box.add_child(row)


func _show_level(lv: LevelDef) -> void:
	_preview.level = lv
	_lv_name.text = lv.display_name
	NeonStyle.set_label_color(_lv_name, lv.ui_color)
	(_detail.get_theme_stylebox("panel") as StyleBoxFlat).border_color = lv.ui_color
	var stars := "■".repeat(lv.difficulty) + "□".repeat(5 - lv.difficulty)
	_lv_stats.text = "LENGTH  %.1f km     WIDTH  %d m     DIFFICULTY  %s" % [_preview.length_m / 1000.0, roundi(lv.width), stars]
	_lv_desc.text = lv.subtitle


func _column(layer: CanvasLayer, name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(80, 200)
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	layer.add_child(box)
	_screens[name] = box
	return box


func _btn(box: Container, text: String, color: Color, action: Callable) -> Button:
	var b := NeonStyle.button(text, color, Vector2(420, 54), 22)
	b.pressed.connect(action)
	box.add_child(b)
	return b


func _slider_row(box: Container, text: String, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := NeonStyle.label(text, 20, NeonStyle.CYAN)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(250, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var grab := StyleBoxFlat.new()
	grab.bg_color = NeonStyle.CYAN
	grab.set_corner_radius_all(3)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	s.value_changed.connect(on_change)
	s.focus_entered.connect(func() -> void: Sound.play("ui_move"))
	row.add_child(s)
	box.add_child(row)
	return s


func _stepper_row(box: Container, text: String, value: int, lo: int, hi: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := NeonStyle.label(text, 20, NeonStyle.CYAN)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var minus := NeonStyle.button("−", NeonStyle.CYAN, Vector2(56, 42), 20)
	var val := NeonStyle.label(str(value), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size = Vector2(60, 0)
	var plus := NeonStyle.button("+", NeonStyle.CYAN, Vector2(56, 42), 20)
	var current := [value]
	var apply := func(d: int) -> void:
		current[0] = clampi(current[0] + d, lo, hi)
		val.text = str(current[0])
		on_change.call(current[0])
	minus.pressed.connect(apply.bind(-1))
	plus.pressed.connect(apply.bind(1))
	row.add_child(minus)
	row.add_child(val)
	row.add_child(plus)
	box.add_child(row)


# --- Background stage -------------------------------------------------------------

func _show_jet(i: int) -> void:
	_jet_index = i
	for ch in _jet_pivot.get_children():
		ch.queue_free()
	var built := JetModel.build(JetCatalog.get_spec(i))
	var m: Node3D = built.root
	m.scale = Vector3.ONE * 0.6
	_jet_pivot.add_child(m)
	create_tween().tween_property(m, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_stage() -> void:
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 4000.0
	add_child(_cam)
	_cam.current = true
	_jet_pivot = Node3D.new()
	_jet_pivot.position = Vector3(4.2, 0, 0)
	add_child(_jet_pivot)
	var light := OmniLight3D.new()
	light.position = Vector3(4, 3, 3)
	light.light_energy = 3.0
	light.omni_range = 14.0
	light.light_color = Color(0.6, 0.8, 1.0)
	add_child(light)
	var mat := ShaderMaterial.new()
	mat.shader = GLOW
	for k in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 5.0 + k * 3.0
		torus.outer_radius = 5.2 + k * 3.0
		torus.rings = 64
		ring.mesh = torus
		ring.material_override = mat
		ring.position = Vector3(4.2, -1.5 - k * 0.6, -k * 4.0)
		add_child(ring)
		ring.set_instance_shader_parameter("tint", [NeonStyle.CYAN, NeonStyle.MAGENTA][k % 2])
