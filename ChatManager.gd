extends Node
class_name ChatManager

@export var proxy_url: String = "http://127.0.0.1:3000/gemini"

# Nodes
var http_request: HTTPRequest
var chat_panel: Window
var user_input: LineEdit
var chat_log: RichTextLabel
var send_button: Button

signal ai_response(text: String)

func _ready():
	# Get nodes
	http_request = get_node_or_null("HTTPRequest")
	chat_panel = get_node_or_null("ChatPanel")
	user_input = get_node_or_null("ChatPanel/UserInput")
	chat_log = get_node_or_null("ChatPanel/ChatLog")
	send_button = get_node_or_null("ChatPanel/SendButton")

	if not chat_panel:
		push_error("ChatPanel missing!")
		return
	chat_panel.hide()

	# Connect send button
	if send_button:
		send_button.pressed.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("SendButton missing!")

	# Connect Enter key
	if user_input:
		user_input.text_submitted.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("UserInput LineEdit missing!")

	# Connect HTTPRequest
	if http_request:
		http_request.request_completed.connect(Callable(self, "_on_request_completed"))
	else:
		push_error("HTTPRequest missing!")

# Open chat panel
func open_chat():
	if chat_panel and user_input:
		chat_panel.popup_centered()
		user_input.text = ""
		user_input.grab_focus()
		print("Opening chat panel")
	else:
		print("Cannot open chat: chat_panel or user_input is null")

# Called on SendButton press or Enter key
func _on_send_pressed(submitted_text: String = ""):
	var prompt = submitted_text.strip_edges()
	if prompt == "" and user_input:
		prompt = user_input.text.strip_edges()
	if prompt == "":
		return

	send_prompt_to_proxy(prompt)

	# Show user message
	if chat_log:
		chat_log.append_text("[You]: %s\n" % prompt)

	# Clear input
	if user_input:
		user_input.text = ""

# Send prompt to Node.js proxy
func send_prompt_to_proxy(prompt: String) -> void:
	if not http_request:
		push_error("HTTPRequest node missing!")
		return

	var json_body = {"prompt": prompt}
	var body_str = JSON.stringify(json_body)

	var err = http_request.request(
		proxy_url,
		[],                     # headers can be empty
		HTTPClient.METHOD_POST,
		body_str
	)

	if err != OK:
		push_error("Failed to send HTTP request: %d" % err)

# Callback when proxy responds
func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray):
	if result != OK or response_code != 200:
		push_error("HTTP request failed: %d, code %d" % [result, response_code])
		return

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
		chat_log.append_text("[Pet]: %s\n" % ai_text)
	else:
		push_error("Unexpected API response format")
