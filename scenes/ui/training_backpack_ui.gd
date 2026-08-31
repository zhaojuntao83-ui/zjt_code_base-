## 训练背包UI - 示范卡片管理界面
## GDD: 卡片视觉化，分类标签，支持回放/替换/删除
extends Control

@onready var category_tabs: TabContainer = $HSplit/Left/CategoryTabs
@onready var card_detail: VBoxContainer = $HSplit/Right/CardDetail
@onready var replay_btn: Button = $HSplit/Right/Actions/ReplayBtn
@onready var replace_btn: Button = $HSplit/Right/Actions/ReplaceBtn
@onready var delete_btn: Button = $HSplit/Right/Actions/DeleteBtn
@onready var back_btn: Button = $TopBar/BackBtn

var backpack: TrainingBackpack
var selected_card_id: String = ""

# 动态添加的"开始训练"按钮（场景 Actions 容器中没有对应 tscn 节点）
var train_btn: Button


func _ready() -> void:
	backpack = GameManager.training_backpack
	back_btn.pressed.connect(_go_back)
	replay_btn.pressed.connect(_replay_card)
	replace_btn.pressed.connect(_replace_card)
	delete_btn.pressed.connect(_delete_card)

	# 动态插入"开始训练"按钮（放在其他操作按钮同一容器）
	train_btn = Button.new()
	train_btn.text = "开始训练"
	train_btn.disabled = true
	train_btn.pressed.connect(_start_training)
	$HSplit/Right/Actions.add_child(train_btn)

	_populate_tabs()
	_clear_detail()


func _populate_tabs() -> void:
	# 清除旧标签页，避免多次调用时内容累积
	for child in category_tabs.get_children():
		child.queue_free()

	# 为每个分类创建卡片列表
	for category_key in TrainingBackpack.CATEGORIES:
		var scroll = ScrollContainer.new()
		scroll.name = TrainingBackpack.CATEGORIES[category_key]
		var vbox = VBoxContainer.new()
		vbox.name = "CardList"
		scroll.add_child(vbox)
		category_tabs.add_child(scroll)

		var cards = backpack.get_cards_by_category(category_key)
		for card in cards:
			var btn = Button.new()
			btn.text = "%s  %s  %s" % [
				card.skill_name,
				_stars(card.quality_score),
				"(练习%d次)" % card.practice_count
			]
			var cid = card.card_id
			btn.pressed.connect(func(): _select_card(cid))
			vbox.add_child(btn)

		if cards.is_empty():
			var label = Label.new()
			label.text = "暂无卡片"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(label)


func _select_card(card_id: String) -> void:
	selected_card_id = card_id
	var card = backpack.get_card(card_id)
	if card == null:
		_clear_detail()
		return

	# 清空详情区域
	for child in card_detail.get_children():
		child.queue_free()

	# 技能名称
	var name_label = Label.new()
	name_label.text = card.skill_name
	name_label.add_theme_font_size_override("font_size", 24)
	card_detail.add_child(name_label)

	# 质量评分
	var quality_label = Label.new()
	quality_label.text = "质量: %s" % _stars(card.quality_score)
	card_detail.add_child(quality_label)

	# 时长
	var dur_label = Label.new()
	dur_label.text = "示范时长: %.1f秒" % card.duration
	card_detail.add_child(dur_label)

	# 练习次数
	var practice_label = Label.new()
	practice_label.text = "练习次数: %d" % card.practice_count
	card_detail.add_child(practice_label)

	# 质量详情
	if card.quality_detail:
		var detail_label = Label.new()
		detail_label.text = "完整度:%s  流畅度:%s  多样性:%s" % [
			_stars(card.quality_detail.get("completeness", 0)),
			_stars(card.quality_detail.get("fluency", 0)),
			_stars(card.quality_detail.get("diversity", 0)),
		]
		card_detail.add_child(detail_label)

	# 创建时间
	var time_label = Label.new()
	time_label.text = "录制于: %s" % card.created_at
	card_detail.add_child(time_label)

	# 启用操作按钮
	replay_btn.disabled = false
	replace_btn.disabled = false
	delete_btn.disabled = false
	if train_btn:
		train_btn.disabled = false


func _clear_detail() -> void:
	for child in card_detail.get_children():
		child.queue_free()
	var hint = Label.new()
	hint.text = "选择一张卡片查看详情"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_detail.add_child(hint)
	replay_btn.disabled = true
	replace_btn.disabled = true
	delete_btn.disabled = true
	if train_btn:
		train_btn.disabled = true


func _replay_card() -> void:
	if selected_card_id.is_empty():
		return
	var card = backpack.get_card(selected_card_id)
	if card == null:
		return

	# 统计帧中的动作分布，作为「回放分析」展示给玩家
	var state_counts: Dictionary = {}
	for frame in card.frame_data:
		var state = frame.get("current_state", "（未知）")
		if state != "":
			state_counts[state] = state_counts.get(state, 0) + 1

	var total = card.frame_data.size()
	var text = "=== 示范回放分析 ===\n"
	text += "技能: %s  |  时长: %.1f 秒  |  帧数: %d\n\n" % [card.skill_name, card.duration, total]
	text += "动作分布:\n"

	if total > 0:
		var sorted_states = state_counts.keys()
		sorted_states.sort_custom(func(a, b): return state_counts[a] > state_counts[b])
		for s in sorted_states:
			var pct = int(float(state_counts[s]) / total * 100.0)
			text += "  %s: %d%%\n" % [s, pct]
	else:
		text += "  （无帧数据，该卡片可能由接管录制或旧版存档生成）\n"

	var dialog = AcceptDialog.new()
	dialog.title = "示范回放"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


func _replace_card() -> void:
	if selected_card_id.is_empty():
		return
	# 将替换目标存入全局增益字典，进入训练营后玩家选择关卡录制
	GameManager.active_consumable_buffs["replace_card_id"] = selected_card_id
	EventBus.message_requested.emit("进入关卡后开始录制，新示范将自动替换当前卡片", 3.5)
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")


func _delete_card() -> void:
	if selected_card_id.is_empty():
		return

	if backpack.is_high_risk_delete(selected_card_id):
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "该卡片已被练习超过100次，删除后弟子可能会慢慢遗忘相关技能。\n确定删除吗？"
		dialog.confirmed.connect(func():
			backpack.remove_card(selected_card_id)
			selected_card_id = ""
			_clear_detail()
			_populate_tabs()
		)
		add_child(dialog)
		dialog.popup_centered()
	else:
		backpack.remove_card(selected_card_id)
		selected_card_id = ""
		_clear_detail()
		_populate_tabs()


func _stars(count: int) -> String:
	var s = ""
	for i in range(5):
		s += "*" if i < count else "-"
	return s


func _start_training() -> void:
	if selected_card_id.is_empty():
		return
	GameManager.active_training_card_id = selected_card_id
	var path = "res://scenes/ui/training_view.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		EventBus.message_requested.emit("训练界面场景开发中...", 2.0)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")
