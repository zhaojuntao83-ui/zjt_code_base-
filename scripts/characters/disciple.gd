## 弟子角色 - AI控制的机器人，通过模仿师傅学习
extends BaseCharacter

# ========== 弟子专属属性 ==========
var disciple_data: DiscipleData
var ai_controller: AIController
var color_growth_system: ColorGrowthSystem

# 颜色成长：0.0=深黑 -> 1.0=近白色
var color_value: float = 0.0:
	set(val):
		color_value = clampf(val, 0.0, 1.0)
		_update_visual_color()
		EventBus.disciple_color_changed.emit(get_display_color())

# 成长属性
var learning_ability: float = 1.0   # 学习力
var reaction_speed: float = 0.5     # 反应速度（0-1）
var endurance: float = 0.5          # 耐力

# AI控制标志
var is_ai_controlled: bool = true
var is_being_taken_over: bool = false

# 弟子对话冷却（避免连续打断式说话）
var _dialogue_cooldown: float = 0.0
const DIALOGUE_COOLDOWN: float = 15.0

# 连续成功计数（触发突破感悟对话）
var _consecutive_successes: int = 0


func _ready() -> void:
	super._ready()
	add_to_group("disciple")

	ai_controller = AIController.new()
	ai_controller.character = self
	add_child(ai_controller)

	# 初始化颜色成长系统（修复：弟子自己持有，供训练系统调用）
	color_growth_system = ColorGrowthSystem.new()
	add_child(color_growth_system)

	# 绑定当前弟子数据（关卡启动时 GameManager.active_disciple 已设置）
	disciple_data = GameManager.active_disciple

	# 监听卡片删除事件，触发遗忘曲线
	EventBus.card_forgotten.connect(_on_card_forgotten)

	_update_visual_color()


func _physics_process(delta: float) -> void:
	if is_ai_controlled and not is_being_taken_over:
		ai_controller.think_and_act()
	if _dialogue_cooldown > 0:
		_dialogue_cooldown -= delta


# ========== 颜色系统 ==========

func get_display_color() -> Color:
	"""优先使用 ColorGrowthSystem 的整体颜色"""
	if color_growth_system:
		return color_growth_system.get_overall_display_color()
	return _color_from_value(color_value)


func _color_from_value(v: float) -> Color:
	var dark = Color(0.1, 0.1, 0.12)
	var mid = Color(0.45, 0.47, 0.5)
	var bright = Color(0.88, 0.9, 0.95)
	if v < 0.5:
		return dark.lerp(mid, v * 2.0)
	else:
		return mid.lerp(bright, (v - 0.5) * 2.0)


func get_growth_stage() -> String:
	if color_growth_system:
		return color_growth_system.get_growth_stage()
	return "初创期"


func _update_visual_color() -> void:
	if sprite:
		sprite.modulate = get_display_color()


# ========== 学习与成长 ==========

func learn_from_demonstration(demo_data: Dictionary) -> void:
	"""接收示范数据，触发学习"""
	var category = demo_data.get("category", "")
	var quality = demo_data.get("quality", {}).get("overall", 1)

	# 修复：临时调整学习率，不永久累乘破坏基础值
	var multiplier = _get_talent_multiplier(category)

	# PERFECT_MIMIC 天赋：示范质量 ≥ 4星时额外 +30% 模仿精度
	if disciple_data and disciple_data.talent == GameManager.Talent.PERFECT_MIMIC and quality >= 4:
		multiplier *= 1.3

	var original_lr = ai_controller.learning_rate
	ai_controller.learning_rate = ai_controller.base_learning_rate * multiplier
	ai_controller.add_training_data(demo_data)
	ai_controller.learning_rate = original_lr  # 恢复，不留副作用

	# 分析并更新训练风格得分（TrainingStyleAnalyzer.analyze 是静态方法，无需实例化）
	if disciple_data:
		var increments = TrainingStyleAnalyzer.analyze(demo_data)
		for style in increments:
			disciple_data.training_style_scores[style] = \
				disciple_data.training_style_scores.get(style, 0) + increments[style]


func grow_color(amount: float) -> void:
	"""兼容旧接口，直接更新整体颜色值"""
	var prev_stage = get_growth_stage()
	color_value = clampf(color_value + amount, 0.0, 1.0)
	# 同步 color_growth_system.overall_color 以保证 get_growth_stage() 读值正确
	# 注意：不调用 apply_training_result，避免覆盖其按部位精细计算的结果
	if color_growth_system:
		color_growth_system.overall_color = maxf(color_growth_system.overall_color, color_value)
	var new_stage = get_growth_stage()
	if new_stage != prev_stage:
		AudioManager.play_color_change()
		EventBus.milestone_reached.emit("color_stage_%s" % new_stage)
		_trigger_dialogue_milestone(new_stage)


func on_training_finished(skill_name: String, success_rate: float) -> void:
	"""
	训练完成后同步双色系统：
	- ColorGrowthSystem 按技能更新各部位颜色
	- Disciple.color_value 同步整体颜色值
	修复：原先 TrainingSystem 直接调 grow_color 绕过了 ColorGrowthSystem
	"""
	if color_growth_system:
		color_growth_system.apply_training_result(skill_name, success_rate)
		# 同步整体颜色值：只升不降（grow_color 可能已写入更高的值）
		var prev_stage = get_growth_stage()
		color_value = maxf(color_value, color_growth_system.overall_color)
		_update_visual_color()
		var new_stage = get_growth_stage()
		if new_stage != prev_stage:
			AudioManager.play_color_change()
			EventBus.milestone_reached.emit("color_stage_%s" % new_stage)
			_trigger_dialogue_milestone(new_stage)

	# 连续成功触发突破感悟对话
	if success_rate >= 0.8:
		_consecutive_successes += 1
		if _consecutive_successes >= 3:
			_consecutive_successes = 0
			_trigger_dialogue_breakthrough()
	else:
		_consecutive_successes = 0


# ========== 遗忘曲线 ==========

func _on_card_forgotten(_card_id: String, frame_data: Array, decay_amount: float) -> void:
	"""卡片被删除时，AI逐渐淡忘相关策略（遗忘曲线）"""
	ai_controller.decay_policy_from_card(frame_data, decay_amount)


# ========== 弟子对话 ==========

func _trigger_dialogue_milestone(stage: String) -> void:
	"""阶段跃迁时发出感悟"""
	if _dialogue_cooldown > 0:
		return
	_dialogue_cooldown = DIALOGUE_COOLDOWN
	var lines = {
		"入门期": "我...好像有点感觉了。",
		"成长期": "师傅，我开始明白你的意思了。",
		"熟练期": "这些动作，已经刻进我的记忆里了。",
		"精通期": "我...已经超越你当年了吗？",
	}
	if lines.has(stage):
		EventBus.dialog_requested.emit("弟子", lines[stage])


func _trigger_dialogue_breakthrough() -> void:
	"""连续成功时发出突破感悟"""
	if _dialogue_cooldown > 0:
		return
	_dialogue_cooldown = DIALOGUE_COOLDOWN
	var lines = [
		"连续成功！我好像突破了什么。",
		"我记住了，下次不会再犯同样的错误。",
		"越来越熟练了...",
	]
	EventBus.dialog_requested.emit("弟子", lines[randi() % lines.size()])


func trigger_dialogue_confused() -> void:
	"""连续失败时表达困惑（供外部调用）"""
	if _dialogue_cooldown > 0:
		return
	_dialogue_cooldown = DIALOGUE_COOLDOWN
	var lines = [
		"这个动作...我还不太明白。",
		"师傅，能再示范一次吗？",
		"我有点卡住了...",
	]
	EventBus.dialog_requested.emit("弟子", lines[randi() % lines.size()])


func _get_talent_multiplier(category: String) -> float:
	if disciple_data == null:
		return 1.0
	var talent = disciple_data.talent
	var talent_data = GameManager.TALENT_DATA.get(talent, {})
	match category:
		"parkour":
			return talent_data.get("parkour_multiplier", 1.0)
		"combat":
			return talent_data.get("combat_multiplier", 1.0)
		_:
			return 1.0


# ========== 接管 ==========

func start_takeover() -> void:
	is_being_taken_over = true
	is_ai_controlled = false


func end_takeover() -> void:
	is_being_taken_over = false
	is_ai_controlled = true


# ========== 死亡 ==========

func die() -> void:
	# 停止 AI 决策，防止死亡后继续触发移动/攻击
	is_ai_controlled = false
	# 禁用碰撞，避免同帧重复触发死亡事件
	set_collision_layer(0)
	set_collision_mask(0)
	velocity = Vector2.ZERO
	EventBus.disciple_died.emit()
	trigger_dialogue_confused()
	# 目前无独立 dead 状态，转 idle 等待 base_level 重载关卡
	if state_machine:
		state_machine.transition_to("idle")
