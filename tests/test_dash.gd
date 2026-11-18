extends SceneTree

var worker: CharacterBody2D
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		failures += 1

func step(delta: float = 0.05) -> void:
	await physics_frame
	worker._physics_process(delta)

func press_dash() -> void:
	await process_frame
	Input.action_press("dash")
	await physics_frame
	worker._physics_process(0.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	worker = load("res://Worker.tscn").instantiate()
	root.add_child(worker)
	worker.set_physics_process(false)
	var sprite: AnimatedSprite2D = worker.sprite
	var normal_scale := sprite.scale
	var normal_position := sprite.position
	var normal_height: float = sprite.sprite_frames.get_frame_texture("walk", 0).get_height() * sprite.scale.y
	var key: InputEventKey = InputMap.action_get_events("dash")[0]
	check(key.physical_keycode == KEY_SHIFT, "Shift is mapped to dash")
	await press_dash()
	check(sprite.animation == &"idle", "Standing Shift does not dash")
	Input.action_release("dash")
	Input.action_press("move_right")
	await step()
	await press_dash()
	check(sprite.animation == &"dash" and not sprite.flip_h, "Moving Shift shows right-facing Dash")
	var dash_height: float = sprite.sprite_frames.get_frame_texture("dash", 0).get_height() * sprite.scale.y
	check(dash_height < normal_height, "Leaning Dash has a shorter silhouette than Walk")
	check(is_equal_approx(sprite.position.y + dash_height * 0.5, normal_position.y + normal_height * 0.5), "Smaller Dash keeps the same foot baseline")
	check(sprite.position.x == normal_position.x and is_equal_approx(sprite.scale.x / normal_scale.x, sprite.scale.y / normal_scale.y), "Dash preserves horizontal anchor and aspect ratio")
	check(worker.velocity == Vector2.RIGHT * worker.move_speed * 3.0, "Dash uses triple movement speed")
	worker._update_animation()
	check(sprite.animation == &"dash", "Per-frame animation cannot overwrite Dash")
	for i in 3:
		await step()
	check(sprite.animation == &"dash", "Dash remains active before 0.2 seconds")
	await step(0.051)
	check(sprite.animation == &"walk" and sprite.scale == normal_scale, "Dash restores Walk after 0.2 seconds")
	await step()
	check(sprite.animation == &"walk", "Held Shift does not retrigger")
	Input.action_release("dash")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await press_dash()
	check(sprite.animation != &"dash" and worker.velocity.x == -worker.move_speed, "Cooldown blocks Dash but allows normal movement")
	Input.action_release("dash")
	await step(0.36)
	await press_dash()
	check(sprite.animation == &"dash" and sprite.flip_h, "Dash mirrors with normal facing")
	Input.action_release("move_left")
	Input.action_release("dash")
	await step(0.21)
	check(sprite.animation == &"idle" and sprite.position == normal_position, "Stopped Dash restores Idle without shifting")
	await step(0.36)
	Input.action_press("move_right")
	worker.carrying_box = true
	worker.carried_box.show()
	await press_dash()
	check(sprite.animation == &"dash" and worker.carried_box.visible, "Dash preserves carried box")
	Input.action_release("dash")
	await step(0.21)
	check(sprite.animation == &"hold_walk", "Dash restores carried animation")
	await step(0.36)
	await press_dash()
	worker.set_dialogue_locked(true)
	check(sprite.animation == &"hold_idle" and sprite.scale == normal_scale, "Dialogue immediately cancels Dash")
	Input.action_release("dash")
	var before := worker.global_position
	await press_dash()
	check(sprite.animation == &"hold_idle" and worker.global_position == before, "Locked movement rejects Dash")
	Input.action_release("dash")
	Input.action_release("move_right")
	worker.set_dialogue_locked(false)
	worker.release_box()
	await step()
	check(sprite.animation == &"idle", "Unlock does not queue a Dash")
	# 暂停沿用场景树的处理规则，真实物理回调不能启动冲刺。
	worker.set_physics_process(true)
	paused = true
	Input.action_press("move_right")
	Input.action_press("dash")
	before = worker.global_position
	await physics_frame
	await physics_frame
	check(sprite.animation == &"idle" and worker.global_position == before, "Paused game rejects Dash and movement")
	Input.action_release("dash")
	Input.action_release("move_right")
	paused = false
	worker.set_physics_process(false)
	worker.queue_free()
	await process_frame
	print("Dash checks completed: %d failures" % failures)
	quit(1 if failures else 0)
