extends CharacterBody2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var pomodoro_scene = preload("res://PomodoroWindow.tscn")
var pomodoro_instance: Window = null # Variable to hold the actual window instance
# Use DisplayServer here to get the full USABLE screen size dynamically
@onready var screen_size = DisplayServer.screen_get_usable_rect().size
@onready var anim = $AnimatedSprite2D
signal menu_requested(global_position)

var speed = 200 # Controls how fast PET walks
var direction = 1 # Controls LEFT and RIGHT directions
var offset = 96 # offset so we don't touch edge exactly

enum PetState {
	IDLE, # IDLE State
	WALK, # Walk State
	DRAGGING, # Dragged State
	FALL # Fall State (Post release from Dragged State)
}
var current_state: PetState = PetState.IDLE # Initial pet state
var time_left = 5.0 			
#func _input_event(viewport, event, shape_idx):
	#if event is InputEventMouseButton and 			# Duration before we change states
 	# event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#emit_signal("menu_requested", global_position)

# Executes once when the node and all its children enter the scene tree
func _ready():
	# Fixes the black/grey box behind the pet
	get_tree().get_root().set_transparent_background(true)
	
	# Optimization: Only update the click mask when the animation frame ACTUALLY changes
	# This prevents asking the OS to redraw the window 60 times a second (lag prevention)
	anim.frame_changed.connect(update_click_mask)
	# Make sure the initial mask is set for PET
	update_click_mask()
	
	# Create the instance but keep it hidden (not opened yet)
	pomodoro_instance = pomodoro_scene.instantiate()
	add_child(pomodoro_instance)
	pomodoro_instance.hide() # Hide it initially
	# Handle the XButton on the window properly
	pomodoro_instance.close_requested.connect(func(): pomodoro_instance.hide())
	

# _process runs every VIDEO frame (e.g. 144hz if user's monitor is 144hz). 
# This makes dragging buttery smooth and removes the "jitter/pixel border" effect.
func _process(delta: float) -> void:
	# Update the mask EVERY frame so the window follows the pet perfectly
	update_click_mask()
	# Handle Dragging
	if current_state == PetState.DRAGGING: 
		global_position = get_global_mouse_position() # Set PET's position based on mouse position
		anim.play("idle") # While being dragged, play idle animation
		
# _physics_process runs at a fixed 60 times per second 
# Keep gravity and movement here so they are consistent!
func _physics_process(delta: float) -> void:
	if current_state == PetState.DRAGGING:
		# If dragging, stop physics calculations entirely so it doesn't fight the mouse
		return 
	
	# returns a Rect2i that represents the usable area of the screen
	# According to docs, a "usable area of the screen" is the part of the screen where
	# windows are allowed to appear without being covered by system UI such as the task bar.
	var screen_bottom = DisplayServer.screen_get_usable_rect().end.y
	var current_scale = anim.scale # Get scale property value from AnimatedSprite2D
	
	var base_size = Vector2(48, 48) # Size of our sprite
	var effective_size = base_size * current_scale # The effective size displayed
	
	# Sink pet down a bit (Else pet is "floating" and not walking on taskbar)
	var vertical_sink = 10.0
	# The floor (taskbar)
	var floor_limit = screen_bottom - (effective_size.y / 2) + vertical_sink

	# Gravity logic
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > 0:
			current_state = PetState.FALL
		if global_position.y >= floor_limit: 
			global_position.y = floor_limit # Snap pet y position to equal the floor limit 
			velocity.y = 0 # Stop falling 
			
			if current_state == PetState.FALL:
				current_state = PetState.IDLE
	
	if current_state == PetState.IDLE or current_state == PetState.WALK:
		# !!! Subtract delta from timer !!!
		time_left -= delta
		
		# If time runs out
		if time_left <= 0:
			# Reset it.
			time_left = randf_range(2.0, 5.0) 
			
			# if WALK -> IDLE, if IDLE -> WALK
			if current_state == PetState.WALK:
				current_state = PetState.IDLE
			else: 
				current_state = PetState.WALK
				# Randomize direction when starting Walk State
				if randf() > 0.5:
					direction = 1
				else:
					direction = -1
		
	# Animation Handler
	if current_state == PetState.WALK:
		# Velocity in the x direction: either speed or -speed
		velocity.x = speed * direction 
		anim.play("walk") # Play walk animation 
		if direction == 1:
			anim.flip_h = true 
		else:
			anim.flip_h = false
		
	elif current_state == PetState.IDLE: 
		velocity.x = 0
		anim.play("idle")
	
	elif current_state == PetState.FALL: 
		anim.play("fall")
		velocity.x = 0 # Don't move sideways while falling
		
	# Screen Bounds logic
	if (global_position.x > screen_size.x - offset):
		direction = -1
		velocity.x = -speed # Update velocity immediately so we don't get stuck
		global_position.x = screen_size.x - offset
	elif (global_position.x < offset):
		direction = 1
		velocity.x = speed
		global_position.x = offset
		
	move_and_slide()
	
	if is_on_floor() and current_state == PetState.FALL:
		current_state = PetState.IDLE
		velocity = Vector2.ZERO

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		
		# LEFT CLICK: Dragging
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				print("Clicked!")
				current_state = PetState.DRAGGING
				velocity = Vector2.ZERO
				# If you need that signal for your friend's menu, emit it here:
				emit_signal("menu_requested", global_position) 
			else: 
				print("Released!")
				# FIX: Switch to FALL so he drops to the floor properly.
				# If we set IDLE here, he freezes in mid-air.
				current_state = PetState.FALL
		# MIDDLE CLICK: Pomodoro
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			print("Middle Click detected: opening Pomodoro")
			
			# Center the window on the screen
			pomodoro_instance.position = Vector2i(screen_size / 2) - (pomodoro_instance.size / 2)
			pomodoro_instance.show()	
			
			if pomodoro_instance.has_method("start_pomodoro"):
				pomodoro_instance.start_pomodoro()

func update_click_mask():
	# Only mask around the pet
	var current_scale = anim.scale
	var base_size = Vector2(48, 48)
	var buffer = 20.0
	var half_size = (base_size * current_scale + Vector2(buffer, buffer)) / 2

	var top_left = global_position - half_size
	var bottom_right = global_position + half_size

	# Define corners in clockwise order
	var corners = PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y)
	])

	# Set the window mask for only the pet area
	DisplayServer.window_set_mouse_passthrough(corners)
