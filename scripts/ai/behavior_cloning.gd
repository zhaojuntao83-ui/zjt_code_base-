## 行为克隆模块 - 从示范数据中学习状态-动作映射（K近邻软匹配）
## GDD: 弟子看玩家示范数据，学习相同场景做相同动作
## 现在被 AIController 真正调用，不再是死代码
class_name BehaviorCloning
extends RefCounted

# 状态-动作数据对
var state_action_pairs: Array[Dictionary] = []

# 近邻搜索的K值
const K_NEIGHBORS: int = 5


func train(demonstration_frames: Array) -> void:
	"""从示范帧中提取状态-动作对进行训练"""
	for frame in demonstration_frames:
		var state = _extract_state(frame)
		var action = _extract_action(frame)
		if not action.is_empty():
			state_action_pairs.append({"state": state, "action": action})


func predict(current_obs: Dictionary) -> Dictionary:
	"""给定当前观察值，预测最佳动作（K近邻投票）"""
	if state_action_pairs.is_empty():
		return {}

	# 计算与所有训练样本的距离
	var distances = []
	for i in range(state_action_pairs.size()):
		var dist = _compute_distance(current_obs, state_action_pairs[i]["state"])
		distances.append({"index": i, "distance": dist})

	# 按距离排序
	distances.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# K近邻投票（距离越近权重越大）
	var action_votes: Dictionary = {}
	var k = mini(K_NEIGHBORS, distances.size())

	for i in range(k):
		var idx = distances[i]["index"]
		var action = state_action_pairs[idx]["action"]
		var action_key = action.get("type", "idle")
		var weight = 1.0 / (distances[i]["distance"] + 0.01)
		action_votes[action_key] = action_votes.get(action_key, 0.0) + weight

	# 选择得票最高的动作
	var best_action_key = ""
	var best_votes = -1.0
	for key in action_votes:
		if action_votes[key] > best_votes:
			best_votes = action_votes[key]
			best_action_key = key

	if best_action_key.is_empty():
		return {}
	return {"type": best_action_key}


func _extract_state(frame: Dictionary) -> Dictionary:
	"""从帧数据提取状态特征向量（与 AIController 观察格式一致）"""
	return {
		"velocity_x": frame.get("velocity", Vector2.ZERO).x if frame.get("velocity") is Vector2 else 0.0,
		"velocity_y": frame.get("velocity", Vector2.ZERO).y if frame.get("velocity") is Vector2 else 0.0,
		"on_floor": frame.get("on_floor", true),
		"current_state": frame.get("current_state", "idle"),
		# 从 observations 中提取障碍信息（与录制系统格式对齐）
		"front_obstacle": frame.get("observations", {}).get("nearby_obstacles", []).size() > 0,
		"front_enemy": frame.get("observations", {}).get("nearby_enemies", {}).get("found", false),
	}


func _extract_action(frame: Dictionary) -> Dictionary:
	"""从帧数据提取动作（修复：区分左右方向）"""
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
	# 修复：区分左右方向，不再都映射为 move_forward
	if inputs.get("move_right", false):
		return {"type": "move_right"}
	if inputs.get("move_left", false):
		return {"type": "move_left"}
	return {"type": "idle"}


func _compute_distance(obs_a: Dictionary, state_b: Dictionary) -> float:
	"""计算观察值与训练样本状态之间的加权距离"""
	var dist = 0.0

	# 速度差异（加权）
	var vx_diff = absf(obs_a.get("velocity_x", 0) - state_b.get("velocity_x", 0)) / 300.0
	var vy_diff = absf(obs_a.get("velocity_y", 0) - state_b.get("velocity_y", 0)) / 500.0
	dist += vx_diff * 0.2 + vy_diff * 0.1

	# 地面状态（权重高，影响跳跃/攻击决策）
	if obs_a.get("on_floor") != state_b.get("on_floor"):
		dist += 0.3

	# 当前状态名称
	if obs_a.get("current_state", "") != state_b.get("current_state", ""):
		dist += 0.2

	# 前方障碍（权重高，影响跳跃决策）
	if obs_a.get("front_obstacle", false) != state_b.get("front_obstacle", false):
		dist += 0.25

	# 前方敌人
	var a_enemy = obs_a.get("front_enemy", {})
	var b_enemy = state_b.get("front_enemy", false)
	var a_found = a_enemy.get("found", false) if a_enemy is Dictionary else bool(a_enemy)
	if a_found != b_enemy:
		dist += 0.15

	return dist


func get_pair_count() -> int:
	return state_action_pairs.size()
