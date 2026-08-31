## 道场守护者 - 第一世界Boss（近战型）
## GDD: 攻击有明显前摇停顿，开阔场地，引导弟子识别前摇精准反击
extends BaseBoss


func _ready() -> void:
	boss_id = "dojo_guardian"
	boss_display_name = "道场守护者"
	enemy_type = "boss"
	max_health = 500.0
	attack_damage = 20.0
	move_speed = 120.0
	attack_range = 70.0
	exp_reward = 300
	warning_duration = 1.0
	phase_health_thresholds = [0.5]

	attack_patterns = [
		{"type": "basic", "damage": 20.0},
		{"type": "basic", "damage": 25.0},
		{"type": "charge", "damage": 35.0, "speed": 350.0},
	]

	super._ready()


func _enter_phase(phase: int) -> void:
	super._enter_phase(phase)
	if phase == 2:
		# 二阶段：加快攻速，新增AOE
		warning_duration = 0.7
		attack_patterns.append({"type": "aoe", "range": 120.0, "damage": 30.0})
