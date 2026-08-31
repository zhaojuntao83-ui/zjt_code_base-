## 城镇霸主 - 第二世界Boss（远程狙击型）
## GDD: 攻击范围极大近战无法靠近，场景有高台和弹射装置
extends BaseBoss


func _ready() -> void:
	boss_id = "town_overlord"
	boss_display_name = "城镇霸主"
	enemy_type = "boss"
	max_health = 600.0
	attack_damage = 25.0
	move_speed = 80.0
	attack_range = 300.0
	detection_range = 600.0
	exp_reward = 300
	warning_duration = 1.2
	phase_health_thresholds = [0.5]

	attack_patterns = [
		{"type": "ranged", "damage": 20.0},
		{"type": "ranged", "damage": 25.0},
		{"type": "aoe", "range": 100.0, "damage": 30.0},
	]

	super._ready()


func _enter_phase(phase: int) -> void:
	super._enter_phase(phase)
	if phase == 2:
		warning_duration = 0.8
		attack_patterns.append({"type": "ranged", "damage": 35.0})
		move_speed = 60.0  # 二阶段更专注于射击


func _ranged_attack(pattern: Dictionary) -> void:
	"""远程狙击：发射投射物"""
	if not target:
		await get_tree().create_timer(0.5).timeout
		return

	# 瞄准预警线
	var dir = (target.global_position - global_position).normalized()
	var warning_rect = Rect2(global_position, dir * 400)
	EventBus.boss_attack_warning.emit(warning_rect, warning_duration)
	await get_tree().create_timer(warning_duration).timeout

	# 发射
	if target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range:
			target.take_damage(pattern.get("damage", attack_damage))

	await get_tree().create_timer(0.6).timeout
