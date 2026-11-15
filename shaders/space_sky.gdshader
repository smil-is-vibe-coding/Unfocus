shader_type sky;
// Deep-space sky: starfield, drifting nebula and animated aurora curtains
// above (plus a dimmer mirrored aurora below, since the track floats in space).

uniform vec3 aurora_low : source_color = vec3(0.05, 1.0, 0.55);
uniform vec3 aurora_mid : source_color = vec3(0.1, 0.6, 1.0);
uniform vec3 aurora_high : source_color = vec3(0.85, 0.2, 1.0);
uniform vec3 under_low : source_color = vec3(1.0, 0.15, 0.6);
uniform vec3 under_high : source_color = vec3(0.3, 0.1, 1.0);
uniform float aurora_strength = 0.75;
uniform float under_strength = 0.18;
uniform float aurora_speed = 0.035;
uniform vec3 nebula_a : source_color = vec3(0.22, 0.03, 0.35);
uniform vec3 nebula_b : source_color = vec3(0.0, 0.12, 0.3);
uniform float nebula_strength = 0.25;
uniform float star_brightness = 2.0;
uniform int aurora_layers = 14;   // Lowered by the graphics preset.

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

vec3 star_layer(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 id = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash31(id);
	if (h < threshold) {
		return vec3(0.0);
	}
	float k = (h - threshold) / (1.0 - threshold);
	float d = length(f);
	float core = smoothstep(0.16, 0.0, d);
	float twinkle = 0.65 + 0.35 * sin(TIME * (2.0 + k * 4.0) + h * 300.0);
	vec3 tint = mix(vec3(0.6, 0.8, 1.0), vec3(1.0, 0.75, 0.9), fract(h * 37.0));
	return tint * core * k * twinkle;
}

// Curtain-like aurora: ridged noise projected onto stacked horizontal sheets.
vec3 aurora(vec3 dir, vec3 c_low, vec3 c_mid, vec3 c_high, float seed) {
	if (dir.y < 0.06) {
		return vec3(0.0);
	}
	vec3 col = vec3(0.0);
	float t = TIME * aurora_speed;
	for (int i = 0; i < aurora_layers; i++) {
		float fi = float(i) / float(aurora_layers);
		float h = 1.0 + fi * 0.9;
		vec2 uv = dir.xz / dir.y * h * 0.35;
		uv += vec2(seed, seed * 0.7);
		// Slow sideways sway.
		uv.x += sin(uv.y * 0.6 + t * 6.0) * 0.6;
		float n = fbm2(uv * vec2(0.6, 1.6) + vec2(t, -t * 0.5));
		float ridge = 1.0 - abs(n * 2.0 - 1.0);
		float curtain = pow(ridge, 10.0);
		vec3 c = fi < 0.5 ? mix(c_low, c_mid, fi * 2.0) : mix(c_mid, c_high, (fi - 0.5) * 2.0);
		col += c * curtain * (1.0 - fi) * 0.32 * sqrt(14.0 / float(aurora_layers));
	}
	// Fade near the horizon: the projection gets huge there and aliases.
	float horizon = smoothstep(0.06, 0.35, dir.y) * smoothstep(1.0, 0.6, dir.y);
	return col * horizon;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = vec3(0.0);

	// Nebula haze everywhere (also below: we are in space).
	float neb = fbm3(dir * 2.2 + vec3(0.0, TIME * 0.004, 0.0));
	float neb2 = fbm3(dir * 4.5 + vec3(5.0));
	col += mix(nebula_a, nebula_b, neb2) * pow(neb, 2.2) * nebula_strength;

	if (!AT_CUBEMAP_PASS) {
		col += star_layer(dir, 160.0, 0.975) * star_brightness;
		col += star_layer(dir, 420.0, 0.985) * star_brightness * 0.7;
	}

	col += aurora(dir, aurora_low, aurora_mid, aurora_high, 0.0) * aurora_strength;
	col += aurora(vec3(dir.x, -dir.y, dir.z), under_low, under_high, under_high, 17.0) * under_strength;

	COLOR = col;
}
