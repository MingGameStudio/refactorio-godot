extends Node
## 玩家 E 交互适配层：拾箱、输入带投料和点焊，并持续验证操作距离。
var game: Node2D
var worker: Node2D
var active: Node2D
var focused: Node2D
var _hint: Label
const INTERACTION_FRAME = preload("res://assets/UI/InteractionFrame.png")
var _frame: Sprite2D
var _frame_base_scale := Vector2.ONE
var _breath_time: float = 0.0
const BREATH_PERIOD: float = 1.8

func _process(delta: float) -> void:
	if not is_instance_valid(_frame) or not _frame.visible:
		_breath_time = 0.0
		return
	_breath_time = fmod(_breath_time + delta, BREATH_PERIOD)
	_apply_frame_breath()

func _apply_frame_breath() -> void:
	var pulse := 0.5 - 0.5 * cos(_breath_time / BREATH_PERIOD * TAU)
	_frame.scale = _frame_base_scale * lerpf(1.0, 1.035, pulse)
	_frame.modulate.a = lerpf(0.8, 1.0, pulse)

func _ready() -> void:
	_hint = Label.new()
	_hint.name = "InteractionHint"
	_hint.position = Vector2(8, 48)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.get_node("UI").add_child(_hint)
	_frame = Sprite2D.new()
	_frame.name = "InteractionFrame"
	_frame.texture = INTERACTION_FRAME
	_frame.z_index = 100
	_frame.hide()
	game.add_child(_frame)

func _show_frame(target: Node2D, bounds: Rect2) -> void:
	# 将目标的实际矩形转换到关卡坐标，兼容箱子偏移和机器缩放。
	var relative: Transform2D = game.global_transform.affine_inverse() * target.global_transform
	var rect: Rect2 = (relative * bounds).grow(8.0)
	_frame.position = rect.get_center()
	_frame_base_scale = rect.size / INTERACTION_FRAME.get_size()
	_apply_frame_breath()
	_frame.show()

func _can_deliver() -> bool:
	return is_instance_valid(game._source_machine) and game._source_machine.can_accept_box(worker, false)

func is_near(machine: Node2D) -> bool:
	return worker.global_position.distance_to(machine.to_global(Vector2(32, 32))) <= 68.0

func _physics_process(delta: float) -> void:
	if is_instance_valid(active):
		active.advance_operation(delta, worker, is_near(active))
		if not active.processing:
			active = null
	worker.set_operating(is_instance_valid(active) and active.processing)
	focused = null
	var nearest := INF
	for machine in game.get_welding_machines():
		machine.get_node("Prompt").hide()
		var distance: float = worker.global_position.distance_to(machine.to_global(Vector2(32, 32)))
		if distance <= 68.0 and distance < nearest:
			nearest = distance
			focused = machine
	var box_ready: bool = not is_instance_valid(active) and worker.can_pickup(game._box)
	var delivery_ready: bool = not is_instance_valid(active) and worker.carrying_box and _can_deliver()
	_hint.text = "E 投料" if delivery_ready else ("E 拾取箱子" if box_ready else "")
	_frame.hide()
	# 与 E 的执行优先级一致，同一时刻只标记实际将响应的目标。
	if delivery_ready:
		_show_frame(game._source_machine.get_node("InputBelt"), Rect2(0, 0, 64, 64))
	elif box_ready:
		_show_frame(game._box, game._box.get_rect())
	elif not is_instance_valid(active) and is_instance_valid(focused) and not worker.carrying_box and focused.can_begin_operation(worker):
		var sprite: Sprite2D = focused.get_node("Sprite2D")
		_show_frame(sprite, sprite.get_rect())
	if is_instance_valid(focused) and not worker.carrying_box and not box_ready:
		focused.get_node("Prompt").show()

func operate() -> bool:
	_physics_process(0.0)
	if is_instance_valid(active):
		return false
	if worker.carrying_box:
		if not _can_deliver():
			return false
		worker._face_toward(game._source_machine.input_position())
		if game._source_machine.accept_box(worker):
			worker.cancel_navigation()
			worker.set_operating(false)
			_physics_process(0.0)
			return true
		return false
	if worker.pickup_box(game._box):
		_physics_process(0.0)
		return true
	if not is_instance_valid(focused):
		return false
	if focused.begin_operation(worker):
		active = focused
		worker._face_toward(active.to_global(Vector2(32, 32)))
		worker.set_operating(true)
		_frame.hide()
		return true
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode != KEY_E:
		return
	if event.pressed and not event.echo:
		operate()
	elif not event.pressed and is_instance_valid(active):
		active.cancel_operation()
		active = null
		worker.set_operating(false)
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(active):
		active.cancel_operation()
		active = null
		worker.set_operating(false)
