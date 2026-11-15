class_name NeonMinimap
extends Control
## Player-centred, heading-up neon radar. The road is drawn as a glowing band
## at its real width, clipped to the circle; rivals beyond the rim pin to the
## edge. Zooms out a little with speed.

@export var view_radius := 110.0       ## Metres from centre to rim at rest.
@export var speed_zoom := 0.9          ## Extra metres of view per m/s.

var track: RaceTrack
var jets: Array = []
var player: HoverJet

var _world_pts := PackedVector2Array()
var _heading := 0.0
var _view := 110.0
var _canvas: Control


func _ready() -> void:
	# The disc drawn by this node masks everything its child draws.
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(func() -> void: _draw_content(_canvas))
	add_child(_canvas)


func setup(t: RaceTrack, all_jets: Array, p: HoverJet) -> void:
	track = t
	jets = all_jets
	player = p
	var baked := track.curve.get_baked_points()
	_world_pts.clear()
	for i in range(0, baked.size(), 2):
		var w := track.to_global(baked[i])
		_world_pts.append(Vector2(w.x, w.z))
	_world_pts.append(_world_pts[0])
	_view = view_radius


func _process(delta: float) -> void:
	if player and is_instance_valid(player):
		var fwd := -player.global_basis.z
		var target := atan2(fwd.z, fwd.x)
		_heading = lerp_angle(_heading, target, 1.0 - exp(-8.0 * delta))
		var v := view_radius + player.linear_velocity.length() * speed_zoom
		_view = lerpf(_view, v, 1.0 - exp(-2.0 * delta))
	queue_redraw()
	if _canvas:
		_canvas.queue_redraw()


## World XZ -> map pixels (player at centre, heading up).
func _map(world: Vector2, c: Vector2, scale: float) -> Vector2:
	var rel := world - Vector2(player.global_position.x, player.global_position.z)
	return c + rel.rotated(-PI / 2.0 - _heading) * scale


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	draw_circle(c, r + 4.0, Color(0.0, 0.0, 0.05, 0.78))


func _draw_content(ci: CanvasItem) -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	for k in [0.33, 0.66]:
		ci.draw_arc(c, r * k, 0.0, TAU, 64, Color(NeonStyle.CYAN, 0.08), 1.0, true)
	if track == null or player == null or not is_instance_valid(player):
		NeonStyle.glow_arc(ci, c, r + 2.0, 0.0, TAU, Color(NeonStyle.CYAN, 0.8), 2.0, 96)
		return

	var scale := r / _view
	var road_w := maxf(track.width * scale, 4.0)
	var clip := r - 2.0

	# Road band, split into runs that stay inside the circle.
	var run := PackedVector2Array()
	var runs: Array[PackedVector2Array] = []
	for wp in _world_pts:
		var m := _map(wp, c, scale)
		if m.distance_to(c) < clip + road_w:
			run.append(m)
		elif run.size() > 1:
			runs.append(run)
			run = PackedVector2Array()
		else:
			run.clear()
	if run.size() > 1:
		runs.append(run)
	for rr in runs:
		ci.draw_polyline(rr, Color(NeonStyle.MAGENTA, 0.12), road_w + 8.0, true)
		ci.draw_polyline(rr, Color(0.08, 0.02, 0.12, 0.9), road_w, true)
		NeonStyle.glow_polyline(ci, rr, Color(NeonStyle.MAGENTA, 0.9), 2.0)

	# Start/finish line.
	var s := _map(Vector2(track.get_point(0.0).x, track.get_point(0.0).z), c, scale)
	if s.distance_to(c) < clip:
		ci.draw_circle(s, 4.0, Color.WHITE)

	NeonStyle.glow_arc(ci, c, r + 2.0, 0.0, TAU, Color(NeonStyle.CYAN, 0.85), 2.0, 96)

	# North marker riding the rim.
	var n_dir := Vector2(0, -1).rotated(-PI / 2.0 - _heading)
	var north := c + n_dir * (r - 12.0)
	ci.draw_string(NeonStyle.font(), north + Vector2(-6, 5), "N", HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color(NeonStyle.CYAN, 0.8))

	# Rivals (edge-pinned when off the map).
	for j in jets:
		var jet := j as HoverJet
		if jet == null or not is_instance_valid(jet) or jet == player or jet.is_invisible:
			continue
		var m := _map(Vector2(jet.global_position.x, jet.global_position.z), c, scale)
		var off := m - c
		var edge := off.length() > r - 8.0
		if edge:
			m = c + off.normalized() * (r - 8.0)
		var col: Color = jet.spec.color
		ci.draw_circle(m, 8.0, Color(col, 0.2 if not edge else 0.12))
		ci.draw_circle(m, 4.5 if not edge else 3.0, Color(col.lerp(Color.WHITE, 0.3), 1.0 if not edge else 0.6))

	# Player arrow, fixed at centre pointing up.
	var tip := c + Vector2(0, -13)
	var l := c + Vector2(-9, 10)
	var rr2 := c + Vector2(9, 10)
	var mid := c + Vector2(0, 4)
	ci.draw_circle(c, 16.0, Color(NeonStyle.CYAN, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([tip, l, mid, rr2]), Color(0.8, 1.0, 1.0))
	NeonStyle.glow_polyline(ci, PackedVector2Array([tip, l, mid, rr2, tip]), NeonStyle.CYAN, 1.5)
