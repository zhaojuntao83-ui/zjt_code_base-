## 全局游戏管理器 - 管理游戏状态、弟子数据、经济系统
extends Node

# ========== 游戏状态 ==========
enum GameState { MENU, TRAINING_CAMP, IN_LEVEL, RECORDING, TRAINING, BOSS_FIGHT, PAUSED }
enum Difficulty { EASY, NORMAL, CHALLENGE }

var current_state: GameState = GameState.MENU
var difficulty: Difficulty = Difficulty.NORMAL

# ========== 弟子数据 ==========
var active_disciple: DiscipleData = null
var retired_disciples: Array[DiscipleData] = []

# ========== 经济 ==========
var exp_points: int = 0
var total_exp_earned: int = 0

# ========== 关卡进度 ==========
var unlocked_worlds: Array[String] = ["world_1"]
var completed_levels: Array[String] = []

# ========== 已购装备 ==========
var owned_weapons: Array[String] = []
var owned_armor: Array[String] = []
var owned_consumables: Dictionary = {}  # item_id -> count

# ========== 接管升级 ==========
var takeover_charges_level: int = 0    # 次数线等级 (0-7, 初始3次, 每级+1, 最高10)
var takeover_duration_level: int = 0   # 时长线等级 (0-6, 初始3s, 每级+2s, 最高15s)
var takeover_cooldown_level: int = 0   # 冷却线等级 (0-5, 初始30s, 每级-5s, 最低5s)

# ========== 系统节点（由 GameManager 统一管理生命周期）==========
var training_backpack: TrainingBackpack
var achievement_system: AchievementSystem
var tutorial_system: TutorialSystem

# ========== 临时消耗品增益 ==========
# 存储当前生效的一次性增益效果，键值语义见 apply_consumable_buff
var active_consumable_buffs: Dictionary = {}

# 下次关卡开始时额外给予的接管次数（来自接管令牌消耗品）
var pending_takeover_charges: int = 0

# 训练背包UI→训练观看界面的卡片传递（不依赖场景参数）
var active_training_card_id: String = ""

# ========== 难度参数 ==========
const DIFFICULTY_PARAMS = {
	Difficulty.EASY: {
		"ai_learn_speed": 1.5,
		"takeover_charges": 5,
		"takeover_duration": 5.0,
		"stamina_recovery": "fast"
	},
	Difficulty.NORMAL: {
		"ai_learn_speed": 1.0,
		"takeover_charges": 3,
		"takeover_duration": 3.0,
		"stamina_recovery": "normal"
	},
	Difficulty.CHALLENGE: {
		"ai_learn_speed": 0.8,
		"takeover_charges": 2,
		"takeover_duration": 2.0,
		"stamina_recovery": "slow"
	}
}

# ========== 天赋定义 ==========
enum Talent { PARKOUR_GENIUS, COMBAT_INTUITION, ALL_ROUNDER, ADVERSITY_GROWTH, PERFECT_MIMIC }

const TALENT_DATA = {
	Talent.PARKOUR_GENIUS: {
		"name": "跑酷天才",
		"description": "学习跑酷动作速度 x1.5",
		"parkour_multiplier": 1.5,
		"combat_multiplier": 1.0,
	},
	Talent.COMBAT_INTUITION: {
		"name": "战斗悟性",
		"description": "学习战斗技能速度 x1.5",
		"parkour_multiplier": 1.0,
		"combat_multiplier": 1.5,
	},
	Talent.ALL_ROUNDER: {
		"name": "全能学徒",
		"description": "所有技能学习速度 x1.2",
		"parkour_multiplier": 1.2,
		"combat_multiplier": 1.2,
	},
	Talent.ADVERSITY_GROWTH: {
		"name": "逆境成长",
		"description": "失败次数越多，下次学习效率越高",
		"parkour_multiplier": 1.0,
		"combat_multiplier": 1.0,
	},
	Talent.PERFECT_MIMIC: {
		"name": "完美模仿",
		"description": "示范质量高时，模仿精度额外 +30%",
		"parkour_multiplier": 1.0,
		"combat_multiplier": 1.0,
	}
}


func _ready() -> void:
	# 初始化子系统节点
	training_backpack = TrainingBackpack.new()
	add_child(training_backpack)
	achievement_system = AchievementSystem.new()
	add_child(achievement_system)
	tutorial_system = TutorialSystem.new()
	add_child(tutorial_system)

	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.demonstration_quality_evaluated.connect(_on_demo_quality_evaluated)
	EventBus.disciple_learned_action.connect(_on_disciple_learned_action)


# ========== 弟子管理 ==========

func create_disciple(disciple_name: String, talent: Talent) -> DiscipleData:
	active_disciple = DiscipleData.new()
	active_disciple.disciple_name = disciple_name
	active_disciple.talent = talent
	active_disciple.color_value = 0.0  # 深黑色
	EventBus.disciple_created.emit(active_disciple.to_dict())
	return active_disciple


func retire_disciple() -> void:
	if active_disciple == null:
		return
	active_disciple.retired = true
	retired_disciples.append(active_disciple)
	EventBus.disciple_retired.emit(active_disciple.to_dict())
	active_disciple = null


# ========== 经济系统 ==========

func add_exp(amount: int) -> void:
	# 根据难度不调整经验获取（经验获取固定，难度影响AI学习速度和接管资源）
	exp_points += amount
	total_exp_earned += amount
	EventBus.exp_points_changed.emit(exp_points)


func spend_exp(amount: int) -> bool:
	if exp_points < amount:
		return false
	exp_points -= amount
	EventBus.exp_points_changed.emit(exp_points)
	return true


# ========== 接管属性计算 ==========

func get_takeover_max_charges() -> int:
	var base = DIFFICULTY_PARAMS[difficulty]["takeover_charges"]
	return base + takeover_charges_level


func get_takeover_duration() -> float:
	var base = DIFFICULTY_PARAMS[difficulty]["takeover_duration"]
	return base + takeover_duration_level * 2.0


func get_takeover_cooldown() -> float:
	return maxf(5.0, 30.0 - takeover_cooldown_level * 5.0)


# ========== 信号回调 ==========

func _on_enemy_defeated(_enemy_type: String, exp_reward: int) -> void:
	add_exp(exp_reward)


func _on_boss_defeated(_boss_id: String, exp_reward: int) -> void:
	add_exp(exp_reward)


func _on_level_completed(level_id: String, stats: Dictionary) -> void:
	if level_id not in completed_levels:
		completed_levels.append(level_id)
	add_exp(50)

	# Boss 关卡通关后解锁下一世界
	if stats.get("level_type") == BaseLevel.LevelType.BOSS:
		var next_world = _get_next_world(stats.get("world_id", ""))
		if next_world != "" and next_world not in unlocked_worlds:
			unlocked_worlds.append(next_world)
			EventBus.world_unlocked.emit(next_world)
			EventBus.message_requested.emit("新世界解锁！", 3.0)


func _get_next_world(world_id: String) -> String:
	match world_id:
		"world_1": return "world_2"
		"world_2": return "world_3"
		"world_3": return "world_4"
	return ""


func _on_demo_quality_evaluated(score: Dictionary) -> void:
	if score.get("overall", 0) >= 5:  # 满分示范
		add_exp(50)


func _on_disciple_learned_action(_action_name: String) -> void:
	add_exp(30)


# ========== 消耗品增益 ==========

func apply_consumable_buff(item_id: String) -> void:
	"""使用消耗品后激活对应的临时增益"""
	match item_id:
		"focus_potion":
			active_consumable_buffs["learning_speed_bonus"] = 0.5  # +50% 学习速度
		"enhance_scroll":
			active_consumable_buffs["attack_bonus"] = 0.3  # 攻击力 +30%（训练时生效）
		"tenacity_charm":
			active_consumable_buffs["tenacity"] = true  # 受击不打断动作
		"memory_crystal":
			active_consumable_buffs["data_weight_double"] = true  # 下次录制数据权重翻倍
		"training_manual":
			active_consumable_buffs["training_iterations_bonus"] = 0.5  # 迭代次数 x1.5
		"demo_magnifier":
			active_consumable_buffs["mimicry_bonus"] = 0.2  # AI 模仿精度 +20%
		"forget_cleanser":
			active_consumable_buffs["forget_cleanser"] = true  # 清除指定卡片错误记忆
		"takeover_token_s":
			pending_takeover_charges += 1
			EventBus.message_requested.emit("获得 +1 次接管机会", 2.0)
		"takeover_token_l":
			pending_takeover_charges += 3
			EventBus.message_requested.emit("获得 +3 次接管机会", 2.0)


# ========== 状态切换 ==========

func change_state(new_state: GameState) -> void:
	current_state = new_state
