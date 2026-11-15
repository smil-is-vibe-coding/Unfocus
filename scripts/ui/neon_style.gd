class_name NeonStyle
extends RefCounted
## Shared neon UI helpers: a techy font, glowing labels and glow-stroke drawing
## (layered translucent strokes fake a bloom in 2D).

const CYAN := Color(0.2, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.85)
const AMBER := Color(1.0, 0.7, 0.15)
const RED := Color(1.0, 0.25, 0.25)
const GREEN := Color(0.35, 1.0, 0.5)

static var _font: Font


static func font() -> Font:
	# Bundled (not a system font) so the web build looks identical to desktop:
	# Barlow Semi Condensed Bold + Noto Sans Math fallback for arrows/shapes.
	if _font == null:
		_font = load("res://resources/ui_font.tres")
	return _font


## Label with a hot white core, coloured outline and wide coloured halo.
static func label(text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	style_label(l, size, color)
	return l


static func style_label(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.55))
	l.add_theme_color_override("font_outline_color", Color(color, 0.95))
	l.add_theme_constant_override("outline_size", maxi(2, size / 12))
	l.add_theme_color_override("font_shadow_color", Color(color, 0.45))
	l.add_theme_constant_override("shadow_outline_size", maxi(4, size / 4))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func set_label_color(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.55))
	l.add_theme_color_override("font_outline_color", Color(color, 0.95))
	l.add_theme_color_override("font_shadow_color", Color(color, 0.45))


## Glowing arc: wide faint passes under a thin hot core.
static func glow_arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, color: Color, width := 4.0, points := 64) -> void:
	if absf(a1 - a0) < 0.001:
		return
	for pass_data in [[width * 4.0, 0.07], [width * 2.2, 0.16], [width, 0.85]]:
		ci.draw_arc(c, r, a0, a1, points, Color(color, color.a * pass_data[1]), pass_data[0], true)
	ci.draw_arc(c, r, a0, a1, points, Color(color.lerp(Color.WHITE, 0.6), color.a), maxf(width * 0.35, 1.0), true)


static func glow_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 3.0) -> void:
	for pass_data in [[width * 4.0, 0.07], [width * 2.2, 0.16], [width, 0.9]]:
		ci.draw_line(a, b, Color(color, color.a * pass_data[1]), pass_data[0], true)
	ci.draw_line(a, b, Color(color.lerp(Color.WHITE, 0.6), color.a), maxf(width * 0.35, 1.0), true)


static func glow_polyline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width := 3.0) -> void:
	for pass_data in [[width * 4.0, 0.06], [width * 2.2, 0.14], [width, 0.85]]:
		ci.draw_polyline(pts, Color(color, color.a * pass_data[1]), pass_data[0], true)
	ci.draw_polyline(pts, Color(color.lerp(Color.WHITE, 0.6), color.a), maxf(width * 0.35, 1.0), true)


static func hexagon(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := rot + TAU * i / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0) -> void:
	var f := font()
	ci.draw_string_outline(f, pos, s, align, width, size, maxi(4, size / 3), Color(color, 0.35))
	ci.draw_string_outline(f, pos, s, align, width, size, maxi(2, size / 12), Color(color, 0.9))
	ci.draw_string(f, pos, s, align, width, size, color.lerp(Color.WHITE, 0.55))


## Keyboard/gamepad-navigable neon button. Plays UI sounds on focus/press.
static func button(caption: String, color := CYAN, min_size := Vector2(320, 56), font_size := 24) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(color, 0.8))
	b.add_theme_constant_override("outline_size", 0)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Plain and calm: flat dark row; the focused one gets a bright left bar.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.07, 0.6)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(color, 0.0)
	normal.border_width_left = 4
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 0.92)
	hot.border_color = color
	hot.shadow_color = Color(color, 0.25)
	hot.shadow_size = 6
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.focus_entered.connect(func() -> void: Sound.play("ui_move"))
	b.pressed.connect(func() -> void: Sound.play("ui_select"))
	return b


## Bottom key-prompt bar used by every menu screen.
static func footer(text := "↑ ↓  MOVE        ENTER  SELECT        ESC  BACK") -> Label:
	var l := label(text, 15, Color(0.65, 0.75, 1.0))
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -46
	l.offset_bottom = -18
	l.offset_left = 60
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


## Dark rounded info panel used on the right of menu screens.
static func panel(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.015, 0.05, 0.78)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(accent, 0.6)
	sb.border_width_top = 3
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	return p
