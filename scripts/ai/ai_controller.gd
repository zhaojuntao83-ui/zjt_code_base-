## AI控制器 - 弟子的决策大脑，基于模仿学习驱动行为
## GDD: 行为克隆打底 -> 自我练习补全 -> 强化学习微调
class_name AIController
extends Node

var character: BaseCharacter

# 训练数据：每条记录是一个 (observation -> action) 映射
var training_dataset: Array[Dictionary] = []

# 行为策略表：observation_hash -> {action, confidence}
var policy_table: Dictionary = {}

# 行为克隆模块（K近邻软匹配，现在真正启用）
var behavior_cloning: BehaviorCloning = BehaviorCloning.new()

# 学习参数
var learning_rate: float = 0.1
var base_learning_rate: float = 0.1  # 保留基础值，防止累乘破坏
var exploration_rate: float = 0.3    # 探索概率（未见过的情况时随机尝试）
var confidence_threshold: float = 0.5

# 决策冷却（防止每帧都切换动作）
var decision_cooldown: float = 0.0
const DECISION_INTERVAL: float = 0.15  # 每0.15秒决策一次

# 当前正在执行的动作
var current_action: Dictionary = {}

# 卡壳检测
var stuck_counter: int = 0
var last_position: Vector2 = Vector2.ZERO
const STUCK_THRESHOLD: int = 20  # 连续20次决策未移动则判定卡壳


func _process(delta: float) -> void:
	if decision_cooldown > 0:
		decision_cooldown -= delta


## 主决策入口 - 由 Disciple._physics_process 调用
func think_and_act() -> void:
	if character == null or decision_cooldown > 0:
		return

	decision_cooldown = DECISION_INTERVAL

	_check_stuck()

	var observation = _observe_environment()
	var action = _decide_action(observation)
	_execute_action(action)

	last_position = character.global_position


# ========== 卡壳检测 ==========

func _check_stuck() -> void:
	if character == null:
		return
	var dist = character.global_position.distance_to(last_position)
	if dist < 5.0:
		stuck_counter += 1
	else:
		stuck_counter = 0
	if stuck_counter >= STUCK_THRESHOLD:
		stuck_counter = 0
		EventBus.message_requested.emit("弟子卡住了，建议使用接管或补录示范", 3.0)


# ========== 第一步：环境观察 ==========

func _observe_environment() -> Dictionary:
	"""收集当前帧的环境特征（AI的输入）"""
	var obs = {
		"position_x": character.global_position.x,
		"position_y": character.global_position.y,
		"velocity_x": character.velocity.x,
		"velocity_y": character.velocity.y,
		"on_floor": character.is_on_floor(),
		"health_ratio": character.health / character.max_health,
		"current_state": "",
	}

	if character.state_machine and character.state_machine.current_state:
		obs["current_state"] = character.state_machine.current_state.name

	# 前方射线检测（障碍物、敌人、地面缺口）
	obs["front_obstacle"] = _raycast_check(Vector2(120, 0))
	obs["front_ground"] = _raycast_check(Vector2(80, 60))
	obs["above_clear"] = not _raycast_check(Vector2(0, -80))
	obs["front_enemy"] = _detect_nearby_enemy()

	# Boss预警检测
	obs["boss_warning"] = _detect_boss_warning()

	return obs


func _raycast_check(offset: Vector2) -> bool:
	"""简单射线检测（自动根据朝向翻转X轴）"""
	var space = character.get_world_2d().direct_space_state
	if not space:
		return false

	var facing = 1.0 if character.sprite_facing_right else -1.0
	var adjusted_offset = Vector2(offset.x * facing, offset.y)

	var query = PhysicsRayQueryParameters2D.create(
		character.global_position,
		character.global_position + adjusted_offset
	)
	query.exclude = [character.get_rid()]
	return space.intersect_ray(query).size() > 0


func _detect_nearby_enemy() -> Dictionary:
	"""检测前方最近的敌人"""
	var enemies = character.get_tree().get_nodes_in_group("enemies")
	var closest_dist = 999.0
	var closest_pos = Vector2.ZERO
	var found = false

	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var dist = character.global_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist < 300.0:
			closest_dist = dist
			closest_pos = enemy.global_position
			found = true

	return {"found": found, "distance": closest_dist, "position": closest_pos}


func _detect_boss_warning() -> Dictionary:
	"""检测Boss攻击预警区域"""
	var warnings = character.get_tree().get_nodes_in_group("boss_warning")
	for warning in warnings:
		if warning is Area2D and warning.has_meta("warning_rect"):
			var rect: Rect2 = warning.get_meta("warning_rect")
			if rect.has_point(character.global_position):
				return {"active": true, "rect": rect}
	return {"active": false}


# ========== 第二步：决策 ==========

func _decide_action(observation: Dictionary) -> Dictionary:
	"""根据观察值查找最匹配的示范动作"""
	var obs_hash = _hash_observation(observation)

	# 优先查精确策略表（O(1) 查找）
	if policy_table.has(obs_hash):
		var entry = policy_table[obs_hash]
		if entry["confidence"] >= confidence_threshold:
			return entry["action"]

	# 次选：行为克隆 K近邻软匹配（现在真正使用 BehaviorCloning 模块）
	if not training_dataset.is_empty() and randf() > exploration_rate:
		var bc_action = behavior_cloning.predict(observation)
		if not bc_action.is_empty():
			# 若需要靠近敌人，补充目标位置（修复原先 target_position 为零的 Bug）
			var enemy_info = observation.get("front_enemy", {})
			if bc_action.get("type") == "move_toward_enemy" and enemy_info.get("found", false):
				bc_action["target_position"] = enemy_info["position"]
			return bc_action

	# 兜底：基于规则的安全回退行为
	return _fallback_action(observation)


func _fallback_action(observation: Dictionary) -> Dictionary:
	"""安全回退行为：基于简单规则避免死亡"""
	if observation.get("front_obstacle", false):
		if observation.get("above_clear", true):
			return {"type": "jump"}
		else:
			return {"type": "crouch"}

	if not observation.get("front_ground", true):
		return {"type": "jump"}

	if observation.get("boss_warning", {}).get("active", false):
		return {"type": "dodge"}

	var enemy_info = observation.get("front_enemy", {})
	if enemy_info.get("found", false):
		if enemy_info["distance"] < 60:
			return {"type": "attack"}
		elif enemy_info["distance"] < 150:
			# 补充 target_position，弟子才会真正朝敌人移动
			return {"type": "move_toward_enemy", "target_position": enemy_info["position"]}

	return {"type": "move_forward"}


func _hash_observation(observation: Dictionary) -> String:
	"""将观察值离散化为哈希键（用于 O(1) 精确查找）"""
	var parts = []
	parts.append("f=%d" % (1 if observation.get("on_floor", true) else 0))
	parts.append("o=%d" % (1 if observation.get("front_obstacle", false) else 0))
	parts.append("g=%d" % (1 if observation.get("front_ground", true) else 0))
	parts.append("e=%d" % (1 if observation.get("front_enemy", {}).get("found", false) else 0))
	parts.append("bw=%d" % (1 if observation.get("boss_warning", {}).get("active", false) else 0))
	return "|".join(parts)


# ========== 第三步：执行动作 ==========

func _execute_action(action: Dictionary) -> void:
	if action.is_empty() or character == null:
		return

	current_action = action
	var sm = character.state_machine
	if sm == null:
		return

	match action.get("type", ""):
		"jump":
			if character.is_on_floor():
				sm.transition_to("jump")
		"crouch":
			sm.transition_to("crouch")
		"slide":
			if character.is_on_floor() and absf(character.velocity.x) > character.slide_min_speed:
				sm.transition_to("slide")
		"attack":
			sm.transition_to("attack")
		"block":
			sm.transition_to("block")
		"dodge":
			sm.transition_to("dodge")
		"move_forward":
			_apply_movement(1.0 if character.sprite_facing_right else -1.0)
		# 修复：区分左右方向，不再统一为 move_forward
		"move_right":
			_apply_movement(1.0)
		"move_left":
			_apply_movement(-1.0)
		"move_toward_enemy":
			var enemy_pos = action.get("target_position", Vector2.ZERO)
			if enemy_pos != Vector2.ZERO:
				# 修复：使用实际目标位置计算方向
				_apply_movement(sign(enemy_pos.x - character.global_position.x))
			else:
				_apply_movement(1.0 if character.sprite_facing_right else -1.0)
		"idle":
			character.velocity.x = move_toward(character.velocity.x, 0, character.friction * 0.016)


func _apply_movement(direction: float) -> void:
	character.velocity.x = direction * character.move_speed
	if direction > 0:
		character.face_right()
	elif direction < 0:
		character.face_left()


# ========== 训练数据管理 ==========

func add_training_data(demo_data: Dictionary) -> void:
	"""从示范数据中提取 observation->action 映射对"""
	var frames = demo_data.get("frames", [])

	for frame in frames:
		# 重建与 _observe_environment 格式一致的观察值（修复原先字段不匹配的 Bug）
		var observation = {
			"on_floor": frame.get("on_floor", true),
			"velocity_x": frame.get("velocity", Vector2.ZERO).x if frame.get("velocity") is Vector2 else 0.0,
			"velocity_y": frame.get("velocity", Vector2.ZERO).y if frame.get("velocity") is Vector2 else 0.0,
			"position_x": frame.get("position", Vector2.ZERO).x if frame.get("position") is Vector2 else 0.0,
			"position_y": frame.get("position", Vector2.ZERO).y if frame.get("position") is Vector2 else 0.0,
			"front_obstacle": frame.get("observations", {}).get("nearby_obstacles", []).size() > 0,
			"front_ground": frame.get("observations", {}).get("nearest_platform_dist", 0.0) < 999.0,
			"front_enemy": frame.get("observations", {}).get("nearby_enemies", {"found": false}),
			"boss_warning": {"active": frame.get("observations", {}).get("boss_warning_active", false)},
		}

		var action = _extract_action_from_frame(frame)

		if not action.is_empty():
			training_dataset.append({
				"observation": observation,
				"action": action,
			})

			# 更新策略表
			var obs_hash = _hash_observation(observation)
			var existing = policy_table.get(obs_hash, {"confidence": 0.0})
			var new_confidence = minf(existing["confidence"] + learning_rate, 1.0)
			policy_table[obs_hash] = {
				"action": action,
				"confidence": new_confidence,
			}

	# 同步到 BehaviorCloning 模块（K近邻软匹配）
	behavior_cloning.train(frames)

	# 降低探索率（随着数据增多，更多依赖已学行为）
	exploration_rate = maxf(0.05, exploration_rate - frames.size() * 0.001)


func _extract_action_from_frame(frame: Dictionary) -> Dictionary:
	"""从录制帧中提取玩家执行的动作"""
	var inputs = frame.get("inputs", {})

	if inputs.get("jump", false):
		return {"type": "jump"}
	if inputs.get("attack", false):
		return {"type": "attack"}
	if inputs.get("dodge", false):
		return {"type": "dodge"}
	if inputs.get("block", false):
		return {"type": "block"}
	if inputs.get("crouch", false):
		return {"type": "crouch"}
	# 修复：区分向右和向左，不再都映射为 move_forward
	if inputs.get("move_right", false):
		return {"type": "move_right"}
	if inputs.get("move_left", false):
		return {"type": "move_left"}

	return {"type": "idle"}


## 遗忘衰减：删除示范卡片后降低相关策略置信度（实现遗忘曲线）
func decay_policy_from_card(frames: Array, decay_amount: float) -> void:
	for frame in frames:
		var observation = {
			"on_floor": frame.get("on_floor", true),
			"front_obstacle": frame.get("observations", {}).get("nearby_obstacles", []).size() > 0,
			"front_ground": frame.get("observations", {}).get("nearest_platform_dist", 0.0) < 999.0,
			"front_enemy": {"found": false},
			"boss_warning": {"active": false},
		}
		var obs_hash = _hash_observation(observation)
		if policy_table.has(obs_hash):
			policy_table[obs_hash]["confidence"] = maxf(
				0.0,
				policy_table[obs_hash]["confidence"] - decay_amount
			)


## 评估当前AI对给定示范帧的预测准确率（供 TrainingSystem 真实评估用）
func evaluate_prediction_accuracy(sample_frames: Array) -> float:
	if sample_frames.is_empty() or training_dataset.is_empty():
		return 0.0

	var correct = 0
	var total = 0

	for frame in sample_frames:
		var expected = _extract_action_from_frame(frame)
		if expected.is_empty() or expected.get("type") == "idle":
			continue

		var observation = {
			"on_floor": frame.get("on_floor", true),
			"velocity_x": frame.get("velocity", Vector2.ZERO).x if frame.get("velocity") is Vector2 else 0.0,
			"velocity_y": frame.get("velocity", Vector2.ZERO).y if frame.get("velocity") is Vector2 else 0.0,
			"position_y": frame.get("position", Vector2.ZERO).y if frame.get("position") is Vector2 else 0.0,
			"front_obstacle": frame.get("observations", {}).get("nearby_obstacles", []).size() > 0,
			"front_ground": frame.get("observations", {}).get("nearest_platform_dist", 0.0) < 999.0,
			"front_enemy": {"found": false},
			"boss_warning": {"active": false},
		}
		var predicted = _decide_action(observation)
		if predicted.get("type") == expected.get("type"):
			correct += 1
		total += 1

	if total == 0:
		return 0.0
	return float(correct) / float(total)


func get_learned_action_count() -> int:
	return policy_table.size()


func reset() -> void:
	training_dataset.clear()
	policy_table.clear()
	behavior_cloning = BehaviorCloning.new()
	exploration_rate = 0.3
	stuck_counter = 0
