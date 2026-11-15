class_name LevelCatalog
extends RefCounted
## Race circuits, easiest first. Layouts are inspired by famous Grand Prix
## circuits (scaled to ~2.2-3 km, generated + validated by
## tools/circuit_designer.py), each with its own colour vibe.

static var _cache: Array[LevelDef] = []


static func all() -> Array[LevelDef]:
	if _cache.is_empty():
		_cache = [_autodromo(), _airfield(), _ardennes(), _crossover(), _harbour()]
	return _cache


static func get_level(i: int) -> LevelDef:
	var list := all()
	return list[clampi(i, 0, list.size() - 1)]


## 1 - Italian "temple of speed": huge straights, three chicanes, a long Parabolica.
static func _autodromo() -> LevelDef:
	var l := LevelDef.new()
	l.id = "autodromo"
	l.display_name = "AUTODROMO NEON"
	l.subtitle = "Inspired by the Italian temple of speed. Flat out on long straights, brake hard for three chicanes and the long Parabolica."
	l.difficulty = 1
	l.ui_color = Color(1.0, 0.2, 0.85)
	l.width = 22.0
	l.points = PackedVector3Array([
		Vector3(0, 0, -70), Vector3(0, 0, -315), Vector3(0, 0, -546), Vector3(2.8, 0, -623),
		Vector3(29.4, 0, -682.5), Vector3(33.6, 0, -738.5), Vector3(15.4, 0, -801.5), Vector3(28, 0, -875),
		Vector3(112, 0, -980), Vector3(224, 0, -1022), Vector3(269.5, 0, -1022), Vector3(299.6, 0, -988.4),
		Vector3(341.6, 0, -983.5), Vector3(371, 0, -1008), Vector3(420, 0, -976.5), Vector3(453.6, 0, -922.6),
		Vector3(467.6, 0, -861), Vector3(469, 0, -805), Vector3(469, 0, -630), Vector3(469, 0, -546),
		Vector3(456.4, 0, -490), Vector3(485.8, 0, -448), Vector3(485.8, 0, -406), Vector3(463.4, 0, -364),
		Vector3(463.4, 0, -245), Vector3(463.4, 0, -126), Vector3(453.6, 0, -28), Vector3(409.5, 0, 49),
		Vector3(325.5, 0, 91), Vector3(224, 0, 98), Vector3(126, 0, 73.5), Vector3(56, 0, 35),
		Vector3(15.4, 0, -10.5)
	])
	return l


## 2 - British airfield circuit: fast flowing sweepers and the Maggotts/Becketts esses.
static func _airfield() -> LevelDef:
	var l := LevelDef.new()
	l.id = "airfield"
	l.display_name = "AIRFIELD FLOW"
	l.subtitle = "Inspired by the classic British airfield track. High-speed sweepers, a snaking esses section and a long hangar straight."
	l.difficulty = 2
	l.ui_color = Color(1.0, 0.55, 0.15)
	l.width = 22.0
	l.points = PackedVector3Array([
		Vector3(36, 0, 0), Vector3(208, 0, 0), Vector3(312, 0, 28), Vector3(360, 0, 96), Vector3(376, 0, 160),
		Vector3(339.2, 0, 222.4), Vector3(384, 0, 284), Vector3(347.2, 0, 345.6), Vector3(387.2, 0, 404),
		Vector3(420, 0, 460), Vector3(448, 0, 552), Vector3(472, 0, 620), Vector3(480, 0, 664),
		Vector3(448, 0, 712), Vector3(388, 0, 724), Vector3(345.6, 0, 702.4), Vector3(302.4, 0, 724),
		Vector3(264, 0, 718.4), Vector3(192, 0, 688), Vector3(120, 0, 632), Vector3(88, 0, 560),
		Vector3(48, 0, 552), Vector3(16, 0, 512), Vector3(24, 0, 416), Vector3(20, 0, 264), Vector3(-12, 0, 200),
		Vector3(-56, 0, 168), Vector3(-65.6, 0, 112), Vector3(-44, 0, 60), Vector3(-12, 0, 17.6)
	])
	l.hue_offset = 0.88     # magenta -> red -> orange -> gold
	l.hue_range = 0.24
	l.gate_colors = [Color(1.0, 0.45, 0.1), Color(1.0, 0.15, 0.5), Color(1.0, 0.8, 0.2)]
	l.aurora_low = Color(1.0, 0.45, 0.1)
	l.aurora_mid = Color(1.0, 0.15, 0.45)
	l.aurora_high = Color(0.55, 0.1, 0.9)
	l.under_low = Color(1.0, 0.6, 0.1)
	l.under_high = Color(1.0, 0.1, 0.35)
	l.nebula_a = Color(0.35, 0.05, 0.12)
	l.nebula_b = Color(0.3, 0.12, 0.02)
	l.aurora_strength = 0.85
	l.nebula_strength = 0.35
	l.ambient = Color(0.35, 0.15, 0.15)
	l.fog = Color(0.18, 0.05, 0.06)
	l.key_light = Color(1.0, 0.6, 0.4)
	l.decor_palette = [Color(1.0, 0.5, 0.1), Color(1.0, 0.15, 0.5), Color(1.0, 0.85, 0.2), Color(0.7, 0.15, 1.0)]
	l.planet_a = Color(1.0, 0.4, 0.1)
	l.planet_b = Color(1.0, 0.15, 0.55)
	return l


## 3 - Belgian forest classic: the Eau Rouge / Raidillon climb, a huge straight, hairpins.
static func _ardennes() -> LevelDef:
	var l := LevelDef.new()
	l.id = "ardennes"
	l.display_name = "ARDENNES RIDGE"
	l.subtitle = "Inspired by the legendary forest circuit. Dive down to Eau Rouge, climb Raidillon, two hairpins and a Bus Stop chicane."
	l.difficulty = 3
	l.ui_color = Color(0.35, 1.0, 0.3)
	l.width = 20.0
	l.points = PackedVector3Array([
		Vector3(0, 0, 72), Vector3(0, 0, -144), Vector3(18, 0, -240), Vector3(60, -1, -261.6),
		Vector3(86.4, -2, -222), Vector3(86.4, -5, -72), Vector3(86.4, -10, 96), Vector3(69.6, -12, 168),
		Vector3(114, -4, 228), Vector3(102, 6, 300), Vector3(180, 10, 540), Vector3(276, 12, 780),
		Vector3(300, 12, 854.4), Vector3(343.2, 11, 876), Vector3(348, 10, 933.6), Vector3(360, 9, 996),
		Vector3(324, 8, 1038), Vector3(258, 6, 1056), Vector3(206.4, 5, 1026), Vector3(198, 4, 972),
		Vector3(180, 2, 888), Vector3(132, 1, 842.4), Vector3(72, 0, 842.4), Vector3(0, 0, 816),
		Vector3(-36, 0, 756), Vector3(-42, 0, 672), Vector3(-36, 0, 504), Vector3(-24, 0, 360),
		Vector3(-21.6, 0, 294), Vector3(19.2, 0, 235.2), Vector3(-9.6, 0, 180), Vector3(0, 0, 134.4)
	])
	l.hue_offset = 0.25     # lime -> green -> teal
	l.hue_range = 0.22
	l.gate_colors = [Color(0.4, 1.0, 0.2), Color(0.0, 1.0, 0.75), Color(0.8, 1.0, 0.1)]
	l.aurora_low = Color(0.5, 1.0, 0.1)
	l.aurora_mid = Color(0.0, 1.0, 0.6)
	l.aurora_high = Color(0.0, 0.6, 0.5)
	l.under_low = Color(0.3, 1.0, 0.2)
	l.under_high = Color(0.0, 0.5, 0.4)
	l.nebula_a = Color(0.02, 0.2, 0.08)
	l.nebula_b = Color(0.08, 0.18, 0.0)
	l.aurora_strength = 0.7
	l.ambient = Color(0.1, 0.25, 0.12)
	l.fog = Color(0.02, 0.1, 0.04)
	l.fog_density = 0.0016
	l.key_light = Color(0.5, 1.0, 0.6)
	l.decor_palette = [Color(0.4, 1.0, 0.2), Color(0.0, 1.0, 0.7), Color(0.9, 1.0, 0.2), Color(0.1, 0.8, 1.0)]
	l.planet_a = Color(0.3, 1.0, 0.3)
	l.planet_b = Color(0.0, 0.9, 0.7)
	return l


## 4 - Japanese figure-eight: esses, a hairpin, Spoon, and a bridge crossover.
static func _crossover() -> LevelDef:
	var l := LevelDef.new()
	l.id = "crossover"
	l.display_name = "CROSSOVER 8"
	l.subtitle = "Inspired by the famous figure-eight. Rhythm through the esses, a tight hairpin, Spoon, then fly over the bridge into the chicane."
	l.difficulty = 4
	l.ui_color = Color(0.3, 0.75, 1.0)
	l.width = 20.0
	l.points = PackedVector3Array([
		Vector3(344.5, 0, 184.6), Vector3(429, 0, 182), Vector3(494, 0, 143), Vector3(546, 0, 52),
		Vector3(533, 0, -52), Vector3(481, 0, -117), Vector3(416, 1, -101.4), Vector3(364, 1, -156),
		Vector3(299, 2, -127.4), Vector3(247, 2, -169), Vector3(182, 3, -156), Vector3(130, 3, -117),
		Vector3(78, 2, -65), Vector3(0, 0, 0), Vector3(-91, 0, 78), Vector3(-195, 1, 130), Vector3(-299, 2, 145.6),
		Vector3(-357.5, 2, 117), Vector3(-351, 3, 62.4), Vector3(-338, 4, -26), Vector3(-377, 6, -117),
		Vector3(-416, 8, -182), Vector3(-390, 10, -234), Vector3(-312, 12, -244.4), Vector3(-234, 14, -201.5),
		Vector3(-117, 15, -104), Vector3(0, 15, 0), Vector3(78, 11, 71.5), Vector3(143, 6, 130),
		Vector3(184.6, 2, 145.6), Vector3(228.8, 1, 205.4), Vector3(283.4, 0, 184.6)
	])
	l.hue_offset = 0.5      # cyan -> sky -> blue -> violet (glacier)
	l.hue_range = 0.22
	l.gate_colors = [Color(0.3, 0.9, 1.0), Color(0.5, 0.6, 1.0), Color(0.85, 0.95, 1.0)]
	l.aurora_low = Color(0.4, 0.9, 1.0)
	l.aurora_mid = Color(0.3, 0.5, 1.0)
	l.aurora_high = Color(0.75, 0.6, 1.0)
	l.under_low = Color(0.2, 0.6, 1.0)
	l.under_high = Color(0.5, 0.3, 1.0)
	l.nebula_a = Color(0.02, 0.08, 0.25)
	l.nebula_b = Color(0.1, 0.05, 0.3)
	l.aurora_strength = 0.8
	l.ambient = Color(0.15, 0.2, 0.4)
	l.fog = Color(0.03, 0.06, 0.16)
	l.key_light = Color(0.6, 0.8, 1.0)
	l.decor_palette = [Color(0.3, 0.9, 1.0), Color(0.5, 0.5, 1.0), Color(0.9, 0.95, 1.0), Color(0.2, 0.5, 1.0)]
	l.planet_a = Color(0.4, 0.7, 1.0)
	l.planet_b = Color(0.8, 0.85, 1.0)
	return l


## 5 - Harbour street circuit, inverted world: narrow, twisty, a hairpin and a tunnel sweep.
static func _harbour() -> LevelDef:
	var l := LevelDef.new()
	l.id = "harbour"
	l.display_name = "HARBOUR NEGATIVE"
	l.subtitle = "Inspired by the glamorous harbour street race - in negative. Narrow, climbing, a hairpin, the tunnel sweep and the swimming-pool chicanes."
	l.difficulty = 5
	l.ui_color = Color(0.92, 0.92, 0.95)
	l.width = 16.0
	l.points = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(196, 0, 0), Vector3(350, 0, -11.2), Vector3(427, 1, -49),
		Vector3(445.2, 3, -133), Vector3(483, 8, -266), Vector3(553, 12, -406), Vector3(585.2, 13, -497),
		Vector3(548.8, 13, -567), Vector3(585.2, 13, -630), Vector3(669.2, 13, -646.8), Vector3(753.2, 11, -604.8),
		Vector3(792.4, 8, -520.8), Vector3(778.4, 6, -450.8), Vector3(728, 5, -420), Vector3(697.2, 4, -366.8),
		Vector3(736.4, 3, -316.4), Vector3(812, 2, -296.8), Vector3(819, 2, -210), Vector3(777, 2, -126),
		Vector3(707, 1, -63), Vector3(637, 0, 14), Vector3(588, 0, 58.8), Vector3(532, 0, 42),
		Vector3(490, 0, 89.6), Vector3(406, 0, 117.6), Vector3(357, 0, 86.8), Vector3(301, 0, 126),
		Vector3(238, 0, 105), Vector3(140, 0, 140), Vector3(42, 0, 147), Vector3(-35, 0, 112), Vector3(-63, 0, 49)
	])
	# Source colours chosen so that, inverted, everything reads as black ink on white.
	l.hue_offset = 0.5
	l.hue_range = 0.15
	l.gate_colors = [Color(0.9, 0.9, 0.9), Color(0.7, 0.75, 0.8), Color(0.9, 0.85, 0.8)]
	l.aurora_strength = 0.35
	l.nebula_strength = 0.15
	l.invert = true
	l.desaturate = 0.8
	return l
