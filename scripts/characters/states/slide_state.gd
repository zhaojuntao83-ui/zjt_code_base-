## 滑铲状态 - 跑步中蹲下触发
extends CharacterState

var slide_timer: float = 0.0
const SLIDE_DURATION = 0.5
const SLIDE_SPEED_BOOST = 1.4


func enter(_params: Dictionary) -> void:
	slide_timer = 0.0
	# 保持当前方向给速度加成
	character.velocity.x *= SLIDE_SPEED_BOOST
	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("slide")
	if character.has_method("set_crouch_collision"):
		character.set_crouch_collision(true)


func exit() -> void:
	if character.has_method("set_crouch_collision"):
		character.set_crouch_collision(false)


func physics_update(delta: float) -> void:
	slide_timer += delta

	if slide_timer >= SLIDE_DURATION:
		if Input.is_action_pressed("crouch"):
			state_machine.transition_to("crouch")
		else:
			state_machine.transition_to("idle")
		return

	if Input.is_action_just_pressed("jump"):
		state_machine.transition_to("jump")
		return

	# 滑铲减速
	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * 0.3 * delta)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()
