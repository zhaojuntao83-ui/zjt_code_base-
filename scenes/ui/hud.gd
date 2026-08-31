## HUD - 游戏内常驻界面
## GDD: 极简，只显示当前最需要关注的数据
## 左上：弟子体力条+颜色图标 | 右上：接管次数+倒计时 | 右下：经验点 | 中央顶部：关卡进度
extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/TopLeft/HealthBar
@onready var color_icon: ColorRect = $MarginContainer/TopLeft/ColorIcon
@onready var takeover_label: Label = $MarginContainer/TopRight/TakeoverLabel
@onready var takeover_timer: Label = $MarginContainer/TopRight/TakeoverTimer
@onready var exp_label: Label = $MarginContainer/BottomRight/ExpLabel
@onready var progress_bar: ProgressBar = $MarginContainer/TopCenter/ProgressBar
@onready var record_indicator: Control = $RecordIndicator
@onready var message_label: Label = $MessageLabel
@onready var dialog_panel: PanelContainer = $DialogPanel
@onready var dialog_speaker: Label = $DialogPanel/VBox/Speaker
@onready var dialog_text: Label = $DialogPanel/VBox/Text

var message_timer: float = 0.0


func _ready() -> void:
	record_indicator.visible = false
	dialog_panel.visible = false
	message_label.visible = false

	EventBus.disciple_color_changed.connect(_on_color_changed)
	EventBus.disciple_damaged.connect(_on_disciple_damaged)
	EventBus.takeover_charges_changed.connect(_on_takeover_charges_changed)
	EventBus.takeover_cooldown_updated.connect(_on_takeover_cooldown)
	EventBus.takeover_activated.connect(func(): takeover_timer.visible = true)
	EventBus.takeover_deactivated.connect(func(_d): takeover_timer.visible = false)
	EventBus.exp_points_changed.connect(_on_exp_changed)
	EventBus.recording_started.connect(func(): record_indicator.visible = true)
	EventBus.recording_stopped.connect(func(_d): record_indicator.visible = false)
	EventBus.message_requested.connect(show_message)
	EventBus.dialog_requested.connect(show_dialog)

	_update_all()


func _process(delta: float) -> void:
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.visible = false


func _update_all() -> void:
	_on_exp_changed(GameManager.exp_points)
	_on_takeover_charges_changed(GameManager.get_takeover_max_charges())

	if GameManager.active_disciple:
		var d = GameManager.active_disciple
		if health_bar:
			health_bar.max_value = 100
			health_bar.value = d.health


func _on_color_changed(new_color: Color) -> void:
	if color_icon:
		color_icon.color = new_color


func _on_disciple_damaged(amount: float) -> void:
	if health_bar and GameManager.active_disciple:
		health_bar.value = GameManager.active_disciple.health


func _on_takeover_charges_changed(remaining: int) -> void:
	if takeover_label:
		takeover_label.text = "接管: %d" % remaining


func _on_takeover_cooldown(time_left: float) -> void:
	if takeover_timer:
		if time_left > 0:
			takeover_timer.text = "%.1fs" % time_left
			takeover_timer.visible = true
		else:
			takeover_timer.visible = false


func _on_exp_changed(amount: int) -> void:
	if exp_label:
		exp_label.text = "%d" % amount


func show_message(text: String, duration: float = 2.0) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		message_timer = duration


func show_dialog(speaker: String, text: String) -> void:
	if dialog_panel:
		dialog_speaker.text = speaker
		dialog_text.text = text
		dialog_panel.visible = true
		await get_tree().create_timer(3.0).timeout
		dialog_panel.visible = false


func update_progress(current: float, total: float) -> void:
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = current
