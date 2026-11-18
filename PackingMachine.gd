extends "res://PlacedBuilding.gd"
const BATCH_SIZE: int = 5
var battery_count: int = 0

func _ready() -> void:
	_update_progress()

func accept_battery() -> bool:
	if battery_count >= BATCH_SIZE:
		return false
	battery_count += 1
	_update_progress()
	return true

func try_pack(game: Node2D) -> void:
	if battery_count < BATCH_SIZE:
		return
	var output: Vector2i = game.world_to_cell(global_position) + Vector2i.RIGHT
	if game.spawn_packed_box(output):
		battery_count -= BATCH_SIZE
		_update_progress()

func _update_progress() -> void:
	$PackingProgress.text = "%d/%d" % [battery_count, BATCH_SIZE]
