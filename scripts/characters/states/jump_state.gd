## 跳跃状态（含二段跳）
extends CharacterState

var has_double_jumped: bool = false

func enter(_params: Dictionary) -> void:
	has_double_jumped = false
	character.velocity.y = character.jump_force
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("jump")


func physics_update(delta: float) -> void:
	# 二段跳
	if Input.is_action_just_pressed("jump") and not has_double_jumped:
		has_double_jumped = true
		character.velocity.y = character.jump_force * 0.85
		if character.has_node("AnimationPlayer"):
			character.get_node("AnimationPlayer").play("double_jump")

	# 空中攻击
	if Input.is_action_just_pressed("attack"):
		state_machine.transition_to("air_attack")
		return

	# 空中闪避
	if Input.is_action_just_pressed("dodge"):
		state_machine.transition_to("dodge")
		return

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

	# 重力
	character.velocity.y += character.gravity * delta

	# 转为下落状态
	if character.velocity.y > 0:
		state_machine.transition_to("fall")
		return

	character.move_and_slide()

	if character.is_on_floor():
		state_machine.transition_to("idle")
