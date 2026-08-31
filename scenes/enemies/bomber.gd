## 投石兵 - 范围攻击，需快速脱离红圈
## GDD: 逼出的训练需求 -> 示范快速位移和区域规避
extends BaseEnemy

@export var lob_range: float = 220.0
@export var aoe_radius: float = 80.0
@export var throw_cooldown: float = 3.0

var throw_timer: float = 0.0


func _ready() -> void:
	enemy_name = "投石兵"
	enemy_type = "bomber"
	max_health = 25.0
	attack_damage = 15.0
	move_speed = 45.0  # 移动慢
	detection_range = 250.0
	attack_range = lob_range
	exp_reward = 25
	attack_warning_duration = 1.2  # 较长预警给玩家反应

	super._ready()
	current_state = State.IDLE


func _update_ai(delta: float) -> void:
	_detect_target()
	throw_timer += delta

	match current_state:
		State.IDLE:
			if target:
				current_state = State.CHASE
		State.CHASE:
			_ai_chase(delta)
		State.ATTACK:
			pass


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target.global_position)

	# 在投掷范围内且冷却好了
	if dist <= lob_range and throw_timer >= throw_cooldown:
		velocity.x = 0
		current_state = State.ATTACK
		_ai_attack(delta)
		return

	# 接近到投掷范围
	if dist > lob_range:
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * move_speed
		if sprite:
			sprite.flip_h = dir < 0
	else:
		velocity.x = 0


func _ai_attack(_delta: float) -> void:
	if is_attacking:
		return

	is_attacking = true
	throw_timer = 0.0

	if not target:
		is_attacking = false
		current_state = State.CHASE
		return

	# 瞄准目标当前位置显示落点预警（红圈）
	var target_pos = target.global_position
	var warning_rect = Rect2(
		target_pos - Vector2(aoe_radius, aoe_radius),
		Vector2(aoe_radius * 2, aoe_radius * 2)
	)
	EventBus.boss_attack_warning.emit(warning_rect, attack_warning_duration)

	await get_tree().create_timer(attack_warning_duration).timeout

	# 石头落地，在目标位置造成范围伤害
	if is_alive:
		var targets = get_tree().get_nodes_in_group("disciple")
		for t in targets:
			if t is BaseCharacter:
				var dist = target_pos.distance_to(t.global_position)
				if dist <= aoe_radius:
					# 距离越近伤害越高
					var damage_ratio = 1.0 - (dist / aoe_radius) * 0.5
					t.take_damage(attack_damage * damage_ratio)

	await get_tree().create_timer(0.5).timeout
	is_attacking = false
	current_state = State.CHASE
