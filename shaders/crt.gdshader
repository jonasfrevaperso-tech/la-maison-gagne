shader_type canvas_item;
// CRT léger : courbure, scanlines, aberration chromatique, vignettage. Tout est réglable.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float curvature : hint_range(0.0, 0.2) = 0.06;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_count = 540.0;
uniform float aberration : hint_range(0.0, 0.01) = 0.0022;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float flicker : hint_range(0.0, 0.1) = 0.015;

vec2 curve(vec2 uv, float k) {
	vec2 c = uv * 2.0 - 1.0;
	vec2 offset = abs(c.yx) * k;
	c = c + c * offset * offset;
	return c * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve(SCREEN_UV, curvature * intensity * 4.0);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float ab = aberration * intensity;
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
		float scan = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * intensity * (1.0 - scan);
		vec2 v = uv * (1.0 - uv.yx);
		float vig = pow(clamp(v.x * v.y * 15.0, 0.0, 1.0), vignette * intensity * 0.5);
		col *= vig;
		col *= 1.0 - flicker * intensity * sin(TIME * 60.0);
		COLOR = vec4(col, 1.0);
	}
}
