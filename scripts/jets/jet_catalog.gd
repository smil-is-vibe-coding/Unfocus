class_name JetCatalog
extends RefCounted
## The selectable jet classes.

static var _cache: Array[JetSpec] = []


static func all() -> Array[JetSpec]:
	if _cache.is_empty():
		_cache = [_viper(), _dart(), _manta(), _titan(), _wraith()]
	return _cache


static func get_spec(index: int) -> JetSpec:
	var list := all()
	return list[clampi(index, 0, list.size() - 1)]


static func _viper() -> JetSpec:
	var s := JetSpec.new()
	s.id = "viper"
	s.display_name = "VIPER"
	s.tagline = "Balanced interceptor. Good at everything, best at nothing."
	s.ability_name = "Reinforced Hull"
	s.ability_desc = "Takes 15% less damage from all weapons."
	s.pros = PackedStringArray(["Well-rounded handling", "Takes less damage"])
	s.cons = PackedStringArray(["No standout strength"])
	s.color = Color(0.0, 0.9, 1.0)
	s.accent = Color(1.0, 0.25, 0.8)
	s.top_speed = 62.0
	s.accel = 16.5
	s.turn_rate_low = 120.0
	s.turn_rate_high = 52.0
	s.grip = 5.0
	s.max_lateral_accel = 27.0
	s.mass = 900.0
	s.max_health = 100.0
	s.damage_taken_mult = 0.85
	s.length = 4.6
	s.body_width = 0.62
	s.body_height = 0.42
	s.wing_span = 4.4
	s.wing_root_chord = 2.0
	s.wing_tip_chord = 0.7
	s.wing_sweep = 1.4
	s.wing_z = 0.6
	s.wing_dihedral = 0.12
	s.fin_count = 1
	s.engine_count = 2
	return s


static func _dart() -> JetSpec:
	var s := JetSpec.new()
	s.id = "dart"
	s.display_name = "DART"
	s.tagline = "A needle with an engine. Unmatched top speed, glass body."
	s.ability_name = "Afterburner"
	s.ability_desc = "Boosts (item and drift) last 40% longer."
	s.pros = PackedStringArray(["Highest top speed", "Fastest acceleration", "Longer boosts"])
	s.cons = PackedStringArray(["Fragile (70 HP)", "Slides wide in corners"])
	s.color = Color(1.0, 0.85, 0.1)
	s.accent = Color(1.0, 0.3, 0.1)
	s.top_speed = 72.0
	s.accel = 20.0
	s.power_falloff = 2.3
	s.turn_rate_low = 105.0
	s.turn_rate_high = 38.0
	s.grip = 3.0
	s.max_lateral_accel = 20.0
	s.mass = 700.0
	s.max_health = 70.0
	s.boost_mult = 1.4
	s.length = 5.4
	s.body_width = 0.45
	s.body_height = 0.36
	s.nose_ratio = 0.45
	s.wing_span = 3.0
	s.wing_root_chord = 1.8
	s.wing_tip_chord = 0.35
	s.wing_sweep = 1.6
	s.wing_z = 1.2
	s.wing_dihedral = 0.0
	s.canards = true
	s.fin_count = 1
	s.fin_height = 0.55
	s.engine_count = 1
	s.engine_radius = 0.3
	return s


static func _manta() -> JetSpec:
	var s := JetSpec.new()
	s.id = "manta"
	s.display_name = "MANTA"
	s.tagline = "Wide flying wing that carves corners like it's on rails."
	s.ability_name = "Gun Stabilisers"
	s.ability_desc = "Machine gun deals 50% more damage."
	s.pros = PackedStringArray(["Best handling and grip", "Strongest machine gun"])
	s.cons = PackedStringArray(["Low top speed", "Below-average armour"])
	s.color = Color(0.2, 1.0, 0.5)
	s.accent = Color(0.3, 0.5, 1.0)
	s.top_speed = 56.0
	s.accel = 16.0
	s.turn_rate_low = 150.0
	s.turn_rate_high = 72.0
	s.grip = 8.5
	s.max_lateral_accel = 35.0
	s.mass = 850.0
	s.max_health = 85.0
	s.gun_damage_mult = 1.5
	s.length = 4.0
	s.body_width = 0.7
	s.body_height = 0.32
	s.nose_ratio = 0.28
	s.wing_span = 6.6
	s.wing_root_chord = 3.0
	s.wing_tip_chord = 0.9
	s.wing_sweep = 1.3
	s.wing_z = 0.4
	s.wing_dihedral = -0.1
	s.fin_count = 2
	s.fin_height = 0.45
	s.engine_count = 2
	s.engine_radius = 0.2
	return s


static func _titan() -> JetSpec:
	var s := JetSpec.new()
	s.id = "titan"
	s.display_name = "TITAN"
	s.tagline = "Armoured hauler. Slow to wind up, impossible to stop."
	s.ability_name = "Juggernaut"
	s.ability_desc = "Twice the mass to shove rivals aside, and explosions barely move it."
	s.pros = PackedStringArray(["160 HP", "Wins every collision", "Shrugs off missile knock-ups"])
	s.cons = PackedStringArray(["Slow acceleration", "Wide turning circle"])
	s.color = Color(1.0, 0.4, 0.1)
	s.accent = Color(1.0, 0.9, 0.2)
	s.top_speed = 57.0
	s.accel = 11.0
	s.turn_rate_low = 85.0
	s.turn_rate_high = 40.0
	s.grip = 5.0
	s.max_lateral_accel = 23.0
	s.mass = 1800.0
	s.max_health = 160.0
	s.knockback_mult = 0.35
	s.length = 5.8
	s.body_width = 0.95
	s.body_height = 0.6
	s.nose_ratio = 0.22
	s.wing_span = 4.8
	s.wing_root_chord = 2.6
	s.wing_tip_chord = 1.5
	s.wing_sweep = 0.6
	s.wing_z = 0.9
	s.wing_dihedral = 0.0
	s.fin_count = 2
	s.fin_height = 0.8
	s.engine_count = 3
	s.engine_radius = 0.3
	return s


static func _wraith() -> JetSpec:
	var s := JetSpec.new()
	s.id = "wraith"
	s.display_name = "WRAITH"
	s.tagline = "Stealth drifter. Lives sideways and vanishes on command."
	s.ability_name = "Phase Drive"
	s.ability_desc = "Invisibility lasts twice as long; drifts charge boost 60% faster."
	s.pros = PackedStringArray(["Best drift boosts", "Double invisibility time"])
	s.cons = PackedStringArray(["Loose grip", "Light armour (80 HP)"])
	s.color = Color(0.7, 0.3, 1.0)
	s.accent = Color(0.1, 1.0, 0.9)
	s.top_speed = 64.0
	s.accel = 17.0
	s.turn_rate_low = 130.0
	s.turn_rate_high = 55.0
	s.grip = 3.5
	s.max_lateral_accel = 23.0
	s.mass = 800.0
	s.max_health = 80.0
	s.invis_mult = 2.0
	s.drift_boost_mult = 1.6
	s.length = 5.0
	s.body_width = 0.55
	s.body_height = 0.34
	s.nose_ratio = 0.38
	s.wing_span = 5.0
	s.wing_root_chord = 2.4
	s.wing_tip_chord = 0.4
	s.wing_sweep = 2.4
	s.wing_z = 0.8
	s.wing_dihedral = -0.35
	s.canards = true
	s.fin_count = 2
	s.fin_height = 0.5
	s.engine_count = 2
	s.engine_radius = 0.18
	return s
