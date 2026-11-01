extends CharacterBody2D
const GridDepth = preload("res://GridDepth.gd")

@export var move_speed: float = 160.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var carried_box: Sprite2D = $CarriedBox
var target_position: Vector2
var carrying_box: bool = false
var operating: bool = false
var _pickup_target: Sprite2D
var _delivery_target: Node2D
var pathfinder: Callable
var _path := PackedVector2Array()
var _path_index: int = 0
var _moving: bool = false
var _stuck_time: float = 0.0

func cancel_navigation() -> void:
	_path.clear()
	_path_index = 0
	_pickup_target = null
	_delivery_target = null
	target_position = global_position
	_stuck_time = 0.0

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

func can_pickup(box: Sprite2D) -> bool:
	if carrying_box or not is_instance_valid(box) or not box.visible or global_position.distance_to(box.global_position) > 48.0:
		return false
	# E 近距离拾取不能隔着设施进行；物理层 1 仅包含设施和地图边界。
	var ray := PhysicsRayQueryParameters2D.create(global_position, box.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func pickup_box(box: Sprite2D) -> bool:
	if not can_pickup(box):
		return false
	cancel_navigation()
	_face_toward(box.global_position)
	box.hide()
	carrying_box = true
	carried_box.show()
	_update_animation()
	$PickupSound.play()
	return true

func request_delivery(machine: Node2D, approach: Vector2) -> bool:
	if not carrying_box or not move_to(approach):
		return false
	_delivery_target = machine
	return true

func release_box() -> void:
	carrying_box = false
	carried_box.hide()

func set_operating(value: bool) -> void:
	operating = value
	_update_animation()

func _update_animation() -> void:
	var arrived := not _moving and _path_index >= _path.size()
	if carrying_box:
		sprite.play("hold_idle" if arrived else "hold_walk")
	elif operating and arrived:
		sprite.play("interact")
	else:
		sprite.play("idle" if arrived else "walk")

func _physics_process(delta: float) -> void:
	var manual := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var before := global_position
	velocity = Vector2.ZERO
	if not manual.is_zero_approx():
		cancel_navigation()
		velocity = manual * move_speed
		_face_toward(global_position + manual)
	elif _path_index < _path.size() and delta > 0.0:
		var offset := _path[_path_index] - global_position
		velocity = offset.limit_length(move_speed * delta) / delta
		_face_toward(_path[_path_index])
	if delta > 0.0:
		move_and_slide()
	_moving = global_position.distance_squared_to(before) > 0.000001
	if not manual.is_zero_approx():
		target_position = global_position
	if manual.is_zero_approx() and _path_index < _path.size():
		if global_position.distance_to(_path[_path_index]) < 0.01:
			_path_index += 1
			_stuck_time = 0.0
		elif not _moving:
			_stuck_time += delta
			if _stuck_time > 0.4:
				cancel_navigation()
		else:
			_stuck_time = 0.0
	_update_depth()
	var arrived := _path_index >= _path.size()
	if arrived and manual.is_zero_approx():
		_moving = false
	if arrived and is_instance_valid(_delivery_target):
		_face_toward(_delivery_target.input_position())
		_delivery_target.accept_box(self)
		_delivery_target = null
	if arrived and is_instance_valid(_pickup_target):
		pickup_box(_pickup_target)
		_pickup_target = null
	_update_animation()
