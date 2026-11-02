shader_type spatial;
// Tapis de jeu d'un casino abandonné : feutre délavé, usure, auréoles de verres, brûlures de
// cigare, poussière et rayures. Procédural (aucune texture), coordonnées monde.

uniform vec3 felt_a : source_color = vec3(0.035, 0.16, 0.10);
uniform vec3 felt_b : source_color = vec3(0.07, 0.22, 0.14);
uniform vec3 dust_col : source_color = vec3(0.42, 0.40, 0.36);
uniform vec3 stain_col : source_color = vec3(0.22, 0.12, 0.05);
uniform float scale = 1.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * scale;
	// Feutre : grandes plaques délavées + fibres fines.
	float n = fbm(p * 0.35);
	vec3 col = mix(felt_a, felt_b, smoothstep(0.3, 0.75, n));
	col *= 0.88 + 0.12 * vnoise(p * 60.0);
	// Usure : zones râpées plus claires et grisâtres.
	float wear = smoothstep(0.55, 0.8, fbm(p * 0.9 + 7.0));
	col = mix(col, col * 1.35 + vec3(0.03, 0.02, 0.0), wear * 0.6);
	// Auréoles de verres (anneaux) et taches.
	vec2 cell = floor(p * 0.45);
	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 c = cell + vec2(float(dx), float(dy));
			float h = hash(c);
			if (h > 0.55) {
				vec2 ctr = (c + vec2(hash(c + 3.1), hash(c + 5.7))) / 0.45;
				float r = 0.25 + 0.25 * hash(c + 9.2);
				float d = length(p - ctr);
				float ring = exp(-pow((d - r) * 28.0, 2.0)) * (0.5 + 0.5 * vnoise(p * 8.0));
				float fill = (1.0 - smoothstep(r * 0.6, r, d)) * 0.25;
				col = mix(col, stain_col, clamp(ring * 0.55 + fill * step(0.8, h), 0.0, 0.7));
			}
			if (h < 0.08) {
				vec2 ctr2 = (c + vec2(hash(c + 1.3), hash(c + 2.9))) / 0.45;
				float d2 = length((p - ctr2) * vec2(1.0, 1.8));
				float burn = 1.0 - smoothstep(0.03, 0.12, d2 + (vnoise(p * 20.0) - 0.5) * 0.05);
				col = mix(col, vec3(0.02, 0.015, 0.01), burn * 0.9);
				col += vec3(0.12, 0.05, 0.0) * (1.0 - smoothstep(0.1, 0.16, d2)) * (smoothstep(0.08, 0.1, d2)) * 0.6;
			}
		}
	}
	// Rayures fines.
	float sc = abs(sin((p.x * 0.8 + p.y * 2.3) * 9.0 + fbm(p * 2.0) * 6.0));
	col = mix(col, col * 1.6, (1.0 - smoothstep(0.0, 0.02, sc)) * step(0.7, vnoise(p * 1.3)) * 0.5);
	// Poussière accumulée.
	float dust = smoothstep(0.45, 0.9, fbm(p * 1.7 + 13.0)) * 0.55;
	col = mix(col, dust_col, dust * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
