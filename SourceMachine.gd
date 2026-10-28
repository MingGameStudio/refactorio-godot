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

func accept_box(worker: Node2D) -> bool:
	if feeding or not worker.carrying_box:
		return false
	# 到达左侧格中心并转向右方后才接收，不能从上方、下方或右方投放。
	if worker.global_position.distance_to(delivery_position()) > 0.1 or worker.sprite.flip_h:
		return false
	worker.release_box()
	feeding = true
	_feed_progress = 0.0
	$InputBox.position = Vector2(-32, 32)
	$InputBox.show()
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
