extends CanvasLayer
## 独立剧情 UI。TutorialManager 可调用 start_dialogue，并等待 dialogue_finished。
signal dialogue_finished
signal active_changed(active: bool)

@export var idle_frames: SpriteFrames = preload("res://FemaleAssistantIdle.tres")
@export var mouse_advance_enabled: bool = false

var is_active: bool = false
var _lines: Array[Dictionary] = []
var _index: int = 0
var _space_held: bool = false
var _mouse_pressed: bool = false
var _idle_elapsed: float = 0.0
var _use_idle: bool = false
var _opening_frames: SpriteFrames

@onready var _root: Control = $Root
@onready var _panel: Control = $Root/Panel
@onready var _portrait: TextureRect = $Root/Portrait
@onready var _default_portrait: Texture2D = _portrait.texture
@onready var _voice: AudioStreamPlayer = $Voice

func _ready() -> void:
	hide()
	visibility_changed.connect(_on_visibility_changed)
	if mouse_advance_enabled:
		$Root/Panel/ContinueHint.text = "▶ 点击 / 空格继续"
	# 等待子控件完成锚点更新，再计算背景的实际位置。
	_root.resized.connect(_layout.call_deferred)
	_layout()

## 每句格式：{ "text": String, "name": String, "job_title": String, "portrait": Texture2D, "voice": AudioStream }。
## voice 可省略；语音播放结束不推进对话。
## opening_frames 可选：整段对话开始时播放一次，再切回 Idle；切句不重播。
## 播放中拒绝覆盖；空数组不启动。返回是否成功开始。
func start_dialogue(lines: Array, opening_frames: SpriteFrames = null) -> bool:
	if is_active or lines.is_empty():
		return false
	_lines.clear()
	for line in lines:
		if not line is Dictionary or not line.get("text") is String:
			_lines.clear()
			push_warning("DialogueUI: 每句对话必须包含 text 字符串")
			return false
		_lines.append(line.duplicate())
	_index = 0
	_opening_frames = opening_frames
	_idle_elapsed = 0.0
	_mouse_pressed = false
	_space_held = Input.is_physical_key_pressed(KEY_SPACE)
	is_active = true
	_show_line()
	show()
	active_changed.emit(true)
	return true

func _show_line() -> void:
	_voice.stop()
	var line := _lines[_index]
	_voice.stream = line.get("voice", null)
	if _voice.stream != null:
		_voice.play()
	$Root/Panel/Name.text = str(line.get("name", ""))
	$Root/Panel/JobTitle.text = str(line.get("job_title", ""))
	$Root/Panel/Body.text = line.text
	$Root/Panel/Body.scroll_to_line(0)
	_portrait.texture = line.get("portrait", _default_portrait)
	# 显式指定其他人物静态立绘时，不覆盖为徐知夏的待机动画。
	_use_idle = not line.has("portrait")
	_update_idle_portrait()
	_layout()

func _process(delta: float) -> void:
	if not is_active:
		return
	_idle_elapsed += delta
	_update_idle_portrait()

func _update_idle_portrait() -> void:
	if not _use_idle or idle_frames == null or idle_frames.get_frame_count(&"default") == 0:
		return
	# 单次开场动画与文本索引无关，切句不重置，播完立即循环现有 Idle。
	var idle_time := _idle_elapsed
	if _opening_frames != null and _opening_frames.get_frame_count(&"default") > 0:
		var speed := maxf(_opening_frames.get_animation_speed(&"default"), 0.01)
		var duration := _opening_frames.get_frame_count(&"default") / speed
		if _idle_elapsed < duration:
			_portrait.texture = _opening_frames.get_frame_texture(&"default", int(_idle_elapsed * speed))
			return
		idle_time -= duration
	var frame := int(idle_time * idle_frames.get_animation_speed(&"default")) % idle_frames.get_frame_count(&"default")
	_portrait.texture = idle_frames.get_frame_texture(&"default", frame)

func finish_dialogue() -> void:
	_voice.stop()
	if not is_active:
		return
	is_active = false
	_opening_frames = null
	hide()
	_lines.clear()
	active_changed.emit(false)
	dialogue_finished.emit()

func _exit_tree() -> void:
	if is_instance_valid(_voice):
		_voice.stop()
	# 中途移除 UI 时也释放宿主的输入锁。
	if is_active:
		active_changed.emit(false)

func _on_visibility_changed() -> void:
	if not visible:
		_voice.stop()

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	get_viewport().set_input_as_handled()
	if mouse_advance_enabled and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_pressed = true
		elif _mouse_pressed:
			# 松开时推进，完整吞掉点击，避免关闭 UI 后事件落到场景中。
			_mouse_pressed = false
			_advance_line()
	if event is InputEventKey and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE):
		if not event.pressed:
			_space_held = false
		elif not event.echo and not _space_held:
			_space_held = true
			_mouse_pressed = false
			_advance_line()

func _advance_line() -> void:
	_index += 1
	if _index >= _lines.size():
		finish_dialogue()
	else:
		_show_line()

func _layout() -> void:
	# 以背景原始 2052×457 为设计坐标，文字与背景一起等比缩放。
	var viewport_size := _root.size
	var fit_scale := minf(viewport_size.x * 0.96 / 2052.0, viewport_size.y * 0.42 / 457.0)
	_panel.scale = Vector2.ONE * fit_scale
	_panel.position = Vector2(viewport_size.x * 0.5 - 2052.0 * fit_scale * 0.5,
		viewport_size.y - 457.0 * fit_scale - 16.0)
	if _portrait.texture != null:
		# 与 OpeningPortrait 使用相同的可见高度、透明留白和贴底基准。
		var portrait_scale := viewport_size.y * 0.93 / 768.0
		_portrait.size = _portrait.texture.get_size() * portrait_scale
		_portrait.position = Vector2(-104.0 * portrait_scale,
			viewport_size.y - 924.0 * portrait_scale)
