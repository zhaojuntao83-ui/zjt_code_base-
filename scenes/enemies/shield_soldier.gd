## 盾兵 - 正面格挡无效，需绕后攻击
## GDD: 逼出的训练需求 -> 示范绕背动作和闪避路线
extends BaseEnemy

var facing_target: bool = true
var block_active: bool = true  # 盾兵默认举盾


func _ready() -> void:
	enemy_name = "盾兵"
	enemy_type = "shield"
	max_health = 60.0
	attack_damage = 10.0
	move_speed = 55.0
	detection_range = 160.0
	attack_range = 55.0
	exp_reward = 30
	attack_warning_duration = 0.6

	super._ready()
	current_state = State.IDLE


func take_damage(amount: float) -> void:
	if not is_alive:
		return

	# 正面攻击被格挡：检查攻击来源方向
	var attacker_nodes = get_tree().get_nodes_in_group("disciple")
	for attacker in attacker_nodes:
		if attacker is Node2D:
			var attacker_dir = sign(attacker.global_position.x - global_position.x)
			var my_facing = -1.0 if (sprite and sprite.flip_h) else 1.0

			# 攻击者在盾兵面朝方向 -> 格挡
			if sign(attacker_dir) == sign(my_facing) and block_active:
				amount *= 0.1  # 正面仅受10%伤害
				# 盾挡特效提示
				EventBus.message_requested.emit("格挡！尝试绕到背后", 1.0)
				break

	super.take_damage(amount)


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target.global_position)

	if dist <= attack_range:
		current_state = State.ATTACK
		return

	# 缓慢追击，始终面朝目标
	var dir = sign(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed
	if sprite:
		sprite.flip_h = dir < 0


func _ai_attack(_delta: float) -> void:
	if is_attacking:
		return

	is_attacking = true
	# 攻击时短暂放下盾牌
	block_active = false

	_show_attack_warning()
	await get_tree().create_timer(attack_warning_duration).timeout

	if is_alive and target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range * 1.5:
			target.take_damage(attack_damage)

	await get_tree().create_timer(0.4).timeout
	block_active = true  # 重新举盾
	is_attacking = false
	current_state = State.CHASE
