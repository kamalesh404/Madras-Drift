extends Node

# ── Madras Drift ── Game Manager (Singleton)
# Add to AutoLoad in Project Settings as "GameManager"

signal game_paused
signal game_resumed
signal mission_started(mission_name)
signal mission_completed(mission_name)

# Game state
var is_paused: bool = false
var current_mission: String = ""
var player_money: int = 0
var play_time: float = 0.0

# World state
var current_weather: String = "clear"   # clear | rain | heavy_rain | storm
var time_of_day: float = 18.0           # 0–24 hours (18 = 6PM default)
var wanted_level: int = 0

# References
var player: CharacterBody3D = null

func _ready() -> void:
	print("🎮 Madras Drift — Game Manager Ready")

func _process(delta: float) -> void:
	if not is_paused:
		play_time += delta
		_advance_time(delta)

func _advance_time(delta: float) -> void:
	# 1 real second = 1 game minute
	time_of_day += delta / 60.0
	if time_of_day >= 24.0:
		time_of_day -= 24.0

func get_time_string() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60)
	return "%02d:%02d" % [h, m]

func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	emit_signal("game_paused")

func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	emit_signal("game_resumed")

func start_mission(mission_name: String) -> void:
	current_mission = mission_name
	emit_signal("mission_started", mission_name)
	print("Mission started: ", mission_name)

func complete_mission(mission_name: String, reward: int = 0) -> void:
	current_mission = ""
	player_money += reward
	emit_signal("mission_completed", mission_name)
	print("Mission complete: ", mission_name, " | Reward: ₹", reward)

func add_money(amount: int) -> void:
	player_money += amount

func set_weather(weather: String) -> void:
	current_weather = weather
	print("Weather changed to: ", weather)

func is_night() -> bool:
	return time_of_day >= 20.0 or time_of_day <= 6.0
