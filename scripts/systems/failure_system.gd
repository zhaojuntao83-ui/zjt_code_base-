## 失败惩罚与重试机制
## GDD: 惩罚失败但不打击热情，让失败成为有价值的提示
class_name FailureSystem
extends Node

# Boss战挑战机会
var boss_challenge_chances: int = 3
const MAX_BOSS_CHANCES: int = 3


func _ready() -> void:
	EventBus.level_failed.connect(_on_level_failed)
	EventBus.disciple_died.connect(_on_disciple_died)


func _on_level_failed(level_id: String, reason: String) -> void:
	var analysis = analyze_failure(reason)
	_show_failure_guidance(analysis)


func _on_disciple_died() -> void:
	if GameManager.active_disciple:
		GameManager.active_disciple.total_failures += 1


## 分析失败原因，给出具体建议
func analyze_failure(reason: String) -> Dictionary:
	var analysis = {
		"reason": reason,
		"suggestions": [],
		"recommended_actions": [],
	}

	match reason:
		"弟子阵亡":
			analysis["suggestions"].append("弟子体力不足，考虑装备更好的护甲")
			analysis["suggestions"].append("补录格挡或闪避的示范数据")
			analysis["suggestions"].append("在危险段使用接管精准示范一次躲避")
			analysis["recommended_actions"].append("buy_armor")
			analysis["recommended_actions"].append("record_dodge")

		"跌落深渊":
			analysis["suggestions"].append("补录跳跃相关的示范，特别是二段跳时机")
			analysis["suggestions"].append("在落差地形多录制几次示范，增加数据多样性")
			analysis["suggestions"].append("尝试在跌落点使用接管，直接示范正确路线")
			analysis["recommended_actions"].append("record_jump")

		"Boss击杀":
			analysis["suggestions"].append("在拆招训练关多练习Boss攻击模式")
			analysis["suggestions"].append("录制针对Boss前摇的闪避示范")
			analysis["suggestions"].append("考虑使用接管在关键时刻精准介入")
			analysis["suggestions"].append("Boss狂暴阶段攻击更强，需要额外录制应对大招的示范")
			analysis["recommended_actions"].append("boss_training")
			analysis["recommended_actions"].append("use_takeover")

		"时间耗尽":
			analysis["suggestions"].append("弟子行动犹豫不决，补录更流畅的跑酷示范")
			analysis["suggestions"].append("使用训练手册增加训练迭代次数")
			analysis["suggestions"].append("检查弟子是否在某处反复卡壳，针对该障碍补录")
			analysis["recommended_actions"].append("record_parkour")

		_:
			analysis["suggestions"].append("观察弟子在哪个环节卡住，针对性补录示范")

	return analysis


func _show_failure_guidance(analysis: Dictionary) -> void:
	"""
	修复：展示失败分析的所有建议，原先只显示第一条。
	第一条立即弹出，后续条目错开时间避免堆叠。
	"""
	if analysis["suggestions"].is_empty():
		EventBus.message_requested.emit("再试一次！", 3.0)
		return

	# 第一条立即显示
	EventBus.message_requested.emit("💡 " + analysis["suggestions"][0], 4.0)

	# 后续建议错开时间逐条显示
	for i in range(1, analysis["suggestions"].size()):
		var suggestion = analysis["suggestions"][i]
		get_tree().create_timer(float(i) * 3.5).timeout.connect(
			func(): EventBus.message_requested.emit("💡 " + suggestion, 3.5)
		)


## Boss战机会管理
func use_boss_chance() -> bool:
	if boss_challenge_chances <= 0:
		return false
	boss_challenge_chances -= 1
	return true


func refill_boss_chances() -> void:
	boss_challenge_chances = MAX_BOSS_CHANCES


func get_remaining_chances() -> int:
	return boss_challenge_chances
