extends SceneTree
const PhysicsSteps = preload("res://tests/physics_steps.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 4.0
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	game.get_node("TickTimer").stop()
	var worker = game.get_node("Worker")
	var box = game.get_node("Box")
	worker.set_physics_process(false)
	await physics_frame
	assert(box.position == Vector2(-32, 288) and box.is_port_pickup())
	assert(not worker.can_pickup(box))
	# 地图外点击只把工人带到内部取料格，不扩展寻路范围。
	var click: Vector2 = box.to_global(box.get_rect().get_center())
	game._press_world = click
	game._drag_start = game.world_to_cell(click)
	game._pointer_dragged = false
	game._drag_can_build = false
	game._finish_left_gesture(click)
	assert(worker.target_position == Vector2(32, 288))
	await PhysicsSteps.advance(worker, 10.0)
	assert(worker.carrying_box and not box.visible)
	assert(worker.position.x >= 10.0)
	# 原有投料流程仍负责库存；一次箱子增加十份原料。
	var source = game._source_machine
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game.welding_interaction._unhandled_key_input(key)
	assert(source.feeding)
	source._process(1.0)
	assert(source.capacity == 10 and not worker.carrying_box)
	box.show()
	worker.position = Vector2(32, 224)
	assert(not worker.can_pickup(box), "Adjacent row cannot reach through wall")
	worker.position = Vector2(32, 288)
	worker.set_dialogue_locked(true)
	assert(not worker.can_pickup(box))
	worker.set_dialogue_locked(false)
	worker.position = Vector2(32, 224)
	game._set_building(Vector2i(0, 4), game.Building.BELT)
	worker.position = Vector2(32, 288)
	await physics_frame
	assert(not worker.can_pickup(box), "Port exception must not bypass facility collision")
	game._clear_building(Vector2i(0, 4))
	await physics_frame
	assert(worker.can_pickup(box))
	game.welding_interaction._unhandled_key_input(key)
	assert(worker.carrying_box and not box.visible)
	assert(not worker.move_to(box.global_position), "Outside cell is never walkable")
	print("Inlet pickup checks passed")
	game.queue_free()
	await process_frame
	quit()
