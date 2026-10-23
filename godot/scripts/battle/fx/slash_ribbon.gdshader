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
uniform float noise_strength : hint_range(0.0, 1.0) = 0.45;

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
		// 噪声采样三次取平均：单次采样在 UV 放大 3 倍时会有明显颗粒感，
		// 叠加到内缘上就是锯齿。三次平均等效一个 3×3 模糊，成本可忽略。
		vec2 nuv = vec2(v_t * noise_scale_x - age * 1.1, UV.y * noise_scale.y + 0.37);
		float n1 = texture(noise_tex, nuv).r;
		n1 += texture(noise_tex, nuv + vec2(0.011, 0.007)).r;
		n1 += texture(noise_tex, nuv - vec2(0.009, 0.006)).r;
		n1 /= 3.0;
		float n2 = texture(noise_tex, vec2(v_t * noise_scale_x * 1.6 + 5.0 - age * 1.9,
			UV.y * noise_scale.y * 1.5 + 1.3)).r;
		float n = n1 * 0.78 + n2 * 0.22;

		// 内缘是一条「被火烧穿」的曲线：噪声只推动内缘边界，
		// 主体保持实心（否则整条带子会变成一片散点）。
		// 火舌：低频噪声在内缘拉出长长的舌头，高频噪声再啃出毛边
		float tongue = texture(noise_tex, vec2(v_t * tongue_freq - age * 0.8, 0.5)).r;
		// 内缘噪声只做「火舌起伏」，幅度不能大：
		// 幅度一大，边缘就是锯齿状的硬缺口，像被狗啃过。
		// 噪声先平滑再驱动内缘：原始噪声是逐像素的，直接乘上去就是锯齿
		float n_s = smoothstep(0.30, 0.70, n);
		float t_s = smoothstep(0.28, 0.72, tongue);
		// 内缘幅度压到很小：它只该让边缘「呼吸」，不该啃出缺口。
		// 缺口留给下面的亮度变化去做，alpha 保持平滑，才不会出现锯齿硬边。
		float inner_edge = 0.10 + (n_s - 0.5) * noise_strength * 0.14
			+ (t_s - 0.5) * noise_strength * 0.12;
		inner_edge = clamp(inner_edge, 0.0, 0.34);
		// 过渡带要宽：窄过渡 + 噪声 = 硬锯齿；宽过渡让噪声变成柔和的火舌。
		// 最后再乘一个贴边的淡出：过渡带下界是负数，UV.y=0 处 alpha 不是 0，
		// 内缘会留下一条很淡的硬直边。
		float body = smoothstep(inner_edge - 0.06, inner_edge + 0.26, UV.y)
			* smoothstep(0.0, 0.06, UV.y);

		// 归一化到「带宽内」的坐标：0 = 内缘，1 = 刃口
		float by = clamp((UV.y - inner_edge) / max(0.001, 1.0 - inner_edge), 0.0, 1.0);

		// 色阶：内缘暗红 → 主橙 → 外侧暖黄 → 刃口白热
		// 橙必须占主体，白只留最外一窄条，否则在明亮沙地上整条会冲成白线
		vec3 deep = color.rgb * vec3(0.62, 0.16, 0.07);
		// 暖黄只做过渡，不能占大半带宽：之前 0.30 的混合比例 +
		// 从 0.55 就开始过渡，导致整条刀光偏黄白，橙红只剩最里面一丝。
		vec3 warm = mix(color.rgb, vec3(1.0, 0.52, 0.14), 0.24);
		// 主色要占满中段：0.26 就过渡到 color，0.94 才转暖黄
		// 内缘附近压暗，做出「边缘在烧、往里变实」的层次，
		// 这样即使 alpha 是平滑的，也能读出火舌的起伏。
		float eat = smoothstep(0.0, 0.30, by);
		vec3 rgb = mix(deep * (0.55 + 0.45 * n_s), color.rgb, smoothstep(0.0, 0.26, by));
		rgb *= 0.72 + 0.28 * eat;
		rgb = mix(rgb, warm, smoothstep(0.80, 0.97, by));
		// 白刃口：用原始 UV.y，保证无论带宽多少都只是最外一层薄边。
		// 过渡带留宽一点，否则会像贴纸描边；靠外的柔光层再补一点溢出。
		// 刃口必须按「归一化带宽」算：内缘噪声会把可见宽度压掉一半，
		// 如果按原始 UV.y 算，白边就会吃掉整条带子，刀光变成一根白线。
		float rim = smoothstep(0.80, 1.0, by) * rim_strength;
		rgb = mix(rgb, core_color.rgb, rim * 0.55);

		// 刃口过曝：只在最外侧一窄条，做出「烧穿」的亮度
		float hot = smoothstep(0.86, 1.0, by) * rim_strength;
		// 刀头白热：正在推进的那一小段最亮，是「刀锋」而不是「一条亮带」。
		// 没有这个，整条弧亮度一致，看着像静止的贴图。
		float head_hot = (1.0 - smoothstep(0.0, 0.16, behind));
		// 沿弧的亮度起伏：整条一样亮会像塑料，火要有明暗呼吸
		float flick = 0.90 + 0.20 * texture(noise_tex, vec2(v_t * 2.2 - age * 0.7, 0.18)).r;
		float lum = intensity * (1.0 + hot * 0.9) * flick;
		// 刀头再压一层白：色相往 core 推，亮度额外抬
		rgb = mix(rgb, core_color.rgb, head_hot * 0.42);
		lum *= 1.0 + head_hot * 0.7;

		// 刀头处的带宽也撑满：刚扫过的地方不该有内缘烧蚀的缺口
		// 刀头只补 45%：撑满到 1 会把内缘的烧蚀抹平，头部变成一块实心楔形
		// color.a 必须乘进来：_apply() 用它在生命末尾做整体淡出。
		// 漏掉这一项的话，光晕层（用了 color.a）会先淡掉、刀身再突然消失。
		float a = mix(body, 1.0, head_hot * 0.45) * trail * tip * color.a;
		outc = vec4(rgb * lum, a);
	}

	if (outc.a <= 0.004) {
		discard;
	}
	COLOR = outc;
}
