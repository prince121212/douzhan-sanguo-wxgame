shader_type canvas_item;
// 旗帜飘动：离旗杆越远摆幅越大，波谷压暗

uniform float amp = 0.035;
uniform float freq = 7.0;
uniform float speed = 3.4;
uniform float pole_left = 1.0;   // 1 旗杆在左，-1 旗杆在右
uniform float phase = 0.0;

// Godot 4 的 fragment 里 COLOR 已经乘过贴图色，这里改用顶点色（modulate）
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	float d = pole_left > 0.0 ? UV.x : 1.0 - UV.x;
	float w = sin(d * freq - TIME * speed + phase);
	vec2 uv = UV;
	uv.y += w * amp * d;
	uv.x += cos(d * freq * 0.7 - TIME * speed * 0.8 + phase) * amp * 0.25 * d;
	vec4 c = texture(TEXTURE, uv);
	float shade = 0.82 + 0.18 * (w * 0.5 + 0.5);
	c.rgb *= mix(1.0, shade, d);
	COLOR = c * vcol;
}
