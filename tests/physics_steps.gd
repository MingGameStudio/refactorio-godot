extends RefCounted
## move_and_slide 使用真实物理帧 delta；测试不能再用一次大 delta 瞬移。
static func advance(worker: CharacterBody2D, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await worker.get_tree().physics_frame
		var delta := worker.get_physics_process_delta_time()
		worker._physics_process(delta)
		elapsed += delta
		if seconds > 1.0 and worker._path_index >= worker._path.size():
			break
