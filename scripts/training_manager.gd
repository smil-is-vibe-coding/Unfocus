extends Node3D
## Training Ground: a calm oval with target dummies and an ability panel.
##   1-7  give yourself any ability instantly (then E to use it)
##   T    respawn target dummies ahead of you
##   M    toggle dummies holding still / cruising
##   F    drain your shield to 1 charge (to test the force field + falling)
##   ESC  pause menu

const DUMMY_COUNT := 3

@onready var track: RaceTrack = $Track
@onready var camera = $ChaseCamera
@onready var hud = $HUD

var player: HoverJet
var dummies: Array[HoverJet] = []
var jets: Array = []
var dummies_moving := false

var _panel: VBoxContainer
var _mode_btn: Button


func _ready() -> void:
	var grid := track.get_grid_transforms(1)
	player = _spawn(Game.get_selected_spec(), "You", grid[0], true)
	jets.append(player)

	camera.target = player
	camera.distance = 5.0 + player.spec.length * 0.45
	camera.snap_to_target()
	var warp := WarpFX.new()
	warp.jet = player
	camera.add_child(warp)

	hud.car = player
	hud.hide_race_info()
	_spawn_dummies()
	hud.setup_minimap(track, jets, player)
	_build_panel()
	add_child(PauseMenu.new())
	var touch := TouchControls.new()
	touch.player = player
	touch.activated.connect(_compact_panel)
	add_child(touch)
	Sound.play_music("music_hangar")
	Game.apply_graphics(self)
	hud.show_message("TRAINING GROUND", 2.5, NeonStyle.MAGENTA)


func _spawn(spec: JetSpec, driver: String, at: Transform3D, is_player: bool) -> HoverJet:
	var jet := HoverJet.new()
	jet.spec = spec
	jet.player_controlled = is_player
	jet.driver_name = driver
	jet.name = driver.replace(" ", "_")
	add_child(jet)
	jet.global_transform = at
	jet.global_position += Vector3.UP * spec.hover_height
	jet.reset_physics_interpolation()
	return jet


func _spawn_dummies() -> void:
	for d in dummies:
		if is_instance_valid(d):
			jets.erase(d)
			d.queue_free()
	dummies.clear()
	var specs := JetCatalog.all()
	var off := track.get_closest_offset(player.global_position)
	for i in DUMMY_COUNT:
		var spec: JetSpec = specs[(i + 1) % specs.size()]
		var at := track.get_transform_at(off + 45.0 + i * 30.0, [-5.0, 4.0, 0.0][i], 1.0)
		var d := _spawn(spec, "Target %d" % (i + 1), at, false)
		var ai := AIDriver.new()
		ai.use_items = false
		ai.skill = 0.55
		d.add_child(ai)
		var plate := Nameplate.new()
		plate.car = d
		d.add_child(plate)
		d.race_locked = not dummies_moving
		d.shield_charges = 99
		d.max_shield_charges = 99
		dummies.append(d)
		jets.append(d)
	hud.setup_minimap(track, jets, player)
	Effects.ring_burst(self, player.global_position, NeonStyle.CYAN, 5.0, 2)


func _give(type: int) -> void:
	if type == PowerUp.Type.FORCEFIELD:
		player.shield_charges = mini(player.shield_charges, 2)
		player.refill_shield()
		Sound.pickup(type, player.global_position, true)
		return
	player.items.force_give(type)
	Sound.pickup(type, player.global_position, true)
	var how := "UP fires forward, DOWN fires back" if CarItems.is_directional(type) else "press UP to use"
	hud.show_message("%s READY - %s" % [PowerUp.name_of(type), how], 1.8, PowerUp.color_of(type))


func _toggle_moving() -> void:
	dummies_moving = not dummies_moving
	for d in dummies:
		if is_instance_valid(d):
			d.race_locked = not dummies_moving
	_mode_btn.text = "M  TARGETS: " + ("CRUISING" if dummies_moving else "HOLDING")
	hud.show_message("Targets " + ("cruising" if dummies_moving else "holding position"), 1.5, NeonStyle.CYAN)


func _drain_shield() -> void:
	player.shield_charges = 1
	hud.show_message("SHIELD DRAINED TO 1 - next hard edge hit and you fall", 2.5, NeonStyle.RED)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			_give(k.physical_keycode - KEY_1)
		KEY_T:
			_spawn_dummies()
		KEY_M:
			_toggle_moving()
		KEY_F:
			_drain_shield()


## Touch devices: shrink the panel to an icon strip so the joystick has room.
func _compact_panel() -> void:
	for c in _panel.get_children():
		if c is Label:
			c.visible = false
		elif c is Button:
			var b := c as Button
			b.custom_minimum_size = Vector2(54, 40)
			b.text = "" if b.icon else b.text.substr(0, 1)
			b.add_theme_constant_override("icon_max_width", 26)


# --- Ability panel (left side, clickable) ---------------------------------------

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrainingPanel"
	layer.layer = 5
	add_child(layer)
	_panel = VBoxContainer.new()
	_panel.position = Vector2(24, 52)
	_panel.add_theme_constant_override("separation", 3)
	layer.add_child(_panel)
	_panel.add_child(NeonStyle.label("ABILITIES", 16, NeonStyle.MAGENTA))
	for t in PowerUp.COUNT:
		var b := NeonStyle.button("%d   %s" % [t + 1, PowerUp.name_of(t)], PowerUp.color_of(t), Vector2(230, 32), 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = PowerUp.icon_texture(t)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.add_theme_color_override("icon_normal_color", PowerUp.color_of(t))
		b.add_theme_color_override("icon_hover_color", Color.WHITE)
		b.add_theme_color_override("icon_focus_color", Color.WHITE)
		b.focus_mode = Control.FOCUS_NONE  # Keep keyboard driving the jet.
		b.pressed.connect(_give.bind(t))
		_panel.add_child(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_panel.add_child(gap)
	_panel.add_child(NeonStyle.label("TARGETS", 16, NeonStyle.MAGENTA))
	var spawn := NeonStyle.button("T  RESPAWN TARGETS", NeonStyle.CYAN, Vector2(230, 32), 13)
	spawn.focus_mode = Control.FOCUS_NONE
	spawn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	spawn.pressed.connect(_spawn_dummies)
	_panel.add_child(spawn)
	_mode_btn = NeonStyle.button("M  TARGETS: HOLDING", NeonStyle.CYAN, Vector2(230, 32), 13)
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mode_btn.pressed.connect(_toggle_moving)
	_panel.add_child(_mode_btn)
	var drain := NeonStyle.button("F  DRAIN SHIELD", NeonStyle.RED, Vector2(230, 32), 13)
	drain.focus_mode = Control.FOCUS_NONE
	drain.alignment = HORIZONTAL_ALIGNMENT_LEFT
	drain.pressed.connect(_drain_shield)
	_panel.add_child(drain)
