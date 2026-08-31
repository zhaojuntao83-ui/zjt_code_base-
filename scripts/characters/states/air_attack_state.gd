## 空中攻击状态
extends CharacterState

var attack_finished: bool = false


func enter(_params: Dictionary) -> void:
	attack_finished = false
	# 空中攻击时短暂悬停
	character.velocity.y *= 0.3

	if character.has_node("AnimationPlayer"):
		var anim_player = character.get_node("AnimationPlayer")
		anim_player.play("air_attack")
		anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)


func physics_update(delta: float) -> void:
	if attack_finished or character.is_on_floor():
		if character.is_on_floor():
			state_machine.transition_to("idle")
		else:
			state_machine.transition_to("fall")
		return

	# 空中攻击时缓慢下落
	character.velocity.y += character.gravity * 0.5 * delta
	var input_dir = Input.get_axis("move_left", "move_right")
	character.velocity.x = move_toward(
		character.velocity.x,
		input_dir * character.move_speed * 0.3,
		character.acceleration * 0.3 * delta
	)
	character.move_and_slide()


func _on_animation_finished(_anim_name: StringName) -> void:
	attack_finished = true
