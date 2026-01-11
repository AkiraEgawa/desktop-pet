extends CharacterBody2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- POMODORO SETUP ---
var pomodoro_scene = preload("res://PomodoroWindow.tscn")
var pomodoro_instance: Window = null 

# --- SCREEN & ANIMATION ---
@onready var screen_size = DisplayServer.screen_get_usable_rect().size
@onready var anim = $AnimatedSprite2D

# --- SETTINGS ---
var speed = 200 
var direction = 1 
var offset = 96 
var petting_duration = 1.5
var drag_start_position = Vector2.ZERO
var drag_threshold = 10.0

# --- STATE MACHINE ---
enum PetState { IDLE, WALK, DRAGGING, FALL, PETTING, HOLD_SIGN }
var current_state: PetState = PetState.IDLE 
var time_left = 5.0 

# Variable to track the 5-second hold
var sign_timer = 0.0

# --- SIGNALS ---
signal menu_requested(global_position) 

func _ready():
	get_tree().get_root().set_transparent_background(true)
	
	anim.frame_changed.connect(update_click_mask)
	update_click_mask()
	
	pomodoro_instance = pomodoro_scene.instantiate()
	add_child(pomodoro_instance)
	pomodoro_instance.hide() 
	
	# --- NEW CODE: CONNECT THE SIGNAL ---
	# This listens to the Pomodoro window. When "time_milestone" fires, 
	# it runs the 'show_sign' function below.
	if pomodoro_instance.has_signal("time_milestone"):
		pomodoro_instance.time_milestone.connect(show_sign)

func _process(delta: float) -> void:
	update_click_mask() # Update mask every frame for smooth dragging
	
	if current_state == PetState.PETTING and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var current_mouse_pos = get_global_mouse_position()
		# If we moved further than the threshold (10 pixels), start dragging
		if current_mouse_pos.distance_to(drag_start_position) > drag_threshold:
			current_state = PetState.DRAGGING
	# Visual Dragging Logic
	if current_state == PetState.DRAGGING: 
		global_position = get_global_mouse_position()
		anim.play("idle")

func _physics_process(delta: float) -> void:
	if current_state == PetState.DRAGGING:
		return 
	
	# Sign Holding
	if current_state == PetState.HOLD_SIGN:
		# Count down
		sign_timer -= delta
		if sign_timer <= 0:
			# Time's up! Go back to idle
			current_state = PetState.IDLE
		
		# While holding sign, DO NOT run the rest of movement logic
		# But we still call move_and_slide so he stays on the floor
		move_and_slide()
		return

	# --- FLOOR CALCULATION ---
	var screen_bottom = DisplayServer.screen_get_usable_rect().end.y
	var current_scale = anim.scale
	var base_size = Vector2(48, 48)
	var effective_size = base_size * current_scale
	
	# The exact Y position where the feet touch the bottom
	var floor_limit = screen_bottom - (effective_size.y / 2)

	# --- GRAVITY & LANDING LOGIC ---
	
	# We define a tiny "snap margin" (e.g., 2 pixels).
	# If the pet is within 2 pixels of the floor, we consider him "Landed".
	if global_position.y < floor_limit - 2.0:
		# AIRBORNE LOGIC
		velocity.y += gravity * delta
		
		# If we are in the air, we are falling
		if current_state != PetState.FALL:
			current_state = PetState.FALL
			
	else:
		# GROUNDED LOGIC
		# Snap exactly to the floor line
		global_position.y = floor_limit
		velocity.y = 0
		
		# If we were falling, switch to Idle immediately
		if current_state == PetState.FALL:
			current_state = PetState.IDLE

	# --- AI DECISION MAKING (Timer) ---
	if current_state == PetState.PETTING:
		velocity = Vector2.ZERO
		anim.play("petting") # Ensure you have an animation named "pet"
		time_left -= delta
		if time_left <= 0:
			current_state = PetState.IDLE
			time_left = randf_range(2.0, 5.0)
	elif current_state == PetState.IDLE or current_state == PetState.WALK:
		time_left -= delta
		if time_left <= 0:
			time_left = randf_range(2.0, 5.0) 
			
			if current_state == PetState.WALK:
				current_state = PetState.IDLE
			else: 
				current_state = PetState.WALK
				direction = 1 if randf() > 0.5 else -1
	
	
		
	# --- MOVEMENT APPLIER ---
	if current_state == PetState.WALK:
		velocity.x = speed * direction 
		anim.play("walk") 
		anim.flip_h = (direction == 1)
		
	elif current_state == PetState.IDLE: 
		velocity.x = 0
		anim.play("idle")
	
	elif current_state == PetState.FALL: 
		anim.play("fall")
		velocity.x = 0 
		
	elif current_state == PetState.PETTING:
		velocity.x = 0
	
		
	# --- SCREEN BOUNDS ---
	if (global_position.x > screen_size.x - offset):
		direction = -1
		velocity.x = -speed
		global_position.x = screen_size.x - offset
	elif (global_position.x < offset):
		direction = 1
		velocity.x = speed
		global_position.x = offset
		
	move_and_slide()

# --- INPUT HANDLING ---
func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		
		# LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. Default to PETTING immediately
				current_state = PetState.PETTING
				time_left = petting_duration
				velocity = Vector2.ZERO
				
				# 2. Record where we clicked so we can calculate drag later
				drag_start_position = get_global_mouse_position()
				
			else:
				# 3. ON RELEASE
				# If we managed to switch to dragging, then Fall.
				if current_state == PetState.DRAGGING:
					current_state = PetState.FALL
					
		# LEFT CLICK: Dragging

		# MIDDLE CLICK: Pomodoro
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			print("Middle Click: Opening Pomodoro!")
			
			# Center window on screen
			pomodoro_instance.position = Vector2i(screen_size / 2) - (pomodoro_instance.size / 2)
			pomodoro_instance.show()	
			
			# Call the start function if it exists
			#if pomodoro_instance.has_method("start_pomodoro"):
				#pomodoro_instance.start_pomodoro()
		
		# RIGHT CLICK: Open Pet Menu
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("Right Click: Emitting menu_requested")
			speed = 0
			velocity = Vector2.ZERO # stop motion
			emit_signal("menu_requested", global_position)

func show_sign(minutes_left: int):
	# 1. Determine which animation to play
	var anim_name = ""
	match minutes_left:
		25: anim_name = "sign_25"
		20: anim_name = "sign_20"
		15: anim_name = "sign_15"
		10: anim_name = "sign_10"
		5:  anim_name = "sign_5"
		0:  anim_name = "sign_0"
	
	# 2. If valid, enter the state
	if anim_name != "":
		print("Pet showing sign for: ", minutes_left)
		current_state = PetState.HOLD_SIGN
		velocity = Vector2.ZERO # Stop moving immediately
		
		anim.flip_h = false
		
		anim.play(anim_name)
		sign_timer = 5.0 # Hold for 5 seconds

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
