shader_type canvas_item;
// 兵卒换色：把红色军服换成另一种颜色（敌我两军区分），皮肤、脸红不动

uniform float hue_shift = 0.0;      // 0 不换色
uniform float sat_mult = 1.0;
uniform float val_mult = 1.0;
uniform float cheer_flash = 0.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Godot 4 的 fragment 里 COLOR 已经乘过贴图色，这里改用顶点色（modulate）
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (hue_shift != 0.0) {
		vec3 hsv = rgb2hsv(c.rgb);
		float red = (hsv.x < 0.035 || hsv.x > 0.94) ? 1.0 : 0.0;
		float mask = red * step(0.42, hsv.y) * step(hsv.z, 0.93);
		vec3 shifted = hsv2rgb(vec3(fract(hsv.x + hue_shift), clamp(hsv.y * sat_mult, 0.0, 1.0), hsv.z * val_mult));
		c.rgb = mix(c.rgb, shifted, mask);
	}
	c.rgb += vec3(cheer_flash) * c.a;
	COLOR = c * vcol;
}
