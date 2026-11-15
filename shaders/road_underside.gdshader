shader_type spatial;
// Underside / sides of the floating road slab. UV.x: metres along, UV.y: 0 top .. 1 bottom on sides.
render_mode cull_disabled;

#include "res://shaders/neon_common.gdshaderinc"

uniform float hue_scale = 900.0;
uniform float hue_offset = 0.0;
uniform float hue_range = 1.0;

void fragment() {
	float d = UV.x;
	float v = UV.y;
	vec3 neon = theme_hue(d / hue_scale, hue_offset, hue_range);
	ALBEDO = vec3(0.01, 0.01, 0.02);
	METALLIC = 0.7;
	ROUGHNESS = 0.3;
	float band = aa_line(v - 0.08, 0.04) * 3.0 + aa_line(v - 0.92, 0.03) * 1.5;
	float ticks = aa_line(fract(d / 8.0) - 0.5, 0.01) * step(0.2, v) * step(v, 0.8) * 0.6;
	EMISSION = neon * (band + ticks);
}
