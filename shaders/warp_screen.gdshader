shader_type canvas_item;
// Light-speed boost overlay: radial zoom blur with chromatic split toward the
// screen centre, neon edge tint, radial speed streaks and a pulsing vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_a : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform vec4 tint_b : source_color = vec4(1.0, 0.2, 0.85, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 da = vec2(d.x * aspect, d.y);
	float r = length(da);
	float mask = smoothstep(0.12, 0.75, r) * intensity;

	// Radial blur toward the centre, RGB split for that warp shimmer.
	vec3 acc = vec3(0.0);
	const int N = 14;
	for (int i = 0; i < N; i++) {
		float k = float(i) / float(N - 1) * 0.16 * mask;
		vec2 o = d * k;
		acc.r += texture(screen_tex, uv - o * 1.08).r;
		acc.g += texture(screen_tex, uv - o).g;
		acc.b += texture(screen_tex, uv - o * 0.92).b;
	}
	acc /= float(N);
	vec3 col = mix(texture(screen_tex, uv).rgb, acc, clamp(mask * 2.5, 0.0, 1.0));

	// Radial light streaks rushing outward.
	float ang = atan(da.y, da.x);
	float seg = floor(ang * 80.0);
	float lane = hash(seg);
	float run = fract(r * 2.5 - TIME * (2.0 + lane * 3.0) - lane * 10.0);
	float streak = step(0.82, lane) * smoothstep(0.0, 0.08, run) * (1.0 - smoothstep(0.08, 0.5, run));
	vec3 neon = mix(tint_a.rgb, tint_b.rgb, lane);
	col += neon * streak * mask * 1.4;

	// Neon edge glow + pulsing vignette.
	float pulse = 0.85 + 0.15 * sin(TIME * 18.0);
	col += mix(tint_a.rgb, tint_b.rgb, 0.5 + 0.5 * sin(ang * 2.0 + TIME * 2.0)) * smoothstep(0.45, 0.95, r) * intensity * 0.35 * pulse;
	col *= 1.0 - smoothstep(0.55, 1.1, r) * intensity * 0.45;

	COLOR = vec4(col, 1.0);
}
