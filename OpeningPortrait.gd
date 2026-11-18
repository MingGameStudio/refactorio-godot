extends CanvasLayer
## 开场立绘独立于关卡；暂停游戏时仍播放，点击释放后恢复游戏。

@export var frames: SpriteFrames
@export var idle_frames: SpriteFrames = preload("res://FemaleAssistantIdle.tres")
@export_range(1.0, 60.0) var frames_per_second: float = 12.0
## 序列帧共有的左侧透明留白（原图像素），统一偏移以保留入场动作。
@export var transparent_left_margin: float = 104.0
## 按人物可见区域计算高度，排除 PNG 上下透明留白。
@export var portrait_top: float = 156.0
@export var portrait_bottom: float = 924.0
@export_range(0.1, 1.0) var screen_height_ratio: float = 0.93

var _elapsed: float = 0.0
var _dismiss_button: int = 0
var _was_paused: bool = false
var _finished: bool = false

@onready var _portrait: TextureRect = $Root/Portrait

func _ready() -> void:
	if frames == null or frames.get_frame_count(&"default") == 0:
		queue_free()
		return
	_portrait.texture = frames.get_frame_texture(&"default", 0)
	get_viewport().size_changed.connect(_layout_portrait)
	_layout_portrait()
	_was_paused = get_tree().paused
	get_tree().paused = true

func _layout_portrait() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var texture_size := _portrait.texture.get_size()
	var visible_height := maxf(portrait_bottom - portrait_top, 1.0)
	var fit_scale := viewport_size.y * screen_height_ratio / visible_height
	_portrait.size = texture_size * fit_scale
	# 固定整组帧的缩放和偏移，保持入场动作稳定；人物下沿贴住窗口底部。
	_portrait.position = Vector2(
		-transparent_left_margin * fit_scale,
		viewport_size.y - portrait_bottom * fit_scale
	)

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var enter_duration := frames.get_frame_count(&"default") / frames_per_second
	if _elapsed >= enter_duration and idle_frames != null and idle_frames.get_frame_count(&"default") > 0:
		var idle_frame := int((_elapsed - enter_duration) * idle_frames.get_animation_speed(&"default")) % idle_frames.get_frame_count(&"default")
		_portrait.texture = idle_frames.get_frame_texture(&"default", idle_frame)
		return
	var frame := mini(int(_elapsed * frames_per_second), frames.get_frame_count(&"default") - 1)
	_portrait.texture = frames.get_frame_texture(&"default", frame)

func _input(event: InputEvent) -> void:
	if _finished:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			return
		if event.pressed:
			_dismiss_button = event.button_index
		elif event.button_index == _dismiss_button:
			# 吞掉完整的点击手势，恢复后不向游戏透传按下或释放事件。
			_finished = true
			hide()
			get_tree().paused = _was_paused
			queue_free()
