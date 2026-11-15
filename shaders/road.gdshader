shader_type spatial;
// Glossy black road with a faint neon grid and steady neon edge lines whose
// colour drifts slowly along the length of the track (static, no animation). UV.x: 0..1 across, UV.y: metres along the track.

#include "res://shaders/neon_common.gdshaderinc"

uniform float track_length = 1000.0;
uniform float hue_scale = 900.0;      // metres per full rainbow cycle
uniform float hue_offset = 0.0;
uniform float hue_range = 1.0;
uniform float grid_strength = 0.07;
uniform float edge_strength = 1.6;

void fragment() {
	float x = UV.x;
	float d = UV.y;
	vec3 neon = theme_hue(d / hue_scale, hue_offset, hue_range);
	vec3 neon2 = theme_hue(d / hue_scale + 0.45, hue_offset, hue_range);

	ALBEDO = vec3(0.008, 0.008, 0.015);
	METALLIC = 0.5;
	ROUGHNESS = 0.32;
	SPECULAR = 0.35;

	vec3 e = vec3(0.0);

	// Grid.
	vec2 g = vec2(x * 10.0, d / 5.0);
	vec2 gd = abs(fract(g) - 0.5);
	float grid = max(aa_line(gd.x - 0.5, 0.02), aa_line(gd.y - 0.5, 0.02));
	e += mix(neon, neon2, x) * grid * grid_strength;

	// Edge neon tubes + thin inner line.
	float edge = min(x, 1.0 - x);
	e += neon * aa_line(edge - 0.025, 0.012) * edge_strength;
	e += neon2 * aa_line(edge - 0.06, 0.003) * edge_strength * 0.35;

	// Centre dashes.
	if (mod(d, 10.0) < 5.0) {
		e += vec3(0.8, 0.9, 1.0) * aa_line(x - 0.5, 0.004) * 0.6;
	}

	// Start / finish line.
	float sd = min(d, track_length - d);
	if (sd < 4.0) {
		float cx = floor(x * 22.0);
		float cy = floor(d / 1.0);
		e += (mod(cx + cy, 2.0) < 1.0 ? vec3(0.0) : vec3(1.2));
	}

	EMISSION = e;
}
