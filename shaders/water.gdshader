shader_type spatial;
// Eau de bassin : vagues douces sur les sommets, moirures et reflets, transparence partielle
// pour voir les carpes. Purement cosmétique.
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 deep : source_color = vec4(0.03, 0.18, 0.24, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.38, 0.44, 1.0);
uniform float alpha = 0.62;
uniform float wave = 0.012;
uniform float speed = 1.0;

void vertex() {
	float t = TIME * speed;
	VERTEX.y += sin(VERTEX.x * 3.1 + t * 1.5) * wave + cos(VERTEX.z * 4.3 + t * 1.1) * wave;
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV * vec2(28.0, 11.0);
	float m = sin(uv.x + t * 1.3 + sin(uv.y * 1.7 + t)) * sin(uv.y * 1.3 - t * 0.9);
	float glint = smoothstep(0.82, 1.0, m);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * m) + vec3(glint * 0.08);
	ALPHA = alpha;
	ROUGHNESS = 0.18;
	SPECULAR = 0.4;
	vec2 n = vec2(cos(uv.x * 1.1 + t), sin(uv.y * 1.4 - t)) * 0.18;
	NORMAL = normalize(NORMAL + vec3(n.x, 0.0, n.y));
}
