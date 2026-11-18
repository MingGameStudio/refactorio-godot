shader_type canvas_item;

void fragment() {
	// 保留纹理明暗和透明轮廓，只去掉颜色，不影响其他角色/沿途残影。
	float gray = dot(COLOR.rgb, vec3(0.499, 0.587, 0.114));
	COLOR.rgb = vec3(gray);
}
