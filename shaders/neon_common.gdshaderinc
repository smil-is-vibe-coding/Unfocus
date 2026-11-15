// Shared helpers for the neon world shaders.

// Fully saturated rainbow colour for hue h (0..1, wraps).
vec3 neon_hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// Anti-aliased line mask: 1 on the line, fading over ~1px.
float aa_line(float dist_to_line, float half_width) {
	float w = fwidth(dist_to_line) + 1e-5;
	return 1.0 - smoothstep(half_width, half_width + w, abs(dist_to_line));
}

// Level palette: full rainbow when range >= 1, otherwise sweeps back and forth
// inside a band of hues [offset, offset + range].
vec3 theme_hue(float t, float offset, float range) {
	if (range >= 0.999) {
		return neon_hue(t + offset);
	}
	return neon_hue(offset + range * (0.5 + 0.5 * sin(t * 6.2831853)));
}
