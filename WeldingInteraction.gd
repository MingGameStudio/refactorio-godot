extends Node
## 玩家 E 交互适配层：拾箱、输入带投料和点焊，并持续验证操作距离。
var game: Node2D
var worker: Node2D
var active: Node2D
var focused: Node2D
var _e_held: bool = false
var _waiting_welder: Node2D
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
	if worker.dialogue_locked:
		return
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
	var pickup_box: Sprite2D = game.nearest_pickup_box()
	# 提前按住 E 等待电芯：只延续本次在该机器旁发起的操作意图。
	if is_instance_valid(_waiting_welder):
		if not _e_held or focused != _waiting_welder or worker.carrying_box or pickup_box != null:
			_waiting_welder = null
		elif not is_instance_valid(active) and _waiting_welder.can_begin_operation(worker):
			_begin_welding(_waiting_welder)
	var box_ready: bool = not is_instance_valid(active) and pickup_box != null
	var delivery_ready: bool = not is_instance_valid(active) and worker.carrying_box and _can_deliver()
	var shipping_ready: bool = not is_instance_valid(active) and game.can_ship_carried_box()
	_hint.text = "E 投料" if delivery_ready else ("E 拾取箱子" if box_ready else "")
	if worker.carrying_box and not delivery_ready:
		if game.is_at_shipping_port():
			_hint.text = "E 发货（+1）" if shipping_ready else "出货口仅接收装箱机生成的成品箱"
		else:
			_hint.text += "  Q 放下箱子（面前空格）"
	_frame.hide()
	# 与 E 的执行优先级一致，同一时刻只标记实际将响应的目标。
	if shipping_ready:
		# 标记墙外出货格，复用 S1 投料的目标框与呼吸效果。
		var approach: Node2D = game.get_node("WorkshopWalls/OutletApproach")
		_show_frame(approach, Rect2(Vector2(game.CELL * 0.5, -game.CELL * 0.5), Vector2.ONE * game.CELL))
	elif delivery_ready:
		_show_frame(game._source_machine.get_node("InputBelt"), Rect2(0, 0, 64, 64))
	elif box_ready:
		_show_frame(pickup_box, pickup_box.get_rect())
	elif not is_instance_valid(active) and is_instance_valid(focused) and not worker.carrying_box and focused.can_begin_operation(worker):
		var sprite: Sprite2D = focused.get_node("Sprite2D")
		_show_frame(sprite, sprite.get_rect())
	if is_instance_valid(focused) and not worker.carrying_box and not box_ready:
		focused.get_node("Prompt").show()

func operate() -> bool:
	if worker.dialogue_locked:
		return false
	_physics_process(0.0)
	if is_instance_valid(active):
		return false
	if worker.carrying_box:
		if game.can_ship_carried_box():
			if game._ship_carried_box():
				_physics_process(0.0)
				return true
		if not _can_deliver():
			return false
		worker._face_toward(game._source_machine.input_position())
		if game._source_machine.accept_box(worker):
			worker.cancel_navigation()
			worker.set_operating(false)
			_physics_process(0.0)
			return true
		return false
	if worker.pickup_box(game.nearest_pickup_box()):
		_physics_process(0.0)
		return true
	if not is_instance_valid(focused):
		return false
	if _begin_welding(focused):
		return true
	if _e_held and focused.cells < 2 and not focused.output_pending:
		_waiting_welder = focused
	return false

func _begin_welding(machine: Node2D) -> bool:
	if machine.begin_operation(worker):
		_waiting_welder = null
		active = machine
		worker._face_toward(active.to_global(Vector2(32, 32)))
		worker.set_operating(true)
		_frame.hide()
		return true
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if worker.dialogue_locked:
		return
	if not event is InputEventKey or event.physical_keycode != KEY_E:
		return
	if event.pressed and not event.echo:
		_e_held = true
		operate()
	elif not event.pressed:
		_e_held = false
		_waiting_welder = null
		if is_instance_valid(active):
			active.cancel_operation()
			active = null
			worker.set_operating(false)
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_e_held = false
		_waiting_welder = null
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(active):
		active.cancel_operation()
		active = null
		worker.set_operating(false)

func cancel_for_dialogue() -> void:
	_e_held = false
	_waiting_welder = null
	if is_instance_valid(active):
		active.cancel_operation()
	active = null
	focused = null
	worker.set_operating(false)
	_hint.text = ""
	_frame.hide()
	for machine in game.get_welding_machines():
		machine.get_node("Prompt").hide()
