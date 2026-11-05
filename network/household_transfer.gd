extends RefCounted
## Bounded, atomic creator requests over the existing 1024-byte transport.
## One assembly per authenticated peer, expired after ten seconds. No world access.
const RAW_LIMIT := 49152
const WIRE_LIMIT := 32768
const PART_BYTES := 540
const PART_LIMIT := 61
const Character = preload("res://game/character_profile.gd")
var assemblies := {}

static func packets(id: int, intent: Dictionary) -> Array:
	if intent.get("type")!="household_edit": return []
	var raw := JSON.stringify(intent).to_utf8_buffer()
	if raw.size()>RAW_LIMIT: return []
	var compressed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.size()>WIRE_LIMIT: return []
	var count := ceili(float(compressed.size())/PART_BYTES)
	var result: Array=[]
	for index in range(count):
		result.append({"type":"household_part","id":id,"index":index,"count":count,"size":raw.size(),"hash":raw.hex_encode().sha256_text(),"data":Marshalls.raw_to_base64(compressed.slice(index*PART_BYTES,(index+1)*PART_BYTES))})
	return result

func receive(sender: int, message: Dictionary, now: int) -> Dictionary:
	for peer_id: int in assemblies.keys():
		if now-int(assemblies[peer_id].at)>10000: assemblies.erase(peer_id)
	if not Character.integer(message.get("id"),1,2147483647) or not Character.integer(message.get("index"),0,PART_LIMIT-1) or not Character.integer(message.get("count"),1,PART_LIMIT) or int(message.index)>=int(message.count) or not Character.integer(message.get("size"),1,RAW_LIMIT): return {}
	if not message.get("data") is String or message.data.length()>720 or not message.get("hash") is String or message.hash.length()!=64: return {}
	var bytes := Marshalls.base64_to_raw(message.data)
	if bytes.is_empty() or bytes.size()>PART_BYTES: return {}
	var assembly: Dictionary=assemblies.get(sender,{})
	if assembly.is_empty() or int(message.id)>int(assembly.id):
		assembly={"id":int(message.id),"at":now,"count":int(message.count),"size":int(message.size),"hash":message.hash,"parts":{}}
		assemblies[sender]=assembly
	if int(message.id)!=int(assembly.id) or int(message.count)!=int(assembly.count) or int(message.size)!=int(assembly.size) or message.hash!=assembly.hash: return {}
	if assembly.parts.has(int(message.index)) and assembly.parts[int(message.index)]!=bytes:
		assemblies.erase(sender); return {}
	assembly.parts[int(message.index)]=bytes
	if assembly.parts.size()!=int(assembly.count): return {}
	assemblies.erase(sender)
	var compressed := PackedByteArray()
	for index in range(assembly.count): compressed.append_array(assembly.parts[index])
	if compressed.size()>WIRE_LIMIT: return {}
	var raw := compressed.decompress(int(assembly.size),FileAccess.COMPRESSION_DEFLATE)
	if raw.size()!=int(assembly.size) or raw.hex_encode().sha256_text()!=assembly.hash: return {}
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8())!=OK or not parser.data is Dictionary or parser.data.get("type")!="household_edit": return {}
	return {"type":"command","id":int(assembly.id),"intent":parser.data}
