## 训练背包系统 - 管理示范卡片的增删改查
## GDD: 每次录制的示范数据都变成可管理的示范卡片
class_name TrainingBackpack
extends Node

# 卡片存储：card_id -> DemonstrationCard
var cards: Dictionary = {}

# 分类
const CATEGORIES = {
	"parkour": "跑酷技能",
	"combat": "战斗技能",
	"mixed": "综合示范",
}


# ========== 增 ==========

func add_card(demo_data: Dictionary) -> DemonstrationCard:
	"""录制完成后自动生成卡片存入背包"""
	var card = DemonstrationCard.new()
	card.card_id = demo_data.get("id", "")
	card.skill_name = _infer_skill_name(demo_data)
	card.category = demo_data.get("category", "mixed")
	card.duration = demo_data.get("duration", 0.0)
	card.quality_score = demo_data.get("quality", {}).get("overall", 1)
	card.quality_detail = demo_data.get("quality", {})
	card.frame_data = demo_data.get("frames", [])
	card.created_at = demo_data.get("created_at", "")
	card.practice_count = 0

	cards[card.card_id] = card
	return card


# ========== 删 ==========

func remove_card(card_id: String) -> bool:
	"""
	删除卡片。高练习次数的卡片显示高风险警告。
	修复：删除后触发遗忘曲线事件，弟子不会立刻忘记，而是慢慢淡忘。
	原先只是直接删除，没有任何后续处理。
	"""
	if not cards.has(card_id):
		return false

	var card = cards[card_id]

	# 高风险检查（由UI层调用前检查并提示用户）
	if card.practice_count > 100:
		push_warning("TrainingBackpack: 高练习次数卡片被删除 (id=%s, practices=%d)" % [card_id, card.practice_count])

	# 根据练习次数计算遗忘强度（练得越多，删除后遗忘过程越慢、越不彻底）
	var decay_amount = clampf(float(card.practice_count) / 500.0, 0.05, 0.4)
	EventBus.card_forgotten.emit(card_id, card.frame_data, decay_amount)

	cards.erase(card_id)
	return true


func is_high_risk_delete(card_id: String) -> bool:
	"""检查删除该卡片是否为高风险操作"""
	if not cards.has(card_id):
		return false
	return cards[card_id].practice_count > 100


# ========== 改（替换） ==========

func replace_card(card_id: String, new_demo_data: Dictionary) -> DemonstrationCard:
	"""替换旧卡片：重新录制 -> 覆盖 -> 弟子开始学新版本"""
	if cards.has(card_id):
		cards.erase(card_id)

	var new_card = add_card(new_demo_data)
	new_card.card_id = card_id  # 保持原ID
	cards[card_id] = new_card
	return new_card


# ========== 查 ==========

func get_card(card_id: String) -> DemonstrationCard:
	return cards.get(card_id)


func get_cards_by_category(category: String) -> Array:
	var result = []
	for card in cards.values():
		if card.category == category:
			result.append(card)
	return result


func get_all_cards() -> Array:
	return cards.values()


func get_card_count() -> int:
	return cards.size()


# ========== 内部 ==========

func _infer_skill_name(demo_data: Dictionary) -> String:
	"""根据示范数据中的动作推断技能名称"""
	var frames = demo_data.get("frames", [])
	var states_seen = {}
	for frame in frames:
		var state = frame.get("current_state", "")
		if state:
			states_seen[state] = states_seen.get(state, 0) + 1

	if states_seen.is_empty():
		return "未知示范"

	# 找到出现最多的状态
	var max_state = ""
	var max_count = 0
	for state in states_seen:
		if states_seen[state] > max_count:
			max_count = states_seen[state]
			max_state = state

	var state_name_map = {
		"run": "跑步", "jump": "跳跃", "slide": "滑铲",
		"crouch": "蹲下", "climb": "攀爬翻越", "fall": "空翻",
		"attack": "挥剑攻击", "block": "格挡", "dodge": "闪避",
		"air_attack": "空中攻击",
	}
	return state_name_map.get(max_state, max_state)


func to_save_data() -> Array:
	var result = []
	for card in cards.values():
		result.append(card.to_dict())
	return result


func load_from_save_data(data: Array) -> void:
	cards.clear()
	for card_data in data:
		var card = DemonstrationCard.from_dict(card_data)
		cards[card.card_id] = card


## 示范卡片数据结构
class DemonstrationCard:
	var card_id: String = ""
	var skill_name: String = ""
	var category: String = ""      # parkour / combat / mixed
	var duration: float = 0.0
	var practice_count: int = 0
	var quality_score: int = 1     # 1-5 星
	var quality_detail: Dictionary = {}
	var frame_data: Array = []
	var created_at: String = ""

	func to_dict() -> Dictionary:
		return {
			"card_id": card_id,
			"skill_name": skill_name,
			"category": category,
			"duration": duration,
			"practice_count": practice_count,
			"quality_score": quality_score,
			"quality_detail": quality_detail,
			"created_at": created_at,
			# frame_data 单独存储以减小存档主文件大小
		}

	static func from_dict(data: Dictionary) -> DemonstrationCard:
		var card = DemonstrationCard.new()
		card.card_id = data.get("card_id", "")
		card.skill_name = data.get("skill_name", "")
		card.category = data.get("category", "mixed")
		card.duration = data.get("duration", 0.0)
		card.practice_count = data.get("practice_count", 0)
		card.quality_score = data.get("quality_score", 1)
		card.quality_detail = data.get("quality_detail", {})
		card.created_at = data.get("created_at", "")
		return card
