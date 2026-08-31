## 主菜单界面
extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var new_game_btn: Button = $VBoxContainer/Buttons/NewGameBtn
@onready var continue_btn: Button = $VBoxContainer/Buttons/ContinueBtn
@onready var settings_btn: Button = $VBoxContainer/Buttons/SettingsBtn
@onready var quit_btn: Button = $VBoxContainer/Buttons/QuitBtn
@onready var save_slots_panel: PanelContainer = $SaveSlotsPanel
@onready var slot_buttons: Array[Button] = []


func _ready() -> void:
	title_label.text = "师 与 影"
	subtitle_label.text = "MASTER & ECHO"

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	save_slots_panel.visible = false

	# 检查是否有存档
	var has_any_save = false
	for i in SaveManager.MAX_SLOTS:
		if SaveManager.has_save(i):
			has_any_save = true
			break
	continue_btn.disabled = not has_any_save

	AudioManager.play_music("main_menu")


func _on_new_game() -> void:
	_show_save_slots("new")


func _on_continue() -> void:
	_show_save_slots("load")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_ui.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _show_save_slots(mode: String) -> void:
	save_slots_panel.visible = true

	# 动态创建存档槽按钮
	var container = save_slots_panel.get_node("VBox")
	for child in container.get_children():
		if child is Button:
			child.queue_free()

	for i in SaveManager.MAX_SLOTS:
		var btn = Button.new()
		var info = SaveManager.get_save_info(i)

		if info.is_empty():
			btn.text = "存档槽 %d - 空" % (i + 1)
		else:
			btn.text = "存档槽 %d - %s (关卡 %d)" % [
				i + 1,
				info.get("disciple_name", "未命名"),
				info.get("completed_levels", 0)
			]

		var slot_index = i
		if mode == "new":
			btn.pressed.connect(func(): _start_new_game(slot_index))
		else:
			btn.disabled = info.is_empty()
			btn.pressed.connect(func(): _load_game(slot_index))

		container.add_child(btn)

	# 返回按钮
	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(func(): save_slots_panel.visible = false)
	container.add_child(back_btn)


func _start_new_game(slot: int) -> void:
	SaveManager.current_slot = slot
	GameManager.change_state(GameManager.GameState.TRAINING_CAMP)
	# 切换到弟子创建界面
	get_tree().change_scene_to_file("res://scenes/ui/disciple_creation.tscn")


func _load_game(slot: int) -> void:
	if SaveManager.load_game(slot):
		GameManager.change_state(GameManager.GameState.TRAINING_CAMP)
		get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")
