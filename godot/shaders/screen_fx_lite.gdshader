shader_type canvas_item;
render_mode blend_mix;
// 小游戏版全屏后期：不读屏幕纹理，只叠一层半透明颜色。
// 保留：暗角、残血红边、水墨转场、闪白、去色（用灰雾近似）。
// 色散 / 径向模糊 / 调色在手机上直接省掉（uniform 保留，post_fx.gd 照常设置不报错）。

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
uniform float ink = 0.0;

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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// 把 (c, a) 盖到已有的 (col, alpha) 上
void over(inout vec3 col, inout float alpha, vec3 c, float a) {
	float na = a + alpha * (1.0 - a);
	if (na > 0.0001) {
		col = (c * a + col * alpha * (1.0 - a)) / na;
	}
	alpha = na;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	vec2 d = uv - 0.5;
	d.x *= 1.25;
	float v = smoothstep(0.32, 0.92, length(d));
	over(col, alpha, vignette_color.rgb, clamp(v * vignette, 0.0, 1.0));
	if (desat > 0.001) {
		over(col, alpha, vec3(0.5, 0.48, 0.45), desat * 0.35);
	}
	float edge_l = smoothstep(0.25, 0.0, uv.x);
	float edge_r = smoothstep(0.75, 1.0, uv.x);
	float dg = (danger_l * edge_l + danger_r * edge_r) * (0.6 + 0.4 * v);
	if (dg > 0.001) {
		over(col, alpha, vec3(0.6, 0.03, 0.0), clamp(dg * 0.7, 0.0, 1.0));
	}
	if (ink > 0.001) {
		vec2 q = uv * vec2(6.0, 3.4);
		float n = fbm(q + vec2(3.1, 1.7)) * 0.75 + (1.0 - length(d) * 1.2) * 0.45;
		float th = -0.15 + ink * 1.3;
		float m = smoothstep(th - 0.06, th + 0.02, n);
		float rim = smoothstep(th - 0.14, th - 0.06, n) * (1.0 - m);
		over(col, alpha, vec3(0.045, 0.035, 0.03), clamp(1.0 - m + rim * 0.45, 0.0, 1.0));
	}
	over(col, alpha, flash_color.rgb, clamp(flash_color.a, 0.0, 1.0));
	COLOR = vec4(col, alpha);
}
