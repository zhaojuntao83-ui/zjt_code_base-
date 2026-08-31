## 新手引导系统
## GDD: 让玩家在不读任何说明文字的情况下自然学会所有操作
## 师傅教弟子的过程本身就是教玩家的过程
class_name TutorialSystem
extends Node

# 引导步骤完成状态
var completed_steps: Dictionary = {}

# 是否跳过引导（老玩家创建新弟子时）
var skip_tutorial: bool = false

# 引导步骤定义
const STEPS = {
	"create_disciple": {
		"order": 1,
		"trigger": "game_start",
		"speaker": "师傅",
		"dialog": "来，先为你铸造一个身体。取个名字，再选一份天赋。",
		"highlight": "铸造台界面",
	},
	"first_record": {
		"order": 2,
		"trigger": "first_obstacle",
		"speaker": "师傅",
		"dialog": "看到前面的障碍了吗？按下 R 键，做给他看。",
		"highlight": "录制键",
	},
	"watch_training": {
		"order": 3,
		"trigger": "after_record",
		"speaker": "师傅",
		"dialog": "好，现在看着他练。别急，他会慢慢学会的。",
		"highlight": "训练画面",
	},
	"first_takeover": {
		"order": 4,
		"trigger": "disciple_stuck",
		"speaker": "师傅",
		"dialog": "他卡住了？按住 T 键，我来亲自带他过这一段。",
		"highlight": "接管键",
	},
	"open_backpack": {
		"order": 5,
		"trigger": "after_first_record",
		"speaker": "师傅",
		"dialog": "这是你的示范卡片，每次录制都会记录在这里。你可以随时管理。",
		"highlight": "训练背包入口",
	},
}


func _ready() -> void:
	EventBus.recording_started.connect(_on_recording_started)
	EventBus.recording_stopped.connect(_on_recording_stopped)
	EventBus.training_completed.connect(_on_training_completed)
	EventBus.disciple_died.connect(_on_disciple_stuck)
	# 弟子首次创建时触发铸造台引导（补充 game_start 触发器）
	EventBus.disciple_created.connect(_on_disciple_created)


func _on_disciple_created(_data: Dictionary) -> void:
	show_step("create_disciple")


func should_show_step(step_id: String) -> bool:
	if skip_tutorial:
		return false
	if step_id in completed_steps:
		return false
	return STEPS.has(step_id)


func show_step(step_id: String) -> void:
	"""展示引导步骤（通过师傅对话）"""
	if not should_show_step(step_id):
		return

	var step = STEPS[step_id]
	EventBus.dialog_requested.emit(step["speaker"], step["dialog"])
	completed_steps[step_id] = true


func _on_recording_started() -> void:
	if not "first_record" in completed_steps:
		show_step("first_record")


func _on_recording_stopped(_data: Dictionary) -> void:
	show_step("open_backpack")


func _on_training_completed(_card_id: String, _result: Dictionary) -> void:
	show_step("watch_training")


func _on_disciple_stuck() -> void:
	show_step("first_takeover")


func is_tutorial_complete() -> bool:
	return completed_steps.size() >= STEPS.size()


func to_save_data() -> Dictionary:
	return {"completed_steps": completed_steps, "skip": skip_tutorial}


func from_save_data(data: Dictionary) -> void:
	completed_steps = data.get("completed_steps", {})
	skip_tutorial = data.get("skip", false)
