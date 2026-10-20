shader_type canvas_item;
// 全屏后期：调色、暗角、色散、径向模糊、去色、闪白、残血红边

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.38;
uniform vec4 vignette_color : source_color = vec4(0.05, 0.02, 0.01, 1.0);
uniform float aberration = 0.0;
uniform float radial_blur = 0.0;
uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float desat = 0.0;
uniform vec4 flash_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float contrast = 1.06;
uniform float saturation = 1.1;
uniform vec3 grade = vec3(1.0, 1.0, 1.0);
uniform vec3 lift = vec3(0.0, 0.0, 0.0);
uniform float danger_l = 0.0;
uniform float danger_r = 0.0;
uniform float ink = 0.0;   // 水墨转场
uniform vec3 shadow_tint = vec3(-0.012, 0.0, 0.022);   // 暗部偏青
uniform vec3 high_tint = vec3(0.018, 0.008, -0.012);   // 亮部偏暖

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
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

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (radial_blur > 0.001) {
		vec2 dir = uv - blur_center;
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 12; i++) {
			float s = 1.0 - radial_blur * float(i) / 12.0 * 0.16;
			acc += textureLod(screen_tex, blur_center + dir * s, 0.0).rgb;
		}
		col = acc / 12.0;
	} else {
		col = textureLod(screen_tex, uv, 0.0).rgb;
	}
	if (aberration > 0.001) {
		vec2 off = (uv - 0.5) * aberration * 0.012;
		col.r = mix(col.r, textureLod(screen_tex, uv + off, 0.0).r, 0.85);
		col.b = mix(col.b, textureLod(screen_tex, uv - off, 0.0).b, 0.85);
	}
	col = col * grade + lift;
	float l0 = dot(col, vec3(0.299, 0.587, 0.114));
	col += shadow_tint * (1.0 - l0) * (1.0 - l0) + high_tint * l0 * l0;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	// 去色时保留一点红色（血与旗）
	float redness = clamp((col.r - max(col.g, col.b)) * 2.0, 0.0, 1.0);
	col = mix(col, vec3(l) * vec3(1.02, 0.98, 0.92), desat * (1.0 - redness * 0.7));
	vec2 d = uv - 0.5;
	d.x *= 1.25;
	float v = smoothstep(0.32, 0.92, length(d));
	col = mix(col, vignette_color.rgb, v * vignette);
	float edge_l = smoothstep(0.25, 0.0, uv.x);
	float edge_r = smoothstep(0.75, 1.0, uv.x);
	col += vec3(0.55, 0.02, 0.0) * (danger_l * edge_l + danger_r * edge_r) * (0.6 + 0.4 * v);
	if (ink > 0.001) {
		// 水墨晕开：分形噪声 + 由四周向中心收拢，边缘带一圈淡墨
		vec2 q = uv * vec2(6.0, 3.4);
		float n = fbm(q + vec2(3.1, 1.7)) * 0.75 + (1.0 - length(d) * 1.2) * 0.45;
		float th = -0.15 + ink * 1.3;
		float m = smoothstep(th - 0.06, th + 0.02, n);
		float rim = smoothstep(th - 0.14, th - 0.06, n) * (1.0 - m);
		vec3 inkc = vec3(0.045, 0.035, 0.03);
		col = mix(col, inkc, 1.0 - m);
		col = mix(col, col * 0.55, rim);
	}
	col = mix(col, flash_color.rgb, flash_color.a);
	COLOR = vec4(col, 1.0);
}
