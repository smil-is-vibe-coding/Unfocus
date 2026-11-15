class_name EngineAudio
extends Node3D
## Layered engine sound for a HoverJet:
##   core   - the jet's own engine loop (unique per class), pitch rides the speed
##   roar   - shared thrust roar, loudness follows the throttle (the "push")
##   burner - afterburner blast while boosting
##   air    - airbrake hiss while drifting
## The player's jet is louder and wider; rivals use distance + doppler so they
## whoosh past.

var jet: HoverJet
var is_player := false

var _core: AudioStreamPlayer3D
var _roar: AudioStreamPlayer3D
var _burner: AudioStreamPlayer3D
var _air: AudioStreamPlayer3D
var _thr := 0.0
var _boost := 0.0
var _drift := 0.0
var _rev := 0.0          ## Smoothed "rpm" 0..~1.4
var _boost_was := false


func _ready() -> void:
	jet = get_parent() as HoverJet
	is_player = jet.player_controlled
	var unit := 22.0 if is_player else 9.0
	_core = Sound.attach_loop("engine_" + jet.spec.id, self, -4.0, unit, "Engines")
	_roar = Sound.attach_loop("engine_roar", self, -6.0, unit, "Engines")
	_burner = Sound.attach_loop("afterburner", self, -60.0, unit, "Engines")
	_air = Sound.attach_loop("airbrake", self, -60.0, unit, "Engines")
	for p in [_core, _roar, _burner, _air]:
		if p and is_player:
			p.panning_strength = 0.35
			p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


func _process(delta: float) -> void:
	if jet == null or _core == null:
		return
	var alive := not jet.is_destroyed
	var speed_t := clampf(absf(jet.forward_speed) / jet.spec.top_speed, 0.0, 1.4)
	_thr = lerpf(_thr, jet.throttle_input if alive else 0.0, 1.0 - exp(-8.0 * delta))
	_boost = lerpf(_boost, 1.0 if jet.boost_time > 0.0 and alive else 0.0, 1.0 - exp(-6.0 * delta))
	var drifting := (jet.is_drifting or jet.handbrake) and absf(jet.forward_speed) > 8.0
	_drift = lerpf(_drift, 1.0 if drifting else 0.0, 1.0 - exp(-10.0 * delta))
	# "Revs" lead the speed when you floor it, so acceleration is audible.
	var target_rev := speed_t * 0.8 + _thr * 0.25 + _boost * 0.2
	_rev = lerpf(_rev, target_rev, 1.0 - exp(-(4.0 if target_rev > _rev else 2.0) * delta))

	var stealth := -12.0 if jet.is_invisible and not is_player else 0.0
	var dead := -30.0 if not alive else 0.0

	var sputter := 0.0
	if jet.stall_time > 0.0:
		# Flooded engine: choppy, starved, low.
		sputter = -14.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.16) < 0.08 else 0.0
		_rev *= 0.5
	_core.pitch_scale = 0.55 + _rev * 0.95
	_core.volume_db = -4.0 + linear_to_db(0.45 + 0.55 * maxf(_thr, speed_t * 0.6)) + stealth + dead + sputter
	_roar.pitch_scale = 0.7 + _rev * 0.45
	_roar.volume_db = -6.0 + linear_to_db(0.08 + 0.92 * _thr * (0.6 + 0.4 * speed_t)) + stealth + dead
	_burner.pitch_scale = 0.9 + _rev * 0.2
	_burner.volume_db = -2.0 + linear_to_db(maxf(_boost, 0.001)) + stealth
	_air.pitch_scale = 0.8 + speed_t * 0.4
	_air.volume_db = -8.0 + linear_to_db(maxf(_drift * clampf(speed_t * 1.5, 0.0, 1.0), 0.001)) + stealth

	var boosting := jet.boost_time > 0.0 and alive
	if boosting and not _boost_was:
		if is_player:
			Sound.play("boost", 0.0)
		else:
			Sound.play_at("boost", global_position, -3.0)
	_boost_was = boosting
