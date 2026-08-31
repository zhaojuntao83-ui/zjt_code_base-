## 攻击状态 - 普通攻击、连招
extends CharacterState

var combo_count: int = 0
var can_combo: bool = false
var attack_finished: bool = false
const MAX_COMBO = 3
const COMBO_WINDOW = 0.3


func enter(_params: Dictionary) -> void:
	combo_count = _params.get("combo", 0)
	can_combo = false
	attack_finished = false

	var anim_name = "attack_%d" % (combo_count + 1)
	if character.has_node("AnimationPlayer"):
		var anim_player = character.get_node("AnimationPlayer")
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name)
			anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
		else:
			anim_player.play("attack_1")
			anim_player.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)

	# 攻击时给一个小的前冲力
	var facing = 1.0 if character.sprite_facing_right else -1.0
	character.velocity.x = facing * character.move_speed * 0.3


func physics_update(delta: float) -> void:
	# 检测连招输入
	if can_combo and Input.is_action_just_pressed("attack"):
		if combo_count < MAX_COMBO - 1:
			state_machine.transition_to("attack", {"combo": combo_count + 1})
			return

	if attack_finished:
		if character.is_on_floor():
			state_machine.transition_to("idle")
		else:
			state_machine.transition_to("fall")
		return

	character.velocity.x = move_toward(character.velocity.x, 0, character.friction * delta)
	character.velocity.y += character.gravity * delta
	character.move_and_slide()


func _on_animation_finished(_anim_name: StringName) -> void:
	can_combo = true
	# 短暂连招窗口后结束
	await character.get_tree().create_timer(COMBO_WINDOW).timeout
	if state_machine.current_state == self and not attack_finished:
		attack_finished = true
