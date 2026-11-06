extends RefCounted
## Original Linden Grove pictograms. Editable SVG geometry, no font/emoji dependency.
## These are UI surfaces only; world furniture always uses the existing 3D models.
const PATHS := {
	"lamp": '<path d="M8 3h8l5 9H3zM12 12v10m-6 0h12"/>',
	"chair": '<path d="M6 14V3h12v11M4 14h16v4H4zm2 4v4m12-4v4M9 5v7m6-7v7"/>',
	"tree": '<path d="M10 22h4v-7c8 2 10-6 5-8 0-7-12-7-13 0-5 2-3 10 4 8z"/>',
	"flowers": '<circle cx="12" cy="8" r="2"/><path d="M10 6c-5-5 4-8 4-2 7-3 7 6 2 6 3 6-6 7-6 2-6 2-8-6-2-6m4 8v8m0-4c-7 0-7-4-7-4m7 6c6 0 7-4 7-4"/>',
	"fence": '<path d="M4 22V5l3-3 3 3v17m4 0V5l3-3 3 3v17M1 9h22M1 17h22"/>',
	"rock": '<path d="m2 17 4-11 9-3 7 9-3 9H6zm4-11 6 6 10 0m-10 0 7 9"/>',
	"stairs": '<path d="M2 21v-5h5v-5h5V6h5V2h5v20H2"/>',
	"pool": '<path d="M6 15V4a2 2 0 0 1 4 0m4 11V4a2 2 0 0 1 4 0M6 8h8M6 12h8M2 18q3-3 6 0t6 0 6 0M2 22q3-3 6 0t6 0 6 0"/>',
	"terrain_up": '<path d="M2 21q10-11 20 0M12 15V2m-5 5 5-5 5 5"/>',
	"terrain_down": '<path d="M2 21q10-11 20 0M12 2v13m-5-5 5 5 5-5"/>',
	"terrain_flat": '<path d="M2 20h20M12 2v12m-5-5 5 5 5-5"/>',
	"grass": '<path d="M2 22h20M6 22Q6 8 2 4q10 5 10 18M12 22Q9 3 13 2m1 20q0-10 8-15-4 8-4 15"/>',
	"soil": '<path d="m2 10 10-7 10 7-10 7zm0 5 10 7 10-7M8 9h1m6 1h1m-5 2h1"/>',
	"diagonal": '<path d="m2 17 15-15 5 5L7 22zm3-3 5 5M10 9l5 5m0-10 5 5"/>',
	"settings": '<path d="M9 2h6l1 4 4 1 2 5-3 3v5l-5 2-3-3H6l-4-5 3-4V5z"/><circle cx="12" cy="12" r="3"/>',
	"help": '<circle cx="12" cy="12" r="10"/><path d="M8 8a4 4 0 1 1 6 3c-2 1-2 2-2 3m0 4v1"/>',
	"load": '<path d="M3 20V4h7l3 3h8v13zM12 9v8m-4-4 4 4 4-4"/>',
	"new_home": '<path d="m2 11 10-8 10 8M5 9v12h14V9m-7 2v7m-3-3h6"/>',
	"power": '<path d="M12 2v10M6 5a9 9 0 1 0 12 0"/>',
	"network": '<circle cx="12" cy="12" r="10"/><ellipse cx="12" cy="12" rx="4" ry="10"/><path d="M2 12h20"/>',
	"console": '<path d="m3 5 6 7-6 7m9 0h9"/>',
	"catalog": '<path d="M3 5h7l2 2 2-2h7v15h-7l-2 2-2-2H3zM12 7v15M6 10h3m-3 4h3m6-4h3m-3 4h3"/>',
	"build": '<path d="m4 21 10-12-3-3 3-3 7 6-3 3-2-2L6 22zM3 3l5 5"/>',
	"check": '<path d="m4 12 5 5L20 6"/>',
	"close": '<path d="m6 6 12 12M18 6 6 18"/>',
	"back": '<path d="m14 5-7 7 7 7M7 12h14"/>',
	"next": '<path d="m10 5 7 7-7 7M3 12h14"/>',
	"more": '<circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/>',
	"menu": '<path d="M4 6h16M4 12h16M4 18h16"/>',
	"home": '<path d="m2 11 10-8 10 8M5 9v12h5v-7h4v7h5V9"/>',
	"neighborhood": '<path d="m2 7 4-4 4 4M3 6v6h6V6m5 3 4-4 4 4m-7-1v6h6V8M5 17h14m-7-4v8"/>',
	"visit": '<path d="m10 8 6-5 6 5m-10-2v15h8V6M2 14h12m-4-4 4 4-4 4"/>',
	"people": '<circle cx="9" cy="6" r="3"/><path d="M3 20v-4a6 6 0 0 1 12 0v4M16 3a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 5v3"/>',
	"person": '<circle cx="12" cy="6" r="3"/><path d="M5 21v-5a7 7 0 0 1 14 0v5"/>',
	"household": '<circle cx="8" cy="6" r="3"/><path d="M2 20v-4a6 6 0 0 1 10-4m0 7 8-8 2 2-8 8-3 1z"/>',
	"together": '<circle cx="6" cy="5" r="2"/><circle cx="16" cy="5" r="2"/><path d="M2 14v-3a4 4 0 0 1 8 0v3m2 0v-3a4 4 0 0 1 8 0v3M4 19h16m-4-3 4 3-4 3"/>',
	"mail": '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 6 9 7 9-7"/>',
	"save": '<path d="M4 3h13l4 4v14H3V3h1m3 0v7h10V3M7 21v-7h10v7"/>',
	"find": '<circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="1"/><path d="M12 1v5m0 12v5M1 12h5m12 0h5"/>',
	"needs": '<path d="M3 5h18M3 12h18M3 19h18"/><circle cx="8" cy="5" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="10" cy="19" r="2"/>',
	"plan": '<path d="M9 5h12M9 12h12M9 19h12m-19-15 2 2 3-3m-5 8 2 2 3-3m-5 8 2 2 3-3"/>',
	"heart": '<path d="M12 21 3 12C-2 5 7 0 12 7c5-7 14-2 9 5z"/>',
	"star": '<path d="m12 2 3 6 7 1-5 5 1 8-6-4-6 4 1-8-5-5 7-1z"/>',
	"activities": '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="8" cy="8" r="1"/><circle cx="16" cy="8" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="8" cy="16" r="1"/><circle cx="16" cy="16" r="1"/>',
	"history": '<path d="M4 8a9 9 0 1 1-1 8M3 3v6h6m3-3v6l4 3"/>',
	"repeat": '<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
	"autonomy": '<path d="M9 3h6l-1 7h6L9 22l2-9H5z"/>',
	"stop": '<rect x="5" y="5" width="14" height="14" rx="2"/>',
	"pause": '<path d="M8 4v16M16 4v16"/>',
	"fast": '<path d="m2 4 9 8-9 8zm11 0 9 8-9 8z"/>',
	"faster": '<path d="m1 5 6 7-6 7zm8 0 6 7-6 7zm8 0 6 7-6 7z"/>',
	"play": '<path d="m7 3 14 9-14 9z"/>',
	"undo": '<path d="m8 3-6 6 6 6M2 9h12a7 7 0 0 1 0 14"/>',
	"redo": '<path d="m16 3 6 6-6 6m6-6H10a7 7 0 0 0 0 14"/>',
	"rotate": '<path d="M19 7a9 9 0 1 0 2 10M20 2v6h-6"/>',
	"move": '<path d="M12 2v20M2 12h20M8 6l4-4 4 4m-8 12 4 4 4-4M6 8l-4 4 4 4m12-8 4 4-4 4"/>',
	"sell": '<path d="m3 3 10 1 9 9-9 9-9-9z"/><circle cx="8" cy="8" r="1.5"/>',
	"discard": '<path d="M3 6h18M9 6V3h6v3M5 6l1 16h12l1-16M10 10v8m4-8v8"/>',
	"access": '<path d="M3 20V4h7v16m-7-5h14V6m-4 4 4-4 4 4"/>',
	"search": '<circle cx="10" cy="10" r="6"/><path d="m15 15 7 7"/>',
	"all": '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
	"bed": '<path d="M3 21V5m18 16V9M3 17h18M3 9h7v8m0-7h11M5 6h3"/>',
	"fridge": '<rect x="5" y="2" width="14" height="20" rx="2"/><path d="M5 9h14M8 5v1m0 6v4"/>',
	"shower": '<path d="M19 22V5a3 3 0 0 0-6 0v2M9 9h8l-4-3zM8 13l-1 2m5-2-1 2m5-2-1 2M6 19l-1 2m5-2-1 2m5-2-1 2"/>',
	"toilet": '<path d="M4 3h6v10H3a8 8 0 0 0 14 5l1-5H10M8 20v2h8v-4m-3-8h8"/>',
	"sofa": '<path d="M5 11V6a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v5M5 20v2m14-2v2M2 10h4v5h12v-5h4v10H2z"/>',
	"tv": '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="m8 1 4 4 4-4M8 22h8"/>',
	"bookshelf": '<path d="M3 3h18v19H3zM3 12h18M7 5v5m4-5v5m4-5 3 5M7 15v5m4-5v5m5-5v5"/>',
	"table": '<path d="M2 9h20v4H2zM5 13v9m14-9v9M8 3h7v5H8zm7 0h3v3h-3"/>',
	"food": '<circle cx="14" cy="12" r="7"/><path d="M3 3v6m-2-6v4a2 2 0 0 0 4 0V3M3 9v13"/>',
	"plant": '<path d="M7 15h10l-2 7H9zM12 15V8C3 8 3 2 3 2s9-1 9 6m0 4c0-8 9-8 9-8s1 8-9 8"/>',
	"garden_bed": '<path d="M2 13h20v9H2zM8 13V6m0 4C2 10 3 5 3 5s5 0 5 5m8 3V4m0 4c6 0 5-5 5-5s-5 0-5 5"/>',
	"palette": '<path d="M12 2a10 10 0 1 0 0 20h2c3 0 3-4 1-5s-1-3 2-3h3c5-2 1-12-8-12z"/><circle cx="7" cy="8" r="1"/><circle cx="12" cy="5" r="1"/><circle cx="17" cy="8" r="1"/><circle cx="5" cy="14" r="1"/>',
	"room": '<path d="M3 3h18v18h-6v-6h-6v6H3z"/>',
	"copy": '<path d="M8 3H3v14h5M8 8h13v14H8zM12 12h5m-5 4h5"/>',
	"floor": '<path d="m2 12 10-8 10 8-10 8zm5-4 10 8M7 16l10-8"/>',
	"wall": '<path d="M2 4h20v16H2zM2 9h20M2 15h20M8 4v5m8-5v5M6 9v6m7-6v6m6-6v6M8 15v5m8-5v5"/>',
	"door": '<path d="M4 22V2h16v20M7 22V5h10v17M13 13h1"/>',
	"window": '<path d="M3 3h18v18H3zM12 3v18M3 12h18"/>',
	"art": '<rect x="2" y="3" width="20" height="18" rx="1"/><circle cx="16" cy="8" r="2"/><path d="m3 18 6-7 5 5 3-3 4 5"/>',
	"stereo": '<rect x="2" y="4" width="20" height="17" rx="2"/><circle cx="7" cy="15" r="3"/><circle cx="17" cy="15" r="3"/><path d="M6 8h12"/>',
	"chat": '<path d="M3 3h18v14H9l-6 5zm4 5h10M7 12h7"/>',
	"info": '<circle cx="12" cy="12" r="10"/><path d="M12 11v7m0-12v1"/>',
	"walk": '<circle cx="14" cy="4" r="2"/><path d="m4 14 5-5 5 1 4 5h4M12 10l-2 6-6 6m6-6 6 2 1 4"/>',
	"happy": '<circle cx="12" cy="12" r="10"/><path d="M8 8v1m8-1v1M7 14q5 7 10 0"/>',
	"neutral": '<circle cx="12" cy="12" r="10"/><path d="M8 8v1m8-1v1M7 16h10"/>',
	"sad": '<circle cx="12" cy="12" r="10"/><path d="M8 8v1m8-1v1M7 18q5-7 10 0"/>'
}
const ALIASES := {"seating":"sofa","lighting":"lamp","armchair":"chair","loveseat":"sofa","long_sofa":"sofa","wood_chair":"chair","garden_bench":"sofa","floor_lamp":"lamp","arc_lamp":"lamp","globe_lamp":"lamp","pendant_lamp":"lamp","garden_lantern":"lamp","lamp_post":"lamp","linden_tree":"tree","hedge":"tree","picket_fence":"fence","boulder":"rock","diagonal_wall":"diagonal","terrain_raise":"terrain_up","terrain_lower":"terrain_down","terrain_flatten":"terrain_flat","terrain_grass":"grass","terrain_dirt":"soil","terrain_sand":"soil","terrain_gravel":"rock","hunger":"food","energy":"bed","hygiene":"shower","bladder":"toilet","fun":"activities","social":"chat","comfort":"sofa","structure":"build","bedroom":"bed","kitchen":"food","bathroom":"shower","living":"sofa","garden":"plant","finishes":"palette","dining_table":"food","game_table":"activities","easel":"palette","wall_art":"art","furniture_color":"palette","finish_floor":"floor","finish_wall":"wall","saved_rooms":"catalog","copy_room":"copy","clear_lot":"discard"}
const ACTIONS := {
	"Play starter household":"play","Customize household":"household","Continue":"play","Resume":"play","New neighborhood":"new_home","Load neighborhood":"load",
	"Save neighborhood":"save","Settings":"settings","Guide & controls":"help","Quit":"power",
	"Quit to desktop":"power","Main menu":"menu","Developer console":"console","Household":"household",
	"Back":"back","Back to neighborhood":"back","Start your day":"play",
	"Floors":"floor","Walls":"wall","Area":"floor","Room":"room",
	"⌂":"neighborhood","☰":"menu","×":"close","Cancel":"close","‹ Back":"back","More ›":"next",
	"Create a household":"household","Edit household":"household","Needs":"needs","Wishes":"heart","Hobbies":"star","Plan":"plan",
	"Routines":"repeat","Recent":"history","Find resident":"find","More":"more","Build & furnish":"build",
	"Activities":"activities","Visit lot":"visit","Go home":"home","Together…":"together","People":"people",
	"Cancel actions":"stop","Mail":"mail","Play together":"network","Home overview":"home","Center view":"find","Save":"save",
	"People ›":"people","Review originals ›":"art","‹ Activities":"back","Garden ›":"plant",
	"‹ Catalog":"back","Rotate ↻":"rotate","Move family":"together","Door":"door","Move":"move",
	"Sell":"sell","Undo":"undo","Redo":"redo","Cancel area":"close","Cancel move":"close",
	"Save room…":"save","Show everything":"all","Remove window":"discard",
	"Art commissions":"art","Your kitchen garden":"garden_bed","Chat with family":"chat","Clear action queue":"stop"
}
static var _cache: Dictionary = {}

static func has_icon(id: String) -> bool:
	return PATHS.has(str(ALIASES.get(id,id)))

static func texture(id: String, pixels: int=28) -> Texture2D:
	id=str(ALIASES.get(id,id))
	# Catalogs can grow independently of presentation. Keep new named entries usable.
	if not PATHS.has(id): id="catalog"
	var cache_key := id+":"+str(pixels)
	if not _cache.has(cache_key):
		var image := Image.new()
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24"><g fill="none" stroke="white" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+str(PATHS[id])+'</g></svg>'
		assert(image.load_svg_from_string(svg,float(pixels)/28.0)==OK)
		_cache[cache_key]=ImageTexture.create_from_image(image)
	return _cache[cache_key]

static func apply(button: Button, id: String, label: String, badge: String="") -> void:
	button.icon=texture(id)
	button.set_meta("icon_badge",badge)
	var caption := str(button.get_meta("navigation_label",""))
	button.text=(caption+(" · "+badge if not badge.is_empty() else "")) if not caption.is_empty() else badge
	button.expand_icon=true
	button.add_theme_constant_override("icon_max_width",26)
	button.custom_minimum_size=Vector2(44 if badge.is_empty() else 68+maxi(0,badge.length()-1)*6,44)
	button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER if button.text.is_empty() else HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("icon_id",id)
	button.accessibility_name=label
	button.tooltip_text=label
	button.add_theme_color_override("icon_normal_color",Color("f4f0df"))
	button.add_theme_color_override("icon_hover_color",Color("f4f0df"))
	button.add_theme_color_override("icon_focus_color",Color("f4f0df"))
	button.add_theme_color_override("icon_pressed_color",Color("142329"))
	button.add_theme_color_override("icon_disabled_color",Color("63797d"))

static func action(button: Button, label: String) -> void:
	if ACTIONS.has(label): apply(button,str(ACTIONS[label]),str({"×":"Close","⌂":"Neighborhood","☰":"Game menu"}.get(label,label)))

static func navigation(button: Button, caption: String, labeled: bool) -> void:
	button.set_meta("navigation_label",caption if labeled else "")
	button.text=(caption+(" · "+str(button.get_meta("icon_badge","")) if not str(button.get_meta("icon_badge","")).is_empty() else "")) if labeled else str(button.get_meta("icon_badge",""))
	button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT if not button.text.is_empty() else HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon=false
	button.custom_minimum_size.x=maxf(44.0,button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x+42.0) if labeled else 44.0
