extends Node
## 入场期间冻结关卡，只推进助理；到达后交给立绘管理暂停和输入。

const PORTRAIT := preload("res://OpeningPortrait.tscn")
const WALK_FRAMES := preload("res://FemaleAssistantWalk.tres")
const IDLE_TEXTURE := preload("res://assets/Animations/FemaleCharacterIdle/FemaleCharacterIdle.png")
const DEPTH := preload("res://GridDepth.gd")

@export var assistant_speed: float = 110.0
@export var assistant_height: float = 72.0
@export var walk_fps: float = 10.0

var assistant: Sprite2D
var _destination := Vector2.ZERO
var _walk_elapsed: float = 0.0
var _was_paused: bool = false
var _arrived: bool = false

func _ready() -> void:
	_was_paused = get_tree().paused
	get_tree().paused = true
	var main: Node2D = $Main
	var worker: Node2D = $Main/Worker
	var camera: Camera2D = $Main/Camera2D
	camera.force_update_scroll()
	_destination = worker.position + Vector2(-52.0, 0.0)
	assistant = Sprite2D.new()
	assistant.name = "FemaleAssistant"
	assistant.texture = WALK_FRAMES.get_frame_texture(&"default", 0)
	assistant.centered = false
	# 所有帧使用同一个脚底原点和比例，保留自然步态，避免逐帧裁切造成抖动。
	assistant.offset = Vector2(-200.0, -600.0)
	assistant.scale = Vector2.ONE * assistant_height / 464.0
	main.add_child(assistant)
	var visible_left := main.get_global_transform_with_canvas().affine_inverse() * Vector2.ZERO
	assistant.position = Vector2(minf(visible_left.x - 32.0, _destination.x - 64.0), _destination.y)
	assistant.z_index = DEPTH.at_position(assistant.position, DEPTH.WORKER)

func _process(delta: float) -> void:
	if _arrived:
		return
	_walk_elapsed += delta
	assistant.texture = WALK_FRAMES.get_frame_texture(
		&"default", int(_walk_elapsed * walk_fps) % WALK_FRAMES.get_frame_count(&"default")
	)
	assistant.position = assistant.position.move_toward(_destination, assistant_speed * delta)
	if assistant.position.is_equal_approx(_destination):
		_arrived = true
		_set_assistant_idle()
		set_process(false)
		set_process_input(false)
		get_tree().paused = _was_paused
		var portrait := PORTRAIT.instantiate()
		portrait.name = "OpeningPortrait"
		add_child(portrait)

func _set_assistant_idle() -> void:
	assistant.texture = IDLE_TEXTURE
	# Walk 站稳帧（0014）可见范围 y=138..588，高 450；脚底距原点 600 尚有 12 像素。
	# Idle 已裁去透明留白，以同一可见高度和脚底基准对齐，不按 PNG 画布高度缩放。
	var walk_scale := assistant_height / 464.0
	var idle_scale := walk_scale * 450.0 / IDLE_TEXTURE.get_height()
	assistant.scale = Vector2.ONE * idle_scale
	assistant.offset = Vector2(-IDLE_TEXTURE.get_width() * 0.5,
		-IDLE_TEXTURE.get_height() - 12.0 * walk_scale / idle_scale)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
