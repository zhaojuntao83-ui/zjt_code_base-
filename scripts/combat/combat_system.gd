## 战斗系统 - 管理攻击碰撞、伤害计算、格挡交互
class_name CombatSystem
extends Node

## 处理攻击碰撞
func process_attack(attacker: BaseCharacter, attack_area: Area2D, weapon: WeaponData, combo_index: int = 0) -> Array[Dictionary]:
	"""处理一次攻击，返回所有受击结果"""
	var results: Array[Dictionary] = []
	var bodies = attack_area.get_overlapping_bodies()

	for body in bodies:
		if body == attacker:
			continue
		if not body is BaseCharacter:
			continue

		var target = body as BaseCharacter
		var result = _calculate_hit(attacker, target, weapon, combo_index)
		results.append(result)

		if result["hit"]:
			target.take_damage(result["damage"])

	return results


func _calculate_hit(attacker: BaseCharacter, target: BaseCharacter, weapon: WeaponData, combo_index: int) -> Dictionary:
	var base_damage = weapon.get_combo_damage(combo_index) + attacker.attack_power
	var final_damage = base_damage
	var blocked = false

	# 格挡检测
	if target.is_blocking:
		var attacker_dir = sign(attacker.global_position.x - target.global_position.x)
		var target_facing = 1.0 if target.sprite_facing_right else -1.0
		# 只有面朝攻击方向时格挡才有效
		if sign(attacker_dir) == sign(target_facing) or attacker_dir == 0:
			final_damage *= 0.2
			blocked = true

	# 无敌检测
	if target.is_invincible:
		return {"hit": false, "damage": 0, "blocked": false}

	return {"hit": true, "damage": final_damage, "blocked": blocked}


## 远程攻击（弓族）
func spawn_projectile(
	shooter: BaseCharacter,
	projectile_scene: PackedScene,
	spawn_pos: Vector2,
	direction: Vector2,
	damage: float
) -> void:
	var projectile = projectile_scene.instantiate()
	projectile.global_position = spawn_pos
	projectile.direction = direction.normalized()
	projectile.damage = damage
	projectile.shooter = shooter
	shooter.get_tree().current_scene.add_child(projectile)
