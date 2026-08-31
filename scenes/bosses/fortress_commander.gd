## 要塞指挥官 - 第四世界Boss（多阶段Boss）
## GDD: 综合全部技能，群体小怪+Boss同时出现，多层平台
extends BaseBoss

var minion_scene: PackedScene
var minion_spawn_timer: float = 0.0
const MINION_SPAWN_INTERVAL: float = 12.0
const MAX_MINIONS: int = 3


func _ready() -> void:
	boss_id = "fortress_commander"
	boss_display_name = "要塞指挥官"
	enemy_type = "boss"
	max_health = 1000.0
	attack_damage = 25.0
	move_speed = 100.0
	attack_range = 90.0
	exp_reward = 300
	warning_duration = 1.0
	phase_count = 3
	phase_health_thresholds = [0.65, 0.3]

	attack_patterns = [
		{"type": "basic", "damage": 25.0},
		{"type": "ranged", "damage": 20.0},
		{"type": "aoe", "range": 100.0, "damage": 30.0},
	]

	# 召唤的小怪场景——优先使用巡逻兵，文件不存在时禁用召唤功能
	const MINION_PATH = "res://scenes/enemies/patrol_soldier.tscn"
	if ResourceLoader.exists(MINION_PATH):
		minion_scene = load(MINION_PATH)

	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# 阶段2+开始召唤小怪
	if current_phase >= 2 and is_alive:
		minion_spawn_timer += delta
		if minion_spawn_timer >= MINION_SPAWN_INTERVAL:
			minion_spawn_timer = 0.0
			_spawn_minions()


func _spawn_minions() -> void:
	"""召唤小怪"""
	var existing = get_tree().get_nodes_in_group("enemies").size()
	if existing >= MAX_MINIONS:
		return

	if minion_scene:
		var minion = minion_scene.instantiate()
		minion.global_position = global_position + Vector2(randf_range(-100, 100), -50)
		get_tree().current_scene.add_child(minion)


func _enter_phase(phase: int) -> void:
	super._enter_phase(phase)
	match phase:
		2:
			warning_duration = 0.8
			move_speed = 130.0
			attack_patterns.append({"type": "charge", "damage": 40.0, "speed": 380.0})
		3:
			# 最终阶段：全力出击
			warning_duration = 0.5
			move_speed = 160.0
			attack_damage = 35.0
			attack_patterns.append({"type": "aoe", "range": 200.0, "damage": 50.0})


func _special_attack(pattern: Dictionary) -> void:
	"""指挥官大招：全屏警告 + 召唤 + AOE"""
	_spawn_minions()
	await super._special_attack(pattern)
