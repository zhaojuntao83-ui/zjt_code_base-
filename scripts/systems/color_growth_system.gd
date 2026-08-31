## 颜色成长系统 - 弟子的颜色是成长程度最直观的体现
## GDD: 颜色渐变是连续的，不同部位颜色可以不同
class_name ColorGrowthSystem
extends Node

# 各身体部位的独立颜色值（0.0=深黑, 1.0=近白）
# 学会跑酷的腿部先变浅，学会战斗的手臂后变浅
var body_colors: Dictionary = {
	"head": 0.0,
	"torso": 0.0,
	"left_arm": 0.0,
	"right_arm": 0.0,
	"left_leg": 0.0,
	"right_leg": 0.0,
}

# 技能分类 -> 影响的身体部位
const SKILL_BODY_MAP = {
	"run": ["left_leg", "right_leg"],
	"jump": ["left_leg", "right_leg"],
	"slide": ["left_leg", "right_leg", "torso"],
	"crouch": ["left_leg", "right_leg"],
	"climb": ["left_arm", "right_arm", "left_leg", "right_leg"],
	"attack": ["left_arm", "right_arm"],
	"block": ["left_arm", "right_arm", "torso"],
	"dodge": ["torso", "left_leg", "right_leg"],
	"air_attack": ["left_arm", "right_arm"],
}

# 整体颜色也独立追踪（所有部位的加权平均）
var overall_color: float = 0.0


func apply_training_result(skill_name: String, quality: float) -> void:
	"""训练完成后根据技能类型和质量更新对应部位颜色"""
	var affected_parts = SKILL_BODY_MAP.get(skill_name, ["torso"])
	var growth_amount = quality * 0.005  # 每次训练微量变化

	for part in affected_parts:
		if body_colors.has(part):
			body_colors[part] = clampf(body_colors[part] + growth_amount, 0.0, 1.0)

	# 头部特殊处理：所有部位都达到一定程度后头部才开始变浅
	var min_body = 1.0
	for part in body_colors:
		if part != "head":
			min_body = minf(min_body, body_colors[part])
	if min_body > 0.3:
		body_colors["head"] = clampf(body_colors["head"] + growth_amount * 0.5, 0.0, 1.0)

	_recalc_overall()


func get_part_color(part: String) -> Color:
	"""获取指定部位的显示颜色"""
	var value = body_colors.get(part, 0.0)
	return _value_to_color(value)


func get_overall_display_color() -> Color:
	return _value_to_color(overall_color)


func get_growth_stage() -> String:
	if overall_color < 0.15:
		return "初创期"
	elif overall_color < 0.3:
		return "入门期"
	elif overall_color < 0.55:
		return "成长期"
	elif overall_color < 0.8:
		return "熟练期"
	else:
		return "精通期"


func _value_to_color(value: float) -> Color:
	var dark = Color(0.1, 0.1, 0.12)
	var mid = Color(0.45, 0.47, 0.5)
	var bright = Color(0.88, 0.9, 0.95)
	if value < 0.5:
		return dark.lerp(mid, value * 2.0)
	else:
		return mid.lerp(bright, (value - 0.5) * 2.0)


func _recalc_overall() -> void:
	var total = 0.0
	for part in body_colors:
		total += body_colors[part]
	overall_color = total / body_colors.size()


func to_dict() -> Dictionary:
	return body_colors.duplicate()


func from_dict(data: Dictionary) -> void:
	for part in data:
		if body_colors.has(part):
			body_colors[part] = data[part]
	_recalc_overall()
