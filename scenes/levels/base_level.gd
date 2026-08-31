## 关卡基类 - 所有关卡继承此类
class_name BaseLevel
extends Node2D

@export var level_id: String = ""
@export var level_name: String = ""
@export var level_type: LevelType = LevelType.PARKOUR
@export var world_id: String = "world_1"

enum LevelType { PARKOUR, COMBAT, MIXED, BOSS_TRAINING, BOSS }

# 关卡内系统实例
var recording_system: RecordingSystem
var takeover_system: TakeoverSystem
var combat_system: CombatSystem

# 角色引用
var master: BaseCharacter
var disciple: BaseCharacter

# 关卡状态
var is_recording: bool = false
var is_level_complete: bool = false
var level_start_time: float = 0.0

@onready var spawn_point: Marker2D = $SpawnPoint if has_node("SpawnPoint") else null
@onready var goal_area: Area2D = $GoalArea if has_node("GoalArea") else null
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null


func _ready() -> void:
	# 初始化系统
	recording_system = RecordingSystem.new()
	add_child(recording_system)

	takeover_system = TakeoverSystem.new()
	add_child(takeover_system)

	combat_system = CombatSystem.new()
	add_child(combat_system)

	# 重置接管次数，并追加消耗品令牌带来的额外次数
	takeover_system.reset_for_new_level()
	if GameManager.pending_takeover_charges > 0:
		takeover_system.add_bonus_charges(GameManager.pending_takeover_charges)
		GameManager.pending_takeover_charges = 0

	level_start_time = Time.get_ticks_msec() / 1000.0
	GameManager.change_state(GameManager.GameState.IN_LEVEL)
	EventBus.level_started.emit(level_id)

	# 目标区域检测
	if goal_area:
		goal_area.body_entered.connect(_on_goal_reached)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("record_toggle"):
		_toggle_recording()
	elif event.is_action_pressed("takeover"):
		if not takeover_system.is_active:
			takeover_system.activate()
	elif event.is_action_released("takeover"):
		if takeover_system.is_active:
			takeover_system.deactivate()


func _toggle_recording() -> void:
	if is_recording:
		var demo_data = recording_system.stop_recording()
		if not demo_data.is_empty():
			# 检查是否为替换操作（来自训练背包的替换指令）
			var replace_id = GameManager.active_consumable_buffs.get("replace_card_id", "")
			if replace_id != "":
				GameManager.training_backpack.replace_card(replace_id, demo_data)
				GameManager.active_consumable_buffs.erase("replace_card_id")
				EventBus.message_requested.emit("示范已替换！", 2.0)
			else:
				GameManager.training_backpack.add_card(demo_data)
				EventBus.message_requested.emit("示范录制完成！", 2.0)
		is_recording = false
	else:
		if master:
			recording_system.start_recording(master)
			is_recording = true


func _on_goal_reached(body: Node2D) -> void:
	if body.is_in_group("disciple") and not is_level_complete:
		_complete_level()


func _complete_level() -> void:
	is_level_complete = true
	var elapsed = Time.get_ticks_msec() / 1000.0 - level_start_time

	var stats = {
		"time": elapsed,
		"level_type": level_type,
		"world_id": world_id,
	}

	EventBus.level_completed.emit(level_id, stats)
	EventBus.message_requested.emit("关卡完成!", 3.0)
	SaveManager.auto_save()

	# 延迟返回
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")


func _on_disciple_died() -> void:
	EventBus.level_failed.emit(level_id, "弟子阵亡")

	if GameManager.active_disciple:
		GameManager.active_disciple.total_failures += 1

	EventBus.message_requested.emit("弟子失败，返回训练...", 2.0)

	await get_tree().create_timer(2.0).timeout
	# 重新加载关卡 or 返回训练营
	get_tree().reload_current_scene()


func spawn_characters(master_scene: PackedScene, disciple_scene: PackedScene) -> void:
	"""在关卡中生成师傅和弟子"""
	var spawn_pos = spawn_point.global_position if spawn_point else Vector2(100, 300)

	master = master_scene.instantiate()
	master.global_position = spawn_pos
	master.set_meta("spawn_position", spawn_pos)
	add_child(master)

	disciple = disciple_scene.instantiate()
	disciple.global_position = spawn_pos + Vector2(60, 0)
	add_child(disciple)

	# 设置接管系统
	takeover_system.setup(master, disciple, recording_system)

	# 相机跟随弟子
	if camera:
		camera.reparent(disciple)
		camera.position = Vector2.ZERO

	# 监听弟子死亡
	EventBus.disciple_died.connect(_on_disciple_died)
