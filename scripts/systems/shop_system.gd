## 商店系统 - 只有一种货币（经验点数），所有消费共用
## GDD: 每分点数都有多种用途，玩家需要根据需求做取舍
class_name ShopSystem
extends Node

# 商品目录
var catalog: Dictionary = {}


func _ready() -> void:
	_init_catalog()


func _init_catalog() -> void:
	# 武器
	_add_item("wooden_sword", "木剑", "weapon", 0, "剑族入门武器，平衡可靠")
	_add_item("iron_sword", "铁剑", "weapon", 150, "剑族标准武器，攻速与伤害兼顾")
	_add_item("steel_blade", "钢刀", "weapon", 300, "剑族高级武器")
	_add_item("katana", "武士刀", "weapon", 500, "剑族顶级武器")
	_add_item("long_spear", "长枪", "weapon", 200, "枪族武器，长距离刺击")
	_add_item("pike", "刺枪", "weapon", 350, "枪族高级武器")
	_add_item("halberd", "战戟", "weapon", 550, "枪族顶级武器")
	_add_item("short_bow", "短弓", "weapon", 200, "弓族入门，远程攻击")
	_add_item("long_bow", "长弓", "weapon", 400, "弓族高级，射程更远")
	_add_item("crossbow", "十字弓", "weapon", 600, "弓族顶级武器")
	_add_item("dual_daggers", "双匕首", "weapon", 180, "双刀族入门，攻速极快")
	_add_item("dual_swords", "双刀", "weapon", 380, "双刀族高级武器")
	_add_item("claws", "爪刃", "weapon", 550, "双刀族顶级武器")
	_add_item("greatsword", "大剑", "weapon", 250, "重武器族，蓄力重击")
	_add_item("battle_axe", "战斧", "weapon", 450, "重武器族高级")
	_add_item("war_hammer", "巨锤", "weapon", 650, "重武器族顶级，一击重创")

	# 护甲
	_add_item("light_armor", "轻甲", "armor", 100, "微量防御，不影响移动速度")
	_add_item("medium_armor", "中甲", "armor", 250, "中等防御，速度略降")
	_add_item("heavy_armor", "重甲", "armor", 450, "高防御，移动较慢")

	# 消耗品
	_add_item("focus_potion", "专注药剂", "consumable", 80, "弟子学习速度提升50%，持续一次训练")
	_add_item("enhance_scroll", "强化卷轴", "consumable", 60, "弟子攻击力临时提升，持续一次训练")
	_add_item("tenacity_charm", "韧性护符", "consumable", 100, "弟子受击后不打断动作，持续一次训练")
	_add_item("memory_crystal", "记忆晶石", "consumable", 120, "本次示范数据权重翻倍，持续一次录制")

	# 接管道具
	_add_item("takeover_token_s", "接管令牌(小)", "takeover_item", 50, "本场训练 +1次接管")
	_add_item("takeover_token_l", "接管令牌(大)", "takeover_item", 130, "本场训练 +3次接管")

	# 训练道具
	_add_item("training_manual", "训练手册", "training_item", 70, "本场训练迭代次数 x1.5")
	_add_item("demo_magnifier", "示范放大镜", "training_item", 90, "AI对本次示范的模仿精度提升")
	_add_item("forget_cleanser", "遗忘清除剂", "training_item", 150, "清除弟子某张卡片的错误记忆重新学")


func _add_item(id: String, name: String, category: String, price: int, description: String) -> void:
	catalog[id] = {
		"id": id,
		"name": name,
		"category": category,
		"price": price,
		"description": description,
	}


func get_items_by_category(category: String) -> Array:
	var items = []
	for item in catalog.values():
		if item["category"] == category:
			items.append(item)
	items.sort_custom(func(a, b): return a["price"] < b["price"])
	return items


func can_afford(item_id: String) -> bool:
	if not catalog.has(item_id):
		return false
	return GameManager.exp_points >= catalog[item_id]["price"]


func purchase(item_id: String) -> bool:
	"""购买商品"""
	if not catalog.has(item_id):
		return false

	var item = catalog[item_id]
	if not GameManager.spend_exp(item["price"]):
		return false

	match item["category"]:
		"weapon":
			if item_id not in GameManager.owned_weapons:
				GameManager.owned_weapons.append(item_id)
		"armor":
			if item_id not in GameManager.owned_armor:
				GameManager.owned_armor.append(item_id)
		"consumable", "takeover_item", "training_item":
			GameManager.owned_consumables[item_id] = GameManager.owned_consumables.get(item_id, 0) + 1

	EventBus.item_purchased.emit(item_id)
	SaveManager.auto_save()
	return true


func use_consumable(item_id: String) -> bool:
	"""使用消耗品并激活对应的临时增益效果"""
	var count = GameManager.owned_consumables.get(item_id, 0)
	if count <= 0:
		return false

	GameManager.owned_consumables[item_id] = count - 1
	if GameManager.owned_consumables[item_id] <= 0:
		GameManager.owned_consumables.erase(item_id)

	# 激活实际的增益效果
	GameManager.apply_consumable_buff(item_id)

	var item = catalog.get(item_id, {})
	var msg = "使用了 %s" % item.get("name", item_id)
	EventBus.message_requested.emit(msg, 2.0)
	return true


func is_owned(item_id: String) -> bool:
	"""检查装备类物品是否已拥有"""
	return item_id in GameManager.owned_weapons or item_id in GameManager.owned_armor


func get_item_info(item_id: String) -> Dictionary:
	return catalog.get(item_id, {})
