extends RefCounted
## Publish only complete test handoffs; other processes poll the final path.
static func publish(path: String,text: String) -> void:
	var absolute:=ProjectSettings.globalize_path(path)
	var temporary:=absolute+".pending-"+str(OS.get_process_id())
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	assert(file!=null,"Cannot create peer handoff: "+temporary)
	file.store_string(text); file.flush()
	var error:=file.get_error(); file.close()
	assert(error==OK,"Cannot write peer handoff: "+temporary)
	assert(DirAccess.rename_absolute(temporary,absolute)==OK,"Cannot publish peer handoff: "+absolute)
