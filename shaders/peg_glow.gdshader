shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 3.0) = 0.5;
uniform float falloff : hint_range(0.5, 6.0) = 2.5;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float anticipation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	float dist = length(UV - center) * 2.0;
	float glow = pow(max(1.0 - dist, 0.0), falloff);

	// Pulse breathing
	float pulse_mod = 1.0 + pulse * 0.25;

	// Hit flash: bright white burst — more dramatic
	vec3 color = glow_color.rgb;
	float extra_intensity = 0.0;
	if (hit_flash > 0.0) {
		color = mix(color, vec3(1.0), hit_flash * 0.8);
		extra_intensity = hit_flash * 2.5;
		// Reduce falloff during flash so glow spreads wider
		float flash_glow = pow(max(1.0 - dist, 0.0), falloff * (1.0 - hit_flash * 0.4));
		glow = max(glow, flash_glow);
	}

	// Anticipation: brighter, wider glow when ball approaches
	if (anticipation > 0.0) {
		extra_intensity += anticipation * 1.2;
		// Widen the glow during anticipation
		float ant_glow = pow(max(1.0 - dist, 0.0), falloff * (1.0 - anticipation * 0.3));
		glow = max(glow, ant_glow);
	}

	float final_intensity = (intensity + extra_intensity) * pulse_mod;
	COLOR = vec4(color, glow * final_intensity * glow_color.a);
}
