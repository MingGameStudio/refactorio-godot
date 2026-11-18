extends Node2D
## 一次性世界特效，位移只作用于尘团，不改变角色。
@export var duration: float = 0.28
@export var drift_distance: float = 22.0
var _worker: Node2D
var _started := false

func play(dash_direction: Vector2, worker: Node2D) -> void:
	if _started:
		return
	_started = true
	_worker = worker
	_process(0.0)
	var backward := -dash_direction.normalized()
	var sideways := backward.orthogonal()
	var burst := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var main: Sprite2D = $MainDust
	var base_scale := main.scale
	main.scale = base_scale * 0.9
	main.modulate.a = 0.85
	burst.tween_property(main, "position", main.position + backward * drift_distance + Vector2(0, -4), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(main, "scale", base_scale * 1.15, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(main, "modulate:a", 0.0, duration)
	for particle: Sprite2D in [$SmallDustA, $SmallDustB, $Specks]:
		var lifetime := randf_range(duration * 0.7, duration)
		var spread := sideways * randf_range(-9.0, 9.0)
		var destination := particle.position + backward * randf_range(18.0, 30.0) + spread + Vector2(0, -3)
		particle.modulate.a = 0.8
		burst.tween_property(particle, "position", destination, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		burst.tween_property(particle, "scale", particle.scale * randf_range(1.1, 1.25), lifetime)
		burst.tween_property(particle, "modulate:a", 0.0, lifetime)
	burst.chain().tween_callback(queue_free)

func _process(_delta: float) -> void:
	# 真人向上跨行时同步降低层级，世界位置始终固定。
	if is_instance_valid(_worker):
		z_index = _worker.z_index - 1
