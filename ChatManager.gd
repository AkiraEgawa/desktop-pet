extends Node

@export var gemini_api_key: String

# Nodes will be assigned safely in _ready()
var http_request: HTTPRequest
var chat_panel: Panel
var user_input: LineEdit
var chat_log: RichTextLabel

signal ai_response(text: String)

func _ready():
	# Safe node lookups for dynamically instanced scene
	http_request = get_node_or_null("HTTPRequest")
	chat_panel = get_node_or_null("ChatPanel")
	user_input = get_node_or_null("ChatPanel/UserInput")
	chat_log = get_node_or_null("ChatPanel/ChatLog")
	var send_button = get_node_or_null("ChatPanel/SendButton")
	
	if not http_request:
		push_error("HTTPRequest node not found!")
	if not chat_panel:
		push_error("ChatPanel node not found!")
	if not user_input:
		push_error("UserInput node not found!")
	if not chat_log:
		push_error("ChatLog node not found!")
	if not send_button:
		push_error("SendButton node not found!")

	# Hide chat panel by default
	if chat_panel:
		chat_panel.visible = false

	# Connect send button safely
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	
	# Connect HTTPRequest signal safely
	if http_request and not http_request.is_connected("request_completed", self, "_on_request_completed"):
		http_request.request_completed.connect(_on_request_completed)

# Called by Main.gd when Talk button is pressed
func open_chat():
	if chat_panel and user_input:
		chat_panel.visible = true
		user_input.text = ""
		user_input.grab_focus()

# Send user input to Gemini
func _on_send_pressed():
	if not user_input:
		return

	var prompt = user_input.text.strip_edges()
	if prompt == "":
		return

	ask_gemini(prompt)

	# Show user message in chat log
	if chat_log:
		chat_log.append_bbcode("[color=cyan]You:[/color] %s\n" % prompt)

	# Clear input
	user_input.text = ""

# Gemini API request
func ask_gemini(prompt: String) -> void:
	if gemini_api_key == "":
		push_error("Gemini API key not set!")
		return
	if not http_request:
		push_error("HTTPRequest node missing!")
		return

	var url = "https://api.generativeai.googleapis.com/v1beta2/models/gemini-2.0:generateText"
	var headers = [
		"Authorization: Bearer %s" % gemini_api_key,
		"Content-Type: application/json"
	]

	var body = {
		"prompt": prompt,
		"temperature": 0.8,
		"candidate_count": 1,
		"max_output_tokens": 256
	}

	var json_body_bytes = JSON.stringify(body).to_utf8_buffer()
	var err = http_request.request(url, headers, json_body_bytes)
	if err != OK:
		push_error("Failed to send HTTP request: %d" % err)

# HTTPRequest callback
func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if not chat_log:
		push_error("ChatLog missing!")
		return

	var body_text = body.get_string_from_utf8()
	var parse_result = JSON.parse_string(body_text)
	if parse_result.error != OK:
		push_error("Failed to parse JSON response")
		return

	var data = parse_result.result
	if data.has("candidates") and data.candidates.size() > 0:
		var ai_text = data.candidates[0].content
		emit_signal("ai_response", ai_text)
		chat_log.append_bbcode("[color=yellow]Pet:[/color] %s\n" % ai_text)
	else:
		push_error("Unexpected API response format")
