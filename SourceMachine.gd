extends "res://PlacedBuilding.gd"
## 输入带和箱子均为机器子节点；箱子真正进入机器后才增加容量。
const BOX_CAPACITY: int = 10
const FEED_SECONDS: float = 1.0
var capacity: int = 0
var feeding: bool = false
var _feed_progress: float = 0.0

func _ready() -> void:
	_update_capacity_label()

func input_position() -> Vector2:
	return $InputBelt.to_global(Vector2(32, 32))

func delivery_position() -> Vector2:
	return $InputBelt.to_global(Vector2(-32, 32))

func can_accept_box(worker: Node2D, require_facing: bool = true) -> bool:
	if feeding or not worker.carrying_box:
		return false
	# 自由移动无需精确站在格心，但仍必须位于输入带左侧格且足够靠近。
	var point: Vector2 = $InputBelt.to_local(worker.global_position)
	if not Rect2(-64, 0, 64, 64).has_point(point) or point.distance_to(Vector2(32, 32)) > 72.0:
		return false
	return not require_facing or not worker.sprite.flip_h

func accept_box(worker: Node2D) -> bool:
	if not can_accept_box(worker):
		return false
	worker.release_box()
	feeding = true
	_feed_progress = 0.0
	$InputBox.position = Vector2(-32, 32)
	$InputBox.show()
	$InsertSound.play()
	return true

func _process(delta: float) -> void:
	if not feeding:
		return
	_feed_progress = minf(_feed_progress + delta / FEED_SECONDS, 1.0)
	$InputBox.position = Vector2(-32, 32).lerp(Vector2(32, 32), _feed_progress)
	if _feed_progress >= 1.0:
		feeding = false
		$InputBox.hide()
		capacity += BOX_CAPACITY
		_update_capacity_label()

func consume_capacity() -> bool:
	if capacity <= 0:
		return false
	capacity -= 1
	_update_capacity_label()
	return true

func _update_capacity_label() -> void:
	$CapacityLabel.text = str(capacity)
