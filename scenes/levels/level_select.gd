## 关卡选择界面 - 每个世界内的关卡列表
## GDD关卡类型: 跑酷关卡 -> 战斗关卡 -> 混合关卡 -> 拆招训练关 -> Boss关卡
extends Control

@export var world_id: String = "world_1"

@onready var world_title: Label = $VBox/WorldTitle
@onready var level_list: VBoxContainer = $VBox/ScrollContainer/LevelList
@onready var back_btn: Button = $TopBar/BackBtn

# 世界数据
const WORLDS = {
	"world_1": {
		"name": "山林道场",
		"theme": "树林、木桩、低矮障碍",
		"levels": [
			{"id": "w1_parkour_1", "name": "林间小径", "type": "跑酷关卡", "desc": "基础跑酷入门"},
			{"id": "w1_parkour_2", "name": "木桩阵", "type": "跑酷关卡", "desc": "跳跃与蹲下"},
			{"id": "w1_combat_1", "name": "巡逻遭遇", "type": "战斗关卡", "desc": "近战入门"},
			{"id": "w1_mixed_1", "name": "密林穿越", "type": "混合关卡", "desc": "跑酷与战斗交叉"},
			{"id": "w1_boss_train", "name": "拆招训练", "type": "拆招训练关", "desc": "学习道场守护者的攻击模式"},
			{"id": "w1_boss", "name": "道场守护者", "type": "Boss关卡", "desc": "第一世界Boss"},
		]
	},
	"world_2": {
		"name": "废弃城镇",
		"theme": "坍塌建筑、高低落差",
		"levels": [
			{"id": "w2_parkour_1", "name": "废墟跑酷", "type": "跑酷关卡", "desc": "高低落差跑酷"},
			{"id": "w2_parkour_2", "name": "楼顶穿梭", "type": "跑酷关卡", "desc": "攀爬翻越训练"},
			{"id": "w2_combat_1", "name": "弓箭手巷", "type": "战斗关卡", "desc": "躲避远程攻击"},
			{"id": "w2_mixed_1", "name": "城镇突围", "type": "混合关卡", "desc": "复杂地形综合战斗"},
			{"id": "w2_boss_train", "name": "拆招训练", "type": "拆招训练关", "desc": "学习城镇霸主的射击模式"},
			{"id": "w2_boss", "name": "城镇霸主", "type": "Boss关卡", "desc": "第二世界Boss"},
		]
	},
	"world_3": {
		"name": "地下熔岩",
		"theme": "移动平台、岩浆地形",
		"levels": [
			{"id": "w3_parkour_1", "name": "熔岩跳台", "type": "跑酷关卡", "desc": "移动平台挑战"},
			{"id": "w3_parkour_2", "name": "岩浆裂谷", "type": "跑酷关卡", "desc": "极限跑酷"},
			{"id": "w3_combat_1", "name": "高温炼狱", "type": "战斗关卡", "desc": "高伤害敌人"},
			{"id": "w3_mixed_1", "name": "深渊突进", "type": "混合关卡", "desc": "移动平台+战斗"},
			{"id": "w3_boss_train", "name": "拆招训练", "type": "拆招训练关", "desc": "学习熔岩巨兽的行为"},
			{"id": "w3_boss", "name": "熔岩巨兽", "type": "Boss关卡", "desc": "第三世界Boss"},
		]
	},
	"world_4": {
		"name": "天空要塞",
		"theme": "浮空平台、强风干扰",
		"levels": [
			{"id": "w4_parkour_1", "name": "浮空之路", "type": "跑酷关卡", "desc": "浮空平台跑酷"},
			{"id": "w4_parkour_2", "name": "风暴走廊", "type": "跑酷关卡", "desc": "强风环境挑战"},
			{"id": "w4_combat_1", "name": "要塞先锋", "type": "战斗关卡", "desc": "精英敌人"},
			{"id": "w4_mixed_1", "name": "登顶之战", "type": "混合关卡", "desc": "全技能综合考验"},
			{"id": "w4_boss_train", "name": "拆招训练", "type": "拆招训练关", "desc": "学习要塞指挥官的指挥模式"},
			{"id": "w4_boss", "name": "要塞指挥官", "type": "Boss关卡", "desc": "最终Boss"},
		]
	},
}


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn"))
	_populate_levels()


func _populate_levels() -> void:
	var world = WORLDS.get(world_id, {})
	if world.is_empty():
		return

	world_title.text = "%s - %s" % [world["name"], world["theme"]]

	for child in level_list.get_children():
		child.queue_free()

	var levels = world.get("levels", [])
	var prev_completed = true

	for level in levels:
		var is_completed = level["id"] in GameManager.completed_levels

		# 解锁逻辑：前一关完成后解锁下一关（跑酷关卡默认开放）
		var is_unlocked = prev_completed or level["type"] == "跑酷关卡"

		var hbox = HBoxContainer.new()

		# 状态图标
		var status_label = Label.new()
		if is_completed:
			status_label.text = "[V]"
		elif is_unlocked:
			status_label.text = "[ ]"
		else:
			status_label.text = "[X]"
		status_label.custom_minimum_size.x = 40
		hbox.add_child(status_label)

		# 关卡按钮
		var btn = Button.new()
		btn.text = "%s (%s) - %s" % [level["name"], level["type"], level["desc"]]
		btn.disabled = not is_unlocked
		btn.custom_minimum_size.x = 500
		var lid = level["id"]
		btn.pressed.connect(func(): _enter_level(lid))
		hbox.add_child(btn)

		level_list.add_child(hbox)
		prev_completed = is_completed


func _enter_level(level_id: String) -> void:
	# 尝试加载对应关卡场景
	var scene_path = "res://scenes/levels/%s/%s.tscn" % [world_id, level_id]
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		EventBus.message_requested.emit("关卡场景开发中...", 2.0)
