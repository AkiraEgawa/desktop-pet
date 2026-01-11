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
var bubble_showing := false

var menu_open = false

# Called when the node enters the scene tree for the first time.
func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_tree().get_root().set_transparent_background(true)
	# pet.menu_requested.connect(show_pet_menu)
	speech_label.visible = false
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speech_label.clip_text = false
	speech_label.z_index = 100
	speech_label.z_as_relative = false


	quote_timer.timeout.connect(on_quote_timer_timeout)
	quote_timer.one_shot = false
	quote_timer.autostart = true
	quote_timer.start()

	
	print("QuoteTimer exists? ", quote_timer)
	print("QuoteTimer wait_time: ", quote_timer.wait_time)
	print("QuoteTimer autostart: ", quote_timer.autostart)



	

func show_pet_menu(pet_pos: Vector2):
	hide_quote()
	# remove previous menu
	for child in menu_container.get_children():
		child.queue_free()

	# instantiate menu
	var menu = pet_menu_scene.instantiate()
	menu_container.add_child(menu)

	# position menu around pet
	menu.position = pet_pos
	menu_open = true

	# connect buttons
	menu.get_node("TalkButton").pressed.connect(func():
		on_talk()
		close_menu()
	)
	menu.get_node("InteractButton").pressed.connect(func():
		on_interact()
		close_menu()
	)
	menu.get_node("ScheduleButton").pressed.connect(func():
		on_schedule()
		close_menu()
	)

func on_talk():
	print("Talk clicked")

func on_interact():
	print("Interact clicked")

func on_schedule():
	print("Schedule clicked")	

func close_menu():
	# remove menu
	for child in menu_container.get_children():
		child.queue_free()
	menu_open = false
	
func on_quote_timer_timeout():
	# Don't talk while dragging OR while menu is open
	if pet.current_state == pet.PetState.DRAGGING:
		hide_quote()
		return
	if menu_open:
		hide_quote()
		return

	show_quote()

func show_quote():
	speech_label.text = quotes[randi() % quotes.size()]
	var box_size = Vector2(600, 220)
	speech_label.size = box_size
	speech_label.visible = true

	await get_tree().create_timer(1.2).timeout
	hide_quote()

func hide_quote():
	speech_label.visible = false


func _process(delta: float):
	if not speech_label.visible:
		return

	var x = pet.global_position.x - speech_label.size.x / 2.0
	var y = pet.global_position.y - 70 - speech_label.size.y
	speech_label.global_position = Vector2(x, y)
