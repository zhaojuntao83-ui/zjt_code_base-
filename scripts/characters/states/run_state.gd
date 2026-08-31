## 奔跑状态
extends CharacterState

func enter(_params: Dictionary) -> void:
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("run")


func physics_update(delta: float) -> void:
	if not character.is_on_floor():
		state_machine.transition_to("fall")
		return

	var input_dir = Input.get_axis("move_left", "move_right")

	if input_dir == 0.0:
		state_machine.transition_to("idle")
		return

	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("jump")
		return

	# 跑步时按下蹲 -> 滑铲
	if Input.is_action_just_pressed("crouch") and absf(character.velocity.x) > character.slide_min_speed:
		state_machine.transition_to("slide")
		return

	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("attack")
		return

	# 更新面朝方向
	if input_dir > 0:
		character.face_right()
	elif input_dir < 0:
		character.face_left()

	# 加速移动
	character.velocity.x = move_toward(
		character.velocity.x,
		input_dir * character.move_speed,
		character.acceleration * delta
	)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()
