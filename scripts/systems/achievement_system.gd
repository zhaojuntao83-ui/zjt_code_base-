## 成就与里程碑系统
## GDD: 成就分为培养/示范/战斗/退休/效率五类，里程碑触发专属动画
class_name AchievementSystem
extends Node

var unlocked_achievements: Array[String] = []

# 成就定义
const ACHIEVEMENTS = {
	# 培养成就
	"first_pass": {"name": "初学乍练", "desc": "弟子首次成功过关", "category": "培养", "reward_exp": 50},
	"first_color_change": {"name": "微光初现", "desc": "弟子颜色首次变浅", "category": "培养", "reward_exp": 50},
	"reach_growth": {"name": "渐入佳境", "desc": "弟子达到成长期", "category": "培养", "reward_exp": 100},
	"reach_master": {"name": "炉火纯青", "desc": "弟子达到精通期", "category": "培养", "reward_exp": 200},

	# 示范成就
	"perfect_demo": {"name": "完美示范", "desc": "单次示范质量满分", "category": "示范", "reward_exp": 50},
	"demo_100": {"name": "百炼成钢", "desc": "累计录制100次示范", "category": "示范", "reward_exp": 100},
	"demo_all_types": {"name": "全能教练", "desc": "录制过跑酷、战斗、综合三类示范", "category": "示范", "reward_exp": 80},

	# 战斗成就
	"first_boss_kill": {"name": "初战告捷", "desc": "弟子首次击败Boss", "category": "战斗", "reward_exp": 100},
	"all_weapons": {"name": "十八般武艺", "desc": "弟子使用过所有武器族", "category": "战斗", "reward_exp": 150},
	"all_bosses": {"name": "传说终结者", "desc": "击败所有Boss", "category": "战斗", "reward_exp": 300},

	# 退休成就
	"first_retire": {"name": "薪火相传", "desc": "第一个弟子退休", "category": "退休", "reward_exp": 100},
	"retire_master": {"name": "一代宗师", "desc": "退休一个精通期弟子", "category": "退休", "reward_exp": 200},

	# 效率成就
	"no_takeover_clear": {"name": "无为而治", "desc": "不使用接管道具通关", "category": "效率", "reward_exp": 100},
	"fast_learn": {"name": "天纵之才", "desc": "3次示范内弟子学会新动作", "category": "效率", "reward_exp": 80},
}

# 里程碑（触发专属动画）
const MILESTONES = {
	"color_stage_入门期": {"text": "他开始有感觉了", "trigger": "color_stage"},
	"color_stage_成长期": {"text": "不错，他记住了", "trigger": "color_stage"},
	"color_stage_精通期": {"text": "他已经超越我当年了", "trigger": "color_stage"},
	"first_retire": {"text": "去吧，这是你的路了", "trigger": "retire"},
	"first_enemy_solo": {"text": "不错，他记住了", "trigger": "combat"},
}

var demo_count: int = 0
var demo_categories_seen: Dictionary = {}


func _ready() -> void:
	EventBus.level_completed.connect(_on_level_completed)
	EventBus.disciple_color_changed.connect(_on_color_changed)
	EventBus.demonstration_quality_evaluated.connect(_on_demo_quality)
	EventBus.recording_stopped.connect(_on_recording_stopped)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.disciple_retired.connect(_on_disciple_retired)
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)


func _try_unlock(achievement_id: String) -> void:
	if achievement_id in unlocked_achievements:
		return
	if not ACHIEVEMENTS.has(achievement_id):
		return

	unlocked_achievements.append(achievement_id)
	var ach = ACHIEVEMENTS[achievement_id]
	GameManager.add_exp(ach["reward_exp"])
	EventBus.achievement_unlocked.emit(achievement_id)


# ========== 信号回调 ==========

func _on_level_completed(_level_id: String, _stats: Dictionary) -> void:
	_try_unlock("first_pass")


func _on_color_changed(_new_color: Color) -> void:
	_try_unlock("first_color_change")
	if GameManager.active_disciple:
		var stage = ""
		var cv = GameManager.active_disciple.color_value
		if cv >= 0.55:
			stage = "成长期"
		if cv >= 0.8:
			stage = "精通期"
		if stage == "成长期":
			_try_unlock("reach_growth")
		elif stage == "精通期":
			_try_unlock("reach_master")


func _on_demo_quality(score: Dictionary) -> void:
	if score.get("overall", 0) >= 5:
		_try_unlock("perfect_demo")


func _on_recording_stopped(demo_data: Dictionary) -> void:
	demo_count += 1
	var cat = demo_data.get("category", "")
	if cat:
		demo_categories_seen[cat] = true
	if demo_count >= 100:
		_try_unlock("demo_100")
	if demo_categories_seen.size() >= 3:
		_try_unlock("demo_all_types")


func _on_boss_defeated(boss_id: String, _exp: int) -> void:
	_try_unlock("first_boss_kill")
	if GameManager.active_disciple:
		if GameManager.active_disciple.bosses_defeated.size() >= 4:
			_try_unlock("all_bosses")


func _on_disciple_retired(_data: Dictionary) -> void:
	_try_unlock("first_retire")
	if _data.get("color_value", 0) >= 0.8:
		_try_unlock("retire_master")


func _on_milestone_reached(milestone_id: String) -> void:
	if MILESTONES.has(milestone_id):
		var ms = MILESTONES[milestone_id]
		EventBus.dialog_requested.emit("师傅", ms["text"])


func _on_enemy_defeated(_type: String, _exp: int) -> void:
	# 弟子独立击败：接管系统未激活时视为弟子自主行为
	# （师傅不直接参与战斗，接管期间才是师傅操控）
	var takeover_active = false
	# 尝试从关卡场景查询接管状态，安全降级处理
	var level_scene = get_tree().current_scene
	if level_scene and level_scene.has_method("get") :
		var ts = level_scene.get("takeover_system")
		if ts and ts.is_active:
			takeover_active = true
	if not takeover_active:
		_try_unlock("first_enemy_solo")


func get_all_achievements() -> Array:
	var result = []
	for id in ACHIEVEMENTS:
		var ach = ACHIEVEMENTS[id].duplicate()
		ach["id"] = id
		ach["unlocked"] = id in unlocked_achievements
		result.append(ach)
	return result


func to_save_data() -> Dictionary:
	return {
		"unlocked": unlocked_achievements,
		"demo_count": demo_count,
		"demo_categories": demo_categories_seen,
	}


func from_save_data(data: Dictionary) -> void:
	unlocked_achievements = data.get("unlocked", [])
	demo_count = data.get("demo_count", 0)
	demo_categories_seen = data.get("demo_categories", {})
