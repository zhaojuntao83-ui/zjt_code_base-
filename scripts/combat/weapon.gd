## 武器基础资源定义
class_name WeaponData
extends Resource

@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var family: WeaponFamily.Family = WeaponFamily.Family.SWORD
@export var damage: float = 10.0
@export var attack_speed: float = 1.0      # 攻速倍率
@export var range_distance: float = 50.0    # 攻击距离
@export var charge_time: float = 0.0        # 蓄力时间（重武器）
@export var description: String = ""
@export var price: int = 100
@export var sprite_path: String = ""

# 连招支持
@export var max_combo: int = 3
@export var combo_damage_multipliers: Array[float] = [1.0, 1.2, 1.5]


func get_combo_damage(combo_index: int) -> float:
	if combo_index < combo_damage_multipliers.size():
		return damage * combo_damage_multipliers[combo_index]
	return damage
