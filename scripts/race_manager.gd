extends Node3D
## Runs a race: grid spawn, 3-2-1-GO countdown with launch timing, lap and
## position tracking, finish + results. Esc returns to the hangar.
##
## Launch control (player): rev during the countdown if you like, but holding
## the throttle before the last half-second floods the engine (stall at GO).
## Hitting the throttle right on GO gives a launch boost.


enum State { INTRO, COUNTDOWN, RACING }

@export var ai_count := 5
@export var race_laps := 3
@export var countdown_lead := 0.3        ## Pause between the flyover and "3".
@export var flood_hold_limit := 0.35     ## Seconds of early throttle that floods the engine.
@export var perfect_window := Vector2(-0.22, 0.08)   ## Relative to GO.
@export var good_window := Vector2(-0.5, 0.22)

@onready var track: RaceTrack = $Track
@onready var camera = $ChaseCamera
@onready var hud = $HUD

var player: HoverJet
var jets: Array[HoverJet] = []
var state := State.INTRO
var race_time := 0.0
var finish_order: Array[HoverJet] = []

var _progress := {}
var _prev_off := {}
var _finish_time := {}
var _cd := 0.0
var _last_count := 4
var _go_time := 3.0
# Launch timing.
var _early_hold := 0.0
var _first_press := INF
var _prev_thr := 0.0
var _launch_judged := false
var _player_lap := 1
var _player_done := false
var _intro: RaceIntro
var _handoff_started := false


func _enter_tree() -> void:
	# Runs before the children are ready, so the track + scenery build themed.
	LevelTheme.apply(Game.get_level(), self)


func _ready() -> void:
	ai_count = Game.ai_count
	race_laps = Game.race_laps
	var grid := track.get_grid_transforms(ai_count + 1)
	var specs := JetCatalog.all()

	player = _spawn(Game.get_selected_spec(), "You", grid[0], true)
	for i in ai_count:
		# Mix of classes so every race has a bit of everything.
		var spec: JetSpec = specs[(Game.selected_jet + 1 + i) % specs.size()]
		var jet := _spawn(spec, "%s %d" % [spec.display_name.capitalize(), i + 1], grid[i + 1], false)
		var ai := AIDriver.new()
		ai.name = "AIDriver"
		ai.skill = randf_range(0.86, 0.97)
		ai.lane_offset = randf_range(-3.5, 3.5)
		jet.add_child(ai)
		var plate := Nameplate.new()
		plate.car = jet
		jet.add_child(plate)
		hud.watch_car(jet)

	for j in jets:
		j.race_locked = true
		var off := track.get_closest_offset(j.global_position)
		_prev_off[j] = off
		_progress[j] = off - track.length if off > track.length * 0.5 else off

	camera.target = player
	camera.distance = 5.0 + player.spec.length * 0.45
	camera.snap_to_target()
	var warp := WarpFX.new()
	warp.jet = player
	camera.add_child(warp)

	hud.car = player
	hud.race = self
	hud.setup_minimap(track, jets, player)
	_cd = -countdown_lead
	add_child(PauseMenu.new())
	var touch := TouchControls.new()
	touch.player = player
	add_child(touch)

	# Cinematic intro: flyover -> rival shots on 3/2 -> hero shot on 1 -> GO.
	_intro = RaceIntro.new()
	_intro.track = track
	_intro.jets = jets
	_intro.player = player
	_intro.chase_cam = camera
	add_child(_intro)
	_intro.flyover_finished.connect(func() -> void:
		if state == State.INTRO:
			state = State.COUNTDOWN)
	_intro.start()
	hud.set_cinematic(true)
	var lvl := Game.get_level()
	hud.set_world_inverted(lvl.invert, lvl.desaturate)
	hud.show_intro_card(lvl.display_name, "%d LAPS  ·  %d RACERS  ·  ENTER TO SKIP" % [race_laps, jets.size()])
	Sound.play_music("music_race")
	Game.apply_graphics(self)


func _spawn(spec: JetSpec, driver: String, at: Transform3D, is_player: bool) -> HoverJet:
	var jet := HoverJet.new()
	jet.spec = spec
	jet.player_controlled = is_player  # Before add_child: engine audio reads it in _ready.
	jet.driver_name = driver
	jet.name = driver.replace(" ", "_")
	add_child(jet)
	jet.global_transform = at
	jet.global_position += Vector3.UP * spec.hover_height
	jet.reset_physics_interpolation()
	jets.append(jet)
	return jet


# --- Queries for the HUD ------------------------------------------------------------

func position_of(jet: HoverJet) -> int:
	var idx := finish_order.find(jet)
	if idx >= 0:
		return idx + 1
	var ahead := finish_order.size()
	var mine: float = _progress.get(jet, 0.0)
	for j in jets:
		if j != jet and not finish_order.has(j) and _progress.get(j, 0.0) > mine:
			ahead += 1
	return ahead + 1


func lap_of(jet: HoverJet) -> int:
	return clampi(int(floor(_progress.get(jet, 0.0) / track.length)) + 1, 1, race_laps)


# --- Race flow ------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.RACING:
			race_time += delta
			if not _launch_judged:
				_watch_launch_press(_go_time + race_time)
				if race_time >= good_window.y:
					_judge_launch()
			_track_progress()


func _countdown(delta: float) -> void:
	_cd += delta
	_watch_launch_press(_cd)
	if _cd < _go_time + good_window.x and player.throttle_input > 0.3:
		_early_hold += delta

	var n := 3 - int(floor(_cd))
	if _cd >= 0.0 and n >= 1 and n < _last_count:
		_last_count = n
		var colors := {3: NeonStyle.RED, 2: NeonStyle.AMBER, 1: Color(1.0, 1.0, 0.3)}
		hud.show_countdown(str(n), colors[n])
		_intro.show_count(n)
		Sound.play("countdown_beep", 0.0, 1.0)
		if n == 3:
			hud.show_message("Hit the throttle right on GO for a launch boost", 2.6, NeonStyle.CYAN)
	if _cd >= _go_time - 0.45 and not _handoff_started:
		_handoff_started = true
		_intro.begin_handoff(0.45)
	if _cd >= _go_time:
		_go()


func _watch_launch_press(t: float) -> void:
	var thr := player.throttle_input
	if thr > 0.5 and _prev_thr <= 0.5 and _first_press == INF and t >= _go_time + good_window.x:
		_first_press = t
	_prev_thr = thr


func _go() -> void:
	state = State.RACING
	race_time = 0.0
	hud.show_countdown("GO!", NeonStyle.CYAN)
	if is_instance_valid(_intro):
		_intro.finish()
	hud.set_cinematic(false)
	Sound.play("go_beep")
	for j in jets:
		j.race_locked = false
		if j != player:
			var roll := randf()
			j.apply_launch("perfect" if roll < 0.25 else ("good" if roll < 0.65 else ("stall" if roll < 0.8 else "")))
	if _early_hold > flood_hold_limit:
		_judge_launch()


func _judge_launch() -> void:
	_launch_judged = true
	var rel := _first_press - _go_time
	if _early_hold > flood_hold_limit:
		player.apply_launch("stall")
		hud.show_message("JUMPED THE START - ENGINE FLOODED!", 2.5, NeonStyle.RED)
		Sound.play("stall")
	elif rel >= perfect_window.x and rel <= perfect_window.y:
		player.apply_launch("perfect")
		hud.show_message("PERFECT LAUNCH!", 2.0, NeonStyle.AMBER)
		Sound.play("perfect_start")
	elif rel >= good_window.x and rel <= good_window.y:
		player.apply_launch("good")
		hud.show_message("GOOD START", 1.5, NeonStyle.CYAN)


func _track_progress() -> void:
	var L := track.length
	for j in jets:
		if not is_instance_valid(j):
			continue
		var off := track.get_closest_offset(j.global_position)
		var d: float = off - _prev_off[j]
		if d < -L * 0.5:
			d += L
		elif d > L * 0.5:
			d -= L
		_prev_off[j] = off
		_progress[j] += d
		if not finish_order.has(j) and _progress[j] >= race_laps * L:
			_on_finished(j)

	var lap := lap_of(player)
	if lap != _player_lap and not _player_done:
		_player_lap = lap
		Sound.play("lap")
		if lap == race_laps:
			hud.show_message("FINAL LAP", 2.5, NeonStyle.MAGENTA)
		else:
			hud.show_message("LAP %d / %d" % [lap, race_laps], 2.0, NeonStyle.CYAN)


func _on_finished(j: HoverJet) -> void:
	finish_order.append(j)
	_finish_time[j] = race_time
	if j == player:
		_player_done = true
		Sound.play("finish")
		# Autopilot takes over for a victory lap.
		var ai := AIDriver.new()
		ai.skill = 0.8
		player.add_child(ai)
	if _player_done:
		_refresh_results()


func _refresh_results() -> void:
	var place := finish_order.find(player) + 1
	var rows := []
	var order: Array[HoverJet] = finish_order.duplicate()
	var rest := jets.filter(func(j): return not finish_order.has(j))
	rest.sort_custom(func(a, b): return _progress[a] > _progress[b])
	order.append_array(rest)
	for i in order.size():
		var j := order[i]
		var t: String = hud._fmt_time(_finish_time[j]) if _finish_time.has(j) else "racing..."
		var col := j.spec.color if j != player else Color(1.0, 1.0, 1.0)
		rows.append({"text": "%d.  %-12s %s" % [i + 1, j.driver_name.to_upper(), t], "color": col})
	var title := "%d%s PLACE" % [place, hud._ordinal(place)]
	hud.show_results(rows, title, NeonStyle.AMBER if place == 1 else NeonStyle.CYAN)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.INTRO and event.is_action_pressed("ui_accept"):
		_intro.skip_flyover()
		get_viewport().set_input_as_handled()
		return
	if _player_done and event.is_action_pressed("ui_accept"):
		Game.goto(Game.HANGAR)
