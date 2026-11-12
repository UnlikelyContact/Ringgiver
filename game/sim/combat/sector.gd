class_name Sector
extends RefCounted
## The band's part of a great battle's line (concept.md, Hafrsfjord c. 872;
## docs/design/notes/battles-2.md): the band fights its own sector on the
## field, and to left and right of it the line goes on, fought by others.
## The neighbours are not men on the field but a state each, from broken to
## having broken the men before them, that moves a step a round with a roll
## leaning on the kings' strengths (`edge`) and on how the band's own
## sector goes. A neighbour that breaks lets the enemy over onto the band's
## flank (`Battle.arrivals`); one that wins sends its men in on the
## enemy's. The king's banner stands somewhere along the line. The day is
## the whole line's: when it ends (the day's length, or the band's own
## fight decided), `verdict` weighs every part of it, the band's own
## heavier, and that is the battle's winner.
##
## Built by Scenario.build_sector with its parameters, so any great battle
## can use it; Battle calls `round_end` each round and `verdict` at the end.

const STATE_TEXT := {-2: "is broken and running", -1: "wavers", 0: "holds", 1: "presses them hard", 2: "has broken the men before it"}
const STATE_SHORT := {-2: "broken", -1: "wavering", 0: "holding", 1: "pressing", 2: "won"}

## What the battle is called and whose the two sides are, for the log.
var battle_name := "the battle"
var ours_name := "your side"
var theirs_name := "the enemy"
## {hand: -1 left / +1 right, name, state: -2..2, cells: Array[Vector2i]
## (where the enemy comes onto the band's flank when it breaks), ally_cells
## (where its men come in on the enemy's when it wins), came: bool}.
var neighbours: Array[Dictionary] = []
## Our kings' share of the strength of the whole line, 0 to 1.
var edge := 0.5
## Where the king's banner stands: -1 with the left neighbour, +1 the
## right, 0 with the band itself; and whose banner it is.
var banner_hand := 0
var banner_name := "the king's banner"
var day_rounds := 26
var drift := 0.3
var weight := 0.6
var own_weight := 2.0
var banner_weight := 1.0
## The men a broken neighbour lets onto the band's flank, and the men a
## winning one sends in, by hand (Array[Warrior] each), drawn by the builder.
var foes_over := {}
var friends_over := {}
var reason := ""
## Set once the day's verdict is given.
var final := false
var score := 0.0
var _seed := 0


func _init(seed_in := 0) -> void:
	_seed = seed_in


func neighbour(hand: int) -> Dictionary:
	for n in neighbours:
		if int(n.hand) == hand:
			return n
	return {}


## The neighbours move, after the round is fought: each that is neither
## broken nor has won steps up with `drift` times the line's lean our way,
## down with the rest. The lean is the kings' `edge`, moved by `weight`
## times how the band's own sector stands (its share of men still standing
## less the enemy's).
func round_end(battle: Battle) -> void:
	var r := SimRng.new(_seed).fork("sector:%d" % battle.round)
	var lean := clampf(edge + weight * 0.5 * own_share(battle), 0.05, 0.95)
	for n in neighbours:
		var s := int(n.state)
		if s <= -2 or s >= 2:
			continue
		var x := r.fork("hand:%d" % int(n.hand)).randf()
		var to := s
		if x < drift * lean:
			to = s + 1
		elif x < drift:
			to = s - 1
		if to == s:
			continue
		n.state = to
		var where := "On your %s" % ("left" if int(n.hand) < 0 else "right")
		battle.log.append("%s, %s %s" % [where, n.name, STATE_TEXT[to]])
		if to == -2:
			_broke(battle, n)
		elif to == 2:
			_won(battle, n)


## A neighbour breaks: the band sees it, the enemy comes over onto its
## flank next round, and if the king's banner stood there it goes back.
func _broke(battle: Battle, n: Dictionary) -> void:
	var hand := int(n.hand)
	for w in battle.active(0):
		w.morale = clampi(w.morale - 1, 0, 10)
	var men: Array[Warrior] = []
	men.assign(foes_over.get(hand, []))
	if not men.is_empty():
		var cells: Array[Vector2i] = []
		cells.assign(n.get("cells", []))
		battle.add_arrival(battle.round + 1, 1, men, cells, Vector2i(0, 1),
				"the enemy come over onto your %s flank, {n} of them" % ("left" if hand < 0 else "right"))
	if hand == banner_hand:
		battle.log.append("%s goes back with them" % banner_name)
		for w in battle.active(0):
			w.morale = clampi(w.morale - 1, 0, 10)


## A neighbour wins its part: their men lose heart, and its men come in on
## the enemy's flank next round.
func _won(battle: Battle, n: Dictionary) -> void:
	var hand := int(n.hand)
	for w in battle.active(1):
		w.morale = clampi(w.morale - 1, 0, 10)
	var men: Array[Warrior] = []
	men.assign(friends_over.get(hand, []))
	if not men.is_empty():
		var cells: Array[Vector2i] = []
		cells.assign(n.get("ally_cells", []))
		battle.add_arrival(battle.round + 1, 0, men, cells, Vector2i(0, -1),
				"%s's men come in on their flank, {n} of them" % str(n.name))


## The band's sector as it stands: its share of men standing less the
## enemy's, -1 to 1.
func own_share(battle: Battle) -> float:
	var s := [0.0, 0.0]
	for side in 2:
		var standing := 0
		for w in battle.active(side):
			if not w.broken:
				standing += 1
		s[side] = float(standing) / maxf(1.0, float(battle.result.started[side]))
	return s[0] - s[1]


## Whether the day is over: its length has run.
func decided(battle: Battle) -> bool:
	return battle.round >= day_rounds


## The day's verdict: the side the whole line went to. Each neighbour
## counts its state (the banner's neighbour `banner_weight` more), the
## band's own part `own_weight` times its state: routing them +2, routed
## -2, the field +1 / -1, withdrawn -1.5, else its standing share doubled;
## the banner with the band adds to that weight. A dead level goes to the
## band's own result. `local` is the band's own fight's winner (-2: still
## going), `how` how it ended.
func verdict(battle: Battle, local := -2, how := BattleResult.End.STALL) -> int:
	if final:
		return 0 if score > 0.0 else (1 if score < 0.0 else -1)
	var own := clampf(own_share(battle) * 2.0, -2.0, 2.0)
	if local >= 0:
		match how:
			BattleResult.End.ROUT:
				own = 2.0 if local == 0 else -2.0
			BattleResult.End.WITHDRAWAL:
				own = -1.5 if local == 1 else 1.5
			_:
				own = 1.0 if local == 0 else -1.0
	var ow := own_weight + (banner_weight if banner_hand == 0 else 0.0)
	score = own * ow
	for n in neighbours:
		var w := 1.0 + (banner_weight if int(n.hand) == banner_hand else 0.0)
		score += float(n.state) * w
	final = true
	var day := 0 if score > 0.0 else (1 if score < 0.0 else (local if local >= 0 else -1))
	if day == 0:
		reason = "the day at %s goes to %s" % [battle_name, ours_name]
	elif day == 1:
		reason = "the day at %s goes to %s" % [battle_name, theirs_name]
	else:
		reason = "neither side has the day at %s" % battle_name
	battle.log.append(reason)
	return day


## The line in a few words for the HUD: "left holding, right wavering".
func line_text() -> String:
	var parts := PackedStringArray()
	for n in neighbours:
		parts.append("%s %s" % ["left" if int(n.hand) < 0 else "right", STATE_SHORT[int(n.state)]])
	return ", ".join(parts)
