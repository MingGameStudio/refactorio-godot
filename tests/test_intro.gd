extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var intro = load("res://Intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	assert(intro.get_node("Cargo").get_child_count() == 11)
	assert(intro.get_node("FloorLayer").get_child_count() == 84)
	assert(not paused)
	var worker = intro.get_node("Worker")
	var before: Vector2 = worker.position
	var dialogue = intro.get_node("DialogueUI")
	assert(dialogue.is_active and worker.dialogue_locked)
	assert(dialogue.get_node("Root/Panel/JobTitle").text == "新厂长")
	assert(dialogue.get_node("Root/Panel/Name").text.is_empty())
	assert(not intro.get_node("UI/MovementHint").visible)
	Input.action_press("move_right")
	for i in range(6):
		await physics_frame
	Input.action_release("move_right")
	assert(worker.position == before, "Opening blocks movement without pausing the scene")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	assert(dialogue.get_node("Root/Panel/JobTitle").text == "新厂长", "Click waits for release")
	click.pressed = false
	root.push_input(click)
	assert(dialogue.get_node("Root/Panel/Name").text == "徐知夏")
	assert(dialogue.get_node("Root/Panel/JobTitle").text == "厂长助理")
	assert(worker.dialogue_locked and dialogue.get_node("Root/Portrait").texture != null)
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/intro-opening-preview.png")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	space.echo = true
	root.push_input(space)
	assert(dialogue.is_active, "Key repeat cannot skip opening")
	space.echo = false
	root.push_input(space)
	space.pressed = false
	root.push_input(space)
	assert(not dialogue.visible and not worker.dialogue_locked)
	assert(intro.get_node("UI/MovementHint").visible)
	Input.action_press("move_right")
	for i in range(6):
		await physics_frame
	Input.action_release("move_right")
	assert(worker.position.x > before.x)
	worker.position = before
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/intro-preview.png")
	var box: Sprite2D = intro.get_node("Cargo/LooseBox/Sprite2D")
	var pickup := InputEventKey.new()
	pickup.physical_keycode = KEY_E
	pickup.pressed = true
	root.push_input(pickup)
	assert(not worker.carrying_box, "Distant E cannot pick up")
	worker.position = box.global_position + Vector2(-36, 0)
	await physics_frame
	await process_frame
	assert(worker.can_pickup(box), "Box collider must not obstruct its own pickup")
	var frame: Sprite2D = intro.get_node("InteractionFrame")
	assert(frame.visible and frame.global_position.is_equal_approx(box.to_global(box.get_rect().get_center())), "Pickup frame encloses ground box")
	pickup.echo = true
	root.push_input(pickup)
	assert(not worker.carrying_box, "Key echo cannot pick up")
	pickup.echo = false
	worker.set_dialogue_locked(true)
	root.push_input(pickup)
	assert(not worker.carrying_box, "Dialogue lock blocks pickup")
	worker.set_dialogue_locked(false)
	root.push_input(pickup)
	await process_frame
	assert(worker.carrying_box and not box.visible)
	assert(worker.carried_box.texture == load("res://assets/Boxes/BoxFront.png"))
	assert(worker.sprite.animation == &"hold_idle")
	assert(intro.get_node("Cargo/LooseBox/CollisionShape2D").disabled)
	assert(not intro.get_node("UI/PickupHint").visible)
	assert(not frame.visible, "Pickup immediately hides frame")
	var held_scale: Vector2 = worker.carried_box.scale
	root.push_input(pickup)
	assert(worker.carried_box.scale == held_scale, "Repeated E leaves carried box unchanged")
	var pallet_sprite: Sprite2D = intro.get_node("Cargo/UpperPallet3/Sprite2D")
	var five_boxes := pallet_sprite.texture
	assert(pallet_sprite.texture == five_boxes and worker.carrying_box, "Distant E keeps carried box")
	var return_point: Vector2 = intro.get_node("Cargo/UpperPallet3/ReturnPoint").global_position
	worker.position = return_point + Vector2(0, -32)
	root.push_input(pickup)
	assert(worker.carrying_box and not intro._can_return_box(), "Cannot fill from behind pallet")
	worker.position = return_point + Vector2(0, 32)
	await physics_frame
	await process_frame
	assert(intro._can_return_box(), "Can return near missing box")
	assert(intro.get_node("UI/PickupHint").text == "E 放回箱子")
	assert(frame.visible and frame.global_position.x > pallet_sprite.global_position.x and frame.global_position.y < pallet_sprite.global_position.y - 45, "Return frame marks upper-right empty slot")
	if "--preview" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/intro-return-preview.png")
	pickup.echo = true
	root.push_input(pickup)
	assert(worker.carrying_box and pallet_sprite.texture == five_boxes, "Key repeat cannot return box")
	pickup.echo = false
	worker.set_dialogue_locked(true)
	root.push_input(pickup)
	assert(worker.carrying_box and pallet_sprite.texture == five_boxes, "Dialogue blocks returning box")
	worker.set_dialogue_locked(false)
	root.push_input(pickup)
	await physics_frame
	await process_frame
	assert(not worker.carrying_box and not worker.carried_box.visible)
	assert(worker.sprite.animation == &"idle")
	assert(pallet_sprite.texture == load("res://assets/Boxes/Boxes6.png"))
	assert(pallet_sprite.scale.is_equal_approx(intro.get_node("Cargo/UpperPallet4/Sprite2D").scale))
	assert(not box.visible and not intro.get_node("UI/PickupHint").visible)
	assert(not frame.visible, "Filled slot no longer highlighted")
	root.push_input(pickup)
	assert(not worker.carrying_box and intro._pallet_filled, "Completed pallet cannot consume another box")
	intro.queue_free()
	await process_frame
	print("Intro checks passed")
	quit()
