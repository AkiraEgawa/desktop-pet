extends Window

@onready var label = $Label 
@onready var timer = $Timer 

var minutes = 25 # Total minutes for Pomodoro 
var seconds = 0 # In seconds, track how close we are to total_minutes 
var is_running = false # Boolean for if window is running
var dragging = false # Boolean for if window is dragging
var drag_start_position = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# When window opens, update text immediately 
	# Text needs to be updated continuously to for users to track seconds 
	update_label()
	
	timer.timeout.connect(_on_timer_tick)
	# Stop timer initially
	timer.stop()
	
func _process(delta):
	if dragging:
		# Move window by difference between current mouse and start mouse 
		position += Vector2i(get_mouse_position() - drag_start_position)
	
# Called when window is shown
func start_pomodoro():
	minutes = 25
	seconds = 0
	is_running = true
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
			is_running = false
			timer.stop()
			label.text = "Time is up"
			return # Exit function
			
	update_label()
	
func update_label(): 
	# 0 => padding zeros 
	# 2 => minimum width 
	label.text = "%02d:%02d" % [minutes, seconds] 
	 
func _on_panel_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_position = get_mouse_position()
			else:
				dragging = false


func _on_x_button_pressed() -> void:
	# Clicking the XButton -> 
	hide() # Hides the window
	is_running = false
	# Do not pause the timer, timer should run in background
	
