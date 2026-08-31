## 存档管理器 - 支持3个独立存档槽，自动保存和手动保存
extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3

var current_slot: int = -1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ========== 存档操作 ==========

func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false

	var data = _collect_save_data()
	var json_string = JSON.stringify(data, "\t")
	var path = _get_save_path(slot)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档 %s" % path)
		return false

	file.store_string(json_string)
	current_slot = slot
	return true


func load_game(slot: int) -> bool:
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_error("SaveManager: 存档不存在 %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var json_string = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("SaveManager: 存档数据损坏")
		return false

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	_apply_save_data(data)
	current_slot = slot
	return true


func delete_save(slot: int) -> bool:
	var path = _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))


func get_save_info(slot: int) -> Dictionary:
	"""获取存档槽的摘要信息（不加载完整数据）"""
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}

	var data = json.data
	return {
		"disciple_name": data.get("disciple_name", ""),
		"color_value": data.get("color_value", 0.0),
		"completed_levels": data.get("completed_levels", []).size(),
		"play_time": data.get("play_time", 0),
		"save_time": data.get("save_time", "")
	}


# ========== 自动存档 ==========

func auto_save() -> void:
	if current_slot >= 0:
		save_game(current_slot)


# ========== 内部方法 ==========

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.json" % slot


func _collect_save_data() -> Dictionary:
	var gm = GameManager
	var data = {
		"save_time": Time.get_datetime_string_from_system(),
		"difficulty": gm.difficulty,
		"exp_points": gm.exp_points,
		"total_exp_earned": gm.total_exp_earned,
		"unlocked_worlds": gm.unlocked_worlds,
		"completed_levels": gm.completed_levels,
		"owned_weapons": gm.owned_weapons,
		"owned_armor": gm.owned_armor,
		"owned_consumables": gm.owned_consumables,
		"takeover_charges_level": gm.takeover_charges_level,
		"takeover_duration_level": gm.takeover_duration_level,
		"takeover_cooldown_level": gm.takeover_cooldown_level,
	}

	# 弟子数据
	if gm.active_disciple:
		data["disciple"] = gm.active_disciple.to_dict()
		data["disciple_name"] = gm.active_disciple.disciple_name
		data["color_value"] = gm.active_disciple.color_value

	# 退休弟子
	var retired_list = []
	for d in gm.retired_disciples:
		retired_list.append(d.to_dict())
	data["retired_disciples"] = retired_list

	# 训练背包（示范卡片）
	if gm.training_backpack:
		data["training_backpack"] = gm.training_backpack.to_save_data()

	# 成就系统
	if gm.achievement_system:
		data["achievements"] = gm.achievement_system.to_save_data()

	# 新手引导进度
	if gm.tutorial_system:
		data["tutorial"] = gm.tutorial_system.to_save_data()

	return data


func _apply_save_data(data: Dictionary) -> void:
	var gm = GameManager
	gm.difficulty = data.get("difficulty", GameManager.Difficulty.NORMAL)
	gm.exp_points = data.get("exp_points", 0)
	gm.total_exp_earned = data.get("total_exp_earned", 0)
	gm.unlocked_worlds = data.get("unlocked_worlds", ["world_1"])
	gm.completed_levels = data.get("completed_levels", [])
	gm.owned_weapons = data.get("owned_weapons", [])
	gm.owned_armor = data.get("owned_armor", [])
	gm.owned_consumables = data.get("owned_consumables", {})
	gm.takeover_charges_level = data.get("takeover_charges_level", 0)
	gm.takeover_duration_level = data.get("takeover_duration_level", 0)
	gm.takeover_cooldown_level = data.get("takeover_cooldown_level", 0)

	# 恢复弟子
	if data.has("disciple"):
		gm.active_disciple = DiscipleData.from_dict(data["disciple"])

	gm.retired_disciples.clear()
	for d_data in data.get("retired_disciples", []):
		gm.retired_disciples.append(DiscipleData.from_dict(d_data))

	# 恢复训练背包
	if gm.training_backpack and data.has("training_backpack"):
		gm.training_backpack.load_from_save_data(data["training_backpack"])

	# 恢复成就数据
	if gm.achievement_system and data.has("achievements"):
		gm.achievement_system.from_save_data(data["achievements"])

	# 恢复新手引导进度
	if gm.tutorial_system and data.has("tutorial"):
		gm.tutorial_system.from_save_data(data["tutorial"])
