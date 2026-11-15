shader_type canvas_item;
// Photographic negative of the 3D world (drawn under the HUD so text and
// gauges keep their normal colours). Luminance contrast is preserved, so the
// scene stays just as readable - only flipped.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float desaturate : hint_range(0.0, 1.0) = 0.8;
uniform float contrast = 1.1;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 inv = vec3(1.0) - clamp(c, 0.0, 1.0);
	float luma = dot(inv, vec3(0.299, 0.587, 0.114));
	inv = mix(inv, vec3(luma), desaturate);
	inv = (inv - 0.5) * contrast + 0.5;
	COLOR = vec4(clamp(inv, 0.0, 1.0), 1.0);
}
