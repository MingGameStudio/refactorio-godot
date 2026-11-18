extends Sprite2D
## 轻量跟随：复用现有步行帧、Idle 和脚底深度规则，不依赖玩家输入。
const WALK_FRAMES := preload("res://FemaleAssistantWalk.tres")
const IDLE_TEXTURE := preload("res://assets/Animations/FemaleCharacterIdle/FemaleCharacterIdle.png")
const DEPTH := preload("res://GridDepth.gd")

@export var target_path: NodePath = ^"../Worker"
@export var follow_distance: float = 52.0
@export var minimum_distance: float = 36.0
@export var move_speed: float = 200.0
@export var follow_enabled: bool = false

var _dialogue_active: bool = false
var _walk_elapsed: float = 0.0
var _feet_shape := CircleShape2D.new()
@onready var _target: Node2D = get_node(target_path)

func _ready() -> void:
	_feet_shape.radius = 8.0
	_set_idle()
	_update_depth()

func set_dialogue_active(active: bool) -> void:
	_dialogue_active = active
	if active:
		_set_idle()
		_face_direction(_target.global_position - global_position)

func _physics_process(delta: float) -> void:
	if _dialogue_active or not follow_enabled:
		_set_idle()
		if _dialogue_active:
			_face_direction(_target.global_position - global_position)
		return
	var offset_to_player := _target.global_position - global_position
	var distance := offset_to_player.length()
	var error := 0.0
	if distance > follow_distance:
		error = distance - follow_distance
	elif distance < minimum_distance:
		# 玩家转身走近时让开，避免停在玩家脚底。
		error = distance - minimum_distance
	if absf(error) < 0.5:
		_set_idle()
		return
	var direction := offset_to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	var step := direction * signf(error) * minf(move_speed * delta, absf(error) * (1.0 - exp(-10.0 * delta)))
	# 沿用场景设施碰撞层，仅做短距离扫掠；阻挡时停步，不穿过托盘。
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _feet_shape
	query.transform = Transform2D(0.0, global_position)
	query.motion = step
	query.collision_mask = 1
	var fractions := get_world_2d().direct_space_state.cast_motion(query)
	step *= fractions[0]
	if step.length() < 0.001:
		_set_idle()
		return
	global_position += step
	_face_direction(step)
	_walk_elapsed += delta
	texture = WALK_FRAMES.get_frame_texture(&"default", int(_walk_elapsed * 10.0) % WALK_FRAMES.get_frame_count(&"default"))
	offset = Vector2(-200.0, -600.0)
	_update_depth()

func _face_direction(direction: Vector2) -> void:
	# 素材只有左右朝向，竖直移动保留最近的水平朝向。
	if absf(direction.x) > 0.01:
		flip_h = direction.x < 0.0

func _set_idle() -> void:
	texture = IDLE_TEXTURE
	offset = Vector2(-113.0, -462.0)
	_walk_elapsed = 0.0

func _update_depth() -> void:
	z_index = DEPTH.at_position(position, DEPTH.WORKER)
