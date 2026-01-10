extends Control

signal talk_pressed
signal interact_pressed
signal schedule_pressed

func _ready():
	$TalkButton.pressed.connect(func(): talk_pressed.emit())
	$InteractButton.pressed.connect(func(): interact_pressed.emit())
	$ScheduleButton.pressed.connect(func(): schedule_pressed.emit())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
