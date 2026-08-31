## 全局事件总线 - 解耦系统间通信
extends Node

# ========== 录制系统 ==========
signal recording_started
signal recording_stopped(demonstration_data: Dictionary)
signal demonstration_quality_evaluated(score: Dictionary)
signal recording_quality_preview_updated(score: Dictionary)  # 录制中实时质量预览（新增）

# ========== 训练系统 ==========
signal training_started(card_id: String)
signal training_iteration_completed(iteration: int, success_rate: float)
signal training_completed(card_id: String, result: Dictionary)
signal training_speed_changed(multiplier: float)

# ========== 接管系统 ==========
signal takeover_activated
signal takeover_deactivated(recorded_data: Dictionary)
signal takeover_charges_changed(remaining: int)
signal takeover_cooldown_updated(time_left: float)

# ========== 弟子系统 ==========
signal disciple_created(disciple_data: Dictionary)
signal disciple_color_changed(new_color: Color)
signal disciple_attribute_changed(attribute: String, new_value: float)
signal disciple_learned_action(action_name: String)
signal disciple_retired(disciple_data: Dictionary)
signal disciple_damaged(amount: float)
signal disciple_died
signal disciple_training_style_changed(style: String)  # 训练风格标签变化（新增）

# ========== 战斗系统 ==========
signal weapon_picked_up(weapon_data: Dictionary)
signal enemy_defeated(enemy_type: String, exp_reward: int)
signal boss_phase_changed(boss_id: String, phase: int)
signal boss_attack_warning(area: Rect2, duration: float)
signal boss_defeated(boss_id: String, exp_reward: int)

# ========== 关卡系统 ==========
signal level_started(level_id: String)
signal level_completed(level_id: String, stats: Dictionary)
signal level_failed(level_id: String, reason: String)
signal world_unlocked(world_id: String)

# ========== 经济系统 ==========
signal exp_points_changed(amount: int)
signal item_purchased(item_id: String)
signal equipment_changed(slot: String, item_data: Dictionary)

# ========== 训练背包 ==========
signal card_forgotten(card_id: String, frame_data: Array, decay_amount: float)  # 遗忘曲线触发（新增）

# ========== 成就系统 ==========
signal achievement_unlocked(achievement_id: String)
signal milestone_reached(milestone_id: String)

# ========== UI ==========
signal message_requested(text: String, duration: float)
signal dialog_requested(speaker: String, text: String)
