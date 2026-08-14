shader_type canvas_item;
// Финальная плёнка кадра: виньетка, зерно, хроматика по краям и цветокоррекция.
// Без неё рендер выглядит «чистым 3D», а нам нужна съёмка на дешёвую камеру.

uniform float vignette_amount : hint_range(0.0, 1.5) = 0.55;
uniform float vignette_softness : hint_range(0.1, 2.0) = 0.9;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.035;
uniform float chroma_amount : hint_range(0.0, 0.01) = 0.0022;
uniform float lift_blue : hint_range(0.0, 0.2) = 0.035;
uniform float contrast : hint_range(0.5, 2.0) = 1.08;
uniform float saturation : hint_range(0.0, 2.0) = 0.92;
uniform float time_seed = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float r2 = dot(centered, centered);

	// Хроматика растёт от центра к краям, как в дешёвой оптике
	vec2 offset = centered * chroma_amount * r2 * 4.0;
	vec3 col;
	col.r = texture(screen_tex, uv + offset).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - offset).b;

	// Тени уходят в синеву, света остаются нейтральными
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col.b += lift_blue * (1.0 - luma);
	col.r += lift_blue * 0.35 * luma;

	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	col = mix(vec3(luma), col, saturation);

	float v = smoothstep(1.0, 1.0 - vignette_softness, r2 * 2.0 * (1.0 + vignette_amount));
	col *= mix(1.0, v, vignette_amount);

	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(time_seed)) - 0.5;
	col += g * grain_amount * (1.2 - luma);

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
