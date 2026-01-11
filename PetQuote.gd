extends Node2D

@export var pet_menu_scene: PackedScene
@onready var menu_container := $UI/MenuContainer
@onready var pet := $Pet
@onready var speech_label: Label = $UI/SpeechLabel
@onready var quote_timer: Timer = $Pet/QuoteTimer

var quotes = [
	"Confidence is fake. Everyone’s faking it. At least fake it while working.",
	"You’re stronger than you think. Also, you complain a lot. Both can be true.",
	"Future you is gonna hate you if you don’t move right now. Don’t do that to him.",
	"Stop planning like a strategist and start moving like an idiot with confidence. That’s how I became successful.",
	"Listen… I studied success for years. Not in school. In vibes. And the vibe says: get up.",
	"Discipline is just motivation that stopped being dramatic.",
	"Becoming great is simple. You just suffer daily, but like… politely.",
	"I’m not saying I’m a genius… I’m saying I’ve been confidently wrong enough times to become wise."
]

var menu_open = false
var _last_mask_polygon: PackedVector2Array = PackedVector2Array()

func _ready():
	# 1. WINDOW SETUP
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_tree().get_root().set_transparent_background(true)
	
	# 2. TEXT LABEL SETUP
	speech_label.visible = false
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# ALIGNMENT (Top ensures it grows down)
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# ANCHORS (Unlock size)
	speech_label.anchors_preset = Control.PRESET_TOP_LEFT
	speech_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	speech_label.grow_vertical = Control.GROW_DIRECTION_END
	
	# Default size safety
	speech_label.custom_minimum_size = Vector2(200, 50)
	
	# 3. TIMER SETUP
	quote_timer.timeout.connect(on_quote_timer_timeout)
	quote_timer.one_shot = false
	quote_timer.autostart = true
	quote_timer.start()

func _process(_delta: float):
	# Always update mask (to prevent pet clipping)
	if not speech_label.visible:
		update_stabilized_mask()
		return

	# --- SMART POSITIONING ---
	var screen_rect = DisplayServer.screen_get_usable_rect()
	var margin = 10.0
	
	# Default: Try to put it ABOVE the pet
	# We use the CURRENT size, so we must ensure size is correct before showing!
	var target_x = pet.global_position.x - (speech_label.size.x / 2.0)
	var target_y = pet.global_position.y - 80 - speech_label.size.y
	
	# CHECK 1: Top collision? Flip to bottom.
	if target_y < screen_rect.position.y + margin:
		target_y = pet.global_position.y + 50

	# CHECK 2: Side collision? Clamp X.
	var min_x = screen_rect.position.x + margin
	var max_x = screen_rect.end.x - speech_label.size.x - margin
	target_x = clamp(target_x, min_x, max_x)
	
	# Apply position
	speech_label.global_position = Vector2(target_x, target_y)

	# Update mask
	update_stabilized_mask()

func update_stabilized_mask():
	# 1. Get Pet Bounds
	var anim = pet.get_node("AnimatedSprite2D")
	var current_scale = anim.scale
	var base_size = Vector2(48, 48)
	var buffer = 10.0
	
	var half_size = (base_size * current_scale + Vector2(buffer, buffer)) / 2
	var pet_pos = pet.global_position.floor()
	
	var pet_tl = pet_pos - half_size.floor()
	var pet_br = pet_pos + half_size.floor()

	# 2. Get Text Bounds (Only if visible)
	var final_polygon = PackedVector2Array()
	
	if speech_label.visible:
		var text_pos = speech_label.global_position.floor()
		var text_size = speech_label.size.floor()
		
		# CRITICAL FIX: Add Padding to the mask!
		# If the mask is exactly the size of the text, anti-aliasing gets cut off.
		# We subtract 10 from Top/Left and add 20 to Width/Height to create a buffer.
		var mask_padding = 10.0
		var text_tl = text_pos - Vector2(mask_padding, mask_padding)
		var text_br = text_pos + text_size + Vector2(mask_padding, mask_padding)
		
		# Merge logic
		var min_x = min(pet_tl.x, text_tl.x)
		var min_y = min(pet_tl.y, text_tl.y)
		var max_x = max(pet_br.x, text_br.x)
		var max_y = max(pet_br.y, text_br.y)
		
		final_polygon = PackedVector2Array([
			Vector2(min_x, min_y),
			Vector2(max_x, min_y),
			Vector2(max_x, max_y),
			Vector2(min_x, max_y)
		])
	else:
		# Pet Only
		final_polygon = PackedVector2Array([
			Vector2(pet_tl.x, pet_tl.y),
			Vector2(pet_br.x, pet_tl.y),
			Vector2(pet_br.x, pet_br.y),
			Vector2(pet_tl.x, pet_br.y)
		])

	# 3. Update only if changed
	if final_polygon != _last_mask_polygon:
		_last_mask_polygon = final_polygon
		DisplayServer.window_set_mouse_passthrough(final_polygon)

func on_quote_timer_timeout():
	if pet.current_state == pet.PetState.DRAGGING or menu_open or speech_label.visible:
		return
	show_quote()

func show_quote():
	# 1. HIDE FIRST (Prevents visual glitches)
	speech_label.visible = false
	speech_label.text = quotes.pick_random()
	
	# 2. Force Width (220), Auto Height (0)
	speech_label.custom_minimum_size = Vector2(220, 0)
	speech_label.size = Vector2.ZERO
	
	# 3. CRITICAL: Wait TWO frames.
	# Frame 1: Godot receives the size reset request.
	# Frame 2: Godot calculates the new size based on the text.
	speech_label.visible = true
	await get_tree().process_frame 
	await get_tree().process_frame 
	
	# 4. Now the size is guaranteed to be correct.
	update_stabilized_mask()
	
	# 5. Timer
	await get_tree().create_timer(4.0).timeout
	hide_quote()

func hide_quote():
	speech_label.visible = false

# --- MENU FUNCTIONS ---
func show_pet_menu(pet_pos: Vector2):
	hide_quote()
	for child in menu_container.get_children():
		child.queue_free()

	var menu = pet_menu_scene.instantiate()
	menu_container.add_child(menu)
	menu.position = pet_pos
	menu_open = true

	menu.get_node("TalkButton").pressed.connect(func(): on_talk(); close_menu())
	menu.get_node("InteractButton").pressed.connect(func(): on_interact(); close_menu())
	menu.get_node("ScheduleButton").pressed.connect(func(): on_schedule(); close_menu())

func on_talk(): print("Talk clicked")
func on_interact(): print("Interact clicked")
func on_schedule(): print("Schedule clicked")	

func close_menu():
	for child in menu_container.get_children():
		child.queue_free()
	menu_open = false
