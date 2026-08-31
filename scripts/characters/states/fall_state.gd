## 下落状态
extends CharacterState

func enter(_params: Dictionary) -> void:
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("fall")


func physics_update(delta: float) -> void:
	# 空中水平移动
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0.0:
		character.velocity.x = move_toward(
			character.velocity.x,
			input_dir * character.move_speed * character.air_control,
			character.acceleration * character.air_control * delta
		)
		if input_dir > 0:
			character.face_right()
		elif input_dir < 0:
			character.face_left()

	character.velocity.y += character.gravity * delta
	character.velocity.y = minf(character.velocity.y, character.max_fall_speed)
	character.move_and_slide()

	if character.is_on_floor():
		if input_dir != 0.0:
			state_machine.transition_to("run")
		else:
			state_machine.transition_to("idle")
