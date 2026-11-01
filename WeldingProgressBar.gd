extends ProgressBar
## 只显示机器提供的进度，不参与加工计时。
var _completion_flash: Tween

func update_progress(progress: float, active: bool) -> void:
	value = progress
	if active or progress < 1.0:
		_reset_flash()
	visible = active or _completion_flash != null
	queue_redraw()

func flash_complete() -> void:
	_reset_flash()
	value = 1.0
	show()
	_completion_flash = create_tween()
	_completion_flash.tween_property(self, "modulate", Color(1.45, 1.45, 1.45, 1.0), 0.04)
	_completion_flash.tween_property(self, "modulate", Color.WHITE, 0.11)
	_completion_flash.tween_callback(func() -> void:
		_completion_flash = null
		hide()
	)
	queue_redraw()

func _reset_flash() -> void:
	if _completion_flash != null:
		_completion_flash.kill()
		_completion_flash = null
	modulate = Color.WHITE

func _draw() -> void:
	# 刻度固定在仪表上，仅绘制已填充部分；不将实际进度量化。
	var fill_end := 1.0 + (size.x - 2.0) * ratio
	for x in range(8, int(size.x) - 1, 8):
		if float(x + 1) <= fill_end:
			draw_rect(Rect2(float(x), 1.0, 1.0, size.y - 2.0), Color("192126"))
