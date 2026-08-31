## 敌人基类 - 所有普通敌人和Boss继承此类
class_name BaseEnemy
extends CharacterBody2D

@export var enemy_name: String = "敌人"
@export var enemy_type: String = "patrol"  # patrol/archer/shield/chaser/bomber
@export var max_health: float = 50.0
@export var attack_damage: float = 10.0
@export var move_speed: float = 100.0
@export var detection_range: float = 200.0
@export var attack_range: float = 50.0
@export var exp_reward: int = 20

var health: float
var gravity: float = 980.0
var target: Node2D = null
var is_alive: bool = true

# 攻击预警
var attack_warning_duration: float = 0.5
var is_attacking: bool = false

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var anim_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null


func _ready() -> void:
	health = max_health
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	velocity.y += gravity * delta
	_update_ai(delta)
	move_and_slide()


func _update_ai(delta: float) -> void:
	_detect_target()

	match current_state:
		State.IDLE:
			_ai_idle(delta)
		State.PATROL:
			_ai_patrol(delta)
		State.CHASE:
			_ai_chase(delta)
		State.ATTACK:
			_ai_attack(delta)


func _detect_target() -> void:
	"""检测范围内的弟子"""
	var disciples = get_tree().get_nodes_in_group("disciple")
	var closest_dist = detection_range
	target = null

	for d in disciples:
		if d is Node2D:
			var dist = global_position.distance_to(d.global_position)
			if dist < closest_dist:
				closest_dist = dist
				target = d


func _ai_idle(delta: float) -> void:
	if target:
		current_state = State.CHASE


func _ai_patrol(delta: float) -> void:
	# 左右巡逻
	velocity.x = move_speed
	if is_on_wall():
		move_speed = -move_speed
		if sprite:
			sprite.flip_h = move_speed < 0

	if target:
		current_state = State.CHASE


func _ai_chase(delta: float) -> void:
	if not target:
		current_state = State.IDLE
		return

	var dist = global_position.distance_to(target.global_position)
	if dist <= attack_range:
		current_state = State.ATTACK
		return

	var dir = sign(target.global_position.x - global_position.x)
	velocity.x = dir * move_speed
	if sprite:
		sprite.flip_h = dir < 0


func _ai_attack(_delta: float) -> void:
	if is_attacking:
		return

	is_attacking = true
	# 攻击前显示预警
	_show_attack_warning()

	if anim_player and anim_player.has_animation("attack"):
		anim_player.play("attack")

	# 等待预警时间后执行伤害
	await get_tree().create_timer(attack_warning_duration).timeout

	if is_alive and target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range * 1.5:
			target.take_damage(attack_damage)

	await get_tree().create_timer(0.3).timeout
	is_attacking = false
	current_state = State.CHASE


func _show_attack_warning() -> void:
	"""显示攻击预警区域（红色警示）"""
	var warning_area = _get_attack_warning_rect()
	EventBus.boss_attack_warning.emit(warning_area, attack_warning_duration)


func _get_attack_warning_rect() -> Rect2:
	var facing = 1.0 if (sprite and not sprite.flip_h) else -1.0
	var origin = global_position + Vector2(facing * 10, -20)
	return Rect2(origin, Vector2(attack_range * facing, 40))


func take_damage(amount: float) -> void:
	if not is_alive:
		return

	health -= amount
	current_state = State.HURT

	if anim_player and anim_player.has_animation("hurt"):
		anim_player.play("hurt")

	if health <= 0:
		die()
	else:
		await get_tree().create_timer(0.2).timeout
		if is_alive:
			current_state = State.CHASE


func die() -> void:
	is_alive = false
	current_state = State.DEAD
	EventBus.enemy_defeated.emit(enemy_type, exp_reward)

	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
		await anim_player.animation_finished

	queue_free()
