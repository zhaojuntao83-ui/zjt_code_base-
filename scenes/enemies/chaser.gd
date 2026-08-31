## 追击者 - 高速追击，持续骚扰
## GDD: 逼出的训练需求 -> 示范加速逃跑和反打时机
extends BaseEnemy

@export var chase_speed_multiplier: float = 1.6
@export var stamina: float = 100.0
@export var rest_threshold: float = 20.0

var current_stamina: float = 100.0
var is_resting: bool = false
const STAMINA_DRAIN: float = 15.0  # 追击时体力消耗/秒
const STAMINA_RECOVER: float = 25.0  # 休息时体力恢复/秒


func _ready() -> void:
	enemy_name = "追击者"
	enemy_type = "chaser"
	max_health = 35.0
	attack_damage = 7.0
	move_speed = 140.0
	detection_range = 250.0
	attack_range = 40.0
	exp_reward = 25
	attack_warning_duration = 0.3  # 攻击快但伤害低
	current_stamina = stamina

	super._ready()
	current_state = State.IDLE


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	# 体力管理：追击消耗体力，耗尽则短暂休息
	if is_resting:
		velocity.x = 0
		current_stamina += STAMINA_RECOVER * delta
		if current_stamina >= stamina * 0.8:
			is_resting = false
		return

	current_stamina -= STAMINA_DRAIN * delta
	if current_stamina <= rest_threshold:
		is_resting = true
		return

	var dist = global_position.distance_to(target.global_position)

	if dist <= attack_range:
		current_state = State.ATTACK
		return

	# 高速追击
	var dir = sign(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed * chase_speed_multiplier
	if sprite:
		sprite.flip_h = dir < 0


func _ai_attack(_delta: float) -> void:
	if is_attacking:
		return

	is_attacking = true

	# 快速攻击，预警时间短
	_show_attack_warning()
	await get_tree().create_timer(attack_warning_duration).timeout

	if is_alive and target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range * 1.3:
			target.take_damage(attack_damage)

	# 攻击后短暂停顿（反打窗口）
	velocity.x = 0
	await get_tree().create_timer(0.6).timeout
	is_attacking = false
	current_state = State.CHASE
