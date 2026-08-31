## 商店界面
## GDD: 清晰展示当前经验点余额，商品分类明确
extends Control

@onready var category_tabs: TabContainer = $HSplit/Left/CategoryTabs
@onready var item_detail: VBoxContainer = $HSplit/Right/ItemDetail
@onready var buy_btn: Button = $HSplit/Right/BuyBtn
@onready var exp_label: Label = $TopBar/ExpLabel
@onready var back_btn: Button = $TopBar/BackBtn

var shop: ShopSystem
var selected_item_id: String = ""


func _ready() -> void:
	shop = ShopSystem.new()
	add_child(shop)

	back_btn.pressed.connect(_go_back)
	buy_btn.pressed.connect(_buy_item)
	buy_btn.disabled = true

	EventBus.exp_points_changed.connect(func(_v): _update_exp())

	_update_exp()
	_populate_tabs()


func _update_exp() -> void:
	exp_label.text = "经验点: %d" % GameManager.exp_points


func _populate_tabs() -> void:
	# 清除旧标签页，避免反复调用时内容累积
	for child in category_tabs.get_children():
		child.queue_free()

	var categories = [
		{"key": "weapon", "name": "武器"},
		{"key": "armor", "name": "护甲"},
		{"key": "consumable", "name": "消耗品"},
		{"key": "takeover_item", "name": "接管道具"},
		{"key": "training_item", "name": "训练道具"},
	]

	for cat in categories:
		var scroll = ScrollContainer.new()
		scroll.name = cat["name"]
		var vbox = VBoxContainer.new()
		scroll.add_child(vbox)
		category_tabs.add_child(scroll)

		var items = shop.get_items_by_category(cat["key"])
		for item in items:
			var btn = Button.new()
			var owned_text = " [已拥有]" if shop.is_owned(item["id"]) else ""
			var count_text = ""
			if cat["key"] in ["consumable", "takeover_item", "training_item"]:
				var count = GameManager.owned_consumables.get(item["id"], 0)
				if count > 0:
					count_text = " (x%d)" % count
			btn.text = "%s  %d点%s%s" % [item["name"], item["price"], owned_text, count_text]
			var iid = item["id"]
			btn.pressed.connect(func(): _select_item(iid))
			vbox.add_child(btn)


func _select_item(item_id: String) -> void:
	selected_item_id = item_id
	var item = shop.get_item_info(item_id)
	if item.is_empty():
		return

	for child in item_detail.get_children():
		child.queue_free()

	var name_label = Label.new()
	name_label.text = item["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	item_detail.add_child(name_label)

	var price_label = Label.new()
	price_label.text = "价格: %d 经验点" % item["price"]
	item_detail.add_child(price_label)

	var desc_label = Label.new()
	desc_label.text = item["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_detail.add_child(desc_label)

	# 武器族信息
	if item["category"] == "weapon":
		var family = WeaponFamily._find_family(item_id)
		if family >= 0:
			var family_label = Label.new()
			family_label.text = "武器族: %s" % WeaponFamily.get_family_name(family)
			item_detail.add_child(family_label)

	buy_btn.disabled = not shop.can_afford(item_id) or shop.is_owned(item_id)
	buy_btn.text = "购买" if not shop.is_owned(item_id) else "已拥有"


func _buy_item() -> void:
	if selected_item_id.is_empty():
		return
	if shop.purchase(selected_item_id):
		EventBus.message_requested.emit("购买成功!", 1.5)
		_populate_tabs()
		_select_item(selected_item_id)


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/training_camp.tscn")
