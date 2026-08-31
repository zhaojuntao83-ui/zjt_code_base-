## 音频管理器 - 工业电子风格音效系统，随弟子成长动态变化
extends Node

# 音乐总线
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8

var music_volume: float = 0.8
var sfx_volume: float = 1.0
var current_music_id: String = ""


func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	for i in MAX_SFX_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)


# ========== 音乐控制 ==========

func play_music(music_id: String, fade_duration: float = 1.0) -> void:
	if music_id == current_music_id:
		return

	var path = "res://assets/audio/music/%s.ogg" % music_id
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: 音乐资源不存在 %s" % path)
		return

	# 淡出当前音乐
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
		await tween.finished

	music_player.stream = load(path)
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()
	current_music_id = music_id


func stop_music(fade_duration: float = 1.0) -> void:
	if not music_player.playing:
		return
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
	await tween.finished
	music_player.stop()
	current_music_id = ""


# ========== 音效播放 ==========

func play_sfx(sfx_id: String, volume_scale: float = 1.0) -> void:
	var path = "res://assets/audio/sfx/%s.wav" % sfx_id
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: 音效资源不存在 %s" % path)
		return

	# 查找空闲的音效播放器
	for player in sfx_players:
		if not player.playing:
			player.stream = load(path)
			player.volume_db = linear_to_db(sfx_volume * volume_scale)
			player.play()
			return

	# 所有播放器都在使用中，复用最早的那个
	sfx_players[0].stream = load(path)
	sfx_players[0].volume_db = linear_to_db(sfx_volume * volume_scale)
	sfx_players[0].play()


# GDD关键音效接口
func play_record_start() -> void:
	play_sfx("record_start")  # 金属卡嗒声，像录像机启动

func play_disciple_success() -> void:
	play_sfx("disciple_success")  # 短促的电子确认音

func play_takeover_activate() -> void:
	play_sfx("takeover_activate")  # 低沉切换音效

func play_takeover_warning() -> void:
	play_sfx("takeover_warning")  # 警告蜂鸣声

func play_boss_victory() -> void:
	play_sfx("boss_victory")  # 渐强电子胜利曲

func play_color_change() -> void:
	play_sfx("color_change", 0.3)  # 极轻微的金属摩擦声


# ========== 音量设置 ==========

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
