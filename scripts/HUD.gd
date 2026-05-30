extends CanvasLayer

# ── Madras Drift ── HUD
# Attach to a CanvasLayer in Main scene

@onready var health_bar: ProgressBar    = $HUDContainer/HealthBar
@onready var health_label: Label        = $HUDContainer/HealthLabel
@onready var money_label: Label         = $HUDContainer/MoneyLabel
@onready var speed_label: Label         = $HUDContainer/SpeedLabel
@onready var time_label: Label          = $HUDContainer/TimeLabel
@onready var weather_label: Label       = $HUDContainer/WeatherLabel
@onready var wanted_container: HBoxContainer = $HUDContainer/WantedStars
@onready var nitro_bar: ProgressBar     = $HUDContainer/NitroBar
@onready var mission_label: Label       = $HUDContainer/MissionLabel

var player: CharacterBody3D = null
var bike: VehicleBody3D = null

func _ready() -> void:
	# Connect to GameManager signals
	GameManager.connect("mission_started", _on_mission_started)
	GameManager.connect("mission_completed", _on_mission_completed)
	_update_wanted_stars(0)

func _process(_delta: float) -> void:
	# Live updates — safe check for GameManager autoload
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		time_label.text = gm.get_time_string()
		money_label.text = "₹ %d" % gm.player_money

func connect_player(p: CharacterBody3D) -> void:
	player = p
	player.connect("health_changed", _on_health_changed)
	player.connect("wanted_level_changed", _update_wanted_stars)

func connect_bike(b: VehicleBody3D) -> void:
	bike = b
	bike.connect("speed_changed", _on_speed_changed)
	bike.connect("nitro_changed", _on_nitro_changed)

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health
	health_label.text = "%d HP" % int(new_health)
	if new_health < 30:
		health_bar.modulate = Color.RED
	elif new_health < 60:
		health_bar.modulate = Color.YELLOW
	else:
		health_bar.modulate = Color(0.2, 1.0, 0.4)

func _on_speed_changed(kmh: float) -> void:
	speed_label.text = "%d km/h" % int(kmh)
	speed_label.visible = true

func _on_nitro_changed(fuel: float) -> void:
	nitro_bar.value = fuel
	nitro_bar.modulate = Color.CYAN if fuel > 20 else Color.RED

func _update_wanted_stars(level: int) -> void:
	for i in wanted_container.get_child_count():
		var star: Label = wanted_container.get_child(i)
		star.modulate = Color.GOLD if i < level else Color(0.3, 0.3, 0.3)

func _on_mission_started(mission_name: String) -> void:
	mission_label.text = "▶ " + mission_name
	mission_label.visible = true

func _on_mission_completed(mission_name: String) -> void:
	mission_label.text = "✓ " + mission_name + " Complete!"
	await get_tree().create_timer(3.0).timeout
	mission_label.visible = false

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	mission_label.text = text
	mission_label.modulate = color
	mission_label.visible = true
	await get_tree().create_timer(2.5).timeout
	mission_label.visible = false
