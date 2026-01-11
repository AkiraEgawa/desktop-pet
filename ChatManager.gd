extends Node
class_name ChatManager

@export var proxy_url: String = "http://127.0.0.1:3000/gemini"  # your local Node proxy

# Nodes
var http_request: HTTPRequest
var chat_panel: Window
var user_input: LineEdit
var chat_log: RichTextLabel
var send_button: Button

signal ai_response(text: String)

func _ready():
	# Get nodes safely
	http_request = get_node_or_null("HTTPRequest")
	chat_panel = get_node_or_null("ChatPanel")
	user_input = get_node_or_null("ChatPanel/UserInput")
	chat_log = get_node_or_null("ChatPanel/ChatLog")
	send_button = get_node_or_null("ChatPanel/SendButton")

	if not chat_panel:
		push_error("ChatPanel missing!")
		return
	chat_panel.hide() # hide at start

	# Connect button pressed
	if send_button:
		send_button.pressed.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("SendButton missing!")

	# Connect Enter key (LineEdit)
	if user_input:
		user_input.text_submitted.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("UserInput LineEdit missing!")

	# Connect HTTPRequest completed signal
	if http_request:
		http_request.request_completed.connect(Callable(self, "_on_request_completed"))
	else:
		push_error("HTTPRequest missing!")


# Called by Main.gd when "Talk" button is pressed
func open_chat():
	if chat_panel and user_input:
		chat_panel.popup_centered()
		user_input.text = ""
		user_input.grab_focus()
		print("Opening chat panel")
	else:
		print("Cannot open chat: chat_panel or user_input is null")


# Triggered by button or Enter key
func _on_send_pressed(submitted_text: String = ""):
	var prompt: String = submitted_text.strip_edges()
	if prompt == "":
		# If triggered by button press, get text from input
		if user_input:
			prompt = user_input.text.strip_edges()
	if prompt == "":
		return

	# Show user message in chat log
	if chat_log:
		chat_log.append_text("[You]: %s\n" % prompt)

	# Clear input
	if user_input:
		user_input.text = ""

	# Send prompt to Node proxy
	if http_request:
		var body = {"prompt": prompt}
		var json_str = JSON.stringify(body)
		var err = http_request.request(
			proxy_url,
			[],                     # headers (none needed, proxy accepts JSON)
			HTTPClient.METHOD_POST, # HTTP method
			json_str                 # body as string
		)
		if err != OK:
			push_error("Failed to send HTTP request: %d" % err)
	else:
		push_error("HTTPRequest node missing!")


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
	if data.has("text"):
		var ai_text = str(data.text)
		emit_signal("ai_response", ai_text)
		chat_log.append_text("[Pet]: %s\n" % ai_text)
	else:
		push_error("Unexpected API response format")
