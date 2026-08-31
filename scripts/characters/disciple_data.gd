## 弟子持久化数据 - 保存弟子的所有成长信息
class_name DiscipleData
extends Resource

@export var disciple_name: String = ""
@export var talent: GameManager.Talent = GameManager.Talent.ALL_ROUNDER
@export var color_value: float = 0.0
@export var retired: bool = false

# 基础属性
@export var health: float = 100.0
@export var attack_power: float = 10.0
@export var learning_ability: float = 1.0
@export var reaction_speed: float = 0.5
@export var endurance: float = 0.5

# 已学会的动作列表
@export var learned_actions: Array[String] = []

# 训练统计
@export var total_training_iterations: int = 0
@export var total_failures: int = 0
@export var total_successes: int = 0
@export var bosses_defeated: Array[String] = []

# 训练风格得分（新增，用于 TrainingStyleAnalyzer 和社交分享标签）
@export var training_style_scores: Dictionary = {
	"aggressive": 0,   # 激进型：大量滑铲、冲刺
	"elegant": 0,      # 优雅型：空翻使用频率高
	"defensive": 0,    # 保守型：格挡多、节奏稳
	"sniper": 0,       # 狙击型：弓族武器使用多
}


func get_dominant_style() -> String:
	"""返回当前弟子的主要训练风格标签"""
	return TrainingStyleAnalyzer.get_dominant_style(training_style_scores)


func to_dict() -> Dictionary:
	return {
		"disciple_name": disciple_name,
		"talent": talent,
		"color_value": color_value,
		"retired": retired,
		"health": health,
		"attack_power": attack_power,
		"learning_ability": learning_ability,
		"reaction_speed": reaction_speed,
		"endurance": endurance,
		"learned_actions": learned_actions,
		"total_training_iterations": total_training_iterations,
		"total_failures": total_failures,
		"total_successes": total_successes,
		"bosses_defeated": bosses_defeated,
		"training_style_scores": training_style_scores,
	}


static func from_dict(data: Dictionary) -> DiscipleData:
	var d = DiscipleData.new()
	d.disciple_name = data.get("disciple_name", "")
	d.talent = data.get("talent", GameManager.Talent.ALL_ROUNDER)
	d.color_value = data.get("color_value", 0.0)
	d.retired = data.get("retired", false)
	d.health = data.get("health", 100.0)
	d.attack_power = data.get("attack_power", 10.0)
	d.learning_ability = data.get("learning_ability", 1.0)
	d.reaction_speed = data.get("reaction_speed", 0.5)
	d.endurance = data.get("endurance", 0.5)
	d.learned_actions = data.get("learned_actions", [])
	d.total_training_iterations = data.get("total_training_iterations", 0)
	d.total_failures = data.get("total_failures", 0)
	d.total_successes = data.get("total_successes", 0)
	d.bosses_defeated = data.get("bosses_defeated", [])
	d.training_style_scores = data.get("training_style_scores", {
		"aggressive": 0, "elegant": 0, "defensive": 0, "sniper": 0
	})
	return d
