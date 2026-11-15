class_name TrackPreview
extends Control
## Draws a circuit's outline (top-down) for the level select screen, with the
## start line and racing direction. Raised sections (bridges) glow brighter.

var level: LevelDef:
	set(v):
		level = v
		_build()
		queue_redraw()

var _pts := PackedVector2Array()
var _heights := PackedFloat32Array()
var length_m := 0.0


func _build() -> void:
	_pts.clear()
	_heights.clear()
	if level == null or level.points.size() < 3:
		return
	var curve := Curve3D.new()
	curve.bake_interval = 4.0
	var n := level.points.size()
	for i in n + 1:
		var p := level.points[i % n]
		var h := (level.points[(i + 1) % n] - level.points[(i - 1 + n) % n]) / 6.0
		curve.add_point(p, -h, h)
	length_m = curve.get_baked_length()
	for p in curve.get_baked_points():
		_pts.append(Vector2(p.x, p.z))
		_heights.append(p.y)


func _draw() -> void:
	if _pts.size() < 2:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var ext := hi - lo
	var s := minf((size.x - 40.0) / maxf(ext.x, 1.0), (size.y - 40.0) / maxf(ext.y, 1.0))
	var off := (size - ext * s) * 0.5 - lo * s
	var col := level.ui_color
	var mapped := PackedVector2Array()
	for p in _pts:
		mapped.append(p * s + off)
	draw_polyline(mapped, Color(col, 0.15), 14.0, true)
	draw_polyline(mapped, Color(col, 0.9), 3.0, true)
	# Raised parts (bridges, climbs) drawn brighter on top.
	var max_h := 0.0
	for h in _heights:
		max_h = maxf(max_h, h)
	if max_h > 8.0:
		for i in range(1, mapped.size()):
			if _heights[i] > max_h * 0.7:
				draw_line(mapped[i - 1], mapped[i], Color.WHITE, 4.0, true)
	# Start line + direction arrow.
	var a := mapped[0]
	var b := mapped[mini(8, mapped.size() - 1)]
	var d := (b - a).normalized()
	draw_circle(a, 6.0, Color.WHITE)
	draw_line(a, a + d * 26.0, Color.WHITE, 2.5, true)
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([a + d * 34.0, a + d * 22.0 + n * 6.0, a + d * 22.0 - n * 6.0]), Color.WHITE)
