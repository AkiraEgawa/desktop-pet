extends Node
class_name ChatManager

@export var proxy_url: String = "http://127.0.0.1:3000/gemini"  # local proxy URL
@export var scroll_speed: float = 10.0  # Lerp speed for smooth scroll

# Nodes
var http_request: HTTPRequest
var chat_panel: Window
var user_input: LineEdit
var chat_log: RichTextLabel
var send_button: Button
var scroll_container: ScrollContainer  # Wrap chat_log in ScrollContainer

signal ai_response(text: String)

# Smooth scrolling
var target_scroll_v: float = 0.0

func _ready():
	# Get nodes safely
	http_request = get_node_or_null("HTTPRequest")
	chat_panel = get_node_or_null("ChatPanel")
	user_input = get_node_or_null("ChatPanel/UserInput")
	chat_log = get_node_or_null("ChatPanel/ChatLog")
	send_button = get_node_or_null("ChatPanel/SendButton")

	if chat_log:
		scroll_container = chat_log.get_parent() as ScrollContainer
	else:
		push_error("ChatLog missing!")

	if not chat_panel:
		push_error("ChatPanel missing!")
		return
	chat_panel.hide()  # hide at start

	# Connect Send button
	if send_button:
		send_button.pressed.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("SendButton missing!")

	# Connect Enter key
	if user_input:
		user_input.text_submitted.connect(Callable(self, "_on_send_pressed"))
	else:
		push_error("UserInput missing!")

	# Connect HTTPRequest signal
	if http_request:
		http_request.request_completed.connect(Callable(self, "_on_request_completed"))
	else:
		push_error("HTTPRequest missing!")

func _process(delta: float) -> void:
	# Smooth scroll
	if scroll_container:
		var scrollbar: ScrollBar = scroll_container.get_v_scrollbar()
		scrollbar.value = lerp(scrollbar.value, target_scroll_v, delta * scroll_speed)

# Open chat panel
func open_chat():
	if chat_panel and user_input:
		chat_panel.popup_centered()
		user_input.text = ""
		user_input.grab_focus()
	else:
		push_error("Cannot open chat: chat_panel or user_input is null")

# Called on Send button pressed or Enter
func _on_send_pressed(submitted_text: String = ""):
	var prompt: String = submitted_text.strip_edges()
	if prompt == "" and user_input:
		prompt = user_input.text.strip_edges()
	if prompt == "":
		return

	_send_to_proxy(prompt)

	# Show user message in chat log
	if chat_log:
		chat_log.append_text("[You]: %s\n" % prompt)
		_scroll_chat_to_bottom()

	# Clear input
	if user_input:
		user_input.text = ""

func _send_to_proxy(prompt: String) -> void:
	if not http_request:
		push_error("HTTPRequest missing!")
		return

	# Add Shiba-san personality context
	var personality: String = "You are Shiba-san, a smart, homeless uncle who speaks very straightforwardly and avoids fluff."
	var full_prompt: String = "%s\nUser: %s" % [personality, prompt]

	var body: Dictionary = { "prompt": full_prompt }
	var json_body_str: String = JSON.stringify(body)
	var headers: Array[String] = ["Content-Type: application/json"]

	var err: int = http_request.request(
		proxy_url,
		headers,
		HTTPClient.METHOD_POST,
		json_body_str
	)

	if err != OK:
		push_error("Failed to send HTTP request: %d" % err)


# Callback when proxy responds
func _on_request_completed(result: int, response_code: int, headers: Array, body: PackedByteArray) -> void:
	if result != OK or response_code != 200:
		push_error("HTTP request failed: %d, code %d" % [result, response_code])
		return

	if not chat_log:
		push_error("ChatLog missing!")
		return

	var body_text: String = body.get_string_from_utf8()
	var parse_result = JSON.parse_string(body_text)

	if typeof(parse_result) == TYPE_DICTIONARY:
		var data: Dictionary = parse_result
		if typeof(data) == TYPE_DICTIONARY and data.has("text"):
			var ai_text: String = str(data.text)
			emit_signal("ai_response", ai_text)
			chat_log.append_text("[Pet]: %s\n" % ai_text)
			_scroll_chat_to_bottom()
		else:
			push_error("Unexpected API response format: %s" % body_text)
	else:
		push_error("Failed to parse JSON: %s" % body_text)

# Smooth scroll helper
func _scroll_chat_to_bottom() -> void:
	if not scroll_container:
		return
	var scrollbar: ScrollBar = scroll_container.get_v_scrollbar()
	target_scroll_v = scrollbar.max_value
