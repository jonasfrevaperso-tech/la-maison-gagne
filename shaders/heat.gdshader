shader_type canvas_item;
// Distorsion de chaleur (Pyromane, Brasier) : ondulation verticale du fond d'écran.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 0.02) = 0.004;

void fragment() {
	vec2 uv = SCREEN_UV;
	float w = sin(uv.y * 60.0 + TIME * 4.0) * cos(uv.x * 23.0 + TIME * 2.3);
	uv.x += w * strength * (1.0 - uv.y);
	vec3 c = texture(screen_tex, uv).rgb;
	c.r += strength * 6.0 * (1.0 - uv.y);
	COLOR = vec4(c, 1.0);
}
