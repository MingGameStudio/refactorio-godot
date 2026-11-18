extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ui = load("res://DialogueUI.tscn").instantiate()
	root.add_child(ui)
	var voice: AudioStreamPlayer = ui.get_node("Voice")
	var clip := load("res://assets/audio/dialogs/intro/Intro01.mp3")
	ui.start_dialogue([{"text": "语音", "voice": clip}, {"text": "无语音"}])
	assert(voice.playing and voice.stream == clip)
	ui._advance_line()
	assert(not voice.playing and voice.stream == null)
	ui.finish_dialogue()
	ui.start_dialogue([{"text": "跳过", "voice": clip}])
	ui.finish_dialogue()
	assert(not voice.playing)
	ui.start_dialogue([{"text": "隐藏", "voice": clip}])
	ui.hide()
	assert(not voice.playing)
	ui.finish_dialogue()
	# 短音频自然播放结束，不应自动推进或关闭对话。
	var short_clip := AudioStreamWAV.new()
	short_clip.mix_rate = 8000
	short_clip.format = AudioStreamWAV.FORMAT_16_BITS
	var samples := PackedByteArray()
	samples.resize(800)
	short_clip.data = samples
	ui.start_dialogue([{"text": "等待操作", "voice": short_clip}, {"text": "下一句"}])
	await create_timer(0.3).timeout
	assert(not voice.playing and ui.is_active and ui.visible)
	assert(ui.get_node("Root/Panel/Body").text == "等待操作")
	ui.finish_dialogue()
	ui.start_dialogue([{"text": "中断", "voice": clip}])
	root.remove_child(ui)
	assert(not voice.playing)
	ui.free()
	print("Dialogue voice checks passed")
	quit()
