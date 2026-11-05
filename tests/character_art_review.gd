extends SceneTree
## Native visual contact sheets. Keep captures in ignored build/, not asset output.
const Profile = preload("res://game/character_profile.gd")
var studios: Array[Control]=[]
var labels: Array[Label]=[]

func _initialize() -> void: call_deferred("_run")

func _capture(label: String) -> void:
	for frame in range(8): await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/character-art-"+label+".png")==OK)

func _run() -> void:
	root.size=Vector2i(1600,1000); root.content_scale_size=root.size
	root.get_node("Preferences").settings_path="res://build/character-art-review-settings.json"
	root.get_node("Preferences").reset_defaults()
	root.get_node("Preferences").set_value("reduced_motion",true)
	root.content_scale_factor=1.0
	var grid := GridContainer.new(); grid.columns=4; root.add_child(grid)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in range(8):
		var panel := VBoxContainer.new(); panel.custom_minimum_size=Vector2(396,496); grid.add_child(panel)
		var label := Label.new(); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(label); labels.append(label)
		var studio: Control=load("res://game/character_studio.gd").new(); studio.size_flags_vertical=Control.SIZE_EXPAND_FILL; panel.add_child(studio); studios.append(studio)
	for page in range(2):
		for index in range(8):
			var style := (page*8+index)%10
			var member := {"id":"art-"+str(index),"appearance":{"skin":index%6,"hair":index%6,"shirt":index%8,"style":0}}
			member.character=Profile.defaults(member)
			member.character.hairstyle=style; member.character.face=15+index*12; member.character.nose=15+index*12
			member.character.age=6 if page==1 and index>3 else 5
			studios[index].show_member(member); studios[index].set_close_up(true); studios[index].yaw=-0.22 if index%2==0 else 0.28
			labels[index].text=Profile.HAIRSTYLES[style]+" · "+str(member.character.face)
		await _capture("faces-"+str(page))
		for studio in studios: studio.yaw=PI*0.65; studio.set_night(true)
		await _capture("reverse-"+str(page))
	for index in range(8):
		var member := {"id":"wardrobe-"+str(index),"appearance":{"skin":index%6,"hair":index%6,"shirt":index%8,"style":0}}
		member.character=Profile.defaults(member)
		member.character.hairstyle=index
		member.character.build=20+index*10; member.character.shoulders=80-index*10; member.character.hips=20+index*10
		var occasion: String=Profile.OCCASIONS[index%7]
		member.character.outfits[occasion].accessory=index%5
		studios[index].show_member(member,occasion); studios[index].set_close_up(false); studios[index].set_night(false); studios[index].yaw=-0.28
		labels[index].text=Profile.OCCASION_NAMES[index%7]
	await _capture("wardrobe")
	print("CHARACTER_ART_REVIEW_PASS")
	await root.get_node("Soundscape").shutdown_and_wait(); quit()
