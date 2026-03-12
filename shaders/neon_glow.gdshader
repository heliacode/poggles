shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.6;
uniform float falloff : hint_range(0.5, 6.0) = 2.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = length(UV - center) * 2.0;
	float glow = pow(max(1.0 - dist, 0.0), falloff);
	float pulse_mod = 1.0 + pulse * 0.3;
	COLOR = vec4(glow_color.rgb * pulse_mod, glow * intensity * glow_color.a);
}
