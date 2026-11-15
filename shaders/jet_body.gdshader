shader_type spatial;
// Dark glossy hull with a neon fresnel rim. Flat-shaded facets catch the rim
// differently, giving a faceted neon look.
render_mode cull_disabled;

uniform vec3 glow_color : source_color = vec3(0.0, 0.9, 1.0);
uniform float rim_strength = 2.4;
uniform float base_glow = 0.12;

void fragment() {
	ALBEDO = glow_color * 0.08 + vec3(0.02);
	METALLIC = 0.85;
	ROUGHNESS = 0.22;
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	EMISSION = glow_color * (base_glow + f * rim_strength);
}
