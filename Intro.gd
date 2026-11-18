extends Node2D
## 独立仓库场景；固定构图等比适配窗口，所有布景保存在场景节点中。
const ROOM_SIZE := Vector2(768.0, 432.0)
const CARRIED_BOX_TEXTURE := preload("res://assets/Boxes/BoxFront.png")
const FULL_PALLET_TEXTURE := preload("res://assets/Boxes/Boxes6.png")
enum StoryState { INTRO, WALKING, BRANCH_DIALOGUE, TASK_STARTED }
var story_state: StoryState = StoryState.INTRO

const SUCCESS_TEXT := "看来我的眼光不错。"
const SUCCESS_DETAILS_TEXT := "就多告诉你一点信息。我爸只给我三个月。救不活这家厂，就关门大吉，我们都得走人。"
const MISSED_TEXT := "逗你的。不过留给我们的时间确实不多——"
const MISSED_DETAILS_TEXT := "我爸只给我三个月。救不活这家厂，就关门大吉，我们都得走人。"
const PLAYER_REPLY := "三个月？行吧，刚端起饭碗，总不能第一天就陪你失业。从哪开始？"
const TASK_TEXT := "先交出 5 个电池组的急单，顺便熟悉一下生产线！"

var _carrying_loose_box: bool = false
var _pallet_filled: bool = false
var _frame_base_scale := Vector2.ONE
var _breath_time: float = 0.0
const BREATH_PERIOD: float = 1.8

@onready var _worker: CharacterBody2D = $Worker
@onready var _box: Sprite2D = $Cargo/LooseBox/Sprite2D
@onready var _pallet: StaticBody2D = $Cargo/UpperPallet3
@onready var _return_point: Marker2D = $Cargo/UpperPallet3/ReturnPoint
@onready var _frame: Sprite2D = $InteractionFrame

func _process(delta: float) -> void:
	if not _frame.visible:
		_breath_time = 0.0
		return
	_breath_time = fmod(_breath_time + delta, BREATH_PERIOD)
	_apply_frame_breath()

func _apply_frame_breath() -> void:
	var pulse := 0.5 - 0.5 * cos(_breath_time / BREATH_PERIOD * TAU)
	_frame.scale = _frame_base_scale * lerpf(1.0, 1.035, pulse)
	_frame.modulate.a = lerpf(0.8, 1.0, pulse)

func _show_frame(target: Node2D, bounds: Rect2) -> void:
	# 与 Main 的交互框一致：目标局部矩形转换到场景坐标，外扩后呼吸。
	var relative := global_transform.affine_inverse() * target.global_transform
	var rect: Rect2 = (relative * bounds).grow(8.0)
	_frame.position = rect.get_center()
	_frame_base_scale = rect.size / _frame.texture.get_size()
	_apply_frame_breath()
	_frame.show()

func _physics_process(_delta: float) -> void:
	if story_state == StoryState.WALKING and $WorkshopEntrance.overlaps_body(_worker):
		_start_branch_dialogue()
	var can_return := _can_return_box()
	var can_pickup: bool = _worker.can_pickup(_box)
	$UI/PickupHint.text = "E 放回箱子" if can_return else "E 拾取箱子"
	$UI/PickupHint.visible = can_return or can_pickup
	_frame.hide()
	if can_return:
		var pallet_sprite: Sprite2D = $Cargo/UpperPallet3/Sprite2D
		# 五箱原图右上角的缺口，使用图片像素范围，不框住整块托盘。
		_show_frame(pallet_sprite, Rect2(pallet_sprite.offset + Vector2(450, 8), Vector2(210, 244)))
	elif can_pickup:
		_show_frame(_box, _box.get_rect())

func _can_return_box() -> bool:
	if _pallet_filled or not _carrying_loose_box or not _worker.carrying_box or _worker.dialogue_locked:
		return false
	# 缺箱位置在托盘右侧，从下方通道靠近；不能隔着托盘从背面放入。
	if _pallet.to_local(_worker.global_position).y < 0.0 \
			or _worker.global_position.distance_to(_return_point.global_position) > 48.0:
		return false
	var ray := PhysicsRayQueryParameters2D.create(_worker.global_position, _return_point.global_position, 1)
	ray.exclude = [_pallet.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _return_box() -> void:
	var pallet_sprite: Sprite2D = $Cargo/UpperPallet3/Sprite2D
	var width := pallet_sprite.texture.get_width() * pallet_sprite.scale.x
	pallet_sprite.texture = FULL_PALLET_TEXTURE
	pallet_sprite.scale = Vector2.ONE * width / FULL_PALLET_TEXTURE.get_width()
	pallet_sprite.offset = Vector2(-FULL_PALLET_TEXTURE.get_width() * 0.5, -FULL_PALLET_TEXTURE.get_height())
	_worker.cancel_navigation()
	_worker._face_toward(_return_point.global_position)
	_worker.release_box()
	_worker.set_operating(false)
	_carrying_loose_box = false
	_pallet_filled = true
	$UI/PickupHint.hide()
	_frame.hide()
	_start_branch_dialogue()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode != KEY_E:
		return
	if event.pressed and not event.echo and _can_return_box():
		_return_box()
		get_viewport().set_input_as_handled()
		return
	if event.pressed and not event.echo and _worker.pickup_box(_box):
		_carrying_loose_box = true
		# 沿用 Worker 的距离/遮挡验证、持箱动画和音效；仅替换本关卡手持外观。
		var held_box: Sprite2D = _worker.carried_box
		var held_width := held_box.texture.get_width() * held_box.scale.x
		held_box.texture = CARRIED_BOX_TEXTURE
		held_box.scale = Vector2.ONE * held_width / CARRIED_BOX_TEXTURE.get_width()
		$Cargo/LooseBox/CollisionShape2D.set_deferred("disabled", true)
		$UI/PickupHint.hide()
		_frame.hide()
	get_viewport().set_input_as_handled()

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	# Worker 默认面向左，本场景沿通道面向右。
	$Worker/AnimatedSprite2D.flip_h = false
	$DialogueUI.active_changed.connect(_on_dialogue_active_changed)
	$DialogueUI.dialogue_finished.connect(_on_dialogue_finished)
	$WorkshopEntrance.body_entered.connect(_on_workshop_entered)
	$DialogueUI.start_dialogue([
		{"name": "", "job_title": "新厂长", "text": "三天前刚被裁员，今天就来管生产……徐小姐，你真不怕招错人？", "portrait": null},
		_assistant_line("我看过你的履历。说真的，以我这点预算，能请到你算我捡了大便宜。走吧，先去车间看看。", preload("res://assets/audio/dialogs/intro/Intro00.mp3")),
	])

func _on_dialogue_active_changed(active: bool) -> void:
	# 分支结束信号发出前 UI 会解除 active，切场景前仍保持输入锁。
	var locked := active or story_state in [StoryState.BRANCH_DIALOGUE, StoryState.TASK_STARTED]
	_worker.set_dialogue_locked(locked)
	$FemaleAssistant.set_dialogue_active(locked)

func _on_dialogue_finished() -> void:
	match story_state:
		StoryState.INTRO:
			story_state = StoryState.WALKING
			$UI/MovementHint.show()
			$FemaleAssistant.follow_enabled = true
		StoryState.BRANCH_DIALOGUE:
			story_state = StoryState.TASK_STARTED
			_load_workshop.call_deferred()

func _on_workshop_entered(body: Node2D) -> void:
	if body == _worker:
		_start_branch_dialogue()

func _start_branch_dialogue() -> void:
	if story_state != StoryState.WALKING or $DialogueUI.is_active:
		return
	# 先改变状态，再发起对话，阻止区域信号和放回操作重复触发。
	story_state = StoryState.BRANCH_DIALOGUE
	$FemaleAssistant.follow_enabled = false
	$UI/MovementHint.hide()
	$UI/PickupHint.hide()
	_frame.hide()
	var lines: Array = []
	if _pallet_filled:
		lines.append(_assistant_line(SUCCESS_TEXT, preload("res://assets/audio/dialogs/intro/Intro01.mp3")))
		lines.append(_assistant_line(SUCCESS_DETAILS_TEXT, preload("res://assets/audio/dialogs/intro/Intro02.mp3")))
	else:
		lines.append(_assistant_line("厂长先生，刚才地上那个箱子，你就这么放过它了？", preload("res://assets/audio/dialogs/intro/Intro03.mp3")))
		lines.append(_player_line("……光顾着看车间了。"))
		lines.append(_assistant_line(MISSED_TEXT, preload("res://assets/audio/dialogs/intro/Intro04.mp3")))
		lines.append(_assistant_line(MISSED_DETAILS_TEXT, preload("res://assets/audio/dialogs/intro/Intro05.mp3")))
	lines.append(_player_line(PLAYER_REPLY))
	lines.append(_assistant_line(TASK_TEXT, preload("res://assets/audio/dialogs/intro/Intro06.mp3")))
	$DialogueUI.start_dialogue(lines)

func _assistant_line(text: String, voice: AudioStream = null) -> Dictionary:
	return {"name": "徐知夏", "job_title": "厂长助理", "text": text, "voice": voice}

func _player_line(text: String) -> Dictionary:
	return {"name": "", "job_title": "新厂长", "text": text, "portrait": null}

func _load_workshop() -> void:
	var error := get_tree().change_scene_to_file("res://Main.tscn")
	if error != OK:
		push_error("无法加载生产车间 Main.tscn：%s" % error_string(error))

func _fit_camera() -> void:
	var viewport_size := get_viewport_rect().size
	var fit_scale := minf(viewport_size.x / ROOM_SIZE.x, viewport_size.y / ROOM_SIZE.y)
	$Camera2D.position = ROOM_SIZE * 0.5
	$Camera2D.zoom = Vector2.ONE * maxf(fit_scale, 0.01)
