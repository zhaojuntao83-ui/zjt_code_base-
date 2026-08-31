## 录制系统 - 主动录制师傅的示范动作，生成训练数据
## GDD核心原则：玩家主动决定何时示范，不是被动后台记录
class_name RecordingSystem
extends Node

var is_recording: bool = false

# 当前录制的帧数据
var recorded_frames: Array[Dictionary] = []
var recording_start_time: float = 0.0
var recording_duration: float = 0.0

# 录制目标（师傅角色）
var target_character: BaseCharacter

# 场景状态快照（存数量而非节点引用，避免节点销毁后引用失效）
var scene_obstacles_count: int = 0
var scene_enemies_count: int = 0

# 录制的技能分类
var current_category: String = ""  # "parkour" / "combat" / "mixed"

# 实时质量预览（每秒向UI推送一次）
var _preview_timer: float = 0.0
const PREVIEW_INTERVAL: float = 1.0

# 障碍/敌人交互计数（用于修正后的完整度评估）
var _obstacle_interactions: int = 0
var _enemy_interactions: int = 0
var _last_obstacle_contact: bool = false
var _last_enemy_contact: bool = false


func start_recording(character: BaseCharacter, category: String = "mixed") -> void:
	"""按下录制键，进入示范模式"""
	if is_recording:
		return

	target_character = character
	current_category = category
	recorded_frames.clear()
	recording_start_time = Time.get_ticks_msec() / 1000.0
	is_recording = true

	_obstacle_interactions = 0
	_enemy_interactions = 0
	_last_obstacle_contact = false
	_last_enemy_contact = false
	_preview_timer = 0.0

	# 快照当前场景状态
	_snapshot_scene()

	AudioManager.play_record_start()
	EventBus.recording_started.emit()


func stop_recording() -> Dictionary:
	"""按下停止键，结束录制并评估质量"""
	if not is_recording:
		return {}

	is_recording = false
	recording_duration = Time.get_ticks_msec() / 1000.0 - recording_start_time

	var demo_data = _build_demonstration_data()
	var quality = evaluate_quality(demo_data)
	demo_data["quality"] = quality

	EventBus.recording_stopped.emit(demo_data)
	EventBus.demonstration_quality_evaluated.emit(quality)

	return demo_data


func _physics_process(delta: float) -> void:
	if is_recording and target_character:
		_record_frame()
		# 实时质量预览推送
		_preview_timer += delta
		if _preview_timer >= PREVIEW_INTERVAL:
			_preview_timer = 0.0
			_emit_quality_preview()


# ========== 帧录制 ==========

func _record_frame() -> void:
	"""记录每一帧的场景状态和玩家操作"""
	var frame = {
		"timestamp": Time.get_ticks_msec() / 1000.0 - recording_start_time,
		# 角色状态
		"position": target_character.global_position,
		"velocity": target_character.velocity,
		"on_floor": target_character.is_on_floor(),
		"facing_right": target_character.sprite_facing_right,
		"current_state": target_character.state_machine.current_state.name if target_character.state_machine.current_state else "",
		"health": target_character.health,
		# 输入状态
		"inputs": {
			"move_left": Input.is_action_pressed("move_left"),
			"move_right": Input.is_action_pressed("move_right"),
			"jump": Input.is_action_just_pressed("jump"),
			"crouch": Input.is_action_pressed("crouch"),
			"attack": Input.is_action_just_pressed("attack"),
			"block": Input.is_action_pressed("block"),
			"dodge": Input.is_action_just_pressed("dodge"),
		},
		# 周围环境观察
		"observations": _get_observations(),
	}
	recorded_frames.append(frame)
	_track_interactions(frame)


func _get_observations() -> Dictionary:
	"""
	获取当前帧的环境观察值。
	修复：字段与 AIController._observe_environment 完全对齐，
	解决录制和AI决策输入不匹配导致学习数据无效的问题。
	"""
	var obs = {
		"nearby_obstacles": [],
		"nearby_enemies": {"found": false, "distance": 999.0, "position": Vector2.ZERO},
		"nearest_platform_dist": 999.0,
		"boss_warning_active": false,
		"boss_warning_area": Rect2(),
	}

	var space = target_character.get_world_2d().direct_space_state
	if space:
		var facing = 1.0 if target_character.sprite_facing_right else -1.0

		# 前方障碍检测（根据朝向调整方向，与 AIController 保持一致）
		var obs_query = PhysicsRayQueryParameters2D.create(
			target_character.global_position,
			target_character.global_position + Vector2(120 * facing, 0)
		)
		obs_query.exclude = [target_character.get_rid()]
		var obs_result = space.intersect_ray(obs_query)
		if obs_result:
			obs["nearby_obstacles"].append({
				"position": obs_result.position,
				"distance": target_character.global_position.distance_to(obs_result.position)
			})

		# 脚下地面检测
		var ground_query = PhysicsRayQueryParameters2D.create(
			target_character.global_position,
			target_character.global_position + Vector2(80 * facing, 60)
		)
		ground_query.exclude = [target_character.get_rid()]
		var ground_result = space.intersect_ray(ground_query)
		obs["nearest_platform_dist"] = 0.0 if ground_result else 999.0

	# 敌人检测
	var enemies = target_character.get_tree().get_nodes_in_group("enemies")
	var closest_dist = 999.0
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var dist = target_character.global_position.distance_to(enemy.global_position)
		if dist < closest_dist and dist < 300.0:
			closest_dist = dist
			obs["nearby_enemies"] = {
				"found": true,
				"distance": dist,
				"position": enemy.global_position
			}

	# Boss预警检测
	var warnings = target_character.get_tree().get_nodes_in_group("boss_warning")
	for warning in warnings:
		if warning is Area2D and warning.has_meta("warning_rect"):
			var rect: Rect2 = warning.get_meta("warning_rect")
			if rect.has_point(target_character.global_position):
				obs["boss_warning_active"] = true
				obs["boss_warning_area"] = rect

	return obs


func _track_interactions(frame: Dictionary) -> void:
	"""追踪每帧是否新增了障碍/敌人交互（用于完整度评估）"""
	var has_obstacle = frame["observations"]["nearby_obstacles"].size() > 0
	if has_obstacle and not _last_obstacle_contact:
		_obstacle_interactions += 1
	_last_obstacle_contact = has_obstacle

	var has_enemy = frame["observations"]["nearby_enemies"].get("found", false)
	if has_enemy and not _last_enemy_contact:
		_enemy_interactions += 1
	_last_enemy_contact = has_enemy


func _snapshot_scene() -> void:
	"""录制开始时快照场景中的障碍和敌人数量（不保存节点引用，防止销毁后崩溃）"""
	scene_obstacles_count = get_tree().get_nodes_in_group("obstacles").size()
	scene_enemies_count = get_tree().get_nodes_in_group("enemies").size()


func _emit_quality_preview() -> void:
	"""向UI发送实时质量预览，玩家录制时就能看到评分趋势"""
	if recorded_frames.is_empty():
		return
	var partial_data = {
		"frames": recorded_frames,
		"scene_context": {
			"obstacle_count": scene_obstacles_count,
			"enemy_count": scene_enemies_count,
			"obstacle_interactions": _obstacle_interactions,
			"enemy_interactions": _enemy_interactions,
		}
	}
	var preview = evaluate_quality(partial_data)
	EventBus.recording_quality_preview_updated.emit(preview)


# ========== 示范数据构建 ==========

func _build_demonstration_data() -> Dictionary:
	return {
		"id": _generate_id(),
		"category": current_category,
		"duration": recording_duration,
		"frame_count": recorded_frames.size(),
		"frames": recorded_frames.duplicate(true),
		"scene_context": {
			"obstacle_count": scene_obstacles_count,
			"enemy_count": scene_enemies_count,
			"obstacle_interactions": _obstacle_interactions,
			"enemy_interactions": _enemy_interactions,
		},
		"created_at": Time.get_datetime_string_from_system(),
	}


# ========== 示范质量评估 ==========

func evaluate_quality(demo_data: Dictionary) -> Dictionary:
	"""评估示范质量：完整度、流畅度、多样性"""
	var frames = demo_data.get("frames", [])
	if frames.is_empty():
		return {"completeness": 0, "fluency": 0, "diversity": 0, "overall": 0}

	var completeness = _evaluate_completeness(demo_data)
	var fluency = _evaluate_fluency(frames)
	var diversity = _evaluate_diversity(frames)
	var overall = roundi((completeness + fluency + diversity) / 3.0)

	return {
		"completeness": completeness,
		"fluency": fluency,
		"diversity": diversity,
		"overall": overall,
	}


func _evaluate_completeness(demo_data: Dictionary) -> int:
	"""
	修复后的完整度评估：
	原先只看状态种类数（不反映障碍覆盖）；
	现在结合实际遭遇的障碍次数和敌人交互次数来评分。
	"""
	var frames = demo_data.get("frames", [])
	var context = demo_data.get("scene_context", {})

	var obstacle_hits = context.get("obstacle_interactions", 0)
	var enemy_hits = context.get("enemy_interactions", 0)
	var total_obstacles = context.get("obstacle_count", 0)

	# 障碍覆盖率得分
	var obstacle_score = 0
	if total_obstacles > 0:
		obstacle_score = mini(5, roundi(float(obstacle_hits) / total_obstacles * 5))
	elif obstacle_hits > 0:
		obstacle_score = mini(5, obstacle_hits)

	# 状态多样性补充（排除琐碎的 idle/run 状态）
	var states_seen = {}
	for frame in frames:
		var state_name = frame.get("current_state", "")
		if state_name and state_name not in ["idle", "run"]:
			states_seen[state_name] = true

	var diversity_bonus = mini(2, states_seen.size())
	var enemy_bonus = 1 if enemy_hits > 0 else 0

	var final_score = obstacle_score + diversity_bonus + enemy_bonus
	if final_score >= 6: return 5
	if final_score >= 4: return 4
	if final_score >= 3: return 3
	if final_score >= 2: return 2
	return 1


func _evaluate_fluency(frames: Array) -> int:
	"""流畅度：动作是否连贯自然"""
	if frames.size() < 2:
		return 1

	var sudden_stops = 0
	for i in range(1, frames.size()):
		var prev_vel = frames[i - 1].get("velocity", Vector2.ZERO)
		var curr_vel = frames[i].get("velocity", Vector2.ZERO)
		# 速度突变检测
		if prev_vel is Vector2 and curr_vel is Vector2:
			if (prev_vel - curr_vel).length() > 400:
				sudden_stops += 1

	var stop_rate = float(sudden_stops) / frames.size()
	if stop_rate < 0.02: return 5
	if stop_rate < 0.05: return 4
	if stop_rate < 0.1: return 3
	if stop_rate < 0.2: return 2
	return 1


func _evaluate_diversity(frames: Array) -> int:
	"""多样性：同一障碍是否有多种过法"""
	var action_sequences = []
	var current_sequence = ""
	for frame in frames:
		var state = frame.get("current_state", "")
		if state != current_sequence:
			if current_sequence:
				action_sequences.append(current_sequence)
			current_sequence = state
	# 修复：循环结束后追加最后一个状态，否则录制末尾的动作永远被丢弃
	if current_sequence:
		action_sequences.append(current_sequence)

	var unique_transitions = {}
	for i in range(1, action_sequences.size()):
		var transition = "%s->%s" % [action_sequences[i-1], action_sequences[i]]
		unique_transitions[transition] = true

	var count = unique_transitions.size()
	if count >= 8: return 5
	if count >= 5: return 4
	if count >= 3: return 3
	if count >= 2: return 2
	return 1


func _generate_id() -> String:
	return "%d_%s" % [Time.get_ticks_msec(), current_category]
