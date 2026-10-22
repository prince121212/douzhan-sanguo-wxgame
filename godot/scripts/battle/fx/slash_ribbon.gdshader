shader_type canvas_item;
// 主体用普通混合：加法在明亮沙地上会被冲成一片白，主题色全丢。
// 外圈光晕单独用 slash_ribbon_glow.gdshader（加法）。
// 刀光带：沿圆弧生成一条「月牙」带状网格，用 shader 画出挥砍过程。
//
// 参考实现：REEBOO Stylized VFX (MIT) 的 vfx_slash.gdshader
//   https://github.com/reeboolabs/reeboo-stylized-vfx-free
// 移植了它的核心思路（3D spatial → 2D canvas_item）：
//   1. head = pow(age, sweep_power) —— 先快后慢，读起来像发力
//   2. 头部后面留一段拖尾，越远越淡 —— 刀光是「拖」出来的，不是整条同时亮
//   3. 外缘（刃口）最亮、内圈变薄 —— 让它是一道「刃」，不是一块扇形
// 在此之上加了两点：内缘用噪声啃出火焰状破碎边；外缘叠一层白热芯。
//
// UV：x 沿弧（0 刀尾 → 1 刀尖），y 从内缘 0 到外缘 1。

varying float v_t;

// 内缘半径，用于在顶点着色器里把刀尖收成尖头
uniform float inner_radius = 120.0;
// 刀尖收尖长度（占整条弧的比例）
uniform float head_taper = 0.12;

uniform float age : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_power = 0.42;
uniform float sweep_end = 1.0;
uniform float trail_length = 1.8;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.14, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.85, 1.0);
uniform float intensity = 0.92;
uniform float rim_strength = 1.0;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 noise_scale = vec2(3.2, 1.1);
uniform float noise_scale_x = 3.2;
uniform float tongue_freq = 1.7;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.85;

void vertex() {
	v_t = UV.x;
	// 刀尖收尖：越靠近扫过的头部，带子越薄，最终收成一点。
	// 这样刀锋不是被「切」断，而是尖出去。
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
	// behind > 0：刀锋已经扫过的位置；< 0：还没扫到
	float behind = head - v_t;
	float trail = 1.0 - smoothstep(0.0, trail_length, behind);
	float tip = smoothstep(0.0, 0.05, v_t) * (1.0 - smoothstep(0.93, 1.0, v_t));

	vec4 outc = vec4(0.0);

	if (behind < 0.0) {
		discard;
	}

	{
		// ---- 主体层 ----
		// 两层流动噪声：低频做火舌大形，高频做细碎毛边
		float n1 = texture(noise_tex, vec2(v_t * noise_scale_x - age * 1.1,
			UV.y * noise_scale.y + 0.37)).r;
		float n2 = texture(noise_tex, vec2(v_t * noise_scale_x * 2.3 + 5.0 - age * 1.9,
			UV.y * noise_scale.y * 1.7 + 1.3)).r;
		float n = n1 * 0.68 + n2 * 0.32;

		// 内缘是一条「被火烧穿」的曲线：噪声只推动内缘边界，
		// 主体保持实心（否则整条带子会变成一片散点）。
		// 火舌：低频噪声在内缘拉出长长的舌头，高频噪声再啃出毛边
		float tongue = texture(noise_tex, vec2(v_t * tongue_freq - age * 0.8, 0.5)).r;
		float inner_edge = 0.06 + (n - 0.5) * noise_strength * 0.30
			+ (tongue - 0.5) * noise_strength * 0.26;
		float body = smoothstep(inner_edge, inner_edge + 0.07, UV.y);

		// 归一化到「带宽内」的坐标：0 = 内缘，1 = 刃口
		float by = clamp((UV.y - inner_edge) / max(0.001, 1.0 - inner_edge), 0.0, 1.0);

		// 色阶：内缘暗红 → 主橙 → 外侧暖黄 → 刃口白热
		// 橙必须占主体，白只留最外一窄条，否则在明亮沙地上整条会冲成白线
		vec3 deep = color.rgb * vec3(0.70, 0.20, 0.09);
		vec3 warm = mix(color.rgb, vec3(1.0, 0.66, 0.22), 0.30);
		vec3 rgb = mix(deep, color.rgb, smoothstep(0.0, 0.22, by));
		rgb = mix(rgb, warm, smoothstep(0.55, 0.88, by));
		// 白刃口：用原始 UV.y，保证无论带宽多少都只是最外一层薄边。
		// 过渡带留宽一点，否则会像贴纸描边；靠外的柔光层再补一点溢出。
		float rim = smoothstep(0.78, 0.99, UV.y) * rim_strength;
		rgb = mix(rgb, core_color.rgb, rim * 0.78);

		// 刃口过曝：只在最外侧一窄条，做出「烧穿」的亮度
		float hot = smoothstep(0.90, 1.0, UV.y) * rim_strength;
		// 沿弧的亮度起伏：整条一样亮会像塑料，火要有明暗呼吸
		float flick = 0.90 + 0.20 * texture(noise_tex, vec2(v_t * 2.2 - age * 0.7, 0.18)).r;
		float lum = intensity * (1.0 + hot * 1.6) * flick;

		float a = body * trail * tip;
		outc = vec4(rgb * lum, a);
	}

	if (outc.a <= 0.004) {
		discard;
	}
	COLOR = outc;
}
