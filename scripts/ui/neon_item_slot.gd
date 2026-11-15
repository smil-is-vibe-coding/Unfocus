class_name NeonItemSlot
extends Control
## Three hexagonal neon item slots. The selected one is raised, bigger and
## glowing; ← → change it, ↑ fires forward, ↓ fires backward.

var slots: Array = [PowerUp.Type.NONE, PowerUp.Type.NONE, PowerUp.Type.NONE]
var selected := 0
var ammo_frac := 0.0     ## Machine gun rounds left (0..1), 0 = hidden.
var caption := ""
var _sel_x := 0.0        ## Animated highlight position.
var _pops: Array[float] = [0.0, 0.0, 0.0]
var _prev: Array = [-1, -1, -1]


func _process(delta: float) -> void:
	for i in 3:
		if slots[i] != _prev[i]:
			if slots[i] != PowerUp.Type.NONE:
				_pops[i] = 1.0
			_prev[i] = slots[i]
		_pops[i] = maxf(_pops[i] - delta * 3.0, 0.0)
	_sel_x = lerpf(_sel_x, float(selected), 1.0 - exp(-14.0 * delta))
	queue_redraw()


func _draw() -> void:
	var spacing := 74.0
	var base := Vector2(size.x * 0.5, 50.0)
	# Highlight plate slides under the selected slot.
	var hc := base + Vector2((_sel_x - 1.0) * spacing, 0)

	for i in 3:
		var t: int = slots[i]
		var sel := i == selected
		var c := base + Vector2((i - 1) * spacing, -6.0 if sel else 4.0)
		var empty := t == PowerUp.Type.NONE
		var col := Color(0.5, 0.55, 0.7, 0.55) if empty else PowerUp.color_of(t)
		if not sel and not empty:
			col = Color(col, 0.6)
		var r := (34.0 if sel else 25.0) + _pops[i] * 6.0
		var hex := NeonStyle.hexagon(c, r, PI / 6.0)
		draw_colored_polygon(hex, Color(0.0, 0.0, 0.05, 0.75))
		if sel and not empty:
			draw_colored_polygon(NeonStyle.hexagon(c, r + 8.0, PI / 6.0), Color(col, 0.14 + _pops[i] * 0.2))
		NeonStyle.glow_polyline(self, hex, col, 2.5 if sel else 1.2)
		if sel:
			NeonStyle.glow_polyline(self, NeonStyle.hexagon(c, r - 6.0, 0.0), Color(col, 0.3), 1.0)
		if not empty:
			var tex := PowerUp.icon_texture(t)
			if tex:
				var s := r * 1.1
				if sel:
					for layer in [[1.35, 0.12], [1.15, 0.25]]:
						var sz: float = s * layer[0]
						draw_texture_rect(tex, Rect2(c - Vector2.ONE * sz * 0.5, Vector2.ONE * sz), false, Color(col, layer[1]))
				draw_texture_rect(tex, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false, col.lerp(Color.WHITE, 0.3 if sel else 0.0))
		else:
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), col, 2.0, true)
		if sel and ammo_frac > 0.0:
			NeonStyle.glow_arc(self, c, r + 12.0, -PI / 2.0, -PI / 2.0 + TAU * ammo_frac, PowerUp.color_of(PowerUp.Type.MACHINE_GUN), 3.0)

	# Selector arrows + caption.
	var dim := Color(0.7, 0.8, 1.0, 0.7)
	NeonStyle.text(self, base + Vector2(-spacing * 1.5 - 30, 8), "◀", 18, dim, HORIZONTAL_ALIGNMENT_CENTER, 30)
	NeonStyle.text(self, base + Vector2(spacing * 1.5, 8), "▶", 18, dim, HORIZONTAL_ALIGNMENT_CENTER, 30)
	var cur: int = slots[selected]
	var cap_col := PowerUp.color_of(cur) if cur != PowerUp.Type.NONE else Color(0.6, 0.65, 0.8)
	NeonStyle.text(self, Vector2(0, size.y - 22), caption, 15, cap_col, HORIZONTAL_ALIGNMENT_CENTER, size.x)
