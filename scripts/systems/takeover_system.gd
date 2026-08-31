## 实时接管系统 (Live Takeover) - 弟子卡住时师傅瞬间接管
## GDD: 在弟子失败的那一刻精准介入，学习效果远比重新录制更好
class_name TakeoverSystem
extends Node

var is_active: bool = false
var remaining_charges: int = 3
var duration_remaining: float = 0.0
var cooldown_remaining: float = 0.0

var master_ref: Node  # Master
var disciple_ref: Node  # Disciple
var recording_system: RecordingSystem

# 接管期间录制的帧数据（修复：原先从不填充，接管无法成为训练数据）
var takeover_frames: Array[Dictionary] = []

# 帧采集计时（30fps 采集）
var _frame_timer: float = 0.0
const FRAME_INTERVAL: float = 1.0 / 30.0


func _ready() -> void:
	_refresh_charges()


func _process(delta: float) -> void:
	# 冷却倒计时
	if cooldown_remaining > 0:
		cooldown_remaining -= delta
		EventBus.takeover_cooldown_updated.emit(cooldown_remaining)

	# 接管时长倒计时
	if is_active:
		duration_remaining -= delta

		# 接管期间持续采集师傅的操作帧
		_frame_timer += delta
		if _frame_timer >= FRAME_INTERVAL:
			_frame_timer = 0.0
			_capture_takeover_frame()

		if duration_remaining <= 0:
			# 时间耗尽，自动结束接管
			AudioManager.play_takeover_warning()
			deactivate()


func setup(master: Node, disciple: Node, rec_system: RecordingSystem) -> void:
	master_ref = master
	disciple_ref = disciple
	recording_system = rec_system


func activate() -> bool:
	"""按下接管键，瞬间切换回玩家控制"""
	if is_active:
		return false
	if remaining_charges <= 0:
		EventBus.message_requested.emit("接管次数已用完", 2.0)
		return false
	if cooldown_remaining > 0:
		EventBus.message_requested.emit("接管冷却中", 1.5)
		return false

	is_active = true
	remaining_charges -= 1
	duration_remaining = GameManager.get_takeover_duration()
	takeover_frames.clear()
	_frame_timer = 0.0

	# 切换控制权
	if disciple_ref and disciple_ref.has_method("start_takeover"):
		disciple_ref.start_takeover()

	AudioManager.play_takeover_activate()
	EventBus.takeover_activated.emit()
	EventBus.takeover_charges_changed.emit(remaining_charges)
	return true


func deactivate() -> void:
	"""松开接管键或时间耗尽，交还控制权给AI"""
	if not is_active:
		return

	is_active = false
	cooldown_remaining = GameManager.get_takeover_cooldown()

	# 交还控制权
	if disciple_ref and disciple_ref.has_method("end_takeover"):
		disciple_ref.end_takeover()

	# 修复：将接管期间采集到的操作帧作为训练数据传给弟子
	# 原先 takeover_frames 从不被填充，接管等于没有示范效果
	if takeover_frames.size() > 0 and disciple_ref and disciple_ref.has_method("learn_from_demonstration"):
		var actual_duration = GameManager.get_takeover_duration() - duration_remaining
		var takeover_demo = {
			"id": "%d_takeover" % Time.get_ticks_msec(),
			"category": "mixed",
			"duration": actual_duration,
			"frame_count": takeover_frames.size(),
			"frames": takeover_frames.duplicate(true),
			# 接管示范默认给中等质量权重（精准示范，但时间短）
			"quality": {"completeness": 3, "fluency": 4, "diversity": 3, "overall": 3},
			"created_at": Time.get_datetime_string_from_system(),
		}
		disciple_ref.learn_from_demonstration(takeover_demo)

	var recorded_data = {
		"type": "takeover",
		"frames": takeover_frames.duplicate(true),
		"duration": GameManager.get_takeover_duration() - duration_remaining,
	}
	EventBus.takeover_deactivated.emit(recorded_data)


func _capture_takeover_frame() -> void:
	"""采集当前帧的师傅操作（接管期间的学习来源）"""
	if master_ref == null or not master_ref is BaseCharacter:
		return

	var master = master_ref as BaseCharacter
	var state_name = ""
	if master.state_machine and master.state_machine.current_state:
		state_name = master.state_machine.current_state.name

	var frame = {
		"timestamp": GameManager.get_takeover_duration() - duration_remaining,
		"position": master.global_position,
		"velocity": master.velocity,
		"on_floor": master.is_on_floor(),
		"facing_right": master.sprite_facing_right,
		"current_state": state_name,
		"health": master.health,
		"inputs": {
			"move_left": Input.is_action_pressed("move_left"),
			"move_right": Input.is_action_pressed("move_right"),
			"jump": Input.is_action_just_pressed("jump"),
			"crouch": Input.is_action_pressed("crouch"),
			"attack": Input.is_action_just_pressed("attack"),
			"block": Input.is_action_pressed("block"),
			"dodge": Input.is_action_just_pressed("dodge"),
		},
		"observations": {
			"nearby_obstacles": [],
			"nearby_enemies": {"found": false, "distance": 999.0, "position": Vector2.ZERO},
			"nearest_platform_dist": 0.0,
			"boss_warning_active": false,
			"boss_warning_area": Rect2(),
		},
	}
	takeover_frames.append(frame)


func _refresh_charges() -> void:
	remaining_charges = GameManager.get_takeover_max_charges()
	EventBus.takeover_charges_changed.emit(remaining_charges)


func reset_for_new_level() -> void:
	"""进入新关卡时重置接管次数"""
	_refresh_charges()
	cooldown_remaining = 0.0
	is_active = false


func add_bonus_charges(count: int) -> void:
	"""使用接管令牌增加次数"""
	remaining_charges += count
	EventBus.takeover_charges_changed.emit(remaining_charges)
