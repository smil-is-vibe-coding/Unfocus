extends Node
## Autoload "Game": choices + settings that carry between scenes.

const MAIN_MENU := "res://scenes/main_menu.tscn"
const HANGAR := "res://scenes/menu.tscn"
const RACE := "res://scenes/main.tscn"
const TRAINING := "res://scenes/training.tscn"

enum Mode { RACE, TRAINING }
enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH"]

var mode := Mode.RACE
var selected_jet := 0
var level := 0

# Settings.
var race_laps := 3
var ai_count := 5
var music_volume := 0.8   ## 0..1
var sfx_volume := 0.9     ## 0..1

# Graphics.
var quality_auto := true
var quality := Quality.HIGH
var quality_reason := ""            ## Why AUTO picked this (shown to the player).
var quality_notified := false       ## Main menu shows the notice once per session.
var _fps_t := 0.0
var _fps_sum := 0.0
var _fps_n := 0
var _auto_downgraded := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	detect_quality()
	# Sound (autoload after this one) builds the buses; apply once they exist.
	apply_volumes.call_deferred()


func get_level() -> LevelDef:
	return LevelCatalog.get_level(level)


func get_selected_spec() -> JetSpec:
	return JetCatalog.get_spec(selected_jet)


func apply_volumes() -> void:
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	_set_bus("Engines", sfx_volume, -3.0)


func _set_bus(bus: String, v: float, offset := 0.0) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)) + offset)
		AudioServer.set_bus_mute(idx, v <= 0.001)


# --- Graphics quality --------------------------------------------------------

## Pick a preset from what we know about the device. Sets quality + quality_reason.
func detect_quality() -> void:
	var gpu := RenderingServer.get_video_adapter_name()
	if OS.has_feature("web"):
		# Godot only sees "WebKit WebGL" in the browser; ask WebGL for the real GPU.
		var real = JavaScriptBridge.eval("""(() => { try {
			const gl = document.createElement('canvas').getContext('webgl2');
			const ext = gl && gl.getExtension('WEBGL_debug_renderer_info');
			return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : '';
		} catch (e) { return ''; } })()""", true)
		if typeof(real) == TYPE_STRING and real != "":
			gpu = real
	var low_gpu := false
	for k in ["Mali", "Adreno", "PowerVR", "Apple", "SwiftShader", "llvmpipe", "Microsoft Basic", "Software"]:
		if gpu.containsn(k):
			low_gpu = true
	var integrated := false
	for k in ["Intel", "UHD", "Iris", "Radeon(TM) Graphics", "Radeon Graphics", "Vega"]:
		if gpu.containsn(k):
			integrated = true
	var web := OS.has_feature("web")
	# Browsers report the real GPU through WebGL (e.g. "ANGLE (NVIDIA, GeForce RTX ...)").
	var dedicated := false
	for k in ["NVIDIA", "GeForce", "RTX", "GTX", "Radeon RX", "Radeon Pro", "Arc A"]:
		if gpu.containsn(k):
			dedicated = true
	var mobile := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") 		or (web and DisplayServer.is_touchscreen_available())
	var where := "web browser" if web else OS.get_name()
	var gpu_short := gpu.get_slice("(", 0).strip_edges() if gpu != "" else "unknown GPU"
	if gpu.begins_with("ANGLE"):
		gpu_short = gpu.get_slice(",", 1).get_slice("(0x", 0).get_slice(" Direct3D", 0).strip_edges()
	if mobile or low_gpu or OS.get_processor_count() <= 2:
		quality = Quality.LOW
		quality_reason = "%s · %s" % ["mobile device" if mobile else where, gpu_short]
	elif integrated or (web and not dedicated):
		quality = Quality.MEDIUM
		quality_reason = "%s · %s" % [where, gpu_short]
	else:
		quality = Quality.HIGH
		quality_reason = "%s · %s" % [where, gpu_short]


func quality_name() -> String:
	return QUALITY_NAMES[quality]


## 0.35 / 0.65 / 1.0 - for scaling particle counts, scenery, etc.
func detail_factor() -> float:
	return [0.35, 0.65, 1.0][quality]


func set_quality(q: int, auto := false) -> void:
	quality_auto = auto
	if auto:
		detect_quality()
	else:
		quality = q
	apply_graphics(get_tree().current_scene)


## Applies the live parts of the preset to a scene: environment, 3D resolution,
## space dust, mirror. (Scenery density + trails apply as the level loads.)
func apply_graphics(scene: Node) -> void:
	get_tree().root.scaling_3d_scale = 0.7 if quality == Quality.LOW else 1.0
	if scene == null:
		return
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var env := we.environment
		if not env.resource_local_to_scene and env.resource_path != "":
			env = env.duplicate(true)   # Never edit the shared .tres on disk.
			we.environment = env
		env.glow_enabled = quality != Quality.LOW
		if OS.has_feature("web"):
			# WebGL often clamps colours at 1.0, so the desktop threshold (1.1)
			# would never trigger bloom. Catch the bright neon a bit earlier.
			env.glow_hdr_threshold = 0.82
			env.glow_intensity = 0.75
			env.glow_bloom = 0.03
		env.fog_enabled = quality == Quality.HIGH
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if quality == Quality.HIGH else Environment.REFLECTION_SOURCE_DISABLED
		if env.sky:
			# Realtime radiance (animated reflections) only on HIGH.
			env.sky.process_mode = Sky.PROCESS_MODE_REALTIME if quality == Quality.HIGH else Sky.PROCESS_MODE_INCREMENTAL
			var sm := env.sky.sky_material as ShaderMaterial
			if sm:
				sm.set_shader_parameter("aurora_layers", [4, 8, 14][quality])
	var dust := scene.get_node_or_null("ChaseCamera/SpaceDust") as GPUParticles3D
	if dust:
		dust.visible = quality != Quality.LOW
		dust.amount_ratio = 1.0 if quality == Quality.HIGH else 0.5
	var hud := scene.get_node_or_null("HUD")
	if hud and hud.has_method("apply_quality"):
		hud.apply_quality(quality)


## AUTO safety net: if a race runs badly, step down once and say so.
func _process(delta: float) -> void:
	if not quality_auto or _auto_downgraded or quality == Quality.LOW:
		return
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("position_of") or get_tree().paused:
		_fps_t = 0.0
		return
	_fps_t += delta
	if _fps_t < 6.0:          # Let the scene settle (shader compiles, intro).
		return
	_fps_sum += Engine.get_frames_per_second()
	_fps_n += 1
	if _fps_t >= 11.0:
		var avg := _fps_sum / maxf(_fps_n, 1)
		_fps_t = 0.0
		_fps_sum = 0.0
		_fps_n = 0
		if avg < 28.0:
			_auto_downgraded = true
			quality -= 1
			apply_graphics(scene)
			var hud := scene.get_node_or_null("HUD")
			if hud:
				hud.show_message("Graphics lowered to %s to keep it smooth (%d fps)" % [quality_name(), roundi(avg)], 3.5, NeonStyle.AMBER)


## Real browser fullscreen on the web build, borderless fullscreen on desktop.
func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func goto(scene: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene)


## Hangar "launch" goes to whichever mode was picked on the main menu.
func launch() -> void:
	goto(TRAINING if mode == Mode.TRAINING else RACE)
