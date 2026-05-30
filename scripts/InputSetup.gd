extends Node

# ── Madras Drift ── Input Map Setup
# Run this once to register all actions
# Or manually add in: Project → Project Settings → Input Map

func _ready() -> void:
	_register_inputs()

func _register_inputs() -> void:
	var actions := {
		"move_forward":  [KEY_W, KEY_UP],
		"move_back":     [KEY_S, KEY_DOWN],
		"move_left":     [KEY_A, KEY_LEFT],
		"move_right":    [KEY_D, KEY_RIGHT],
		"sprint":        [KEY_SHIFT],
		"jump":          [KEY_SPACE],
		"interact":      [KEY_E],
		"attack":        [MOUSE_BUTTON_LEFT],
		"aim":           [MOUSE_BUTTON_RIGHT],
		"drone_launch":  [KEY_Q],
		"hack":          [KEY_F],
		"pause":         [KEY_ESCAPE],
		"map":           [KEY_M],
		"phone":         [KEY_TAB],
	}

	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for key in actions[action_name]:
				var event: InputEvent
				if key is int and key < 10:
					# Mouse button
					var mb := InputEventMouseButton.new()
					mb.button_index = key
					event = mb
				else:
					var kb := InputEventKey.new()
					kb.keycode = key
					event = kb
				InputMap.action_add_event(action_name, event)

	print("✅ Input map registered")
