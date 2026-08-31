## 训练观看界面 - 观看弟子反复练习，支持加速/慢动作
## GDD: 实时显示尝试次数和成功率曲线，支持x2/x5/x10加速
extends Control

@onready var training_viewport: SubViewportContainer = $HSplit/ViewportContainer
@onready var iteration_label: Label = $HSplit/SidePanel/IterationLabel
@onready var success_rate_label: Label = $HSplit/SidePanel/SuccessRateLabel
@onready var speed_buttons: HBoxContainer = $HSplit/SidePanel/SpeedButtons
@onready var stop_btn: Button = $HSplit/SidePanel/StopBtn
@onready var back_btn: Button = $TopBar/BackBtn

var training_system: TrainingSystem


func _ready() -> void:
	training_system = TrainingSystem.new()
	add_child(training_system)

	stop_btn.pressed.connect(_stop_training)
	back_btn.pressed.connect(_go_back)

	_create_speed_buttons()

	EventBus.training_iteration_completed.connect(_on_iteration)
	EventBus.training_completed.connect(_on_training_done)

	# 自动从 GameManager 读取待训练卡片并启动（训练背包UI传递）
	_auto_start_from_backpack()


func _auto_start_from_backpack() -> void:
	"""从 GameManager.active_training_card_id 读取卡片，自动启动训练循环"""
	var card_id = GameManager.active_training_card_id
	if card_id.is_empty():
		return

	var card = GameManager.training_backpack.get_card(card_id)
	if card == null:
		GameManager.active_training_card_id = ""
		EventBus.message_requested.emit("卡片已不存在，请重新选择", 2.0)
		return

	# 构造 demo_data（training_system.start_training 所需格式）
	var demo_data = {
		"id": card.card_id,
		"category": card.category,
		"duration": card.duration,
		"frames": card.frame_data,
		"quality": card.quality_detail,
		"created_at": card.created_at,
	}

	# disciple 传 null：training_system._evaluate_attempt() 会降级为 _fallback_simulate()
	start(card_id, demo_data, null)
	# 累加练习次数
	card.practice_count += 1
	GameManager.active_training_card_id = ""


func _create_speed_buttons() -> void:
	var speeds = [
		{"label": "x1", "speed": TrainingSystem.TrainingSpeed.NORMAL},
		{"label": "x2", "speed": TrainingSystem.TrainingSpeed.FAST_2X},
		{"label": "x5", "speed": TrainingSystem.TrainingSpeed.FAST_5X},
		{"label": "x10", "speed": TrainingSystem.TrainingSpeed.FAST_10X},
	]

	for s in speeds:
		var btn = Button.new()
		btn.text = s["label"]
		var spd = s["speed"]
		btn.pressed.connect(func(): training_system.set_speed(spd))
		speed_buttons.add_child(btn)


func start(card_id: String, demo_data: Dictionary, disciple: Node) -> void:
	training_system.start_training(card_id, demo_data, disciple)


func _on_iteration(iteration: int, success_rate: float) -> void:
	iteration_label.text = "第 %d 次尝试" % iteration
	success_rate_label.text = "成功率: %.1f%%" % (success_rate * 100)


func _on_training_done(_card_id: String, result: Dictionary) -> void:
	iteration_label.text = "训练完成!"
	success_rate_label.text = "最终成功率: %.1f%%" % (result.get("success_rate", 0) * 100)
	stop_btn.text = "返回训练营"


func _stop_training() -> void:
	training_system.stop_training()
	_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")
