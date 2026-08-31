## 荣誉台界面 - 退休弟子永久陈列展示
## GDD: 深色、浅色的机器人并排站着，就是完整的培养历史
extends Control

@onready var hall_container: HBoxContainer = $ScrollContainer/HallContainer
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var back_btn: Button = $TopBar/BackBtn


func _ready() -> void:
	back_btn.pressed.connect(func():
		var p = "res://scenes/ui/training_camp.tscn"
		if ResourceLoader.exists(p): get_tree().change_scene_to_file(p)
	)
	detail_panel.visible = false
	_display_retired_disciples()


func _display_retired_disciples() -> void:
	for child in hall_container.get_children():
		child.free()

	if GameManager.retired_disciples.is_empty():
		var label = Label.new()
		label.text = "荣誉台空空如也\n培养并退休一个弟子后，他将永远陈列于此"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hall_container.add_child(label)
		return

	for i in range(GameManager.retired_disciples.size()):
		var d = GameManager.retired_disciples[i]
		var pedestal = _create_pedestal(d, i)
		hall_container.add_child(pedestal)


func _create_pedestal(disciple: DiscipleData, index: int) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(120, 200)
	vbox.alignment = BoxContainer.ALIGNMENT_END

	# 弟子颜色展示
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(80, 100)
	var t = disciple.color_value
	var dark = Color(0.1, 0.1, 0.12)
	var mid = Color(0.45, 0.47, 0.5)
	var bright = Color(0.88, 0.9, 0.95)
	if t < 0.5:
		color_rect.color = dark.lerp(mid, t * 2.0)
	else:
		color_rect.color = mid.lerp(bright, (t - 0.5) * 2.0)
	vbox.add_child(color_rect)

	# 名字
	var name_label = Label.new()
	name_label.text = disciple.disciple_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 成长阶段
	var stage_label = Label.new()
	stage_label.text = _get_stage(disciple.color_value)
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stage_label)

	# 点击查看详情
	var btn = Button.new()
	btn.text = "查看"
	var idx = index
	btn.pressed.connect(func(): _show_detail(idx))
	vbox.add_child(btn)

	return vbox


func _show_detail(index: int) -> void:
	if index >= GameManager.retired_disciples.size():
		return

	var d = GameManager.retired_disciples[index]
	detail_panel.visible = true

	var vbox = detail_panel.get_node_or_null("VBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		child.free()

	var labels = [
		"名字: %s" % d.disciple_name,
		"天赋: %s" % GameManager.TALENT_DATA[d.talent]["name"],
		"最终阶段: %s" % _get_stage(d.color_value),
		"训练次数: %d" % d.total_training_iterations,
		"成功次数: %d" % d.total_successes,
		"击败Boss: %s" % (", ".join(d.bosses_defeated) if not d.bosses_defeated.is_empty() else "无"),
	]

	for text in labels:
		var label = Label.new()
		label.text = text
		vbox.add_child(label)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(func(): detail_panel.visible = false)
	vbox.add_child(close_btn)


func _get_stage(cv: float) -> String:
	if cv < 0.15: return "初创期"
	elif cv < 0.3: return "入门期"
	elif cv < 0.55: return "成长期"
	elif cv < 0.8: return "熟练期"
	else: return "精通期"
