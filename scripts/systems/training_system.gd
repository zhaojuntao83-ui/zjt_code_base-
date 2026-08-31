## 训练系统 - 让弟子根据示范数据反复练习，从笨拙到熟练
class_name TrainingSystem
extends Node

enum TrainingSpeed { NORMAL = 1, FAST_2X = 2, FAST_5X = 5, FAST_10X = 10 }

var is_training: bool = false
var current_card_id: String = ""
var current_iteration: int = 0
var total_iterations: int = 50
var success_count: int = 0
var training_speed: TrainingSpeed = TrainingSpeed.NORMAL

# 训练目标场景
var training_scene: Node2D
var disciple_ref: Node  # Disciple

# 当前训练使用的示范帧（用于真实 AI 评估）
var current_demo_frames: Array = []


func start_training(card_id: String, demo_data: Dictionary, disciple: Node) -> void:
	"""开始训练弟子"""
	if is_training:
		return

	current_card_id = card_id
	current_iteration = 0
	success_count = 0
	disciple_ref = disciple
	is_training = true
	current_demo_frames = demo_data.get("frames", [])

	# 将示范数据注入弟子AI
	if disciple.has_method("learn_from_demonstration"):
		disciple.learn_from_demonstration(demo_data)

	# 根据难度调整迭代次数
	var difficulty_multiplier = GameManager.DIFFICULTY_PARAMS[GameManager.difficulty]["ai_learn_speed"]
	total_iterations = roundi(50 / difficulty_multiplier)

	EventBus.training_started.emit(card_id)
	await _run_training_loop()


func stop_training() -> void:
	is_training = false


func set_speed(speed: TrainingSpeed) -> void:
	training_speed = speed
	EventBus.training_speed_changed.emit(float(speed))


func _run_training_loop() -> void:
	"""用 while 循环替代递归，避免50层异步调用链堆叠"""
	while is_training and current_iteration < total_iterations:
		current_iteration += 1

		var success = _evaluate_attempt()
		if success:
			success_count += 1

		var success_rate = float(success_count) / current_iteration
		EventBus.training_iteration_completed.emit(current_iteration, success_rate)

		var delay = 1.0 / float(training_speed)
		await get_tree().create_timer(delay).timeout

	if is_training:
		_finish_training()


func _evaluate_attempt() -> bool:
	"""
	真实评估：用弟子 AI 对示范帧进行预测，
	与示范中的实际动作对比计算准确率，
	替代原先纯随机的假模拟。
	"""
	if disciple_ref == null:
		return _fallback_simulate()

	var ai = disciple_ref.get("ai_controller")
	if ai == null:
		return _fallback_simulate()

	# 均匀采样示范帧，评估 AI 当前预测精度
	var sample = _sample_frames(current_demo_frames, 10)
	var accuracy = ai.evaluate_prediction_accuracy(sample)

	# 叠加天赋加成
	accuracy = clampf(accuracy + _get_talent_bonus(), 0.0, 0.98)
	return randf() < accuracy


func _sample_frames(frames: Array, count: int) -> Array:
	"""从帧列表中均匀采样，避免只看开头或结尾"""
	if frames.size() <= count:
		return frames
	var result = []
	var step = frames.size() / count
	for i in range(count):
		result.append(frames[i * step])
	return result


func _fallback_simulate() -> bool:
	"""无法获取 AI 时的备用模拟（逐步上升的成功概率）"""
	var base_rate = float(current_iteration) / float(total_iterations)
	return randf() < clampf(base_rate + _get_talent_bonus(), 0.0, 0.95)


func _get_talent_bonus() -> float:
	if GameManager.active_disciple == null:
		return 0.0
	var talent = GameManager.active_disciple.talent
	if talent == GameManager.Talent.ADVERSITY_GROWTH:
		# 逆境成长：失败越多，加成越高
		var failure_count = current_iteration - success_count
		return failure_count * 0.01
	return 0.0


func _finish_training() -> void:
	is_training = false
	var success_rate = float(success_count) / maxi(current_iteration, 1)

	var result = {
		"iterations": current_iteration,
		"success_rate": success_rate,
		"success_count": success_count,
	}

	# 通知弟子训练完成，由弟子负责同步双色系统（修复双色系统断路 Bug）
	if disciple_ref and disciple_ref.has_method("on_training_finished"):
		var skill = _infer_skill_from_card_id()
		disciple_ref.on_training_finished(skill, success_rate)

	# 更新弟子统计
	if GameManager.active_disciple:
		GameManager.active_disciple.total_training_iterations += current_iteration
		GameManager.active_disciple.total_successes += success_count
		GameManager.active_disciple.total_failures += (current_iteration - success_count)

	EventBus.training_completed.emit(current_card_id, result)
	AudioManager.play_disciple_success()
	SaveManager.auto_save()


func _infer_skill_from_card_id() -> String:
	"""从卡片ID推断技能分类（卡片ID格式：timestamp_category）"""
	var parts = current_card_id.split("_")
	if parts.size() >= 2:
		return parts[parts.size() - 1]
	return "mixed"
