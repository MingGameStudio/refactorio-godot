extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var intro = load("res://Intro.tscn").instantiate()
	root.add_child(intro)
	await physics_frame
	await process_frame
	var assistant = intro.get_node("FemaleAssistant")
	var worker = intro.get_node("Worker")
	var dialogue = intro.get_node("DialogueUI")
	assistant.set_physics_process(false)
	worker.set_physics_process(false)
	var start: Vector2 = assistant.position
	assistant._physics_process(0.1)
	assert(assistant.position == start and not assistant.follow_enabled)
	dialogue.finish_dialogue()
	assert(assistant.follow_enabled)
	var original_scale: Vector2 = assistant.scale
	# 模拟玩家沿无遮挡的中间通道匀速前进，助理每步不得瞬移。
	for i in range(60):
		worker.position.x += 160.0 / 60.0
		var before: Vector2 = assistant.position
		assistant._physics_process(1.0 / 60.0)
		assert(assistant.position.distance_to(before) <= assistant.move_speed / 60.0 + 0.01)
	assert(assistant.position.x > start.x and not assistant.flip_h)
	assert(assistant.texture != assistant.IDLE_TEXTURE)
	for i in range(180):
		assistant._physics_process(1.0 / 60.0)
	assert(absf(assistant.position.distance_to(worker.position) - assistant.follow_distance) < 1.0)
	assert(assistant.texture == assistant.IDLE_TEXTURE and assistant.scale == original_scale)
	# 转向、近距离退让和动画。
	worker.position = assistant.position + Vector2(-90, 0)
	assistant._physics_process(1.0 / 60.0)
	assert(assistant.flip_h and assistant.texture != assistant.IDLE_TEXTURE)
	worker.position = assistant.position + Vector2(10, 0)
	for i in range(90):
		assistant._physics_process(1.0 / 60.0)
	assert(assistant.position.distance_to(worker.position) > assistant.minimum_distance - 1.0)
	# 后续任意对话都暂停并面向玩家，结束后尊重剧情状态。
	worker.position = assistant.position + Vector2(100, 0)
	dialogue.start_dialogue([{"text": "测试对话"}])
	start = assistant.position
	assistant._physics_process(0.2)
	assert(assistant.position == start and not assistant.flip_h and assistant.texture == assistant.IDLE_TEXTURE)
	dialogue.finish_dialogue()
	assistant._physics_process(0.1)
	assert(assistant.position.x > start.x)
	dialogue.start_dialogue([{"text": "剧情停止跟随"}])
	assistant.follow_enabled = false
	dialogue.finish_dialogue()
	start = assistant.position
	assistant._physics_process(0.2)
	assert(assistant.position == start and assistant.texture == assistant.IDLE_TEXTURE)
	# 托盘阻挡时停步，不直线穿过设施。
	assistant.follow_enabled = true
	assistant.position = Vector2(424, 190)
	worker.position = Vector2(424, 70)
	for i in range(180):
		assistant._physics_process(1.0 / 60.0)
	assert(assistant.position.y >= 163.0, "Assistant feet cannot pass through pallet")
	assert(assistant.texture == assistant.IDLE_TEXTURE)
	intro.queue_free()
	await process_frame
	print("Assistant follow checks passed")
	quit()
