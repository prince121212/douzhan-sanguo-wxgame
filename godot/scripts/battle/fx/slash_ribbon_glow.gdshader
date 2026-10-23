shader_type canvas_item;
render_mode blend_add;
// 刀光外圈柔光：只做加法光晕，不参与主体分层。
// 单独一个 shader 是因为 render_mode 是编译期属性，没法用 uniform 切换。
// 思路同 REEBOO Stylized VFX (MIT)。

varying float v_t;

uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_power = 0.42;
uniform float sweep_end = 1.0;
uniform float trail_length = 1.45;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.14, 1.0);
uniform float intensity = 0.5;
uniform float inner_radius = 120.0;
uniform float head_taper = 0.12;

void vertex() {
	v_t = UV.x;
	// 和主体一样在刀尖收尖，否则光晕会在刀尖处冒出一截
	float head = pow(age, sweep_power) * sweep_end;
	float behind = head - UV.x;
	float k = smoothstep(0.0, head_taper, behind);
	vec2 dir = normalize(VERTEX.xy);
	float r = length(VERTEX.xy);
	float ro = r - inner_radius;
	VERTEX.xy = dir * (inner_radius + ro * k);
}

void fragment() {
	float head = pow(age, sweep_power) * sweep_end;
	float behind = head - v_t;
	if (behind < 0.0) {
		discard;
	}
	float trail = 1.0 - smoothstep(0.0, trail_length, behind);
	float tip = smoothstep(0.0, 0.05, v_t) * (1.0 - smoothstep(0.93, 1.0, v_t));
	float d = (UV.y - 0.5) * 2.0;
	float soft = exp(-d * d * 5.2);
	float a = soft * trail * tip * color.a;
	if (a <= 0.004) {
		discard;
	}
	COLOR = vec4(color.rgb * intensity, a);
}
