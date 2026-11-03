shader_type canvas_item;
// Loupe tactile : agrandit la zone de l'écran sous le doigt (disque, bord doux).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Point visé, en UV d'écran.
uniform vec2 focus_uv = vec2(0.5);
// Taille de la loupe, en UV d'écran.
uniform vec2 span_uv = vec2(0.1);
uniform float zoom = 2.0;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	if (r > 0.5) {
		discard;
	}
	vec2 uv = focus_uv + d * span_uv / zoom;
	vec3 col = texture(screen_tex, uv).rgb;
	// Léger assombrissement vers le bord : relief de verre.
	col *= 1.0 - smoothstep(0.38, 0.5, r) * 0.35;
	COLOR = vec4(col, 1.0);
}
