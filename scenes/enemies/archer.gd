## 弓箭手 - 远距离射击，移动中躲避
## GDD: 逼出的训练需求 -> 示范跑动中的躲避和接近路线
extends BaseEnemy

@export var shoot_range: float = 250.0
@export var retreat_range: float = 80.0
@export var shoot_cooldown: float = 2.0

var shoot_timer: float = 0.0


func _ready() -> void:
	enemy_name = "弓箭手"
	enemy_type = "archer"
	max_health = 30.0
	attack_damage = 12.0
	move_speed = 60.0
	detection_range = 280.0
	attack_range = shoot_range
	exp_reward = 25
	attack_warning_duration = 0.8  # 拉弓蓄力时间作为预警

	super._ready()
	current_state = State.IDLE


func _update_ai(delta: float) -> void:
	_detect_target()
	shoot_timer += delta

	match current_state:
		State.IDLE:
			if target:
				current_state = State.CHASE
		State.CHASE:
			_ai_chase(delta)
		State.ATTACK:
			pass  # 攻击逻辑在 _ai_attack 中通过协程处理


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target.global_position)

	# 目标太近，后退保持距离
	if dist < retreat_range:
		var dir = sign(global_position.x - target.global_position.x)
		velocity.x = dir * move_speed * 1.2
		if sprite:
			sprite.flip_h = dir < 0
		return

	# 在射程内且冷却好了，开始射击
	if dist <= shoot_range and shoot_timer >= shoot_cooldown:
		velocity.x = 0
		current_state = State.ATTACK
		_ai_attack(delta)
		return

	# 不在射程内，接近目标
	if dist > shoot_range:
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * move_speed * 0.7
		if sprite:
			sprite.flip_h = dir < 0
	else:
		velocity.x = 0
		# 面朝目标
		if sprite and target:
			sprite.flip_h = target.global_position.x < global_position.x


func _ai_attack(_delta: float) -> void:
	if is_attacking:
		return

	is_attacking = true
	shoot_timer = 0.0

	# 显示瞄准预警
	_show_aim_warning()
	await get_tree().create_timer(attack_warning_duration).timeout

	# 射击
	if is_alive and target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= shoot_range:
			target.take_damage(attack_damage)

	await get_tree().create_timer(0.3).timeout
	is_attacking = false
	current_state = State.CHASE


func _show_aim_warning() -> void:
	"""显示瞄准线预警"""
	if not target:
		return
	var dir = (target.global_position - global_position).normalized()
	var warning_rect = Rect2(global_position, dir * shoot_range)
	EventBus.boss_attack_warning.emit(warning_rect, attack_warning_duration)
