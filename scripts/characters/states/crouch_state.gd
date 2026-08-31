## 蹲下状态
extends CharacterState

func enter(_params: Dictionary) -> void:
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("crouch")
	# 缩小碰撞体
	if character.has_method("set_crouch_collision"):
		character.set_crouch_collision(true)


func exit() -> void:
	if character.has_method("set_crouch_collision"):
		character.set_crouch_collision(false)


func physics_update(delta: float) -> void:
	if not Input.is_action_pressed("crouch"):
		state_machine.transition_to("idle")
		return

	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * delta)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()
