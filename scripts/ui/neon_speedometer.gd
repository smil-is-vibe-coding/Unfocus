class_name NeonSpeedometer
extends Control
## Digital LCD dashboard (motorbike-cluster style): curved speed bar across the
## top with a red zone, big green 7-segment speed, blue divider and a TRIP
## odometer. A boost icon lights up on the left while boosting.

@export var max_kmh := 300.0
@export var color := Color(0.15, 0.55, 1.0)     ## Bar / LCD blue (kept for HUD API)
@export var accent := Color(1.0, 0.2, 0.3)       ## Red zone
@export var digit_color := Color(0.35, 1.0, 0.2) ## Speed digits (LCD green)
@export var lcd_blue := Color(0.25, 0.65, 1.0)

## Drawn at this design size, then scaled to fit the control (keeps it crisp + compact).
const DESIGN := Vector2(400, 212)

var kmh := 0.0
var boost := 0.0         ## 0..1 remaining boost (lights the boost icon)
var trip_km := 0.0
var _shown := 0.0

# 7-segment layout: a b c d e f g
const DIGITS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	" ": "", "-": "g",
}


func _process(delta: float) -> void:
	_shown = lerpf(_shown, kmh, 1.0 - exp(-12.0 * delta))
	trip_km += kmh / 3600.0 * delta
	queue_redraw()


func _draw() -> void:
	var k := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	# --- neon-glass housing (matches the rest of the HUD) ---
	var housing := StyleBoxFlat.new()
	housing.bg_color = Color(0.0, 0.01, 0.04, 0.72)
	housing.border_color = Color(lcd_blue, 0.85)
	housing.set_border_width_all(3)
	housing.set_corner_radius_all(26)
	housing.shadow_color = Color(lcd_blue, 0.35)
	housing.shadow_size = 14
	draw_style_box(housing, Rect2(Vector2.ZERO, DESIGN))
	var lcd := Rect2(Vector2(14, 12), DESIGN - Vector2(28, 24))
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(0.0, 0.02, 0.06)
	glass.set_corner_radius_all(14)
	glass.border_color = Color(lcd_blue, 0.25)
	glass.set_border_width_all(1)
	draw_style_box(glass, lcd)
	# Faint blue backlight glow toward the middle.
	draw_circle(lcd.get_center() + Vector2(0, -6), lcd.size.y * 0.55, Color(lcd_blue, 0.05))

	var t := clampf(_shown / max_kmh, 0.0, 1.0)

	# --- curved bar across the top ---
	var p0 := Vector2(lcd.position.x + 22, lcd.position.y + 68)
	var p1 := Vector2(lcd.position.x + lcd.size.x * 0.32, lcd.position.y + 30)
	var p2 := Vector2(lcd.end.x - 22, lcd.position.y + 28)
	var segs := 64
	var red_from := 0.85
	var prev := p0
	for i in range(1, segs + 1):
		var f := float(i) / segs
		var pt := _bezier(p0, p1, p2, f)
		var in_red := f > red_from
		var lit := f <= t
		var base := accent if in_red else lcd_blue.lerp(Color(0.2, 0.95, 1.0), f / red_from)
		if lit:
			draw_line(prev, pt, Color(base, 0.22), 16.0, true)
			draw_line(prev, pt, base.lerp(Color.WHITE, 0.15), 8.0, true)
		else:
			draw_line(prev, pt, Color(base, 0.12 if not in_red else 0.45), 8.0, true)
		prev = pt
	# Scale numbers (x50 km/h).
	var marks := int(round(max_kmh / 50.0))
	for m in marks + 1:
		var f := float(m) / marks
		var pt := _bezier(p0, p1, p2, f)
		var col := accent if f > red_from else Color(0.85, 0.9, 1.0)
		draw_string(NeonStyle.font(), pt + Vector2(-10, -12), str(m), HORIZONTAL_ALIGNMENT_CENTER, 20, 13, Color(col, 0.9))
	draw_string(NeonStyle.font(), lcd.position + Vector2(10, 22), "x50 km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.9, 1.0, 0.8))

	# --- boost badge (left) ---
	var badge_c := Vector2(lcd.position.x + 48, lcd.position.y + 104)
	var lit_boost := boost > 0.0
	var bcol := Color(1.0, 0.85, 0.1) if lit_boost else Color(0.4, 0.45, 0.55, 0.35)
	draw_arc(badge_c, 22.0, 0.0, TAU, 40, bcol, 3.0, true)
	if lit_boost:
		draw_circle(badge_c, 26.0, Color(bcol, 0.15))
	var icon := PowerUp.icon_texture(PowerUp.Type.BOOST)
	if icon:
		draw_texture_rect(icon, Rect2(badge_c - Vector2(16, 16), Vector2(32, 32)), false, bcol)

	# --- big 7-segment speed ---
	var speed_txt := str(roundi(_shown))
	speed_txt = speed_txt.lpad(3, " ")
	var dh := 66.0
	var dw := 36.0
	var digits_w := 3 * (dw + 10)
	var dx := lcd.get_center().x - digits_w * 0.5 + 10
	var dy := lcd.position.y + 70
	for i in 3:
		_seven_seg(Vector2(dx + i * (dw + 10), dy), dw, dh, speed_txt[i], digit_color)
	draw_string(NeonStyle.font(), Vector2(dx + digits_w + 4, dy + dh - 4), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(lcd_blue.lerp(Color.WHITE, 0.4), 0.95))

	# --- blue divider ---
	var ly := lcd.end.y - 46
	draw_line(Vector2(lcd.position.x + 18, ly), Vector2(lcd.end.x - 18, ly), Color(lcd_blue, 0.25), 9.0, true)
	draw_line(Vector2(lcd.position.x + 18, ly), Vector2(lcd.end.x - 18, ly), lcd_blue, 4.0, true)

	# --- TRIP odometer ---
	var odo := "%07.1f" % fmod(trip_km, 100000.0)   # 00000.0
	var ox := lcd.position.x + 70
	var oy := lcd.end.y - 36
	draw_string(NeonStyle.font(), Vector2(lcd.position.x + 18, oy + 22), "TRIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(lcd_blue.lerp(Color.WHITE, 0.3), 0.95))
	var ch_w := 15.0
	var x := ox
	for ch in odo:
		if ch == ".":
			draw_circle(Vector2(x + 1, oy + 25), 2.2, lcd_blue.lerp(Color.WHITE, 0.4))
			x += 7.0
			continue
		_seven_seg(Vector2(x, oy), ch_w, 26.0, ch, lcd_blue.lerp(Color.WHITE, 0.3), 3.2)
		x += ch_w + 5.0
	draw_string(NeonStyle.font(), Vector2(x + 4, oy + 24), "km", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(lcd_blue.lerp(Color.WHITE, 0.3), 0.9))


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## One slanted 7-segment digit. Unlit segments show a faint LCD "ghost".
func _seven_seg(pos: Vector2, w: float, h: float, ch: String, col: Color, thick := -1.0) -> void:
	var th := thick if thick > 0.0 else w * 0.2
	var g := th * 0.35
	var half := h * 0.5
	var segs := {
		"a": [Vector2(th * 0.5 + g, th * 0.5), Vector2(w - th * 0.5 - g, th * 0.5)],
		"b": [Vector2(w - th * 0.5, th * 0.5 + g), Vector2(w - th * 0.5, half - g)],
		"c": [Vector2(w - th * 0.5, half + g), Vector2(w - th * 0.5, h - th * 0.5 - g)],
		"d": [Vector2(th * 0.5 + g, h - th * 0.5), Vector2(w - th * 0.5 - g, h - th * 0.5)],
		"e": [Vector2(th * 0.5, half + g), Vector2(th * 0.5, h - th * 0.5 - g)],
		"f": [Vector2(th * 0.5, th * 0.5 + g), Vector2(th * 0.5, half - g)],
		"g": [Vector2(th * 0.5 + g, half), Vector2(w - th * 0.5 - g, half)],
	}
	var on: String = DIGITS.get(ch, "")
	var slant := 0.12
	for key in segs:
		var p: Array = segs[key]
		var poly := _seg_poly(p[0], p[1], th)
		for i in poly.size():
			poly[i] = pos + Vector2(poly[i].x + (h - poly[i].y) * slant, poly[i].y)
		if on.contains(key):
			draw_colored_polygon(_grow(poly, 1.6), Color(col, 0.18))
			draw_colored_polygon(poly, col.lerp(Color.WHITE, 0.2))
		else:
			draw_colored_polygon(poly, Color(col, 0.06))


static func _seg_poly(a: Vector2, b: Vector2, th: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * th * 0.5
	var e := d * th * 0.5
	return PackedVector2Array([a, a + e + n, b - e + n, b, b - e - n, a + e - n])


static func _grow(poly: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var out := PackedVector2Array()
	for p in poly:
		out.append(c + (p - c) * k)
	return out
