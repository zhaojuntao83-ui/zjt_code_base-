## 熔岩巨兽 - 第三世界Boss（AOE攻击型）
## GDD: 会持续追击不停，迷宫状地形，需要拉开距离伺机偷袭
extends BaseBoss


func _ready() -> void:
	boss_id = "lava_beast"
	boss_display_name = "熔岩巨兽"
	enemy_type = "boss"
	max_health = 800.0
	attack_damage = 30.0
	move_speed = 150.0
	attack_range = 80.0
	exp_reward = 300
	warning_duration = 0.8
	phase_health_thresholds = [0.5]

	attack_patterns = [
		{"type": "aoe", "range": 130.0, "damage": 25.0},
		{"type": "charge", "damage": 40.0, "speed": 400.0},
		{"type": "aoe", "range": 180.0, "damage": 35.0},
	]

	super._ready()


func _ai_chase(delta: float) -> void:
	"""熔岩巨兽持续追击不停"""
	if not target:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target.global_position)
	var dir = sign(target.global_position.x - global_position.x)

	# 持续追击，不会因为距离远而放弃
	velocity.x = dir * move_speed
	if sprite:
		sprite.flip_h = dir < 0

	if dist <= attack_range:
		current_state = State.ATTACK


func _enter_phase(phase: int) -> void:
	super._enter_phase(phase)
	if phase == 2:
		move_speed = 180.0  # 二阶段更快
		warning_duration = 0.5
		attack_patterns.append({"type": "aoe", "range": 200.0, "damage": 45.0})
