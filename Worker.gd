extends Node2D
const GridDepth = preload("res://GridDepth.gd")

@export var move_speed: float = 160.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var carried_box: Sprite2D = $CarriedBox
var target_position: Vector2
var carrying_box: bool = false
var _pickup_target: Sprite2D
var _delivery_target: Node2D
var pathfinder: Callable
var _path := PackedVector2Array()
var _path_index: int = 0

func _ready() -> void:
	target_position = global_position
	sprite.play("idle")
	_update_depth()

func _update_depth() -> void:
	# 根节点位于脚底；sprite 的向上偏移不参与遮挡排序。
	z_index = GridDepth.at_position(position, GridDepth.WORKER)

func move_to(destination: Vector2) -> bool:
	var route := _find_path(destination)
	if route.is_empty():
		return false
	_pickup_target = null
	_delivery_target = null
	target_position = destination
	_set_path(route)
	return true

func _find_path(destination: Vector2) -> PackedVector2Array:
	if not pathfinder.is_valid():
		return PackedVector2Array()
	return pathfinder.call(global_position, destination)

func _set_path(route: PackedVector2Array) -> void:
	_path = route
	_path_index = 0
	while _path_index < _path.size() and global_position.is_equal_approx(_path[_path_index]):
		_path_index += 1
	if _path_index < _path.size():
		_face_toward(_path[_path_index])

func repath() -> void:
	if _path_index >= _path.size():
		return
	var route := _find_path(target_position)
	_set_path(route)
	if route.is_empty():
		target_position = global_position
		_pickup_target = null
		_delivery_target = null

func _face_toward(destination: Vector2) -> void:
	var horizontal := destination.x - global_position.x
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0.0
	carried_box.position.x = -22.0 if sprite.flip_h else 22.0

func request_pickup(box: Sprite2D) -> void:
	if carrying_box or not is_instance_valid(box) or not box.visible:
		return
	# 从左右较近的一侧接近，停在箱子旁边，避免脚底与箱子重合。
	var side := -1.0 if global_position.x <= box.global_position.x else 1.0
	# 较近的一侧不可达时尝试另一侧；不绕过寻路直接移动。
	for direction in [side, -side]:
		if move_to(box.global_position + Vector2(direction * 32.0, 0.0)):
			_pickup_target = box
			return

func request_delivery(machine: Node2D, approach: Vector2) -> bool:
	if not carrying_box or not move_to(approach):
		return false
	_delivery_target = machine
	return true

func release_box() -> void:
	carrying_box = false
	carried_box.hide()

func _physics_process(delta: float) -> void:
	var remaining := move_speed * delta
	while _path_index < _path.size():
		var waypoint := _path[_path_index]
		var distance := global_position.distance_to(waypoint)
		_face_toward(waypoint)
		if distance > remaining:
			global_position = global_position.move_toward(waypoint, remaining)
			break
		global_position = waypoint
		remaining -= distance
		_path_index += 1
	_update_depth()
	var arrived := _path_index >= _path.size()
	if arrived and is_instance_valid(_delivery_target):
		_face_toward(_delivery_target.input_position())
		_delivery_target.accept_box(self)
		_delivery_target = null
	if arrived and is_instance_valid(_pickup_target):
		if _pickup_target.visible and global_position.distance_to(_pickup_target.global_position) <= 33.0:
			_face_toward(_pickup_target.global_position)
			_pickup_target.hide()
			carrying_box = true
			carried_box.show()
		_pickup_target = null
	if carrying_box:
		sprite.play("hold_idle" if arrived else "hold_walk")
	else:
		sprite.play("idle" if arrived else "walk")
