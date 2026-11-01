shader_type canvas_item;
// Brillance d'édition sur une carte : 0 brillante (reflet balayé), 1 holographique (arc-en-ciel),
// 2 polychrome (teinte cyclique), 3 noire (négatif + halo).
uniform int mode = 0;
uniform float strength : hint_range(0.0, 1.0) = 0.6;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = COLOR;
	float t = TIME;
	if (mode == 0) {
		float band = smoothstep(0.08, 0.0, abs(UV.x + UV.y * 0.5 - fract(t * 0.35) * 2.0 + 0.3));
		c.rgb += band * strength * 0.8;
	} else if (mode == 1) {
		vec3 rb = hue(UV.x * 0.8 + UV.y * 0.6 + t * 0.15);
		c.rgb = mix(c.rgb, c.rgb * 0.6 + rb * 0.6, strength * 0.45);
	} else if (mode == 2) {
		float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
		c.rgb = mix(c.rgb, hue(fract(t * 0.12 + UV.y * 0.3)) * (0.4 + l), strength * 0.5);
	} else {
		c.rgb = mix(c.rgb, vec3(1.0) - c.rgb, strength * 0.85);
	}
	COLOR = c;
}
