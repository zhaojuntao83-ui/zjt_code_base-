## 武器族系统 - 同族武器只需示范一次，弟子可举一反三
## GDD: 同族武器握持方式和动作相似，学一即通；不同族差异大需重新示范
class_name WeaponFamily
extends RefCounted

enum Family { SWORD, SPEAR, BOW, DUAL_BLADE, HEAVY }

# 武器族定义
const FAMILY_DATA = {
	Family.SWORD: {
		"name": "剑族",
		"description": "平衡型，攻速与伤害兼顾",
		"weapons": ["wooden_sword", "iron_sword", "steel_blade", "katana"],
		"attack_style": "slash",       # 挥砍
		"training_direction": "近战反击、格挡后输出",
	},
	Family.SPEAR: {
		"name": "枪族",
		"description": "长距离刺击，保持间距",
		"weapons": ["long_spear", "pike", "halberd"],
		"attack_style": "thrust",      # 刺击
		"training_direction": "利用地形保持距离攻击",
	},
	Family.BOW: {
		"name": "弓族",
		"description": "远程攻击，需要站位",
		"weapons": ["short_bow", "long_bow", "crossbow"],
		"attack_style": "ranged",      # 远程
		"training_direction": "高台狙击、Boss战消耗",
	},
	Family.DUAL_BLADE: {
		"name": "双刀族",
		"description": "攻速极快，伤害较低",
		"weapons": ["dual_daggers", "dual_swords", "claws"],
		"attack_style": "rapid",       # 连击
		"training_direction": "连招、高频骚扰",
	},
	Family.HEAVY: {
		"name": "重武器族",
		"description": "高伤害，攻速慢",
		"weapons": ["greatsword", "battle_axe", "war_hammer"],
		"attack_style": "charge",      # 蓄力重击
		"training_direction": "等待时机一击重创Boss",
	},
}


static func get_family_name(family: Family) -> String:
	return FAMILY_DATA.get(family, {}).get("name", "未知")


static func are_same_family(weapon_a_id: String, weapon_b_id: String) -> bool:
	"""检查两把武器是否同族（用于判断是否需要重新示范）"""
	var family_a = _find_family(weapon_a_id)
	var family_b = _find_family(weapon_b_id)
	return family_a == family_b and family_a != -1


static func get_transfer_efficiency(from_weapon: String, to_weapon: String) -> float:
	"""计算武器间技能迁移效率（同族高，不同族低）"""
	if are_same_family(from_weapon, to_weapon):
		return 0.85  # 同族85%迁移
	return 0.1  # 不同族仅10%


static func _find_family(weapon_id: String) -> int:
	for family in FAMILY_DATA:
		if weapon_id in FAMILY_DATA[family]["weapons"]:
			return family
	return -1
