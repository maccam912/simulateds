extends Node
## Existing join-code service. Revocation credentials are never saved or logged.

const PATH := "/v1/join-codes"
const ALPHABET := "23456789ABCDEFGHJKMNPQRSTVWXYZ"

static func valid_code(value: String) -> bool:
	if value.length() != 4:
		return false
	for character in value:
		if not character in ALPHABET:
			return false
	return true

func session_id() -> String:
	return str(ProjectSettings.get_setting("network/iroh/session_id", "godot-iroh-starter/1"))

func register(endpoint: String) -> Dictionary:
	return await request(PATH, HTTPClient.METHOD_POST, {"endpoint_id":endpoint, "session_id":session_id(), "expires_in":600})

func resolve(code: String) -> Dictionary:
	if not valid_code(code):
		return {"ok":false, "message":"Enter a four-character join code."}
	var reply := await request(PATH + "/" + code)
	if reply.ok:
		if reply.payload.get("session_id") != session_id():
			return {"ok":false, "message":"This code is for a different game or protocol version."}
		var endpoint := str(reply.payload.get("endpoint_id", ""))
		if endpoint.length() != 43:
			return {"ok":false, "message":"Invalid endpoint returned by the code service."}
	return reply

func revoke(code: String, token: String) -> void:
	if valid_code(code) and not token.is_empty():
		await request(PATH + "/" + code, HTTPClient.METHOD_DELETE, {}, token)

func request(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, token: String = "") -> Dictionary:
	var url := str(ProjectSettings.get_setting("network/iroh/rendezvous_url", "")).trim_suffix("/")
	if url.is_empty():
		return {"ok":false, "message":"Join-code service disabled. Use a full ticket instead."}
	var http := HTTPRequest.new()
	http.timeout = 10
	http.body_size_limit = 16384
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var error := http.request(url + path, headers, method, JSON.stringify(payload) if method == HTTPClient.METHOD_POST else "")
	if error != OK:
		http.queue_free()
		return {"ok":false, "message":"Could not reach join-code service. Full tickets still work."}
	var result: Array = await http.request_completed
	http.queue_free()
	var status := int(result[1])
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok":false, "message":"Join-code service timed out. Try again or use a ticket."}
	if status == 404:
		return {"ok":false, "message":"Code expired or not found. Ask the host for a new code."}
	if status == 429:
		return {"ok":false, "message":"Join-code service is busy. Wait before retrying."}
	if status == 204:
		return {"ok":true, "payload":{}}
	if status < 200 or status >= 300:
		return {"ok":false, "message":"Join-code service returned HTTP %d." % status}
	var parser := JSON.new()
	if parser.parse((result[3] as PackedByteArray).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {"ok":false, "message":"Invalid response from join-code service."}
	return {"ok":true, "payload":parser.data}
