## 训练营主基地 - 所有系统入口，随弟子成长变化
## GDD区域：训练场地、典籍架、兵器架、商铺、升级台、弟子档案、荣誉台
extends Control

@onready var disciple_display: ColorRect = $Background/DiscipleDisplay
@onready var disciple_name_label: Label = $Background/DiscipleInfo/NameLabel
@onready var disciple_stage_label: Label = $Background/DiscipleInfo/StageLabel
@onready var exp_label: Label = $TopBar/ExpLabel

# 区域按钮
@onready var training_btn: Button = $Areas/TrainingBtn
@onready var backpack_btn: Button = $Areas/BackpackBtn
@onready var armory_btn: Button = $Areas/ArmoryBtn
@onready var shop_btn: Button = $Areas/ShopBtn
@onready var upgrade_btn: Button = $Areas/UpgradeBtn
@onready var profile_btn: Button = $Areas/ProfileBtn
@onready var honor_btn: Button = $Areas/HonorBtn
@onready var retire_btn: Button = $Areas/RetireBtn

@onready var world_select_panel: PanelContainer = $WorldSelectPanel


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.TRAINING_CAMP)

	training_btn.pressed.connect(_on_training)
	backpack_btn.pressed.connect(_on_backpack)
	armory_btn.pressed.connect(_on_armory)
	shop_btn.pressed.connect(_on_shop)
	upgrade_btn.pressed.connect(_on_upgrade)
	profile_btn.pressed.connect(_on_profile)
	honor_btn.pressed.connect(_on_honor)
	retire_btn.pressed.connect(_on_retire)

	world_select_panel.visible = false

	EventBus.exp_points_changed.connect(func(v): _update_exp())
	EventBus.disciple_color_changed.connect(func(_c): _update_disciple_display())

	_update_disciple_display()
	_update_exp()
	AudioManager.play_music("training_camp")


func _update_disciple_display() -> void:
	var d = GameManager.active_disciple
	if d == null:
		return

	disciple_name_label.text = d.disciple_name
	disciple_stage_label.text = "%s | %s" % [
		_get_stage_text(d.color_value),
		GameManager.TALENT_DATA[d.talent]["name"]
	]

	# 弟子颜色
	if disciple_display:
		var t = d.color_value
		var dark = Color(0.1, 0.1, 0.12)
		var mid = Color(0.45, 0.47, 0.5)
		var bright = Color(0.88, 0.9, 0.95)
		if t < 0.5:
			disciple_display.color = dark.lerp(mid, t * 2.0)
		else:
			disciple_display.color = mid.lerp(bright, (t - 0.5) * 2.0)


func _get_stage_text(color_value: float) -> String:
	if color_value < 0.15: return "初创期"
	elif color_value < 0.3: return "入门期"
	elif color_value < 0.55: return "成长期"
	elif color_value < 0.8: return "熟练期"
	else: return "精通期"


func _update_exp() -> void:
	if exp_label:
		exp_label.text = "经验点: %d" % GameManager.exp_points


# ========== 区域入口 ==========

func _safe_change_scene(path: String) -> void:
	"""带存在性检查的场景切换——防止 .tscn 缺失时崩溃"""
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		EventBus.message_requested.emit("该功能场景开发中…", 2.0)


func _on_training() -> void:
	_show_world_select()


func _on_backpack() -> void:
	_safe_change_scene("res://scenes/ui/training_backpack_ui.tscn")


func _on_armory() -> void:
	_safe_change_scene("res://scenes/ui/armory_ui.tscn")


func _on_shop() -> void:
	_safe_change_scene("res://scenes/ui/shop_ui.tscn")


func _on_upgrade() -> void:
	_safe_change_scene("res://scenes/ui/upgrade_ui.tscn")


func _on_profile() -> void:
	_safe_change_scene("res://scenes/ui/disciple_profile.tscn")


func _on_honor() -> void:
	_safe_change_scene("res://scenes/ui/honor_hall.tscn")


func _on_retire() -> void:
	if GameManager.active_disciple == null:
		return
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "确定要让 %s 退休吗？\n退休后将无法继续训练，但会永久陈列在荣誉台。" % \
		GameManager.active_disciple.disciple_name
	dialog.confirmed.connect(func():
		# 二次防护：对话弹出后到确认前 active_disciple 可能已被清空
		if GameManager.active_disciple:
			GameManager.retire_disciple()
			SaveManager.auto_save()
		_safe_change_scene("res://scenes/ui/disciple_creation.tscn")
	)
	add_child(dialog)
	dialog.popup_centered()


func _show_world_select() -> void:
	world_select_panel.visible = true
	var container = world_select_panel.get_node("VBox")

	# 立即释放所有旧子节点（free() 而非 queue_free()，避免同帧重复打开时旧节点未清除）
	for child in container.get_children():
		child.free()

	# 世界列表
	var worlds = [
		{"id": "world_1", "name": "山林道场", "desc": "基础跑酷 + 近战入门"},
		{"id": "world_2", "name": "废弃城镇", "desc": "复杂地形跑酷 + 弓箭敌人"},
		{"id": "world_3", "name": "地下熔岩", "desc": "极限跑酷 + 高伤害敌人"},
		{"id": "world_4", "name": "天空要塞", "desc": "综合全部技能"},
	]

	for world in worlds:
		var btn = Button.new()
		var unlocked = world["id"] in GameManager.unlocked_worlds
		btn.text = "%s - %s" % [world["name"], world["desc"]]
		btn.disabled = not unlocked
		if not unlocked:
			btn.text += " [未解锁]"
		var wid = world["id"]
		btn.pressed.connect(func(): _enter_world(wid))
		container.add_child(btn)

	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(func(): world_select_panel.visible = false)
	container.add_child(back_btn)


func _enter_world(world_id: String) -> void:
	world_select_panel.visible = false
	var scene_path = "res://scenes/levels/%s/level_select.tscn" % world_id
	_safe_change_scene(scene_path)
