## 弟子档案界面 - 查看成长属性、颜色历史、天赋
## GDD: 成长属性雷达图、颜色历史、记录完整成长轨迹
extends Control

@onready var name_label: Label = $VBox/NameLabel
@onready var talent_label: Label = $VBox/TalentLabel
@onready var stage_label: Label = $VBox/StageLabel
@onready var color_display: ColorRect = $VBox/ColorDisplay
@onready var stats_container: VBoxContainer = $VBox/Stats
@onready var history_container: VBoxContainer = $VBox/History
@onready var back_btn: Button = $TopBar/BackBtn


func _ready() -> void:
	back_btn.pressed.connect(func():
		var p = "res://scenes/ui/training_camp.tscn"
		if ResourceLoader.exists(p): get_tree().change_scene_to_file(p)
	)
	_display_profile()


func _display_profile() -> void:
	var d = GameManager.active_disciple
	if d == null:
		name_label.text = "无活跃弟子"
		return

	name_label.text = d.disciple_name
	talent_label.text = "天赋: %s" % GameManager.TALENT_DATA[d.talent]["name"]

	# 成长阶段
	var stage = _get_stage(d.color_value)
	stage_label.text = "阶段: %s (%.0f%%)" % [stage, d.color_value * 100]

	# 颜色
	if color_display:
		var dark = Color(0.1, 0.1, 0.12)
		var mid = Color(0.45, 0.47, 0.5)
		var bright = Color(0.88, 0.9, 0.95)
		if d.color_value < 0.5:
			color_display.color = dark.lerp(mid, d.color_value * 2.0)
		else:
			color_display.color = mid.lerp(bright, (d.color_value - 0.5) * 2.0)

	# 属性列表
	for child in stats_container.get_children():
		child.free()

	var stats = [
		["体力", d.health, 200.0],
		["攻击力", d.attack_power, 50.0],
		["学习力", d.learning_ability, 3.0],
		["反应速度", d.reaction_speed, 1.0],
		["耐力", d.endurance, 1.0],
	]

	for stat in stats:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = "%s:" % stat[0]
		label.custom_minimum_size.x = 80
		hbox.add_child(label)

		var bar = ProgressBar.new()
		bar.max_value = stat[2]
		bar.value = stat[1]
		bar.custom_minimum_size.x = 200
		hbox.add_child(bar)

		var val_label = Label.new()
		val_label.text = "%.1f" % stat[1]
		hbox.add_child(val_label)

		stats_container.add_child(hbox)

	# 训练统计
	var total_label = Label.new()
	total_label.text = "训练统计: %d次迭代 | %d次成功 | %d次失败" % [
		d.total_training_iterations, d.total_successes, d.total_failures
	]
	stats_container.add_child(total_label)

	# 已学动作
	if not d.learned_actions.is_empty():
		var actions_label = Label.new()
		actions_label.text = "已学动作: %s" % ", ".join(d.learned_actions)
		actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_container.add_child(actions_label)

	# 击败Boss
	if not d.bosses_defeated.is_empty():
		var boss_label = Label.new()
		boss_label.text = "击败Boss: %s" % ", ".join(d.bosses_defeated)
		stats_container.add_child(boss_label)

	# 训练风格历史
	for child in history_container.get_children():
		child.free()

	var style_title = Label.new()
	style_title.text = "训练风格"
	style_title.add_theme_font_size_override("font_size", 16)
	history_container.add_child(style_title)

	var style_scores: Dictionary = d.training_style_scores if d.get("training_style_scores") != null else {}
	if style_scores.is_empty():
		var no_style = Label.new()
		no_style.text = "暂无训练记录"
		history_container.add_child(no_style)
	else:
		for style in style_scores:
			var hbox = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = style
			lbl.custom_minimum_size.x = 140
			hbox.add_child(lbl)
			var bar = ProgressBar.new()
			bar.max_value = 100
			bar.value = minf(style_scores[style], 100.0)
			bar.custom_minimum_size.x = 160
			hbox.add_child(bar)
			var score_lbl = Label.new()
			score_lbl.text = "%.0f" % style_scores[style]
			hbox.add_child(score_lbl)
			history_container.add_child(hbox)

	# 训练卡片数量
	var card_count = GameManager.training_backpack.get_card_count() if GameManager.training_backpack else 0
	var card_label = Label.new()
	card_label.text = "当前训练卡: %d 张" % card_count
	history_container.add_child(card_label)


func _get_stage(color_value: float) -> String:
	if color_value < 0.15: return "初创期"
	elif color_value < 0.3: return "入门期"
	elif color_value < 0.55: return "成长期"
	elif color_value < 0.8: return "熟练期"
	else: return "精通期"
