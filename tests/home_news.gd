extends SceneTree
const World = preload("res://game/world.gd")
const News = preload("res://game/home_news.gd")
var world: RefCounted
var family: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _fresh() -> void:
	world=World.new(); world.initialize(); world.ensure_family("a","Alex"); world.ensure_family("b","Violet")
	world.set_online("a",true); world.set_online("b",true)
	family=world.state.families.a

func _mail(gift: int=100) -> Dictionary:
	return world.apply_command("b",{"type":"mail_send","recipient":"a","sequence":world.state.families.b.mailbox.next_sent,"note":"Tea when you get home?","gift":gift})

func _read(revision: Variant, owner: String="a") -> Dictionary:
	return world.apply_command(owner,{"type":"news_read","revision":revision})

func _run() -> void:
	_fresh()
	assert(family.home_news.report.is_empty(),"First arrival has no invented absence")
	world.set_online("a",false); world.step(1.0); world.set_online("a",true)
	assert(family.home_news.report.is_empty(),"A quiet quick reconnect creates no distracting recap")
	world.set_online("a",false)
	for tick in range(20): world.step(1.0)
	world.set_online("a",false)
	assert(is_equal_approx(float(family.home_news.minutes),60.0),"Repeated offline cleanup preserves elapsed time")
	assert(_mail().ok)
	var original_funds: int=world.state.lots.lot_1.funds
	world.state.day_minutes=1439.0; world.step(1.0)
	world.set_online("a",true)
	var report: Dictionary=family.home_news.report
	assert(report.minutes==63 and report.allowance==600 and report.postcards==1 and report.gifts==100 and report.pending)
	assert(world.state.lots.lot_1.funds==original_funds+600 and not family.mailbox.items[0].claimed,"Recap does not collect gifts or add extra income")
	assert(News.elapsed(1501)=="1 day, 1 hour, 1 minute of neighborhood time")
	var before: Dictionary=world.snapshot()
	world.set_online("a",true)
	assert(world.snapshot()==before,"Repeated online presence cannot manufacture another report")
	for invalid: Variant in [null,[],"1",1.5,0,2]:
		assert(not _read(invalid).ok and world.snapshot()==before,"Invalid or stale read revisions are atomic")
	assert(not _read(1,"b").ok and News.pending(family),"Another household cannot read your recap")
	world.set_online("a",false)
	for tick in range(10): world.step(1.0)
	assert(_mail(250).ok)
	world.set_online("a",true)
	report=family.home_news.report
	assert(report.id==2 and report.minutes==93 and report.allowance==600 and report.postcards==2 and report.gifts==350,"Unread absence reports accumulate without losing the earlier facts")
	assert(not _read(1).ok and _read(2).ok and _read(2).ok,"Only the current report is acknowledged, idempotently")
	assert(not News.pending(family) and family.home_news.report.postcards==2,"Read reports remain available")
	world.set_online("a",false)
	for tick in range(10): world.step(1.0)
	world.set_online("a",true)
	assert(family.home_news.report.id==3 and family.home_news.report.minutes==30 and family.home_news.report.allowance==0 and family.home_news.report.postcards==0,"A new absence replaces a read report instead of repeating old income/mail")
	var saved: Dictionary=world.snapshot_for_save()
	var replica := World.new()
	assert(replica.restore(JSON.parse_string(JSON.stringify(saved))))
	var retained: Dictionary=replica.state.families.a.home_news.report.duplicate(true)
	replica.set_online("a",true)
	assert(replica.state.families.a.home_news.report==retained,"Host downtime generates no time or allowance")
	assert(replica.restore(saved,true) and replica.state.families.a.home_news==family.home_news,"Runtime snapshots retain counters and report")
	# A running absence survives host save/restart and continues from recorded facts.
	world.set_online("a",false)
	for tick in range(10): world.step(1.0)
	assert(replica.restore(world.snapshot_for_save()))
	for tick in range(10): replica.step(1.0)
	replica.set_online("a",true)
	assert(replica.state.families.a.home_news.report.minutes==90,"Unread 30 minutes plus 60 minutes of actual absence, with no wall-clock catch-up")
	var stable: Dictionary=replica.snapshot()
	for bad: Variant in [null,{},7,{"seen":true}]:
		var broken: Dictionary=stable.duplicate(true); broken.families.a.home_news=bad
		assert(not replica.restore(broken) and replica.snapshot()==stable)
	for field: String in ["minutes","allowance","postcards","gifts","sequence"]:
		var broken: Dictionary=stable.duplicate(true); broken.families.a.home_news[field]=-1
		assert(not replica.restore(broken) and replica.snapshot()==stable)
	var legacy: Dictionary=stable.duplicate(true)
	for resident_family: Dictionary in legacy.families.values(): resident_family.erase("home_news")
	assert(replica.restore(legacy) and replica.state.families.a.home_news.report.is_empty(),"Legacy saves begin tracking prospectively")
	_fresh()
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":"lot_1","kind":"floor","x":0,"y":0}).ok)
	world.set_online("a",false); world.set_online("a",true)
	assert(family.home_news.report.construction and not [0,0] in world.state.lots.lot_1.floors,"Discarded draft is reported from actual disconnect cleanup")
	# Actual allowance is capped against every reversible balance, not only the draft.
	_fresh(); world.state.lots.lot_1.funds=999999990
	world.set_online("a",false); world.state.day_minutes=1439.0; world.step(1.0); world.set_online("a",true)
	assert(family.home_news.report.allowance==10 and world.state.lots.lot_1.funds==1000000000,"Recap records the actual capped credit")
	world.set_online("a",false); world.state.day_minutes=1439.0; world.step(1.0); world.set_online("a",true)
	assert(family.home_news.report.allowance==10 and replica.restore(world.snapshot_for_save()),"A capped household cannot overflow its saved funds")
	_fresh(); world.state.lots.lot_1.funds=999999990
	assert(world.apply_command("a",{"type":"build_begin","lot_id":"lot_1"}).ok)
	assert(world.apply_command("a",{"type":"place","lot_id":"lot_1","kind":"floor","x":0,"y":0}).ok)
	world.state.day_minutes=1439.0; world.step(1.0)
	assert(world.apply_command("a",{"type":"build_cancel","lot_id":"lot_1"}).ok)
	assert(world.state.lots.lot_1.funds==1000000000 and replica.restore(world.snapshot_for_save()),"Undo/discard balances respect the same funds cap")
	print("HOME_NEWS_PASS")
	quit()
