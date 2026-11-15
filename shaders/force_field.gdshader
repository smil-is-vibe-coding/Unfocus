shader_type spatial;
// Edge force field. Invisible until something hits it: impacts light up a
// hexagonal grid around the contact point with an expanding ripple that fades.
// UV.x = metres along the track, UV.y = metres above the road.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

const int MAX_IMPACTS = 16;

uniform vec4 impacts[16];        // xyz = world position, w = start time (-1 = unused)
uniform vec4 impact_colors[16];  // rgb = colour, a = strength
uniform float now = 0.0;
uniform float hex_size = 0.85;
uniform float ripple_speed = 16.0;
uniform float fade_time = 1.0;
uniform float radius = 7.0;
uniform float wall_height = 5.0;
// Faint warning glow when the player gets close.
uniform vec3 focus_pos = vec3(0.0, -10000.0, 0.0);
uniform vec3 focus_color : source_color = vec3(0.4, 0.9, 1.0);
uniform float focus_strength = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.7320508))), p.x);
}

// 0 at a hex cell edge, 0.5 at the centre.
float hex_edge(vec2 uv) {
	uv /= hex_size;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	return 0.5 - hex_dist(g);
}

void fragment() {
	float e = hex_edge(UV);
	float line = 1.0 - smoothstep(0.0, 0.05 + fwidth(e) * 1.5, e);
	float cell_glow = 0.15 + 0.35 * (1.0 - smoothstep(0.0, 0.25, e));

	vec3 col = vec3(0.0);
	for (int i = 0; i < MAX_IMPACTS; i++) {
		vec4 im = impacts[i];
		if (im.w < 0.0) {
			continue;
		}
		float age = now - im.w;
		if (age < 0.0 || age > fade_time) {
			continue;
		}
		float t = 1.0 - age / fade_time;
		float d = distance(world_pos, im.xyz);
		float area = 1.0 - smoothstep(0.0, radius, d);
		float ring = exp(-pow((d - age * ripple_speed) * 0.9, 2.0)) * (1.0 - smoothstep(radius * 0.6, radius * 1.6, d));
		float core = (1.0 - smoothstep(0.0, radius * 0.35, d)) * t * t;
		float k = area * t * (line * 1.6 + cell_glow * 0.4)
			+ ring * t * (line * 2.2 + 0.25)
			+ core * (line + cell_glow) * 1.5;
		col += impact_colors[i].rgb * k * impact_colors[i].a;
	}

	float fd = distance(world_pos, focus_pos);
	col += focus_color * (1.0 - smoothstep(2.0, 9.0, fd)) * focus_strength * (line + 0.04);

	// Soft top and bottom so the wall has no hard outline.
	col *= smoothstep(0.0, 0.5, UV.y) * (1.0 - smoothstep(wall_height - 1.5, wall_height, UV.y));
	ALBEDO = col;
	ALPHA = 1.0;
}
