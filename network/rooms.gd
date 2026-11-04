extends Node
## Generation checks prevent slow HTTP replies from resurrecting a closed room.

signal changed
var service := preload("res://network/rendezvous.gd").new()
var code := ""
var expires_at := 0.0
var busy := false
var _revoke_token := ""
var _generation := 0

func _ready() -> void:
	add_child(service)
	Session.session_closed.connect(close)

func host() -> bool:
	if not Session.host():
		return false
	return await refresh_code()

func refresh_code() -> bool:
	if busy or Session.role != "host":
		return false
	busy = true
	var expected := _generation
	var endpoint := str(Session.peer.call("endpoint_id"))
	Session._set_status("Hosting · creating join code…")
	var reply: Dictionary = await service.register(endpoint)
	if expected != _generation:
		if reply.ok:
			service.revoke(str(reply.payload.get("code", "")), str(reply.payload.get("revoke_token", "")))
		return false
	busy = false
	if not reply.ok:
		Session._set_status(reply.message + " Hosting remains available by ticket.")
		return false
	var payload: Dictionary = reply.payload
	var new_code := str(payload.get("code", ""))
	var token := str(payload.get("revoke_token", ""))
	var expiry := Time.get_unix_time_from_datetime_string(str(payload.get("expires_at", "")).trim_suffix("Z"))
	if not service.valid_code(new_code) or token.is_empty() or token.length() > 256 or payload.get("endpoint_id") != endpoint or payload.get("session_id") != service.session_id() or expiry <= Time.get_unix_time_from_system():
		service.revoke(new_code, token)
		Session._set_status("Invalid code response. Hosting remains available by ticket.")
		return false
	if not code.is_empty():
		service.revoke(code, _revoke_token)
	code = new_code
	_revoke_token = token
	expires_at = expiry
	Session._set_status("Hosting · join code " + code)
	changed.emit()
	return true

func join(value: String) -> bool:
	value = value.strip_edges()
	if value.length() != 4:
		return Session.join(value)
	Session.leave()
	busy = true
	var expected := _generation
	Session._set_status("Looking up join code…")
	var reply: Dictionary = await service.resolve(value.to_upper())
	if expected != _generation:
		return false
	busy = false
	if not reply.ok:
		Session._set_status(reply.message)
		return false
	return Session.join(str(reply.payload.endpoint_id))

func close() -> void:
	_generation += 1
	busy = false
	if not code.is_empty():
		service.revoke(code, _revoke_token)
	code = ""
	_revoke_token = ""
	expires_at = 0.0
	changed.emit()
