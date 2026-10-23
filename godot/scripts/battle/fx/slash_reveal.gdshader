shader_type canvas_item;
// 刀光揭示：按角度把月牙一点点"扫"出来。
//
// 为什么需要它：素材是一整段约 180° 的月牙。整段一起旋转/淡出，
// 屏幕上从头到尾都是一整条弧，看不出"挥"的过程，像一张贴纸。
// 按角度逐步揭示才是挥砍的读法：光刃从刀尾一路推进到刀尖。

uniform float sweep : hint_range(0.0, 1.0) = 0.0;
// 月牙的起始角与跨度（弧度）。由 _tools/build_fx_assets.py 实测得出。
uniform float angle_start = -2.5311;    // -145°
uniform float angle_span = 3.1534;      // 180.6°
// 圆心在 UV 里的位置
uniform vec2 pivot = vec2(0.5434, 0.7037);
// 图片宽高比（宽/高），把 UV 还原成等比坐标再算角度
uniform float aspect = 1.975;
// 1 = 反向扫（从刀尖往刀尾），用于反手斩
uniform float reverse = 0.0;
// 只揭示弧的一段（0..1），用来裁掉过顶/过脚的部分
uniform float reveal_from = 0.0;
uniform float reveal_to = 1.0;
// 染色。必须走 uniform，不能靠 Sprite2D 的 modulate：
// 在 fragment 里给 COLOR 赋值会把 modulate 覆盖掉，颜色就丢了。
uniform vec4 tint : source_color = vec4(1.0);
uniform float edge_boost = 1.8;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    vec2 p = (UV - pivot) * vec2(aspect, 1.0);
    float ang = atan(p.y, p.x);
    float t = (ang - angle_start) / angle_span;
    if (t < 0.0 || t > 1.0) {
        discard;
    }
    if (reverse > 0.5) {
        t = 1.0 - t;
    }
    // 映射到要显示的那一段。reveal_from 可以大于 reveal_to，表示反向扫。
    float lo = min(reveal_from, reveal_to);
    float hi = max(reveal_from, reveal_to);
    if (t < lo || t > hi) {
        discard;
    }
    float span = max(0.001, hi - lo);
    float local = (t - lo) / span;
    if (reveal_from > reveal_to) {
        local = 1.0 - local;
    }
    if (local > sweep) {
        discard;
    }
    t = local;
    // 前缘加亮：越靠近当前推进的位置越亮，做出"刀锋在走"的感觉
    // GLSL 里 edge0 > edge1 是未定义行为（部分驱动会直接 clamp 掉），
    // 必须写成 1.0 - smoothstep(0.0, 0.10, x)。
    float lead = 1.0 - smoothstep(0.0, 0.10, sweep - t);
    c.rgb *= 1.0 + edge_boost * lead;
    COLOR = vec4(c.rgb, c.a) * tint;
}
