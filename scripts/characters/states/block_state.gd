## 格挡状态
extends CharacterState

func enter(_params: Dictionary) -> void:
	character.is_blocking = true
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("block")


func exit() -> void:
	character.is_blocking = false


func physics_update(delta: float) -> void:
	if not Input.is_action_pressed("block"):
		state_machine.transition_to("idle")
		return

	# 格挡时大幅减速
	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * 2.0 * delta)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()
