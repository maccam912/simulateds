extends Button
## Native drag/drop keeps purchase deferred until a valid drop on the lot.
var kind := ""

func _get_drag_data(_at: Vector2) -> Variant:
	if disabled: return null
	# Keep the source card alive for Godot's entire native drag. Selecting the tool
	# here would rebuild the catalog and discard the control owning the gesture.
	var preview := TextureRect.new()
	preview.texture=get_node("Picture").texture
	preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size=Vector2(100,80)
	set_drag_preview(preview)
	return {"build_catalog_kind":kind}
