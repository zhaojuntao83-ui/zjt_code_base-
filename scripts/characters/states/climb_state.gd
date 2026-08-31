## 攀爬翻越状态 - 接触高墙时触发
extends CharacterState

var climb_timer: float = 0.0
const CLIMB_DURATION = 0.6


func enter(_params: Dictionary) -> void:
	climb_timer = 0.0
	character.velocity = Vector2.ZERO
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("climb")


func physics_update(delta: float) -> void:
	climb_timer += delta

	if climb_timer < CLIMB_DURATION * 0.5:
		# 上升阶段
		character.velocity.y = -character.move_speed * 1.2
	elif climb_timer < CLIMB_DURATION:
		# 翻越阶段：向前推进
		var facing = 1.0 if character.sprite_facing_right else -1.0
		character.velocity.x = facing * character.move_speed
		character.velocity.y = -character.move_speed * 0.3
	else:
		state_machine.transition_to("fall")
		return

	character.move_and_slide()
