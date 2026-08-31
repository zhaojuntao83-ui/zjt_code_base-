## 示范数据管理 - 存储和序列化示范录制数据
class_name DemonstrationData
extends RefCounted

var demo_id: String = ""
var category: String = ""  # parkour / combat / mixed
var frames: Array[Dictionary] = []
var duration: float = 0.0
var quality: Dictionary = {}
var created_at: String = ""


func get_frame_count() -> int:
	return frames.size()


func get_actions_summary() -> Dictionary:
	"""统计该示范中各动作出现的次数"""
	var summary = {}
	for frame in frames:
		var state = frame.get("current_state", "")
		if state:
			summary[state] = summary.get(state, 0) + 1
	return summary


func get_duration_by_state() -> Dictionary:
	"""统计各状态持续的时长（秒）"""
	var result = {}
	if frames.is_empty():
		return result

	var frame_duration = duration / maxf(frames.size(), 1)
	for frame in frames:
		var state = frame.get("current_state", "")
		if state:
			result[state] = result.get(state, 0.0) + frame_duration
	return result


func trim(start_time: float, end_time: float) -> DemonstrationData:
	"""截取指定时间段的数据"""
	var trimmed = DemonstrationData.new()
	trimmed.demo_id = demo_id + "_trimmed"
	trimmed.category = category

	for frame in frames:
		var t = frame.get("timestamp", 0.0)
		if t >= start_time and t <= end_time:
			trimmed.frames.append(frame.duplicate(true))

	trimmed.duration = end_time - start_time
	return trimmed


func serialize() -> Dictionary:
	return {
		"demo_id": demo_id,
		"category": category,
		"duration": duration,
		"quality": quality,
		"created_at": created_at,
		"frame_count": frames.size(),
		"frames": _serialize_frames(),
	}


func _serialize_frames() -> Array:
	"""序列化帧数据（将Vector2转为数组）"""
	var result = []
	for frame in frames:
		var f = frame.duplicate(true)
		if f.has("position") and f["position"] is Vector2:
			f["position"] = [f["position"].x, f["position"].y]
		if f.has("velocity") and f["velocity"] is Vector2:
			f["velocity"] = [f["velocity"].x, f["velocity"].y]
		result.append(f)
	return result


static func deserialize(data: Dictionary) -> DemonstrationData:
	var demo = DemonstrationData.new()
	demo.demo_id = data.get("demo_id", "")
	demo.category = data.get("category", "")
	demo.duration = data.get("duration", 0.0)
	demo.quality = data.get("quality", {})
	demo.created_at = data.get("created_at", "")

	for frame_data in data.get("frames", []):
		var f = frame_data.duplicate(true)
		if f.has("position") and f["position"] is Array:
			f["position"] = Vector2(f["position"][0], f["position"][1])
		if f.has("velocity") and f["velocity"] is Array:
			f["velocity"] = Vector2(f["velocity"][0], f["velocity"][1])
		demo.frames.append(f)

	return demo
