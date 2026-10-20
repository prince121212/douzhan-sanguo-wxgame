shader_type canvas_item;
// 武将贴图：受击白闪、染色、怒气外发光描边、霸体金边

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.93, 0.86, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color = vec4(1.0, 0.6, 0.2, 0.0);   // a = 强度，rgb 可大于 1 产生泛光
uniform float glow_px = 4.0;
uniform float glow_pulse = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;   // 0 正常
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float rim = 0.32;          // 轮廓光强度
uniform vec2 light_dir = vec2(-0.7, -0.7);   // 光从左上来（贴图空间）

// Godot 4 的 fragment 里 COLOR 已经乘过贴图色，这里改用顶点色（modulate）
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (rim > 0.001 && c.a > 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
		float edge = 1.0 - texture(TEXTURE, UV + light_dir * px).a;
		edge = max(edge, (1.0 - texture(TEXTURE, UV + light_dir * px * 2.0).a) * 0.6);
		c.rgb += rim_color.rgb * edge * rim;
	}
	if (glow_color.a > 0.001) {
		float pulse = 1.0 + glow_pulse * sin(TIME * 9.0);
		vec2 px = TEXTURE_PIXEL_SIZE * glow_px * pulse;
		float o = 0.0;
		float o2 = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5235988;
			vec2 off = vec2(cos(ang), sin(ang));
			o = max(o, texture(TEXTURE, UV + off * px).a);
			o2 = max(o2, texture(TEXTURE, UV + off * px * 0.5).a);
		}
		float ring = clamp(max(o * 0.55, o2) - c.a, 0.0, 1.0);
		vec4 g = vec4(glow_color.rgb, ring * glow_color.a);
		c = vec4(mix(g.rgb, c.rgb, c.a), max(c.a, g.a));
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash * step(0.01, c.a));
	c *= tint;
	if (dissolve > 0.0) {
		float n = fract(sin(dot(floor(UV / TEXTURE_PIXEL_SIZE / 3.0), vec2(12.9898, 78.233))) * 43758.5453);
		c.a *= step(dissolve, n);
	}
	COLOR = c * vcol;
}
