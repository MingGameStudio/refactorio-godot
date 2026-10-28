shader_type canvas_item;

// 滚动方向（UV 空间）。默认 (1, 0) = 沿纹理 U 轴正方向滚动
// 由于 Sprite2D 会按 belt 方向旋转，UV 永远沿"纹理自身的右方"滚动
uniform vec2 scroll_dir = vec2(1.0, 0.0);

// 当前滚动偏移（每帧由脚本累加）
uniform float scroll_offset = 0.0;

// 滚动速度（每秒滚动的纹理循环次数）
uniform float scroll_speed = 0.6;

void fragment() {
	vec2 dir = normalize(scroll_dir);
	// 让 UV 沿 dir 滚动；offset 随时间增长使内容朝 dir 方向流动
	vec2 uv = UV - dir * scroll_offset;
	// wrap 到 [0,1) 实现无缝循环
	uv = mod(uv, 1.0);
	COLOR = texture(TEXTURE, uv);
}
