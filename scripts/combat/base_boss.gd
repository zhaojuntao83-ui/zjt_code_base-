## Boss基类 - 各世界的最终Boss
## GDD: Boss战是最高难度训练场景，攻击有预警，分两阶段训练
class_name BaseBoss
extends BaseEnemy

@export var boss_id: String = ""
@export var boss_display_name: String = ""
@export var phase_count: int = 2
@export var warning_duration: float = 1.0  # Boss预警时间比普通敌人长

var current_phase: int = 1
var phase_health_thresholds: Array[float] = [0.5]  # 50%血量切换阶段
var attack_patterns: Array[Dictionary] = []
var current_pattern_index: int = 0

# Boss专属
var is_enraged: bool = false
var special_attack_cooldown: float = 0.0
const SPECIAL_COOLDOWN: float = 8.0


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	remove_from_group("enemies")  # Boss不算普通敌人
	detection_range = 500.0
	attack_warning_duration = warning_duration


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if special_attack_cooldown > 0:
		special_attack_cooldown -= delta

	_check_phase_transition()


func _check_phase_transition() -> void:
	"""检查是否需要切换阶段"""
	if not is_alive:
		return

	var health_ratio = health / max_health
	for i in range(phase_health_thresholds.size()):
		if health_ratio <= phase_health_thresholds[i] and current_phase <= i + 1:
			_enter_phase(i + 2)
			break


func _enter_phase(phase: int) -> void:
	current_phase = phase
	is_enraged = phase >= phase_count
	EventBus.boss_phase_changed.emit(boss_id, phase)

	# 阶段切换时短暂无敌（给玩家反应时间）
	if anim_player and anim_player.has_animation("phase_transition"):
		anim_player.play("phase_transition")


func _ai_attack(_delta: float) -> void:
	"""Boss攻击AI：按照攻击模式循环"""
	if is_attacking:
		return

	is_attacking = true

	# 选择攻击模式
	var pattern = _select_attack_pattern()
	await _execute_attack_pattern(pattern)

	is_attacking = false
	current_state = State.CHASE


func _select_attack_pattern() -> Dictionary:
	"""选择攻击模式（根据阶段和距离）"""
	if attack_patterns.is_empty():
		return {"type": "basic", "damage": attack_damage}

	# 狂暴阶段使用更强力的攻击
	if is_enraged and special_attack_cooldown <= 0:
		special_attack_cooldown = SPECIAL_COOLDOWN
		return {"type": "special", "damage": attack_damage * 2.5}

	# 循环切换攻击模式
	current_pattern_index = (current_pattern_index + 1) % attack_patterns.size()
	return attack_patterns[current_pattern_index]


func _execute_attack_pattern(pattern: Dictionary) -> void:
	"""执行攻击模式"""
	match pattern.get("type", "basic"):
		"basic":
			await _basic_attack(pattern.get("damage", attack_damage))
		"aoe":
			await _aoe_attack(pattern)
		"charge":
			await _charge_attack(pattern)
		"ranged":
			await _ranged_attack(pattern)
		"special":
			await _special_attack(pattern)
		_:
			await _basic_attack(pattern.get("damage", attack_damage))


func _basic_attack(damage: float) -> void:
	"""基础近战攻击（带预警）"""
	var warning_rect = _get_attack_warning_rect()
	EventBus.boss_attack_warning.emit(warning_rect, warning_duration)
	await get_tree().create_timer(warning_duration).timeout

	if target and target is BaseCharacter:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range * 1.5:
			target.take_damage(damage)

	await get_tree().create_timer(0.5).timeout


func _aoe_attack(pattern: Dictionary) -> void:
	"""范围攻击（显示红色警示区域）"""
	var aoe_range = pattern.get("range", 150.0)
	var damage = pattern.get("damage", attack_damage * 1.5)

	# 显示AOE预警
	var warning_rect = Rect2(
		global_position - Vector2(aoe_range, aoe_range),
		Vector2(aoe_range * 2, aoe_range * 2)
	)
	EventBus.boss_attack_warning.emit(warning_rect, warning_duration * 1.5)
	await get_tree().create_timer(warning_duration * 1.5).timeout

	# 范围内所有目标受伤
	var targets = get_tree().get_nodes_in_group("disciple")
	for t in targets:
		if t is BaseCharacter:
			var dist = global_position.distance_to(t.global_position)
			if dist <= aoe_range:
				t.take_damage(damage)

	await get_tree().create_timer(0.8).timeout


func _charge_attack(pattern: Dictionary) -> void:
	"""蓄力冲锋攻击"""
	var charge_speed = pattern.get("speed", move_speed * 3)
	var damage = pattern.get("damage", attack_damage * 2)

	# 蓄力预警
	EventBus.boss_attack_warning.emit(_get_charge_warning_rect(), warning_duration)
	await get_tree().create_timer(warning_duration).timeout

	# 冲锋
	if target:
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * charge_speed
		await get_tree().create_timer(0.5).timeout
		velocity.x = 0

	await get_tree().create_timer(0.5).timeout


func _ranged_attack(pattern: Dictionary) -> void:
	"""远程攻击"""
	EventBus.boss_attack_warning.emit(_get_attack_warning_rect(), warning_duration)
	await get_tree().create_timer(warning_duration).timeout
	# 子类实现具体远程攻击逻辑
	await get_tree().create_timer(0.5).timeout


func _special_attack(pattern: Dictionary) -> void:
	"""特殊大招（狂暴阶段）"""
	# 子类重写具体大招逻辑
	await _aoe_attack({"range": 200.0, "damage": attack_damage * 2.5})


func _get_charge_warning_rect() -> Rect2:
	if not target:
		return Rect2()
	var dir = sign(target.global_position.x - global_position.x)
	var width = absf(target.global_position.x - global_position.x) + 50
	var origin = Vector2(minf(global_position.x, target.global_position.x) - 25, global_position.y - 30)
	return Rect2(origin, Vector2(width, 60))


func die() -> void:
	is_alive = false
	current_state = State.DEAD
	EventBus.boss_defeated.emit(boss_id, exp_reward)
	AudioManager.play_boss_victory()

	if GameManager.active_disciple:
		if boss_id not in GameManager.active_disciple.bosses_defeated:
			GameManager.active_disciple.bosses_defeated.append(boss_id)

	if anim_player and anim_player.has_animation("death"):
		anim_player.play("death")
		await anim_player.animation_finished

	# Boss不立刻消失，等待胜利动画
	await get_tree().create_timer(2.0).timeout
	queue_free()
