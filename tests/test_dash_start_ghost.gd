extends SceneTree

var failures := 0
var worker: CharacterBody2D
var world: Node2D

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func ghosts() -> Array[Node]:
	return world.get_children().filter(func(node: Node) -> bool: return node is Sprite2D and node.material is ShaderMaterial)

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
	world.position = Vector2(30, 40)
	world.scale = Vector2(1.2, 1.2)
	root.add_child(world)
	for animation in ["idle", "walk", "hold_walk"]:
		worker = load("res://Worker.tscn").instantiate()
		world.add_child(worker)
		worker.set_physics_process(false)
		await press_dash()
		check(ghosts().is_empty(), "No ghost without direction")
		Input.action_press("move_right")
		worker.set_dialogue_locked(true)
		await press_dash()
		check(ghosts().is_empty(), "No ghost while locked")
		worker.set_dialogue_locked(false)
		worker.sprite.play(animation)
		worker.sprite.pause()
		worker.sprite.frame = 0 if animation == "idle" else 2
		worker.sprite.flip_h = true
		var texture: Texture2D = worker.sprite.sprite_frames.get_frame_texture(animation, worker.sprite.frame)
		var pose: Transform2D = worker.sprite.global_transform
		await press_dash()
		check(ghosts().size() == 1, "Exactly one starting ghost")
		var ghost: Sprite2D = ghosts()[0]
		check(ghost.texture == texture and ghost.flip_h, "Previous frame and facing preserved: " + animation)
		check(ghost.global_transform.is_equal_approx(pose), "Original visual center and scale preserved")
		check(worker.sprite.animation == &"dash", "Live worker switches to Dash")
		check(ghost.material.shader == load("res://dash_start_ghost.gdshader"), "Only starting ghost uses grayscale")
		await create_timer(0.02).timeout
		check(is_equal_approx(ghost.modulate.a, worker.dash_start_ghost_opacity), "Brief hold before fading")
		await press_dash()
		check(ghosts().size() == 1, "Active Dash does not duplicate starting ghost")
		worker.position += Vector2(40, -80)
		worker._update_depth()
		check(ghost.global_transform.is_equal_approx(pose) and ghost.z_index < worker.z_index, "Ghost stays at origin behind worker")
		worker.set_dialogue_locked(true)
		await create_timer(0.08).timeout
		check(is_instance_valid(ghost) and ghost.modulate.a < worker.dash_start_ghost_opacity, "Ghost fades after interruption")
		worker.queue_free()
		Input.action_release("dash")
		Input.action_release("move_right")
		await create_timer(0.3).timeout
		check(ghosts().is_empty(), "Ghost self-cleans after worker removal")
	world.queue_free()
	await process_frame
	print("Dash start ghost checks completed: %d failures" % failures)
	quit(1 if failures else 0)
