## 训练风格分析器 - 根据示范数据统计弟子的训练风格标签
## GDD §22.2: 激进型 / 优雅型 / 保守型 / 狙击型 / 全能型
## 被 Disciple.learn_from_demonstration 调用，每次录制后更新风格得分
class_name TrainingStyleAnalyzer
extends RefCounted


static func analyze(demo_data: Dictionary) -> Dictionary:
	"""
	分析一次示范录制，返回各风格得分增量。
	调用方将增量累加到 DiscipleData.training_style_scores。
	"""
	var frames = demo_data.get("frames", [])
	var increments = {
		"aggressive": 0,
		"elegant": 0,
		"defensive": 0,
		"sniper": 0,
	}

	var total = frames.size()
	if total == 0:
		return increments

	var slide_count = 0       # 滑铲
	var air_attack_count = 0  # 空中攻击（空翻系列）
	var block_count = 0       # 格挡
	var idle_count = 0        # 停顿/等待
	var ranged_count = 0      # 静止状态下的攻击（粗略判断远程）

	for frame in frames:
		var state = frame.get("current_state", "")
		match state:
			"slide":
				slide_count += 1
			"air_attack":
				air_attack_count += 1
			"block":
				block_count += 1
			"idle":
				idle_count += 1
			"attack":
				# 静止攻击（速度接近零）粗略视为远程站桩
				var vel = frame.get("velocity", Vector2.ZERO)
				if vel is Vector2 and absf(vel.x) < 50:
					ranged_count += 1

	# 激进型：滑铲比例高
	increments["aggressive"] = roundi(float(slide_count) / total * 10.0)

	# 优雅型：空中攻击比例高
	increments["elegant"] = roundi(float(air_attack_count) / total * 10.0)

	# 保守型：格挡 + 停顿比例高
	increments["defensive"] = roundi(float(block_count + idle_count) / total * 5.0)

	# 狙击型：站桩远程攻击比例高
	increments["sniper"] = roundi(float(ranged_count) / total * 10.0)

	return increments


static func get_dominant_style(scores: Dictionary) -> String:
	"""根据累计得分返回主要训练风格标签"""
	if scores.is_empty():
		return "全能型"

	var max_score = 0
	var dominant = ""
	for style in scores:
		if scores[style] > max_score:
			max_score = scores[style]
			dominant = style

	if max_score == 0:
		return "全能型"

	# 全能型判断：最高与最低得分差距很小
	var values = scores.values()
	values.sort()
	if values.back() - values.front() <= 2:
		return "全能型"

	var style_names = {
		"aggressive": "激进型",
		"elegant": "优雅型",
		"defensive": "保守型",
		"sniper": "狙击型",
	}
	return style_names.get(dominant, "全能型")
