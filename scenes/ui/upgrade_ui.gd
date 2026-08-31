## 接管升级界面（升级台）
## GDD: 三条独立升级线互相竞争点数：次数线、时长线、冷却线
extends Control

@onready var exp_label: Label = $TopBar/ExpLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var lines_container: VBoxContainer = $VBox/Lines

# 升级线定义
const UPGRADE_LINES = [
	{
		"key": "charges",
		"name": "次数线",
		"icon": "^",
		"desc": "增加每场接管次数",
		"base": 3,
		"per_level": 1,
		"max_level": 7,
		"unit": "次/场",
		"cost_base": 100,
		"cost_per_level": 50,
	},
	{
		"key": "duration",
		"name": "时长线",
		"icon": ">",
		"desc": "延长每次接管时长",
		"base": 3.0,
		"per_level": 2.0,
		"max_level": 6,
		"unit": "秒/次",
		"cost_base": 120,
		"cost_per_level": 60,
	},
	{
		"key": "cooldown",
		"name": "冷却线",
		"icon": "!",
		"desc": "缩短接管冷却时间",
		"base": 30.0,
		"per_level": -5.0,
		"max_level": 5,
		"unit": "秒",
		"cost_base": 150,
		"cost_per_level": 80,
	},
]


func _ready() -> void:
	back_btn.pressed.connect(func():
		var p = "res://scenes/ui/training_camp.tscn"
		if ResourceLoader.exists(p): get_tree().change_scene_to_file(p)
	)
	EventBus.exp_points_changed.connect(func(_v): _refresh())
	_refresh()


func _refresh() -> void:
	exp_label.text = "经验点: %d" % GameManager.exp_points

	# 使用 free() 立即释放，避免 queue_free 延迟导致同帧节点累积
	for child in lines_container.get_children():
		child.free()

	for line in UPGRADE_LINES:
		var current_level = _get_level(line["key"])
		var max_level = line["max_level"]
		var current_value = line["base"] + current_level * line["per_level"]
		var next_value = line["base"] + (current_level + 1) * line["per_level"]
		var cost = line["cost_base"] + current_level * line["cost_per_level"]
		var is_maxed = current_level >= max_level

		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)

		# 名称和说明
		var info_vbox = VBoxContainer.new()
		info_vbox.custom_minimum_size.x = 200
		var name_label = Label.new()
		name_label.text = "%s %s" % [line["icon"], line["name"]]
		name_label.add_theme_font_size_override("font_size", 18)
		info_vbox.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = line["desc"]
		info_vbox.add_child(desc_label)
		hbox.add_child(info_vbox)

		# 当前值
		var value_label = Label.new()
		value_label.text = "Lv.%d  当前: %.0f%s" % [current_level, current_value, line["unit"]]
		value_label.custom_minimum_size.x = 180
		hbox.add_child(value_label)

		# 升级按钮
		var btn = Button.new()
		if is_maxed:
			btn.text = "已满级"
			btn.disabled = true
		else:
			btn.text = "升级 -> %.0f%s (%d点)" % [next_value, line["unit"], cost]
			btn.disabled = GameManager.exp_points < cost
			var lkey = line["key"]
			var lcost = cost
			btn.pressed.connect(func(): _upgrade(lkey, lcost))
		hbox.add_child(btn)

		lines_container.add_child(panel)


func _get_level(key: String) -> int:
	match key:
		"charges": return GameManager.takeover_charges_level
		"duration": return GameManager.takeover_duration_level
		"cooldown": return GameManager.takeover_cooldown_level
	return 0


func _upgrade(key: String, cost: int) -> void:
	# 防止快速双击在按钮 disabled 状态刷新前超出满级
	for line in UPGRADE_LINES:
		if line["key"] == key and _get_level(key) >= line["max_level"]:
			return

	if not GameManager.spend_exp(cost):
		return

	match key:
		"charges": GameManager.takeover_charges_level += 1
		"duration": GameManager.takeover_duration_level += 1
		"cooldown": GameManager.takeover_cooldown_level += 1

	SaveManager.auto_save()
	_refresh()
