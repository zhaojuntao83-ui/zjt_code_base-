## 师傅角色 - 玩家控制，负责示范动作
extends BaseCharacter

@export var equipped_weapon: Resource = null


func _ready() -> void:
	super._ready()
	add_to_group("master")


func die() -> void:
	# 师傅死亡 = 示范失败，不影响游戏进度
	EventBus.message_requested.emit("示范失败，请重试", 2.0)
	# 重置到关卡起点
	_respawn()


func _respawn() -> void:
	health = max_health
	velocity = Vector2.ZERO
	# 子场景中应设置 spawn_position
	if has_meta("spawn_position"):
		global_position = get_meta("spawn_position")
	state_machine.transition_to("idle")


## 装备武器（用于示范给弟子看）
func equip_weapon(weapon_resource: Resource) -> void:
	equipped_weapon = weapon_resource
	EventBus.equipment_changed.emit("weapon", weapon_resource)
