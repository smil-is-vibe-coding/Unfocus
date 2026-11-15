shader_type spatial;
// Hologram-style object: black body, glowing fresnel rim + optional wire edges.
// Per-object colour and look via instance uniforms (one shared material).
render_mode unshaded, cull_back;

#include "res://shaders/neon_common.gdshaderinc"

instance uniform vec3 tint : source_color = vec3(0.0, 1.0, 1.0);
instance uniform float wire = 0.0;          // 1 = draw BoxMesh face edges
instance uniform float hue_cycle = 0.0;     // >0 = animate the hue
instance uniform float pulse_phase = 0.0;
uniform float rim_power = 2.2;
uniform float rim_strength = 3.0;

void fragment() {
	vec3 c = tint;
	if (hue_cycle > 0.0) {
		c = neon_hue(TIME * 0.05 * hue_cycle + pulse_phase);
	}
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.5 + pulse_phase * 6.28);
	// BoxMesh UVs are a 3x2 atlas of faces: cell borders are the cube edges.
	vec2 cell = fract(UV * vec2(3.0, 2.0));
	float edge_d = min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y));
	float edges = (1.0 - smoothstep(0.0, 0.035 + fwidth(edge_d), edge_d)) * wire;
	ALBEDO = c * (f * rim_strength * pulse + edges * 3.0 + 0.015);
}
