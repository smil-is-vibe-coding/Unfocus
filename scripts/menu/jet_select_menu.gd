extends Node3D
## Hangar: same layout as the main menu. Jet list on the left (↑↓ to browse,
## Enter to launch), the jet spinning in the middle, its stats on the right.
## Esc goes back to the main menu.

const GLOW_SHADER := preload("res://shaders/neon_glow.gdshader")

var _index := 0
var _pivot: Node3D
var _preview: Node3D
var _ring: MeshInstance3D
var _spot: OmniLight3D

var _panel: PanelContainer
var _name: Label
var _tagline: Label
var _bars: Array[ProgressBar] = []
var _fills: Array[StyleBoxFlat] = []
var _values: Array[Label] = []
var _ability: Label
var _ability_desc: Label
var _pros: Label
var _cons: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	_index = Game.selected_jet
	_build_stage()
	_build_ui()
	_show(_index)
	Sound.play_music("music_hangar")
	Game.apply_graphics(self)
	_buttons[_index].grab_focus.call_deferred()


func _process(delta: float) -> void:
	_pivot.rotate_y(delta * 0.6)
	_pivot.position.y = sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sound.play("ui_move")
		Game.goto(Game.MAIN_MENU)


func _launch(i: int) -> void:
	Game.selected_jet = i
	Game.launch()


func _show(i: int) -> void:
	_index = i
	var spec := JetCatalog.get_spec(i)
	if _preview:
		_preview.queue_free()
	_preview = JetModel.build(spec).root
	_pivot.add_child(_preview)
	_preview.scale = Vector3.ONE * 0.7
	create_tween().tween_property(_preview, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ring.set_instance_shader_parameter("tint", spec.color)
	_spot.light_color = spec.color

	_name.text = spec.display_name
	NeonStyle.set_label_color(_name, spec.color)
	(_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = spec.color
	_tagline.text = spec.tagline
	var ratings := [spec.rating_speed(), spec.rating_accel(), spec.rating_handling(), spec.rating_armor()]
	var values := [
		"%d km/h" % roundi(spec.top_speed * 3.6),
		"%.1f s" % (27.8 / spec.accel * 1.15),
		"%d°/s" % roundi(spec.turn_rate_high),
		"%d HP" % roundi(spec.max_health),
	]
	for k in 4:
		create_tween().tween_property(_bars[k], "value", ratings[k] * 100.0, 0.25)
		_fills[k].bg_color = spec.color
		_values[k].text = values[k]
	_ability.text = spec.ability_name.to_upper()
	NeonStyle.set_label_color(_ability, spec.accent)
	_ability_desc.text = spec.ability_desc
	_pros.text = "\n".join(Array(spec.pros).map(func(p): return "+  " + p))
	_cons.text = "\n".join(Array(spec.cons).map(func(c): return "−  " + c))


# --- UI -------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := NeonStyle.label("HANGAR", 56, NeonStyle.MAGENTA)
	title.position = Vector2(80, 50)
	layer.add_child(title)
	var sub := "TRAINING GROUND" if Game.mode == Game.Mode.TRAINING else Game.get_level().display_name
	var subtitle := NeonStyle.label("PICK YOUR JET  ·  " + sub, 20, NeonStyle.CYAN)
	subtitle.position = Vector2(84, 124)
	layer.add_child(subtitle)
	layer.add_child(NeonStyle.footer("↑ ↓  MOVE        ENTER  LAUNCH        ESC  BACK"))

	var list := VBoxContainer.new()
	list.position = Vector2(80, 200)
	list.add_theme_constant_override("separation", 8)
	layer.add_child(list)
	var specs := JetCatalog.all()
	for i in specs.size():
		var b := NeonStyle.button(specs[i].display_name, specs[i].color, Vector2(300, 54), 22)
		b.focus_entered.connect(_show.bind(i))
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		b.pressed.connect(_launch.bind(i))
		list.add_child(b)
		_buttons.append(b)

	_panel = NeonStyle.panel(NeonStyle.CYAN)
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -500
	_panel.offset_right = -60
	_panel.offset_top = 180
	_panel.offset_bottom = -80
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_name = NeonStyle.label("", 38, Color.WHITE)
	box.add_child(_name)
	_tagline = NeonStyle.label("", 15, Color(0.8, 0.85, 1.0))
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tagline)
	for stat in ["SPEED", "ACCELERATION", "HANDLING", "ARMOUR"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := NeonStyle.label(stat, 14, Color(0.75, 0.8, 0.95))
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		var fill := StyleBoxFlat.new()
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var v := NeonStyle.label("", 14, Color.WHITE)
		v.custom_minimum_size = Vector2(80, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
		box.add_child(row)
		_bars.append(bar)
		_fills.append(fill)
		_values.append(v)
	box.add_child(HSeparator.new())
	_ability = NeonStyle.label("", 18, Color.WHITE)
	box.add_child(_ability)
	_ability_desc = NeonStyle.label("", 14, Color(0.8, 0.85, 1.0))
	_ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ability_desc)
	_pros = NeonStyle.label("", 15, NeonStyle.GREEN)
	box.add_child(_pros)
	_cons = NeonStyle.label("", 15, NeonStyle.RED)
	box.add_child(_cons)


func _build_stage() -> void:
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.far = 4000.0
	add_child(cam)
	cam.position = Vector3(0.0, 2.6, 11.5)
	cam.look_at(Vector3(0.0, 0.0, 0.0))
	cam.current = true
	_pivot = Node3D.new()
	_pivot.position = Vector3(-0.8, 0, 0)
	add_child(_pivot)
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("rim_power", 1.0)
	mat.set_shader_parameter("rim_strength", 3.0)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.4
	torus.outer_radius = 3.55
	torus.rings = 64
	_ring.mesh = torus
	_ring.material_override = mat
	_ring.position = Vector3(-0.8, -1.2, 0)
	add_child(_ring)
	_spot = OmniLight3D.new()
	_spot.position = Vector3(-0.8, 3.0, 2.0)
	_spot.light_energy = 3.0
	_spot.omni_range = 12.0
	add_child(_spot)
	var key := OmniLight3D.new()
	key.position = Vector3(3, 2, 5)
	key.light_color = Color(0.7, 0.7, 1.0)
	key.light_energy = 1.4
	key.omni_range = 15.0
	add_child(key)
