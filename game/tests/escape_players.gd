extends RefCounted
## Stand-in first-time players for the burned hall's escape
## (docs/design/notes/first-fight.md), shared by tools/diag_first_fight.gd
## and tests/test_escape.gd. Each model presses the battle screen's controls
## as the HUD lets a player press them: a control the tutorial has shut
## (Tutorial.allowed) or that is disabled (Withdraw out of reach) does
## nothing, a shout toggles the one waiting, Next round fights the round
## with it, and a tap on the board does what BattleView._tap does. Not a
## test file itself (the runner takes only test_*.gd); load it by path.
##
## The models:
##   exact      presses what the banner asks, every time
##   late       presses the asked shout one round late (a Next round first)
##   early      presses the next lesson's shout a round early (Fall Back
##              while still asked to push, Withdraw while asked to fall back)
##   observed   the live playtest: Go on, Shield Wall, Next round, Push, six
##              Next rounds, then Fall Back, Next round, Withdraw, over and over
##   next_only  presses Next round and nothing else it is not made to press
##   back_after_push  after every round under Push, presses Fall Back
##   taps       follows the banner, and taps the board at random between rounds
##   push_only  never falls back: Push wherever the banner says Fall Back
##   withdraw   presses Withdraw whenever it is not disabled
##   random     random presses among the controls that answer
##   nothing    gives no order at all (the sim alone: no tutorial)

const MODELS := ["exact", "late", "early", "observed", "next_only", "back_after_push", "taps", "push_only", "withdraw", "random", "nothing"]
## Presses before a stand-in gives up (a lock it cannot get past).
const MAX_PRESSES := 400
## Rounds before the harness stops a fight that will not end (the battle's
## own `run` then finishes it).
const MAX_ROUNDS := 40


## One escape played by `model` on `seed_in`. Returns what happened:
## {out: on his feet and away, carried: the leader down, rounds, idle: rounds
## that brought him no nearer the dark, lost: of his men, those down, broken
## or fled at the end, dead: of his men, dead after the aftermath, bad: rounds
## the banner asked for something the player could not usefully do, stuck:
## the stand-in could not press on, rescued: the saga's own rescue ended it,
## capped: the round cap ended it, texts: the banner's words each round}.
static func play(model: String, seed_in: int) -> Dictionary:
	var j := Journey.begin(seed_in, "burned_hall", "Egil", true)
	var b: Battle = j.fight.built.battle
	var lw: Warrior = null
	for w in j.fight.built.ours:
		if (w as Warrior).id == j.c.band.leader.id:
			lw = w
	var st := {"model": model, "j": j, "b": b, "leader": lw, "t": null, "pending": CombatTypes.Shout.NONE,
			"action": null, "advance": false, "rng": SimRng.new(seed_in).fork("player:" + model),
			"idle": 0, "bad": 0, "impossible": 0, "texts": [], "last_text": "", "last_progress": true, "last_obeyed": false,
			"pushed_last": false, "early_done": {}, "late_done": {}, "seq": 0, "stuck": false}
	if model == "nothing":
		while not b.is_over() and b.round < MAX_ROUNDS:
			var d0: int = b.objective.leader_distance(b)
			b.run_round()
			if b.objective.leader_distance(b) >= d0:
				st.idle += 1
	else:
		var t := Tutorial.new()
		st.t = t
		t.start(b)
		var presses := 0
		while not b.is_over() and b.round < MAX_ROUNDS and presses < MAX_PRESSES:
			presses += 1
			# The banner never asks for what cannot be pressed: a control it
			# has shut, Withdraw while it is disabled, a hex with nothing marked.
			var asked := t.control()
			if (asked.begins_with("shout:") or asked == "next") and not _may(t, asked):
				st.impossible += 1
			elif asked == "withdraw" and not b.can_withdraw(0):
				st.impossible += 1
			elif asked == "tap" and t.get("point") == BattleGrid.NO_CELL:
				st.impossible += 1
			var id := _choose(st)
			if id == "tap":
				var pt: Vector2i = t.get("point")
				id = "tap:%d,%d" % [pt.x, pt.y] if pt != BattleGrid.NO_CELL else "next"
			_press(st, id)
		st.stuck = not b.is_over() and b.round < MAX_ROUNDS
		t.free()
	if not b.is_over():
		b.run()
	var lost := 0
	for w in j.fight.built.ours:
		var m: Warrior = w
		if m != lw and (m.is_down() or m.broken or m.fled):
			lost += 1
	var before := j.c.band.living_men().size()
	var lines := j.fight_done(b.result)
	var dead := maxi(0, before - j.c.band.living_men().size())
	var why := ""
	for line in b.result.log:
		if line.begins_with("==="):
			why = line
	return {"out": b.result.escaped(0) and not lw.is_down(), "carried": lw.is_down(), "rounds": b.round,
			"idle": st.idle, "impossible": st.impossible, "lost": lost, "dead": dead, "bad": st.bad, "stuck": st.stuck,
			"rescued": b.objective.get("how_out") == "rescued", "capped": b.objective.get("how_out") == "told",
			"texts": st.texts, "lines": lines, "why": why, "alive": j.c.band.leader.alive, "men": j.c.band.living_men().size()}


## What the model presses next: a control name as the HUD has them
## ("ack", "skip", "shout:<n>", "next", "withdraw") or "tap:<x>,<y>".
static func _choose(st: Dictionary) -> String:
	var t: Tutorial = st.t
	var b: Battle = st.b
	var want := t.control()
	var r: SimRng = st.rng
	var fb := "shout:%d" % CombatTypes.Shout.FALL_BACK
	var push := "shout:%d" % CombatTypes.Shout.PUSH
	match str(st.model):
		"exact":
			return want
		"late":
			# The asked shout comes one round late: a Next round first.
			if want.begins_with("shout:") and not (st.late_done as Dictionary).has(want):
				st.late_done[want] = true
				if _may(t, "next"):
					return "next"
			return want
		"early":
			# A round ahead of the lesson: falling back while still asked
			# to push, Withdraw while asked to fall back.
			if want == "next" and st.pushed_last and not (st.early_done as Dictionary).has("fb"):
				st.early_done["fb"] = true
				return fb
			if (t.step == Tutorial.Step.FALL_BACK or want == fb) and _withdraw_open(t, b) and not (st.early_done as Dictionary).has("wd"):
				st.early_done["wd"] = true
				return "withdraw"
			return want
		"observed":
			var seq := ["ack", "shout:%d" % CombatTypes.Shout.SHIELD_WALL, "next", push, "next", "next", "next", "next", "next", "next", "next"]
			var i: int = st.seq
			st.seq = i + 1
			if i < seq.size():
				return seq[i] if _may(t, seq[i]) or seq[i] == "ack" else want
			var k := (i - seq.size()) % 3
			if k == 0:
				return fb if t.pending != CombatTypes.Shout.FALL_BACK else "next"
			if k == 1:
				return "next"
			return "withdraw" if _withdraw_open(t, b) else "next"
		"next_only":
			if want == "ack" or want == "skip":
				return "ack"
			return "next" if _may(t, "next") else want
		"back_after_push":
			if st.pushed_last and not (st.early_done as Dictionary).has(b.round) and _may(t, fb):
				st.early_done[b.round] = true
				return fb
			return want
		"taps":
			if (want == "next" or want.begins_with("shout:")) and r.randf() < 0.5 and st.action == null:
				var lw: Warrior = st.leader
				if lw.is_active():
					var cells: Array[Vector2i] = b.grid.neighbors(lw.pos)
					cells.append(lw.pos)
					var c: Vector2i = cells[r.randi_range(0, cells.size() - 1)]
					return "tap:%d,%d" % [c.x, c.y]
			return want
		"push_only":
			if want == fb:
				return push if t.pending != CombatTypes.Shout.PUSH else "next"
			return want
		"withdraw":
			if _withdraw_open(t, b):
				return "withdraw"
			return want
		"random":
			if want == "ack":
				return "ack"
			var opts: Array[String] = []
			for s in [CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.HOLD, CombatTypes.Shout.PUSH, CombatTypes.Shout.TO_ME,
					CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.FALL_BACK, CombatTypes.Shout.TAUNT]:
				if _may(t, "shout:%d" % s):
					opts.append("shout:%d" % s)
			if _withdraw_open(t, b):
				opts.append("withdraw")
			var lw2: Warrior = st.leader
			if lw2.is_active():
				var nb: Array[Vector2i] = b.grid.neighbors(lw2.pos)
				var c2: Vector2i = nb[r.randi_range(0, nb.size() - 1)]
				opts.append("tap:%d,%d" % [c2.x, c2.y])
			if r.randf() < 0.45 or opts.is_empty():
				return "next" if _may(t, "next") else want
			return opts[r.randi_range(0, opts.size() - 1)]
	return want


## Whether the HUD would let `id` be pressed now.
static func _may(t: Tutorial, id: String) -> bool:
	var allowed := t.allowed()
	return allowed.is_empty() or allowed.has(id)


static func _withdraw_open(t: Tutorial, b: Battle) -> bool:
	return _may(t, "withdraw") and not b.is_over() and b.can_withdraw(0)


## Presses `id` as the HUD would.
static func _press(st: Dictionary, id: String) -> void:
	var t: Tutorial = st.t
	var b: Battle = st.b
	if id == "ack":
		if t.control() == "ack" or t.control() == "skip":
			t.acknowledge()
		return
	if id == "skip":
		return  # the stand-ins never skip
	if id.begins_with("tap:"):
		var xy := id.trim_prefix("tap:").split(",")
		_tap(st, Vector2i(int(xy[0]), int(xy[1])))
		return
	if not _may(t, id):
		return
	if id.begins_with("shout:"):
		var s := int(id.trim_prefix("shout:")) as CombatTypes.Shout
		st.pending = CombatTypes.Shout.NONE if st.pending == s else s
		t.pending = st.pending
		t.evaluate()
		return
	if id == "withdraw":
		if b.can_withdraw(0):
			b.withdraw(0)
			t.evaluate()
		return
	if id == "next":
		_next(st)


## A round: the shout waiting and the man's own act, then the director.
static func _next(st: Dictionary) -> void:
	var t: Tutorial = st.t
	var b: Battle = st.b
	var text := t.text()
	(st.texts as Array).append("r%d %s | %s" % [b.round + 1, t.control(), text])
	# The banner says the same as before a round that came to nothing, when
	# that round was played as it asked (its control was Next round).
	if text == st.last_text and not st.last_progress and st.last_obeyed:
		st.bad += 1
	st.last_obeyed = t.control() == "next"
	var d0: int = b.objective.leader_distance(b)
	var shout: CombatTypes.Shout = st.pending
	if shout != CombatTypes.Shout.NONE:
		b.set_shout(0, shout)
	if st.action != null:
		b.set_player_action(0, st.action)
	if st.advance:
		b.request_wall_step(0)
	st.action = null
	st.advance = false
	b.run_round()
	var progress: bool = b.objective.leader_distance(b) < d0
	if not progress and not b.is_over():
		st.idle += 1
	st.last_text = text
	st.last_progress = progress or b.is_over()
	st.pushed_last = b.last_shout(0) == CombatTypes.Shout.PUSH
	st.pending = CombatTypes.Shout.NONE
	t.after_round()
	if b.round >= 1:
		(st.texts as Array)[-1] += "  => d%d %s" % [b.objective.leader_distance(b), t.said]


## BattleView._tap on the sim: yourself clears your act; the hex ahead of
## your wall takes the wall forward; a free hex is a step, an enemy a blow.
static func _tap(st: Dictionary, cell: Vector2i) -> void:
	var b: Battle = st.b
	var p: Warrior = st.leader
	if not p.is_active() or not b.grid.in_bounds(cell):
		return
	var t: Tutorial = st.t
	if cell == p.pos:
		st.action = null
		st.advance = false
		_tapped(t, BattleGrid.NO_CELL)
		return
	if BattleGrid.chebyshev(cell, p.pos) != 1:
		return
	if b.wall_members(0).has(p) and b.wall_members(0).size() >= 2 \
			and cell == p.pos + BattleGrid.forward(p.pos, p.wall_axis(), p.wall_facing()):
		st.advance = true
		st.action = null
		_tapped(t, cell)
		return
	st.advance = false
	var occ := b.grid.occupant(cell)
	if occ == null and b.grid.is_free(cell):
		st.action = Action.move_to(cell, p.wall_facing())
	elif occ != null and occ.side != p.side and occ.is_active():
		st.action = Action.attack(occ)
	else:
		return
	_tapped(t, cell)


## Tells the director of a tap on the board (the HUD does it on screen).
static func _tapped(t: Tutorial, cell: Vector2i) -> void:
	if t.has_method("on_tap"):
		t.call("on_tap", cell)


## Plays `model` over seeds `from`..`from + n - 1` and sums it up.
static func measure(model: String, n: int, from := 1) -> Dictionary:
	var out := {"model": model, "n": n, "out": 0, "carried": 0, "rounds": 0, "worst": 0, "idle": 0, "lost": 0,
			"dead": 0, "bad": 0, "bad_fights": 0, "impossible": 0, "stuck": 0, "rescued": 0, "capped": 0, "died": 0}
	for s in range(from, from + n):
		var r := play(model, s)
		out.out += 1 if r.out else 0
		out.carried += 1 if r.carried else 0
		out.rounds += r.rounds
		out.worst = maxi(out.worst, r.rounds)
		out.idle += r.idle
		out.lost += r.lost
		out.dead += r.dead
		out.bad += r.bad
		out.impossible += r.impossible
		out.bad_fights += 1 if r.bad > 0 else 0
		out.stuck += 1 if r.stuck else 0
		out.rescued += 1 if r.rescued else 0
		out.capped += 1 if r.capped else 0
		out.died += 0 if r.alive else 1
	return out


## One row of the table.
static func row(m: Dictionary) -> String:
	var n: float = maxf(1.0, float(m.n))
	return "%-16s out %3d%%  carried %3d%%  rounds %4.1f  worst %2d  idle %4.1f  men lost %.2f  dead %.2f  bad banner %4.1f (%2d fights)  impossible %d  stuck %d  rescued %d  capped %d  leader died %d" % [
			m.model, int(round(100.0 * m.out / n)), int(round(100.0 * m.carried / n)), m.rounds / n, m.worst, m.idle / n,
			m.lost / n, m.dead / n, m.bad / n, m.bad_fights, m.impossible, m.stuck, m.rescued, m.capped, m.died]
