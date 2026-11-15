class_name NeonStatusPanel
extends Control
## Bottom-left: segmented, slanted neon hull bar + five hexagon shield cells.

var health := 1.0          ## 0..1
var shield := 5
var max_shield := 5
var shield_color := NeonStyle.CYAN
var _shown := 1.0
var _hit_pulse := 0.0


func pulse() -> void:
	_hit_pulse = 1.0


func _process(delta: float) -> void:
	_shown = lerpf(_shown, health, 1.0 - exp(-8.0 * delta))
	_hit_pulse = maxf(_hit_pulse - delta * 2.5, 0.0)
	queue_redraw()


func _draw() -> void:
	var col := NeonStyle.RED.lerp(NeonStyle.GREEN, clampf(_shown * 1.3 - 0.15, 0.0, 1.0))
	if _hit_pulse > 0.0:
		col = col.lerp(Color.WHITE, _hit_pulse * 0.6)

	# HULL label.
	NeonStyle.text(self, Vector2(0, 18), "HULL", 15, col, HORIZONTAL_ALIGNMENT_LEFT)
	NeonStyle.text(self, Vector2(0, 18), "%d%%" % roundi(_shown * 100.0), 15, col, HORIZONTAL_ALIGNMENT_RIGHT, 300)

	# Segmented slanted bar.
	var segs := 20
	var w := 300.0
	var seg_w := w / segs
	var y := 28.0
	var h := 18.0
	var slant := 6.0
	var filled := _shown * segs
	for i in segs:
		var x := i * seg_w
		var poly := PackedVector2Array([
			Vector2(x + slant, y), Vector2(x + seg_w - 2 + slant, y),
			Vector2(x + seg_w - 2, y + h), Vector2(x, y + h)])
		if i < filled:
			var fill := clampf(filled - i, 0.0, 1.0)
			draw_colored_polygon(_grow(poly, 3.0), Color(col, 0.18 * fill))
			draw_colored_polygon(poly, Color(col.lerp(Color.WHITE, 0.25), 0.9 * fill))
		else:
			draw_polyline(_closed(poly), Color(col, 0.22), 1.0, true)

	# Shield hexes.
	NeonStyle.text(self, Vector2(0, 80), "SHIELD", 15, shield_color, HORIZONTAL_ALIGNMENT_LEFT)
	for i in max_shield:
		var c := Vector2(92 + i * 34, 74)
		var hex := NeonStyle.hexagon(c, 13.0, PI / 6.0)
		if i < shield:
			draw_colored_polygon(NeonStyle.hexagon(c, 17.0, PI / 6.0), Color(shield_color, 0.15))
			draw_colored_polygon(hex, Color(shield_color.lerp(Color.WHITE, 0.3), 0.85))
			NeonStyle.glow_polyline(self, hex, shield_color, 1.5)
		else:
			var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0) if shield == 0 else 1.0
			draw_polyline(hex, Color(NeonStyle.RED if shield == 0 else shield_color, 0.35 * blink), 1.5, true)


func _grow(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	var out := PackedVector2Array()
	for p in poly:
		out.append(c + (p - c) * (1.0 + d / 10.0))
	return out


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out
