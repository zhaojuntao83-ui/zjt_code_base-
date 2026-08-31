## 兵器架界面 - 查看和切换装备的武器防具
## GDD: 装备不是买了直接给弟子，需要先示范如何使用
extends Control

@onready var weapon_list: VBoxContainer = $HSplit/Left/ScrollContainer/WeaponList
@onready var armor_list: VBoxContainer = $HSplit/Left/ScrollContainer2/ArmorList
@onready var detail_panel: VBoxContainer = $HSplit/Right/Detail
@onready var equip_btn: Button = $HSplit/Right/EquipBtn
@onready var back_btn: Button = $TopBar/BackBtn

var selected_item_id: String = ""
var selected_type: String = ""  # "weapon" or "armor"


func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn"))
	equip_btn.pressed.connect(_equip_selected)
	equip_btn.disabled = true
	_populate_lists()


func _populate_lists() -> void:
	# 武器列表
	for child in weapon_list.get_children():
		child.queue_free()

	if GameManager.owned_weapons.is_empty():
		var label = Label.new()
		label.text = "尚未拥有武器\n前往商铺购买"
		weapon_list.add_child(label)
	else:
		for wid in GameManager.owned_weapons:
			var btn = Button.new()
			var family = WeaponFamily._find_family(wid)
			var family_name = WeaponFamily.get_family_name(family) if family >= 0 else ""
			btn.text = "%s [%s]" % [wid, family_name]
			var id = wid
			btn.pressed.connect(func(): _select_item(id, "weapon"))
			weapon_list.add_child(btn)

	# 护甲列表
	for child in armor_list.get_children():
		child.queue_free()

	if GameManager.owned_armor.is_empty():
		var label = Label.new()
		label.text = "尚未拥有护甲"
		armor_list.add_child(label)
	else:
		for aid in GameManager.owned_armor:
			var btn = Button.new()
			btn.text = aid
			var id = aid
			btn.pressed.connect(func(): _select_item(id, "armor"))
			armor_list.add_child(btn)


func _select_item(item_id: String, type: String) -> void:
	selected_item_id = item_id
	selected_type = type
	equip_btn.disabled = false

	for child in detail_panel.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = item_id
	title.add_theme_font_size_override("font_size", 20)
	detail_panel.add_child(title)

	if type == "weapon":
		var family = WeaponFamily._find_family(item_id)
		if family >= 0:
			var family_data = WeaponFamily.FAMILY_DATA.get(family, {})
			var info = Label.new()
			info.text = "武器族: %s\n特点: %s\n适合: %s" % [
				family_data.get("name", ""),
				family_data.get("description", ""),
				family_data.get("training_direction", ""),
			]
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail_panel.add_child(info)

	# 装备使用逻辑提示
	var tip = Label.new()
	tip.text = "\n装备说明：\n1. 装备后进入示范模式\n2. 亲自示范如何使用\n3. 弟子通过模仿学会使用方式\n4. 学会后装备才在弟子身上生效"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(tip)


func _equip_selected() -> void:
	if selected_item_id.is_empty():
		return

	EventBus.equipment_changed.emit(selected_type, {"id": selected_item_id})
	EventBus.message_requested.emit("已装备 %s，进入示范模式后可使用" % selected_item_id, 2.0)
