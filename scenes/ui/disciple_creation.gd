## 弟子创建界面（铸造台）
## GDD: 只需决定两件事：名字和先天天赋，外观由成长驱动
extends Control

@onready var name_input: LineEdit = $VBox/NameInput
@onready var talent_buttons: VBoxContainer = $VBox/TalentList
@onready var talent_desc: Label = $VBox/TalentDesc
@onready var confirm_btn: Button = $VBox/ConfirmBtn
@onready var preview_sprite: ColorRect = $Preview/DisciplePreview

var selected_talent: GameManager.Talent = GameManager.Talent.ALL_ROUNDER


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true
	name_input.text_changed.connect(_on_name_changed)

	_create_talent_buttons()
	_update_preview()

	# 返回主菜单按钮
	var back_btn = Button.new()
	back_btn.text = "返回主菜单"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	$VBox.add_child(back_btn)

	# 触发新手引导第一步（如未完成）
	if GameManager.tutorial_system:
		GameManager.tutorial_system.show_step("create_disciple")


func _create_talent_buttons() -> void:
	for talent_enum in GameManager.TALENT_DATA:
		var data = GameManager.TALENT_DATA[talent_enum]
		var btn = Button.new()
		btn.text = "%s - %s" % [data["name"], data["description"]]
		btn.toggle_mode = true
		var t = talent_enum
		btn.pressed.connect(func(): _select_talent(t))
		talent_buttons.add_child(btn)

		# 默认选中全能学徒
		if talent_enum == GameManager.Talent.ALL_ROUNDER:
			btn.button_pressed = true


func _select_talent(talent: GameManager.Talent) -> void:
	selected_talent = talent
	var data = GameManager.TALENT_DATA.get(talent, {})
	talent_desc.text = data.get("description", "")

	# 更新所有天赋按钮的选中状态：仅高亮当前选中项
	var i = 0
	for t_enum in GameManager.TALENT_DATA:
		var btn = talent_buttons.get_child(i)
		if btn is Button:
			btn.button_pressed = (t_enum == talent)
		i += 1

	_update_preview()


func _on_name_changed(new_text: String) -> void:
	confirm_btn.disabled = new_text.strip_edges().is_empty()


func _on_confirm() -> void:
	var disciple_name = name_input.text.strip_edges()
	if disciple_name.is_empty():
		return

	GameManager.create_disciple(disciple_name, selected_talent)
	SaveManager.auto_save()

	# 进入训练营
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")


func _update_preview() -> void:
	# 显示深黑色的机器人预览（初始状态）
	if preview_sprite:
		preview_sprite.color = Color(0.1, 0.1, 0.12)
