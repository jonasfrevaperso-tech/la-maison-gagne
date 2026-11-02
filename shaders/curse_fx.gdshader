shader_type canvas_item;
// Malus visuels des grigris « maudits pour rire » (pendant le mini-jeu et la course de la bille).
// Chaque intensité ∈ [0, 1] ; 0 partout = image intacte.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float drunk = 0.0;    // tangage + vision double
uniform float smoke = 0.0;    // volutes de fumée qui dérivent
uniform float crack = 0.0;    // verre fêlé (réfraction le long des fissures)
uniform float flicker = 0.0;  // néon qui grésille : baisses de lumière
uniform float jitter = 0.0;   // tremblote caféinée
uniform float mirror = 0.0;   // image retournée (0 → 1 : bascule)
uniform float dark = 0.0;     // lunettes noires : vignette très sombre
uniform vec2 crack_center = vec2(0.8, 0.3);

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Distance aux fissures : rayons brisés partant du point d'impact + anneau.
float crack_dist(vec2 uv, float aspect) {
	vec2 d = (uv - crack_center) * vec2(aspect, 1.0);
	float r = length(d);
	float ang = atan(d.y, d.x);
	float best = 1.0;
	for (int k = 0; k < 9; k++) {
		float a0 = float(k) * 0.698 + hash(vec2(float(k), 3.0)) * 0.5;
		float wob = (vnoise(vec2(r * 9.0, float(k) * 7.0)) - 0.5) * 0.18;
		float da = abs(mod(ang - a0 - wob + 3.14159, 6.28318) - 3.14159);
		float len = 0.1 + hash(vec2(float(k), 9.0)) * 0.26;
		if (r < len) {
			best = min(best, da * r);
		}
	}
	float ring = abs(r - 0.09 - (vnoise(vec2(ang * 3.0, 1.0)) - 0.5) * 0.03);
	return min(best, ring);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// Miroir : bascule horizontale (léger flou de la transition au milieu).
	if (mirror > 0.0) {
		uv.x = mix(uv.x, 1.0 - uv.x, smoothstep(0.0, 1.0, mirror));
	}
	// Café : tremblote haute fréquence.
	if (jitter > 0.0) {
		vec2 j = vec2(hash(vec2(floor(t * 24.0), 1.0)), hash(vec2(floor(t * 24.0), 2.0))) - 0.5;
		uv += j * 0.008 * jitter;
	}
	// Gin : le décor tangue doucement (onde lente) + houle verticale.
	if (drunk > 0.0) {
		uv.x += sin(uv.y * 6.0 + t * 1.3) * 0.010 * drunk;
		uv.y += sin(uv.x * 5.0 + t * 0.9) * 0.008 * drunk;
		vec2 c = uv - 0.5;
		float rot = sin(t * 0.7) * 0.025 * drunk;
		uv = 0.5 + mat2(vec2(cos(rot), sin(rot)), vec2(-sin(rot), cos(rot))) * c;
	}
	// Verre fêlé : réfraction près des fissures.
	float cd = 1.0;
	if (crack > 0.0) {
		cd = crack_dist(uv, aspect);
		uv += (uv - crack_center) * 0.03 * crack * step(length((uv - crack_center) * vec2(aspect, 1.0)), 0.3);
	}
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (drunk > 0.0) {
		vec2 off = vec2(0.012 + 0.008 * sin(t * 1.1), 0.004 * cos(t * 0.8)) * drunk;
		vec3 ghost = textureLod(screen_tex, uv + off, 0.0).rgb;
		col = mix(col, ghost, 0.42 * drunk);
		col = mix(col, textureLod(screen_tex, uv, 2.5).rgb, 0.25 * drunk);
		col *= vec3(1.0 + 0.05 * drunk, 1.0 + 0.08 * drunk, 0.95);
	}
	if (crack > 0.0) {
		float line = 1.0 - smoothstep(0.0008, 0.0035, cd);
		float glint = 1.0 - smoothstep(0.0, 0.012, cd);
		col = mix(col, vec3(0.85, 0.95, 1.0), line * 0.6 * crack);
		col += vec3(0.25, 0.3, 0.35) * glint * 0.25 * crack;
		col = mix(col, col * vec3(0.9, 0.97, 1.08), 0.5 * crack * step(length((uv - crack_center) * vec2(aspect, 1.0)), 0.3));
	}
	if (smoke > 0.0) {
		vec2 p = uv * vec2(aspect, 1.0) * 2.2 + vec2(t * 0.06, -t * 0.03);
		float s = fbm(p + fbm(p * 0.6 + t * 0.05) * 1.6);
		float m = smoothstep(0.42, 0.85, s) * smoke;
		col = mix(col, vec3(0.72, 0.70, 0.68), m * 0.75);
		col = mix(col, textureLod(screen_tex, uv, 3.0).rgb, m * 0.4);
	}
	if (flicker > 0.0) {
		float blink = step(0.82, hash(vec2(floor(t * 11.0), 7.0)));
		float hum = 0.5 + 0.5 * sin(t * 120.0);
		col *= 1.0 - flicker * (blink * 0.7 + hum * 0.05);
		col += vec3(0.25, 0.0, 0.12) * flicker * (1.0 - blink) * 0.06;
	}
	if (dark > 0.0) {
		vec2 c = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
		float v = smoothstep(0.3, 0.8, length(c));
		col *= mix(1.0, 0.62, dark) * (1.0 - v * 0.8 * dark);
	}
	COLOR = vec4(col, 1.0);
}
