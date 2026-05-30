extends CanvasLayer

# ── Vehicle HUD ──
# Shows speedometer, interaction prompt, and drift indicator

@onready var speed_label: Label = $SpeedLabel
@onready var prompt_label: Label = $PromptLabel
@onready var drift_label: Label = $DriftLabel
@onready var nitro_bar: ProgressBar = $NitroBar

var current_vehicle: Node = null
var drift_fade: float = 0.0

func _ready() -> void:
	# Create HUD elements programmatically
	_create_hud()

func _create_hud() -> void:
	# ── Speedometer ──
	var speed_panel = PanelContainer.new()
	speed_panel.name = "SpeedPanel"
	speed_panel.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	speed_panel.position = Vector2(-220, -120)
	speed_panel.size = Vector2(200, 100)
	
	var speed_style = StyleBoxFlat.new()
	speed_style.bg_color = Color(0, 0, 0, 0.6)
	speed_style.corner_radius_top_left = 12
	speed_style.corner_radius_top_right = 12
	speed_style.corner_radius_bottom_left = 12
	speed_style.corner_radius_bottom_right = 12
	speed_panel.add_theme_stylebox_override("panel", speed_style)
	add_child(speed_panel)
	
	var speed_vbox = VBoxContainer.new()
	speed_panel.add_child(speed_vbox)
	
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.text = "0 KM/H"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.add_theme_font_size_override("font_size", 32)
	speed_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	speed_vbox.add_child(speed_label)
	
	var gear_label = Label.new()
	gear_label.name = "GearLabel"
	gear_label.text = "GEAR: D"
	gear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_label.add_theme_font_size_override("font_size", 14)
	gear_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	speed_vbox.add_child(gear_label)
	
	# ── Nitro Bar ──
	nitro_bar = ProgressBar.new()
	nitro_bar.name = "NitroBar"
	nitro_bar.min_value = 0
	nitro_bar.max_value = 100
	nitro_bar.value = 100
	nitro_bar.show_percentage = false
	nitro_bar.custom_minimum_size = Vector2(180, 12)
	
	var nitro_style_bg = StyleBoxFlat.new()
	nitro_style_bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	nitro_style_bg.corner_radius_top_left = 4
	nitro_style_bg.corner_radius_top_right = 4
	nitro_style_bg.corner_radius_bottom_left = 4
	nitro_style_bg.corner_radius_bottom_right = 4
	nitro_bar.add_theme_stylebox_override("background", nitro_style_bg)
	
	var nitro_style_fill = StyleBoxFlat.new()
	nitro_style_fill.bg_color = Color(0.0, 0.6, 1.0, 0.9)
	nitro_style_fill.corner_radius_top_left = 4
	nitro_style_fill.corner_radius_top_right = 4
	nitro_style_fill.corner_radius_bottom_left = 4
	nitro_style_fill.corner_radius_bottom_right = 4
	nitro_bar.add_theme_stylebox_override("fill", nitro_style_fill)
	speed_vbox.add_child(nitro_bar)
	
	# ── Interaction Prompt ──
	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = ""
	prompt_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	prompt_label.position = Vector2(-150, -80)
	prompt_label.size = Vector2(300, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(prompt_label)
	
	# ── Drift Label ──
	drift_label = Label.new()
	drift_label.name = "DriftLabel"
	drift_label.text = "🔥 DRIFT!"
	drift_label.anchors_preset = Control.PRESET_CENTER_TOP
	drift_label.position = Vector2(-100, 80)
	drift_label.size = Vector2(200, 50)
	drift_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drift_label.add_theme_font_size_override("font_size", 36)
	drift_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	drift_label.modulate.a = 0.0
	add_child(drift_label)
	
	# ── Controls Help ──
	var controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.text = "WASD: Drive | SHIFT: Nitro | SPACE: Handbrake | L: Lights | F: Exit"
	controls_label.anchors_preset = Control.PRESET_BOTTOM_LEFT
	controls_label.position = Vector2(20, -40)
	controls_label.add_theme_font_size_override("font_size", 13)
	controls_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.7))
	add_child(controls_label)
	
	# Start hidden
	visible = false

func _process(delta: float) -> void:
	if not visible or not current_vehicle:
		return
	
	# Update speedometer
	var speed_kmh = int(current_vehicle.linear_velocity.length() * 3.6) # m/s to km/h
	speed_label.text = str(speed_kmh) + " KM/H"
	
	# Color changes based on speed
	if speed_kmh > 150:
		speed_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Red
	elif speed_kmh > 80:
		speed_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0)) # Yellow
	else:
		speed_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5)) # Green
	
	# Update nitro bar
	if current_vehicle.has_method("get_nitro_percent"):
		nitro_bar.value = current_vehicle.get_nitro_percent()
	
	# Drift indicator
	if current_vehicle.get("is_drifting"):
		drift_label.modulate.a = lerp(drift_label.modulate.a, 1.0, 8.0 * delta)
		drift_label.scale = Vector2.ONE * lerp(drift_label.scale.x, 1.1, 5.0 * delta)
	else:
		drift_label.modulate.a = lerp(drift_label.modulate.a, 0.0, 4.0 * delta)
		drift_label.scale = Vector2.ONE

func show_hud(vehicle: Node) -> void:
	current_vehicle = vehicle
	visible = true

func hide_hud() -> void:
	current_vehicle = null
	visible = false

func show_prompt(text: String) -> void:
	if prompt_label:
		prompt_label.text = text

func hide_prompt() -> void:
	if prompt_label:
		prompt_label.text = ""
