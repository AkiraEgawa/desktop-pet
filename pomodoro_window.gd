extends Window

# Old reference (kept for safety, but we use timer_label now)
@onready var label = $BackgroundPanel/Padding/MainLayout/TimerLabel 

# New UI References
@onready var timer_label = $BackgroundPanel/Padding/MainLayout/TimerLabel
@onready var start_button = $BackgroundPanel/Padding/MainLayout/ButtonRow/StartButton
@onready var quote_label = $BackgroundPanel/Padding/MainLayout/QuoteLabel
@onready var char_image = $BackgroundPanel/Padding/MainLayout/CharImage
@onready var timer = $Timer 

const WORK_MINUTES = 25
const BREAK_MINUTES = 5

var minutes = WORK_MINUTES # Total minutes for Pomodoro 
var seconds = 0 # In seconds, track how close we are to total_minutes 
var is_break_mode = false # Tracks if user is working or resting

var quotes = [
	"Focus on the process.",
	"One step at a time.",
	"Keep pushing!",
	"Rest is part of the work.",
	"Consistency is key."
]

var is_running = false # Boolean for if window is running
var dragging = false # Boolean for if window is dragging
var drag_start_position = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# When window opens, update text immediately 
	# Text needs to be updated continuously to for users to track seconds 
	update_label()
	pick_random_quote()
	
	# Connect Signals (Make sure to disconnect any old red signals in the Node tab!)
	start_button.pressed.connect(_on_start_pressed)
	$BackgroundPanel/Padding/MainLayout/ButtonRow/ResetButton.pressed.connect(_on_reset_pressed)
	$BackgroundPanel/Padding/MainLayout/TopBar/XButton.pressed.connect(func(): hide())
	
	# Dragging logic on the main panel
	$BackgroundPanel.gui_input.connect(_on_panel_gui_input)
	
	timer.timeout.connect(_on_timer_tick)
	# Stop timer initially
	timer.stop()

func _process(delta):
	if dragging:
		# Move window by difference between current mouse and start mouse 
		# Using global mouse position avoids jitter/shaking
		var mouse_pos = DisplayServer.mouse_get_position()
		position = mouse_pos - Vector2i(drag_start_position)

# Called when window is shown
func start_pomodoro():
	minutes = WORK_MINUTES
	seconds = 0
	is_running = true
	is_break_mode = false
	start_button.text = "Pause"
	_set_timer_color(Color.GREEN)
	
	update_label()
	timer.start()

func _on_timer_tick():
	if seconds > 0:
		seconds -= 1
	else:
		if minutes > 0:
			minutes -= 1
			seconds = 59
		else: 
			# Time is up
			_handle_timer_complete()
			return # Exit function
			
	update_label()

func _handle_timer_complete():
	timer.stop()
	is_running = false
	seconds = 0
	
	if is_break_mode:
		# Break finished -> Back to Work
		is_break_mode = false
		minutes = WORK_MINUTES
		timer_label.text = "Ready to Work?"
		pick_random_quote()
	else:
		# Work finished -> Start Break
		is_break_mode = true
		minutes = BREAK_MINUTES
		timer_label.text = "Break Time!"
		quote_label.text = "Take a breather."
	
	start_button.text = "Start"
	_set_timer_color(Color.AQUA) # Different color for finished state

func update_label(): 
	# 0 => padding zeros 
	# 2 => minimum width 
	timer_label.text = "%02d:%02d" % [minutes, seconds] 

func _on_panel_container_gui_input(event: InputEvent) -> void:
	# Note: This connects to the specific _on_panel_gui_input in _ready
	pass 

func _on_panel_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_position = get_mouse_position()
			else:
				dragging = false

func _on_x_button_pressed() -> void:
	# Clicking the CloseButton -> 
	hide() # Hides the window
	is_running = false
	# Do not pause the timer, timer should run in background

func _on_start_pressed():
	if is_running:
		# PAUSE Logic
		is_running = false
		timer.stop()
		start_button.text = "Resume"
		_set_timer_color(Color.RED) 
	else:
		# RESUME/START Logic
		is_running = true
		timer.start()
		start_button.text = "Pause"
		_set_timer_color(Color.GREEN)

func _on_reset_pressed():
	is_running = false
	timer.stop()
	seconds = 0
	
	# Reset to the correct time based on current mode
	if is_break_mode:
		minutes = BREAK_MINUTES
	else:
		minutes = WORK_MINUTES
		
	start_button.text = "Start"
	_set_timer_color(Color.GREEN)
	update_label()

# --- HELPER FUNCTIONS ---

func pick_random_quote():
	quote_label.text = quotes.pick_random()

func _set_timer_color(color: Color):
	# Finds the StyleBoxFlat in the Inspector and changes color dynamically
	var style = timer_label.get_theme_stylebox("normal")
	if style:
		style.bg_color = color
