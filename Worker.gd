extends CharacterBody2D
const GridDepth = preload("res://GridDepth.gd")
const DASH_DUST_SCENE = preload("res://DashDustEffect.tscn")
const DASH_START_GHOST_SHADER = preload("res://dash_start_ghost.gdshader")

@export var move_speed: float = 160.0
@export_range(1.0, 10.0, 0.1) var dash_speed_multiplier: float = 3.0
@export_range(0.01, 2.0, 0.01) var dash_duration: float = 0.2
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.35
@export_range(0.1, 2.0, 0.01) var dash_sprite_scale_multiplier: float = 0.9
@export_range(0.01, 1.0, 0.01) var afterimage_interval: float = 0.05
@export_range(0.0, 1.0, 0.01) var afterimage_opacity: float = 0.55
@export_range(0.01, 2.0, 0.01) var afterimage_fade_duration: float = 0.22
@export_range(0.0, 1.0, 0.01) var dash_start_ghost_opacity: float = 0.5
@export_range(0.0, 1.0, 0.01) var dash_start_ghost_hold: float = 0.2
@export_range(0.01, 1.0, 0.01) var dash_start_ghost_fade: float = 0.2
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var carried_box: Sprite2D = $CarriedBox
var target_position: Vector2
var carrying_box: bool = false
var carried_box_node: Sprite2D
var carried_box_kind: String = "raw_material"
var operating: bool = false
var dialogue_locked: bool = false
var _pickup_target: Sprite2D
var _delivery_target: Node2D
var pathfinder: Callable
var _path := PackedVector2Array()
var _path_index: int = 0
var _moving: bool = false
var _stuck_time: float = 0.0
var _dash_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_direction := Vector2.ZERO
var _normal_sprite_scale: Vector2
var _dash_sprite_scale: Vector2
var _normal_sprite_position: Vector2
var _dash_sprite_position: Vector2
var _afterimage_elapsed: float = 0.0
var _afterimage_blocked: bool = false
var _afterimages: Array[Sprite2D] = []

func cancel_navigation() -> void:
	_path.clear()
	_path_index = 0
	_pickup_target = null
	_delivery_target = null
	target_position = global_position
	_stuck_time = 0.0

func _ready() -> void:
	target_position = global_position
	_normal_sprite_scale = sprite.scale
	_normal_sprite_position = sprite.position
	# 按身体比例缩放，保留前倾姿势较矮的轮廓；缩小后下移中心以固定脚底。
	var frames := sprite.sprite_frames
	_dash_sprite_scale = _normal_sprite_scale * dash_sprite_scale_multiplier
	var walk_height := frames.get_frame_texture("walk", 0).get_height() * _normal_sprite_scale.y
	var dash_height := frames.get_frame_texture("dash", 0).get_height() * _dash_sprite_scale.y
	_dash_sprite_position = _normal_sprite_position + Vector2(0.0, (walk_height - dash_height) * 0.5)
	sprite.play("idle")
	_update_depth()

func _update_depth() -> void:
	# 根节点位于脚底；sprite 的向上偏移不参与遮挡排序。
	z_index = GridDepth.at_position(position, GridDepth.WORKER)
	# 向上跨行时也保证旧残影在真人身后，不改变残影的世界位置。
	for index in range(_afterimages.size() - 1, -1, -1):
		var ghost := _afterimages[index]
		if not is_instance_valid(ghost):
			_afterimages.remove_at(index)
		else:
			ghost.z_index = mini(ghost.z_index, z_index - 1)

func move_to(destination: Vector2) -> bool:
	if dialogue_locked or _dash_remaining > 0.0:
		return false
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
	if _dash_remaining > 0.0:
		horizontal = _dash_direction.x
	if not is_zero_approx(horizontal):
		sprite.flip_h = horizontal < 0.0
	carried_box.position.x = -22.0 if sprite.flip_h else 22.0

func request_pickup(box: Sprite2D) -> void:
	if carrying_box or not is_instance_valid(box) or not box.visible:
		return
	if box.has_method("pickup_approaches"):
		for point in box.pickup_approaches():
			if move_to(point):
				_pickup_target = box
				return
		return
	if box.has_method("is_port_pickup") and box.is_port_pickup():
		if move_to(box.pickup_approach()):
			_pickup_target = box
		return
	# 从左右较近的一侧接近，停在箱子旁边，避免脚底与箱子重合。
	var side := -1.0 if global_position.x <= box.global_position.x else 1.0
	# 较近的一侧不可达时尝试另一侧；不绕过寻路直接移动。
	for direction in [side, -side]:
		if move_to(box.global_position + Vector2(direction * 32.0, 0.0)):
			_pickup_target = box
			return

func can_pickup(box: Sprite2D) -> bool:
	if dialogue_locked:
		return false
	if carrying_box or not is_instance_valid(box) or not box.visible:
		return false
	if box.has_method("pickup_approaches"):
		return box.can_pickup_from(self)
	if box.has_method("is_port_pickup") and box.is_port_pickup():
		return box.can_pickup_from(self)
	if global_position.distance_to(box.global_position) > 48.0:
		return false
	# E 近距离拾取不能隔着设施进行；物理层 1 仅包含设施和地图边界。
	var ray := PhysicsRayQueryParameters2D.create(global_position, box.global_position, 1)
	# 可拾取物自身的碰撞体不是遮挡；设施仍参与射线检测。
	if box.get_parent() is CollisionObject2D:
		ray.exclude = [box.get_parent().get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func pickup_box(box: Sprite2D) -> bool:
	if not can_pickup(box):
		return false
	cancel_navigation()
	_face_toward(box.global_position)
	box.hide()
	carried_box_node = box
	carried_box_kind = str(box.get_meta("box_kind", "raw_material"))
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
	carried_box_node = null
	carried_box_kind = "raw_material"
	carried_box.hide()

func set_operating(value: bool) -> void:
	operating = value
	_update_animation()

func _update_animation() -> void:
	if _dash_remaining > 0.0:
		sprite.scale = _dash_sprite_scale
		sprite.position = _dash_sprite_position
		sprite.play("dash")
		return
	sprite.scale = _normal_sprite_scale
	sprite.position = _normal_sprite_position
	var arrived := not _moving and _path_index >= _path.size()
	if carrying_box:
		sprite.play("hold_idle" if arrived else "hold_walk")
	elif operating and arrived:
		sprite.play("interact")
	else:
		sprite.play("idle" if arrived else "walk")

func _physics_process(delta: float) -> void:
	if dialogue_locked:
		_stop_dash()
		return
	var manual := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _dash_remaining > 0.0:
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
		if _dash_remaining < 0.000001:
			_stop_dash()
	else:
		_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
		if _dash_cooldown_remaining < 0.000001:
			_dash_cooldown_remaining = 0.0
	# 仅响应手动移动时的新按下；长按或冲刺期间再次按下均不延长姿势。
	if _dash_remaining <= 0.0 and _dash_cooldown_remaining <= 0.0 and not manual.is_zero_approx() and Input.is_action_just_pressed("dash"):
		# 在移动、转向及 Dash 姿势切换之前，保存当前 Idle/Walk 等动画帧。
		_spawn_afterimage(true)
		cancel_navigation()
		_dash_direction = manual.normalized()
		_dash_remaining = dash_duration
		_afterimage_elapsed = 0.0
		_afterimage_blocked = false
		var dust := DASH_DUST_SCENE.instantiate()
		get_parent().add_child(dust)
		dust.global_position = global_position
		dust.play(_dash_direction, self)
	var before := global_position
	velocity = Vector2.ZERO
	if _dash_remaining > 0.0:
		velocity = _dash_direction * move_speed * dash_speed_multiplier
		_face_toward(global_position + _dash_direction)
	elif not manual.is_zero_approx():
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
	if _dash_remaining > 0.0 or not manual.is_zero_approx():
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
	if arrived and manual.is_zero_approx() and _dash_remaining <= 0.0:
		_moving = false
	if arrived and is_instance_valid(_delivery_target):
		_face_toward(_delivery_target.input_position())
		_delivery_target.accept_box(self)
		_delivery_target = null
	if arrived and is_instance_valid(_pickup_target):
		pickup_box(_pickup_target)
		_pickup_target = null
	_update_animation()
	_update_afterimages(delta)

func _update_afterimages(delta: float) -> void:
	if _dash_remaining <= 0.0 or dialogue_locked or delta <= 0.0:
		return
	# 碰撞只停止本次冲刺的残影发射，不修改原有冲刺/滑墙行为。
	if get_slide_collision_count() > 0:
		_afterimage_blocked = true
	if _afterimage_blocked:
		return
	_afterimage_elapsed += delta
	if _afterimage_elapsed + 0.000001 >= afterimage_interval:
		_afterimage_elapsed = fmod(maxf(0.0, _afterimage_elapsed - afterimage_interval), afterimage_interval)
		_spawn_afterimage()

func _spawn_afterimage(start_ghost: bool = false) -> void:
	var ghost := Sprite2D.new()
	ghost.name = "DashAfterimage"
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v
	ghost.texture_filter = sprite.texture_filter
	ghost.modulate = sprite.modulate * sprite.self_modulate
	ghost.modulate.a = afterimage_opacity
	if start_ghost:
		ghost.name = "DashStartGhost"
		ghost.modulate.a = dash_start_ghost_opacity
		var grayscale := ShaderMaterial.new()
		grayscale.shader = DASH_START_GHOST_SHADER
		ghost.material = grayscale
	ghost.z_index = z_index - 1
	# 仅复制视觉节点，放到工人的世界父节点；不继承工人后续变换。
	get_parent().add_child(ghost)
	ghost.top_level = true
	ghost.global_transform = sprite.global_transform
	_afterimages.append(ghost)
	# Tween 绑定残影本身，工人移除或场景暂停也不会留下永久残影。
	var fade := ghost.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if start_ghost:
		fade.tween_interval(dash_start_ghost_hold)
	fade.tween_property(ghost, "modulate:a", 0.0, dash_start_ghost_fade if start_ghost else afterimage_fade_duration)
	fade.tween_callback(ghost.queue_free)

func _stop_dash() -> void:
	if _dash_direction.is_zero_approx():
		return
	_dash_remaining = 0.0
	_dash_direction = Vector2.ZERO
	_dash_cooldown_remaining = dash_cooldown
	velocity = Vector2.ZERO
	_moving = false
	_update_animation()

func _notification(what: int) -> void:
	# 场景树暂停/节点禁用后不会再执行物理帧，立即终止，恢复时不续冲。
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_DISABLED:
		_stop_dash()

func set_dialogue_locked(value: bool) -> void:
	dialogue_locked = value
	if value:
		_stop_dash()
		cancel_navigation()
		velocity = Vector2.ZERO
		_moving = false
		set_operating(false)
