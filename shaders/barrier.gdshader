shader_type spatial;
// Additive glowing glass barrier. UV.x: metres/4 along the track, UV.y: 0 bottom .. 1 top.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

#include "res://shaders/neon_common.gdshaderinc"

uniform float hue_scale = 900.0;
uniform float hue_offset = 0.0;
uniform float hue_range = 1.0;
uniform float glass = 0.04;
uniform float rail_strength = 1.3;

void fragment() {
	float d = UV.x * 4.0;
	float v = UV.y;
	vec3 neon = theme_hue(d / hue_scale + 0.2, hue_offset, hue_range);

	float rail = smoothstep(0.86, 0.97, v) * rail_strength;
	float base = smoothstep(0.12, 0.0, v) * rail_strength * 0.5;
	float posts = aa_line(fract(d / 6.0) - 0.5, 0.012) * 0.6;
	float fill = glass * (1.0 - v * 0.6);

	ALBEDO = neon * (rail + base + posts + fill);
	ALPHA = 1.0;
}
