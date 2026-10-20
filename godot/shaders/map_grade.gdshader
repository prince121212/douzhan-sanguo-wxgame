shader_type canvas_item;
// 战场底图调色：降一点饱和、压一点亮度，让人物跳出来；远处（画面上方）略带雾气

uniform float saturation = 0.78;
uniform float brightness = 0.92;
uniform vec4 haze_color : source_color = vec4(0.78, 0.74, 0.7, 1.0);
uniform float haze = 0.18;       // 远景雾强度
uniform float haze_end = 0.42;   // 雾在贴图纵向的结束位置（0 顶 … 1 底）

// Godot 4 的 fragment 里 COLOR 已经乘过贴图色，这里改用顶点色（modulate）
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(l), c.rgb, saturation) * brightness;
	float h = smoothstep(haze_end, 0.0, UV.y) * haze;
	c.rgb = mix(c.rgb, haze_color.rgb, h);
	COLOR = c * vcol;
}
