extends SceneTree

const SUCCESS := [
	"看来我的眼光不错。",
	"就多告诉你一点信息。我爸只给我三个月。救不活这家厂，就关门大吉，我们都得走人。",
	"三个月？行吧，刚端起饭碗，总不能第一天就陪你失业。从哪开始？",
	"先交出 5 个电池组的急单，顺便熟悉一下生产线！",
]
const MISSED := [
	"厂长先生，刚才地上那个箱子，你就这么放过它了？",
	"……光顾着看车间了。",
	"逗你的。不过留给我们的时间确实不多——",
	"我爸只给我三个月。救不活这家厂，就关门大吉，我们都得走人。",
	"三个月？行吧，刚端起饭碗，总不能第一天就陪你失业。从哪开始？",
	"先交出 5 个电池组的急单，顺便熟悉一下生产线！",
]

func _initialize() -> void:
	call_deferred("_run")

func key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event)
	event.pressed = false
	event.echo = false
	root.push_input(event)

func settle() -> void:
	for i in range(3):
		await physics_frame
		await process_frame

func _run() -> void:
	for scenario in ["success", "missed", "carrying"]:
		var intro = load("res://Intro.tscn").instantiate()
		root.add_child(intro)
		current_scene = intro
		await settle()
		var worker = intro.get_node("Worker")
		var ui = intro.get_node("DialogueUI")
		assert(intro.story_state == intro.StoryState.INTRO)
		intro._on_workshop_entered(worker)
		assert(intro.story_state == intro.StoryState.INTRO)
		assert(not ui.get_node("Voice").playing)
		key(KEY_SPACE)
		assert(ui.get_node("Voice").playing and ui.get_node("Voice").stream.resource_path.ends_with("Intro00.mp3"))
		key(KEY_SPACE)
		assert(not ui.get_node("Voice").playing)
		assert(intro.story_state == intro.StoryState.WALKING)
		if scenario != "missed":
			worker.position = intro.get_node("Cargo/LooseBox/Sprite2D").global_position + Vector2(-36, 0)
			await settle()
			key(KEY_E)
			assert(worker.carrying_box and intro.story_state == intro.StoryState.WALKING)
		if scenario == "success":
			worker.position = intro.get_node("Cargo/UpperPallet3/ReturnPoint").global_position + Vector2(0, 32)
			await settle()
			key(KEY_E)
			assert(intro._pallet_filled and not worker.carrying_box)
		else:
			worker.position = Vector2(726, 224)
			await settle()
			assert(not intro._pallet_filled)
		assert(intro.story_state == intro.StoryState.BRANCH_DIALOGUE)
		assert(worker.dialogue_locked and not intro.get_node("FemaleAssistant").follow_enabled)
		var original_position: Vector2 = worker.position
		Input.action_press("move_right")
		await settle()
		Input.action_release("move_right")
		assert(worker.position == original_position)
		var expected: Array = SUCCESS if scenario == "success" else MISSED
		var expected_voice := ["Intro01.mp3", "Intro02.mp3", "", "Intro06.mp3"] if scenario == "success" else ["Intro03.mp3", "", "Intro04.mp3", "Intro05.mp3", "", "Intro06.mp3"]
		var line_index := 0
		for line in expected:
			var voice: AudioStreamPlayer = ui.get_node("Voice")
			if expected_voice[line_index].is_empty():
				assert(not voice.playing and voice.stream == null)
			else:
				assert(voice.playing and voice.stream.resource_path.ends_with(expected_voice[line_index]))
			line_index += 1
			assert(ui.get_node("Root/Panel/Body").text == line, "Branch text must match verbatim")
			intro._on_workshop_entered(worker)
			intro._start_branch_dialogue()
			key(KEY_E)
			key(KEY_SPACE, true)
			assert(ui.get_node("Root/Panel/Body").text == line, "Branch cannot restart or skip on echo")
			key(KEY_SPACE)
		assert(intro.story_state == intro.StoryState.TASK_STARTED and worker.dialogue_locked)
		await settle()
		assert(current_scene != null and current_scene.scene_file_path == "res://Main.tscn")
		assert(not current_scene.get_node("Worker").dialogue_locked)
		current_scene.queue_free()
		await process_frame
		print("Branch passed: ", scenario)
	quit()
