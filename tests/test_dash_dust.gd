extends SceneTree
var failures := 0
var worker: CharacterBody2D
var world: Node2D

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func dust_nodes() -> Array[Node]:
	return world.get_children().filter(func(node: Node) -> bool: return node.get_script() == preload("res://DashDustEffect.gd"))

func press_dash() -> void:
	Input.action_release("dash")
	await process_frame
	Input.action_press("dash")
	await physics_frame
	worker._physics_process(0.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	worker = load("res://Worker.tscn").instantiate()
	world.add_child(worker)
	worker.set_physics_process(false)
	await press_dash()
	check(dust_nodes().is_empty(), "No direction produces no dust")
	Input.action_press("move_right")
	worker.set_dialogue_locked(true)
	await press_dash()
	check(dust_nodes().is_empty(), "Dialogue blocks dust")
	worker.set_dialogue_locked(false)
	await press_dash()
	check(dust_nodes().size() == 1, "Successful Dash creates exactly one effect")
	var effect: Node2D = dust_nodes()[0]
	check(effect.global_position == worker.global_position and effect.get_parent() == world, "Effect spawns at feet as world sibling")
	check(effect.get_child_count() == 4 and effect.z_index < worker.z_index, "Main cloud plus three particles behind player")
	await press_dash()
	check(dust_nodes().size() == 1, "Active Dash does not emit again")
	worker._stop_dash()
	await press_dash()
	check(dust_nodes().size() == 1, "Cooldown does not emit dust")
	Input.action_release("dash")
	Input.action_release("move_right")
	await create_timer(0.35).timeout
	check(dust_nodes().is_empty(), "Completed Tween frees effect")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		effect = load("res://DashDustEffect.tscn").instantiate()
		world.add_child(effect)
		effect.global_position = worker.global_position
		effect.play(direction, worker)
		var anchor := effect.global_position
		var cloud: Sprite2D = effect.get_node("MainDust")
		var origin := cloud.position
		var initial_scale := cloud.scale
		worker.position += Vector2(40, -80)
		worker._update_depth()
		await create_timer(0.1).timeout
		check(effect.global_position == anchor, "Effect anchor does not follow worker")
		check((cloud.position - origin).dot(-direction.normalized()) > 0, "Cloud moves opposite Dash in all eight directions")
		check(cloud.scale.x > initial_scale.x and cloud.modulate.a < 0.85, "Cloud expands and fades")
		check(effect.z_index < worker.z_index, "Effect remains behind worker across depth rows")
		paused = true
		await create_timer(0.25, true).timeout
		check(not is_instance_valid(effect), "Effect cleans up even if game pauses")
		paused = false
	world.queue_free()
	await process_frame
	print("Dash dust checks completed: %d failures" % failures)
	quit(1 if failures else 0)
