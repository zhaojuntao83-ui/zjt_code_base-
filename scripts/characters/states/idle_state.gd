## 待机状态
extends CharacterState

func enter(_params: Dictionary) -> void:
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("idle")


func physics_update(delta: float) -> void:
	# 应用重力
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
		state_machine.transition_to("fall")
		return

	# 输入检测
	var input_dir = _get_move_input()

	if input_dir != 0.0:
		state_machine.transition_to("run")
	elif Input.is_action_just_pressed("jump"):
		state_machine.transition_to("jump")
	elif Input.is_action_just_pressed("crouch"):
		state_machine.transition_to("crouch")
	elif Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
	elif Input.is_action_just_pressed("block"):
		state_machine.transition_to("block")

	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * delta)
	character.move_and_slide()


func _get_move_input() -> float:
	return Input.get_axis("move_left", "move_right")
