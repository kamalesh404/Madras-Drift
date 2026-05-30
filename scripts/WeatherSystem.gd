extends Node

# ── Madras Drift ── Weather System
# Add as child of World scene

@export var rain_particles: NodePath
@export var fog_environment: NodePath
@export var directional_light: NodePath

@onready var rain: GPUParticles3D = get_node_or_null(rain_particles)
@onready var world_env: WorldEnvironment = get_node_or_null(fog_environment)
@onready var sun: DirectionalLight3D = get_node_or_null(directional_light)

enum Weather { CLEAR, DRIZZLE, RAIN, HEAVY_RAIN, STORM }
var current_weather: Weather = Weather.CLEAR
var weather_timer: float = 0.0
var weather_change_interval: float = 120.0  # change every 2 min

# Colors for different weather
const CLEAR_SKY    := Color(0.4, 0.6, 1.0)
const RAIN_SKY     := Color(0.2, 0.25, 0.35)
const STORM_SKY    := Color(0.1, 0.12, 0.18)
const NEON_NIGHT   := Color(0.05, 0.05, 0.15)

signal weather_changed(weather_name)

func _ready() -> void:
	set_weather(Weather.RAIN)  # Start with rain for atmosphere

func _process(delta: float) -> void:
	weather_timer += delta
	if weather_timer >= weather_change_interval:
		weather_timer = 0.0
		_random_weather_change()

func set_weather(weather: Weather) -> void:
	current_weather = weather
	_apply_weather()
	var names := ["Clear", "Drizzle", "Rain", "Heavy Rain", "Storm"]
	emit_signal("weather_changed", names[weather])
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_weather(names[weather].to_lower())

func _apply_weather() -> void:
	match current_weather:
		Weather.CLEAR:
			_set_rain_amount(0.0)
			_set_fog(false, 0.0)
			_set_sky_color(CLEAR_SKY, 1.0)

		Weather.DRIZZLE:
			_set_rain_amount(0.2)
			_set_fog(true, 0.005)
			_set_sky_color(RAIN_SKY, 0.7)

		Weather.RAIN:
			_set_rain_amount(0.6)
			_set_fog(true, 0.012)
			_set_sky_color(RAIN_SKY, 0.4)

		Weather.HEAVY_RAIN:
			_set_rain_amount(1.0)
			_set_fog(true, 0.025)
			_set_sky_color(RAIN_SKY, 0.25)

		Weather.STORM:
			_set_rain_amount(1.0)
			_set_fog(true, 0.04)
			_set_sky_color(STORM_SKY, 0.15)
			_trigger_lightning()

func _set_rain_amount(amount: float) -> void:
	if not rain:
		return
	rain.emitting = amount > 0
	rain.amount = int(amount * 2000)

func _set_fog(enabled: bool, density: float) -> void:
	if not world_env:
		return
	var env := world_env.environment
	if env:
		env.fog_enabled = enabled
		env.fog_density = density
		env.fog_aerial_perspective = 0.5

func _set_sky_color(color: Color, sun_energy: float) -> void:
	if sun:
		sun.light_energy = sun_energy
		sun.light_color = color.lightened(0.2)
	if world_env and world_env.environment:
		world_env.environment.background_color = color

func _trigger_lightning() -> void:
	if sun:
		var tween := create_tween()
		tween.tween_property(sun, "light_energy", 3.0, 0.05)
		tween.tween_property(sun, "light_energy", 0.1, 0.15)

func _random_weather_change() -> void:
	var options: Array
	match current_weather:
		Weather.CLEAR:    options = [Weather.CLEAR, Weather.DRIZZLE]
		Weather.DRIZZLE:  options = [Weather.CLEAR, Weather.RAIN]
		Weather.RAIN:     options = [Weather.DRIZZLE, Weather.RAIN, Weather.HEAVY_RAIN]
		Weather.HEAVY_RAIN: options = [Weather.RAIN, Weather.STORM]
		Weather.STORM:    options = [Weather.HEAVY_RAIN, Weather.RAIN]
	set_weather(options[randi() % options.size()])
