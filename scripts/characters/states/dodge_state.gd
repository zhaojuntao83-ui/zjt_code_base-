## 闪避状态
extends CharacterState

var dodge_timer: float = 0.0
const DODGE_DURATION = 0.35
const DODGE_SPEED = 450.0


func enter(_params: Dictionary) -> void:
	dodge_timer = 0.0
	character.is_invincible = true

	# 闪避方向：按方向键的方向，否则朝面向的反方向
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir == 0.0:
		input_dir = -1.0 if character.sprite_facing_right else 1.0
	character.velocity.x = input_dir * DODGE_SPEED
	character.velocity.y = 0.0

	if character.has_node("AnimationPlayer"):
		character.get_node("AnimationPlayer").play("dodge")


func exit() -> void:
	character.is_invincible = false


func physics_update(delta: float) -> void:
	dodge_timer += delta

	if dodge_timer >= DODGE_DURATION:
		if character.is_on_floor():
			state_machine.transition_to("idle")
		else:
			state_machine.transition_to("fall")
		return

	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * 0.5 * delta)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()
