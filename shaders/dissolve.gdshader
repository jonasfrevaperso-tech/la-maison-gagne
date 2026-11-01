shader_type canvas_item;
// Dissolution en braises (destruction / vente) : progress 0 → 1.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.55, 0.15, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	float n = noise(UV * 12.0) * 0.7 + noise(UV * 30.0) * 0.3;
	float cut = progress * 1.2 - 0.1;
	if (n < cut) { discard; }
	vec4 c = COLOR;
	float edge = smoothstep(cut + 0.08, cut, n);
	c.rgb = mix(c.rgb, edge_color.rgb, edge);
	COLOR = c;
}
