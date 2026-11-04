extends RefCounted
## Local discovery, once per accepted request. Never saved, sent, or used to deliver art.
const SETTLE_MS := 400
const MAX_AGE_MS := 20000
var _context := ""
var _tick := -1
var _revision := -1
var _seen_ready := false
var _pending_at := -1

func reset() -> void:
	_context=""; _tick=-1; _revision=-1; _seen_ready=false; _pending_at=-1

func sample(status: Dictionary,context: String,tick: int,now: int,active: bool=true,allow_notice: bool=true) -> Dictionary:
	var revision:=int(status.get("revision",-1))
	var ready: bool=not status.get("ready",[]).is_empty()
	var fresh:=context!=_context or tick<_tick
	if fresh: reset(); _context=context
	_tick=tick
	if revision!=_revision:
		_revision=revision; _seen_ready=false; _pending_at=-1
	if ready and not _seen_ready:
		_seen_ready=true
		if not fresh and active: _pending_at=now
	if not ready or not active: _pending_at=-1
	if _pending_at<0: return {}
	if now-_pending_at>MAX_AGE_MS: _pending_at=-1; return {}
	if now-_pending_at<SETTLE_MS or not allow_notice: return {}
	_pending_at=-1
	var count: int=status.ready.size()
	var subject:=str(status.subject)+" · §%d" % int(status.reward)
	return {"offer":str(status.offer),"revision":revision,"message":("An original is ready" if count==1 else "%d originals are ready" % count)+" for "+str(status.client).to_lower()+".\n"+subject,"detail":"Open %d matching %s. Choose one to review; nothing is delivered automatically." % [count,"original" if count==1 else "originals"]}
