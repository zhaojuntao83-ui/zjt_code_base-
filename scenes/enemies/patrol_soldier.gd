## 巡逻步兵 - 固定路线巡逻，近战攻击
## GDD: 逼出的训练需求 -> 示范近战时机和基础格挡
extends BaseEnemy

@export var patrol_distance: float = 200.0

var patrol_origin: Vector2
var patrol_direction: float = 1.0


func _ready() -> void:
	enemy_name = "巡逻步兵"
	enemy_type = "patrol"
	max_health = 40.0
	attack_damage = 8.0
	move_speed = 80.0
	detection_range = 180.0
	attack_range = 50.0
	exp_reward = 20
	attack_warning_duration = 0.5
	current_state = State.PATROL

	super._ready()
	patrol_origin = global_position


func _ai_patrol(delta: float) -> void:
	# 在巡逻范围内来回走
	velocity.x = patrol_direction * move_speed

	if absf(global_position.x - patrol_origin.x) > patrol_distance:
		patrol_direction = -patrol_direction

	if sprite:
		sprite.flip_h = patrol_direction < 0

	# 发现目标则追击
	if target:
		current_state = State.CHASE


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.PATROL
		return

	var dist = global_position.distance_to(target.global_position)

	# 超出追击范围则回去巡逻
	if dist > detection_range * 1.5:
		target = null
		current_state = State.PATROL
		return

	if dist <= attack_range:
		current_state = State.ATTACK
		return

	var dir = sign(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed
	if sprite:
		sprite.flip_h = dir < 0
