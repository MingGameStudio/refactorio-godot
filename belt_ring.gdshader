// 固定象限遮罩 + 旋转纹理采样。Sprite 本身不旋转。
shader_type canvas_item;
uniform vec2 mask_direction = vec2(1.0, -1.0);
uniform float turn_sign = 1.0;
uniform float belt_width = 0.3204;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// 在动画变换前裁切，始终只显示格子内部的四分之一圆环。
	if (p.x * mask_direction.x < 0.0 || p.y * mask_direction.y < 0.0) {
		discard;
	}
	// Sprite 宽为两格：中心线半径 0.25，对应半格。
	float radius = length(p);
	float inner_radius = 0.25 - belt_width * 0.5;
	float outer_radius = 0.25 + belt_width * 0.5;
	if (radius < inner_radius || radius > outer_radius) {
		discard;
	}
	// 将原图圆环厚度映射到直线传送带宽度，两端中心对齐格子边缘。
	float source_radius = mix(174.0, 562.0,
		(radius - inner_radius) / belt_width) / 1254.0;
	float angle = atan(p.y, p.x) - TIME * radians(50.0) * turn_sign;
	// 原图箭头顺时针；逆时针弯道同时镜像纹理，保持箭头和运动一致。
	angle *= turn_sign;
	vec2 sample_uv = vec2(0.5, 0.485) + vec2(cos(angle), sin(angle)) * source_radius;
	COLOR = texture(TEXTURE, sample_uv);
}
