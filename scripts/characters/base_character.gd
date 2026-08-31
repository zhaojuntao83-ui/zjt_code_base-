## 角色基类 - 师傅和弟子共享的物理属性和通用方法
class_name BaseCharacter
extends CharacterBody2D

# ========== 移动参数 ==========
@export var move_speed: float = 280.0
@export var acceleration: float = 1800.0
@export var friction: float = 2000.0
@export var jump_force: float = -480.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 600.0
@export var air_control: float = 0.7
@export var slide_min_speed: float = 150.0

# ========== 战斗参数 ==========
@export var max_health: float = 100.0
var health: float = 100.0
var attack_power: float = 10.0
var is_blocking: bool = false
var is_invincible: bool = false

# ========== 节点引用 ==========
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var state_machine: StateMachine = $StateMachine

var sprite_facing_right: bool = true

# 碰撞体尺寸（站立 vs 蹲下）
var standing_shape_size: Vector2
var crouching_shape_size: Vector2


func _ready() -> void:
	health = max_health
	if collision_shape and collision_shape.shape is RectangleShape2D:
		standing_shape_size = collision_shape.shape.size
		crouching_shape_size = Vector2(standing_shape_size.x, standing_shape_size.y * 0.5)


func face_right() -> void:
	if not sprite_facing_right:
		sprite_facing_right = true
		if sprite:
			sprite.flip_h = false


func face_left() -> void:
	if sprite_facing_right:
		sprite_facing_right = false
		if sprite:
			sprite.flip_h = true


func set_crouch_collision(crouching: bool) -> void:
	if collision_shape and collision_shape.shape is RectangleShape2D:
		if crouching:
			collision_shape.shape.size = crouching_shape_size
			collision_shape.position.y += (standing_shape_size.y - crouching_shape_size.y) / 2.0
		else:
			collision_shape.shape.size = standing_shape_size
			collision_shape.position.y -= (standing_shape_size.y - crouching_shape_size.y) / 2.0


func take_damage(amount: float) -> void:
	if is_invincible:
		return
	if is_blocking:
		amount *= 0.2  # 格挡减伤80%

	health -= amount
	health = maxf(health, 0.0)

	if health <= 0.0:
		die()


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)


func die() -> void:
	# 子类重写
	pass
