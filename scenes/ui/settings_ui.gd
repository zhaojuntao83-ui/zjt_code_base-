## 设置界面 - 难度选择、音量调节
## GDD: 难度影响AI学习速度、接管资源和体力恢复，可随时调整
extends Control

@onready var difficulty_label: Label = $VBox/DifficultySection/CurrentDifficulty
@onready var easy_btn: Button = $VBox/DifficultySection/Buttons/EasyBtn
@onready var normal_btn: Button = $VBox/DifficultySection/Buttons/NormalBtn
@onready var challenge_btn: Button = $VBox/DifficultySection/Buttons/ChallengeBtn

@onready var music_slider: HSlider = $VBox/AudioSection/MusicSlider
@onready var sfx_slider: HSlider = $VBox/AudioSection/SFXSlider

@onready var back_btn: Button = $TopBar/BackBtn

const DIFFICULTY_NAMES = {
	GameManager.Difficulty.EASY: "新手模式",
	GameManager.Difficulty.NORMAL: "普通模式",
	GameManager.Difficulty.CHALLENGE: "挑战模式",
}

const DIFFICULTY_DESCS = {
	GameManager.Difficulty.EASY: "AI学习速度 x1.5 | 接管5次/5秒 | 体力恢复快",
	GameManager.Difficulty.NORMAL: "AI学习速度 x1.0 | 接管3次/3秒 | 体力恢复正常",
	GameManager.Difficulty.CHALLENGE: "AI学习速度 x0.8 | 接管2次/2秒 | 体力恢复慢",
}


func _ready() -> void:
	back_btn.pressed.connect(_go_back)

	easy_btn.pressed.connect(func(): _set_difficulty(GameManager.Difficulty.EASY))
	normal_btn.pressed.connect(func(): _set_difficulty(GameManager.Difficulty.NORMAL))
	challenge_btn.pressed.connect(func(): _set_difficulty(GameManager.Difficulty.CHALLENGE))

	music_slider.value = AudioManager.music_volume * 100
	sfx_slider.value = AudioManager.sfx_volume * 100
	music_slider.value_changed.connect(func(v): AudioManager.set_music_volume(v / 100.0))
	sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(v / 100.0))

	_update_difficulty_display()


func _set_difficulty(diff: GameManager.Difficulty) -> void:
	GameManager.difficulty = diff
	_update_difficulty_display()
	SaveManager.auto_save()


func _update_difficulty_display() -> void:
	var diff = GameManager.difficulty
	difficulty_label.text = "%s\n%s" % [DIFFICULTY_NAMES[diff], DIFFICULTY_DESCS[diff]]

	easy_btn.disabled = diff == GameManager.Difficulty.EASY
	normal_btn.disabled = diff == GameManager.Difficulty.NORMAL
	challenge_btn.disabled = diff == GameManager.Difficulty.CHALLENGE


func _go_back() -> void:
	# 若还没有弟子（从主菜单进入），返回主菜单；否则返回训练营
	if GameManager.active_disciple == null:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")
