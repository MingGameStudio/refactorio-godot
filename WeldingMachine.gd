extends "res://PlacedBuilding.gd"
## 加工状态不依赖键盘或人物脚本；操作者可由玩家或未来 AI 提供。
const PROCESS_SECONDS := 3.0
@export_range(0.25, 0.35, 0.01) var spark_interval: float = 0.30
var _next_spark_time: float = 0.0
var cells: int = 0
var output_pending: bool = false
var processing: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	refresh_status()

func accept_cell() -> bool:
	if cells >= 2:
		return false
	cells += 1
	refresh_status()
	return true

func can_begin_operation(operator: Object) -> bool:
	return is_instance_valid(operator) and not processing and not output_pending and cells == 2

func begin_operation(operator: Object) -> bool:
	if not can_begin_operation(operator):
		return false
	processing = true
	elapsed = 0.0
	_next_spark_time = spark_interval
	_emit_welding_pulse()
	refresh_status()
	return true

func _physics_process(delta: float) -> void:
	advance_operation(delta)

# 兼容现有调用接口；启动后不再依赖操作者或距离。
func advance_operation(delta: float, _operator: Object = null, _nearby: bool = true) -> void:
	if not processing:
		return
	elapsed = minf(elapsed + maxf(delta, 0.0), PROCESS_SECONDS)
	if elapsed >= PROCESS_SECONDS:
		cells -= 2
		output_pending = true
		processing = false
		$SparkOrigin/WeldingSparks.emitting = false
		$PulseSound.stop()
		$SparkOrigin/CompletionSparks.restart()
		$CompleteSound.play()
		$ProgressBar.flash_complete()
	elif elapsed >= _next_spark_time:
		# 跟随真实加工进度；卡顿后不补发一串积压的爆发。
		_emit_welding_pulse()
		_next_spark_time = elapsed + spark_interval
	refresh_status()

func _emit_welding_pulse() -> void:
	$SparkOrigin/WeldingSparks.restart()
	# 单个发声实例，重触发不叠加；节奏完全跟随真实火花事件。
	$PulseSound.play()

func cancel_operation() -> void:
	processing = false
	elapsed = 0.0
	_next_spark_time = 0.0
	# 不重置发射器，已生成的粒子保留至自然消失。
	refresh_status()

func confirm_output() -> void:
	output_pending = false
	refresh_status()

func can_remove() -> bool:
	return cells == 0 and not output_pending and not processing

func refresh_status() -> void:
	if not is_node_ready():
		return
	var state := "等待输出" if output_pending else ("点焊中 %.1f / 3 秒" % elapsed if processing else "电芯 %d / 2" % cells)
	$Status.text = state
	$ProgressBar.update_progress(elapsed / PROCESS_SECONDS, processing)
