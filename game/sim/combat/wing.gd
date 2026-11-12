class_name Wing
extends RefCounted
## A named lieutenant's wing (concept.md, "Named lieutenants command flanks
## with their own judgment"; docs/design/notes/battles-2.md). Before the
## fight the leader gives the man one standing word; in the fight he acts
## on it when he judges the moment has come, shaped by his temper: a rash
## man presses too soon, a steady one holds too long. While he acts, his
## wing is out of the leader's wall and does as he says (Battle hands its
## men his order and moves them by `action_for`); when he is done, or the
## leader calls them back (Fall back, To me), they take up the leader's
## word again. If he falls or breaks, the wing is leaderless: its men lose
## heart and go back to the leader's word for good.
##
## Only fights the campaign gives lieutenants have wings (Battle.wings is
## empty everywhere else), so every rule here acts only there.

enum Word { NONE, HOLD_LINE, PRESS, FALL_BACK, ROUND_FLANK, GUARD_ARCHERS }
const WORD_NAMES := ["no word", "hold the line", "press when they waver", "fall back on me", "go round their flank", "guard the archers"]
const WORD_SHORT := ["", "hold", "press", "back", "flank", "bows"]
const WORD_TITLES := ["No word", "Hold the line", "Press when they waver", "Fall back on me", "Go round their flank", "Guard the archers"]
## What each word asks, in a line for the sheet.
const WORD_HINTS := ["He keeps to your word like any man.",
	"His wing stands where it is when you go forward, and stands hard.",
	"When the men before him waver, he takes his wing in.",
	"When his wing is hard pressed, he pulls it back on himself and rallies it.",
	"Once the lines meet, he takes his wing round the end of theirs.",
	"His wing keeps by the bowmen and goes for any man who comes at them."]
## The words a leader can give, in the sheet's order.
const WORDS := [Word.HOLD_LINE, Word.PRESS, Word.FALL_BACK, Word.ROUND_FLANK, Word.GUARD_ARCHERS]
enum Temper { PLAIN, RASH, STEADY, CUNNING }
const TEMPER_NAMES := ["", "rash", "steady", "cunning"]
const HAND_NAMES := {-1: "left", 1: "right", 0: "rear"}

var side := 0
## Which end of the line: -1 the left, +1 the right (as its men face), 0 the
## rear (the bowmen and the men by them, a third named man's).
var hand := -1
var lieutenant: Warrior
var men: Array[Warrior] = []
var word: Word = Word.NONE
var temper: Temper = Temper.PLAIN
## He is acting on his word now: the wing is out of the leader's wall and
## takes `order` from him.
var acting := false
var order: CombatTypes.Shout = CombatTypes.Shout.NONE
var leaderless := false
var fell_round := -1
## The first round he acted on his word, rounds he has been at it this
## time, the round before which he will not fall back again, and whether
## he has announced himself.
var acted_round := -1
var acting_rounds := 0
var rest_until := 0
var told := false
## Rounds the lines have been in contact (his patience, for a steady man).
var contact_rounds := 0
## What he did last, in the saga's words, for the view and the log.
var line := ""


func hand_name() -> String:
	return str(HAND_NAMES.get(hand, "left"))


## A man's temper as a lieutenant: from the words told of him (Man.traits,
## the campaign's; "reckless", "steady" ...), else his nature in a fight,
## else his wits.
static func temper_of(personality: Array, traits: PackedStringArray, wits: int) -> Temper:
	var t := " ".join(traits).to_lower()
	for k in ["reckless", "rash", "hot-head", "hothead", "bold"]:
		if t.contains(k):
			return Temper.RASH
	for k in ["steady", "cautious", "careful", "patient", "grim"]:
		if t.contains(k):
			return Temper.STEADY
	for k in ["cunning", "wily", "shrewd", "crafty"]:
		if t.contains(k):
			return Temper.CUNNING
	if personality.has(CombatTypes.Personality.RECKLESS):
		return Temper.RASH
	if personality.has(CombatTypes.Personality.STEADY) or personality.has(CombatTypes.Personality.GRIM):
		return Temper.STEADY
	if wits >= 6:
		return Temper.CUNNING
	return Temper.PLAIN


## The word a man of this temper would choose for himself: what an enemy's
## named man does, and the sheet's first suggestion.
static func own_word(t: Temper) -> Word:
	match t:
		Temper.RASH:
			return Word.PRESS
		Temper.STEADY:
			return Word.HOLD_LINE
		Temper.CUNNING:
			return Word.ROUND_FLANK
	return Word.PRESS


## The word an enemy leader of `doctrine` gives his named men.
static func doctrine_word(doctrine: int, t: Temper) -> Word:
	match doctrine:
		LeaderAI.Doctrine.STEADY:
			return Word.HOLD_LINE if t != Temper.RASH else Word.PRESS
		LeaderAI.Doctrine.CUNNING:
			return Word.ROUND_FLANK
	return Word.PRESS


## Gives each of `lieutenants` (at most three) a wing of the side's line,
## where he stands in it: the men nearest him across the leader's front
## (`wing_share` of the line's men who are not bowmen, never fewer than
## `wing_min_men`, himself among them), none moved. His hand is the side of
## the leader he stands on (with two, the one further left has the left); a
## bowman lieutenant has the rear: the bowmen. Call before the first round.
## Returns the wings, also added to the battle.
static func form(battle: Battle, side: int, lieutenants: Array[Warrior], words: Array, tempers: Array) -> Array[Wing]:
	var out: Array[Wing] = []
	var leader := battle.sworn_leader(side)
	if leader == null or lieutenants.is_empty():
		return out
	var rules := battle.rules
	var right := LeaderAI.right_vector(leader.wall_axis(), leader.wall_facing())
	var origin := BattleGrid.to_cart(Vector2(leader.pos))
	var lateral := func(w: Warrior) -> float: return (BattleGrid.to_cart(Vector2(w.pos)) - origin).dot(right)
	var line: Array[Warrior] = []
	var bows: Array[Warrior] = []
	for w in battle.side_warriors(side):
		if w == leader or not w.is_active():
			continue
		if w.role == CombatTypes.Role.MISSILE:
			bows.append(w)
		else:
			line.append(w)
	var k := maxi(rules.wing_min_men, roundi(line.size() * rules.wing_share))
	var lts: Array[Warrior] = []
	for i in mini(lieutenants.size(), 3):
		lts.append(lieutenants[i])
	# Hands: by where each stands, the leftmost first.
	var order: Array = []
	for i in lts.size():
		order.append([lateral.call(lts[i]), i])
	order.sort()
	var hands := {}
	for j in order.size():
		var i: int = order[j][1]
		var lat: float = order[j][0]
		if lts[i].role == CombatTypes.Role.MISSILE:
			hands[i] = 0
		elif order.size() == 1:
			hands[i] = -1 if lat <= 0.0 else 1
		else:
			hands[i] = -1 if j == 0 else 1
	var taken := {}
	for lt in lts:
		taken[lt] = true
	for i in lts.size():
		var wing := Wing.new()
		wing.side = side
		wing.hand = int(hands[i])
		wing.lieutenant = lts[i]
		wing.word = int(words[i]) as Word if i < words.size() else Word.NONE
		wing.temper = int(tempers[i]) as Temper if i < tempers.size() else Temper.PLAIN
		wing.men.append(lts[i])
		if wing.hand == 0:
			for b in bows:
				if not taken.has(b):
					wing.men.append(b)
					taken[b] = true
		else:
			var here: float = lateral.call(lts[i])
			var near: Array = []
			for w in line:
				if not taken.has(w):
					near.append([absf(lateral.call(w) - here), w.id, w])
			near.sort()
			for j in mini(k - 1, near.size()):
				var w2: Warrior = near[j][2]
				wing.men.append(w2)
				taken[w2] = true
		out.append(wing)
		battle.wings.append(wing)
	return out


# --- The round -----------------------------------------------------------------

## Every wing's lieutenant reads the field and decides (Battle, after the
## shouts and before the walls move). Marks the men of the wings that act
## (`Battle._wing_of`) and hands them their lieutenant's order.
static func think(battle: Battle) -> void:
	battle._wing_of.clear()
	for wing in battle.wings:
		wing._think(battle)
		if not wing.acting:
			continue
		var lt := wing.lieutenant
		var wall: Array[Warrior] = []
		if wing.word == Word.ROUND_FLANK:
			wall = battle.wall_members(wing.side)
		for w in wing.men:
			if not w.is_active() or w.broken:
				continue
			if w != lt and BattleGrid.distance(w.pos, lt.pos) > battle.rules.wing_voice:
				continue
			if wing.word == Word.ROUND_FLANK and wall.has(w) and not battle.grid.adjacent_warriors(w.pos, 1 - wing.side).is_empty():
				continue  # a man of the wall fast in the fight stays in it; the rest swing round
			battle._wing_of[w] = wing
			w.heard_order = wing.order
			w.order_lag = 0


func _think(battle: Battle) -> void:
	if leaderless or word == Word.NONE:
		return
	var rules := battle.rules
	var lt := lieutenant
	if not lt.is_active() or lt.broken:
		_fall(battle)
		return
	if not told:
		told = true
		battle.log.append("%s has the %s wing: %s" % [lt.display_name, hand_name(), WORD_NAMES[word]])
	var engaged := _engaged(battle)
	if battle.lines_met():
		contact_rounds += 1
	# The leader calling his men back, or to him, is heard over any word.
	var called := battle.last_shout(side)
	if called == CombatTypes.Shout.FALL_BACK or called == CombatTypes.Shout.TO_ME:
		if acting:
			_rejoin(battle, "")
		return
	var near := _foes_near(battle)
	var heart := _heart(battle)
	match word:
		Word.HOLD_LINE:
			# His wing stays in the wall and stands hard in contact
			# (`hearten`); a rash man cannot keep to it and takes his men in
			# as soon as he thinks they waver.
			if engaged and line == "":
				line = "%s's men on the %s stand hard" % [lt.display_name, hand_name()]
				battle.log.append(line)
			if temper == Temper.RASH and not acting and _wavering(near, rules.wing_waver[Temper.RASH]):
				_act(battle, CombatTypes.Shout.BREAK_THEM, lt.said("%s cannot keep to it: he takes the %s in" % [lt.display_name, hand_name()]))
			elif acting and heart <= rules.wing_quit_morale:
				_rejoin(battle, "the %s is thrown back, and %s brings it in again" % [hand_name(), lt.display_name])
		Word.PRESS:
			if acting:
				if heart <= rules.wing_quit_morale:
					_rejoin(battle, "the %s is thrown back, and %s brings it in again" % [hand_name(), lt.display_name])
			elif not near.is_empty() and _wavering(near, rules.wing_waver[temper]):
				_act(battle, CombatTypes.Shout.BREAK_THEM, "%s sees them waver and takes the %s in" % [lt.display_name, hand_name()])
		Word.FALL_BACK:
			if acting:
				acting_rounds += 1
				Morale.rally(rules, battle.grid, lt, battle.warriors, battle.log)
				if acting_rounds >= rules.wing_fallback_rounds:
					rest_until = battle.round + rules.wing_fallback_rest
					_rejoin(battle, "%s's men stand again on the %s" % [lt.display_name, hand_name()])
			elif engaged and battle.round >= rest_until and heart <= rules.wing_pressed[temper]:
				_act(battle, CombatTypes.Shout.TO_ME, lt.said("%s calls the %s back on him" % [lt.display_name, hand_name()]))
				Morale.rally(rules, battle.grid, lt, battle.warriors, battle.log)
		Word.ROUND_FLANK:
			if acting:
				if heart <= rules.wing_quit_morale and _engaged(battle):
					_rejoin(battle, "the %s is thrown back from their flank" % hand_name())
			else:
				# He goes as the lines close, before his wing is fast in the
				# fight: a rash man as soon as the wall is formed, a steady
				# one only once the fight has lasted (too late, as often as
				# not), a cunning one when their line does not reach past his.
				var go := false
				var closing := _closest_foe(battle) <= rules.wing_flank_range and not engaged
				match temper:
					Temper.RASH:
						go = battle.round > rules.ai_form_rounds
					Temper.STEADY:
						go = contact_rounds >= rules.wing_flank_wait and _overlaps(battle)
					Temper.CUNNING:
						go = (closing or _closest_foe(battle) <= rules.wing_flank_range + 1) and _overlaps(battle)
					_:
						go = closing and _overlaps(battle)
				if go:
					_act(battle, CombatTypes.Shout.BREAK_THEM, "%s takes the %s round their flank" % [lt.display_name, hand_name()])
		Word.GUARD_ARCHERS:
			var bows := _bows(battle)
			if bows.is_empty():
				if acting:
					_rejoin(battle, "")
				return
			# His wing keeps its place until a man comes at the bowmen; then
			# it goes for him, and comes back once he is dealt with.
			var threat := _threat_to(battle, bows)
			if threat != null and not acting:
				_act(battle, CombatTypes.Shout.BREAK_THEM, "%s sees them come at the bowmen and goes to meet them" % lt.display_name)
			elif threat == null and acting:
				_rejoin(battle, "%s brings the %s back to its place" % [lt.display_name, hand_name()])


func _act(battle: Battle, p_order: CombatTypes.Shout, why: String) -> void:
	acting = true
	order = p_order
	acting_rounds = 0
	if acted_round < 0:
		acted_round = battle.round
	line = why
	battle.log.append(why)


func _rejoin(battle: Battle, why: String) -> void:
	acting = false
	order = CombatTypes.Shout.NONE
	if why != "":
		line = why
		battle.log.append(why)
	var back := battle.standing_order(side)
	for w in men:
		if w.is_active() and not w.broken:
			w.heard_order = back


## He is down, gone or broken: the wing is leaderless.
func _fall(battle: Battle) -> void:
	leaderless = true
	acting = false
	order = CombatTypes.Shout.NONE
	fell_round = battle.round
	var lt := lieutenant
	var how := "is down" if lt.is_down() else ("breaks" if lt.broken else "is gone")
	line = "%s %s, and the %s wing has no one to lead it" % [lt.display_name, how, hand_name()]
	battle.log.append(line)
	var back := battle.standing_order(side)
	for w in men:
		if w == lt or not w.is_active():
			continue
		w.morale = clampi(w.morale + battle.rules.wing_leaderless_morale, 0, 10)
		if not w.broken:
			w.heard_order = back


## The heart a lieutenant gives the men near him (Battle, before the
## morale beat): a named man at their head steadies them up to
## `wing_heart_cap`; holding the line in contact, up to `wing_hold_cap`;
## acting on his word, out of their leader's sight, without limit.
static func hearten(battle: Battle) -> void:
	var rules := battle.rules
	for wing in battle.wings:
		if wing.leaderless or wing.word == Word.NONE:
			continue
		var lt := wing.lieutenant
		if not lt.is_active() or lt.broken:
			continue
		var holding := wing.word == Word.HOLD_LINE and wing._engaged(battle)
		var cap := 10 if wing.acting else (rules.wing_hold_cap if holding else rules.wing_heart_cap)
		var leader := battle.leader_of(wing.side)
		for w in wing.men:
			if w == lt or not w.is_active() or w.broken:
				continue
			if BattleGrid.distance(w.pos, lt.pos) > rules.morale_leader_near_radius:
				continue
			if leader != null and BattleGrid.distance(w.pos, leader.pos) <= rules.morale_leader_near_radius:
				continue  # his leader's heart is his already
			if w.morale < cap:
				w.morale = mini(cap, w.morale + rules.wing_heart)
			# A wing coming on at men who already waver, shouting, takes the
			# last of the heart out of the men it reaches.
			if wing.acting and wing.order == CombatTypes.Shout.BREAK_THEM and wing.word == Word.PRESS:
				for e in battle.grid.adjacent_warriors(w.pos, 1 - wing.side):
					if e.is_active() and not e.broken:
						e.morale = clampi(e.morale + rules.wing_press_dread, 0, 10)


## What a man of an acting wing does instead of his plain choice, or null
## to let Decision choose under his lieutenant's order: falling back on him
## (step away from the enemy, toward him), going round their flank (toward
## the end of their line until he is at arm's length), keeping by the
## bowmen.
func action_for(battle: Battle, w: Warrior) -> Action:
	var grid := battle.grid
	var enemies := battle.active(1 - side)
	var adj := false
	for e in enemies:
		if not e.broken and BattleGrid.distance(w.pos, e.pos) == 1:
			adj = true
	match word:
		Word.FALL_BACK:
			if adj or w == lieutenant:
				var away := Decision._step_away(grid, w, enemies, lieutenant if w != lieutenant else battle.leader_of(side))
				return away
			if BattleGrid.chebyshev(w.pos, lieutenant.pos) > 1:
				return Decision._step_toward(grid, w, lieutenant.pos, w.facing)
			return null
		Word.ROUND_FLANK:
			if adj:
				return null
			var goal := flank_cell(battle)
			if goal == BattleGrid.NO_CELL or w.pos == goal:
				return null
			var step := Decision._step_toward(grid, w, goal, Vector2i.ZERO)
			if step != null:
				var near := Decision._nearest(step.target_cell, enemies)
				if near != null:
					step.new_facing = BattleGrid.direction_to(step.target_cell, near.pos)
			return step
		Word.GUARD_ARCHERS:
			if adj or order == CombatTypes.Shout.BREAK_THEM:
				return null
			var bows := _bows(battle)
			if bows.is_empty():
				return null
			var near_bow := Decision._nearest(w.pos, bows)
			if BattleGrid.distance(w.pos, near_bow.pos) > battle.rules.wing_guard_keep:
				return Decision._step_toward(grid, w, near_bow.pos, w.facing)
			return null
	return null


## Where the wing makes for to come round the enemy: beyond the end of
## their line on the wing's hand, a hex out and a hex behind it.
func flank_cell(battle: Battle) -> Vector2i:
	var leader := battle.sworn_leader(side)
	var theirs := LeaderAI.standing(battle.active(1 - side))
	if leader == null or theirs.is_empty():
		return BattleGrid.NO_CELL
	var right := LeaderAI.right_vector(leader.wall_axis(), leader.wall_facing())
	var front := LeaderAI.front_vector(leader.wall_axis(), leader.wall_facing())
	var end: Warrior = null
	var best := -INF
	for e in theirs:
		var lat: float = BattleGrid.to_cart(Vector2(e.pos)).dot(right) * float(hand if hand != 0 else 1)
		if lat > best or (lat == best and e.id < end.id):
			best = lat
			end = e
	var goal := BattleGrid.to_cart(Vector2(end.pos)) + right * float(hand if hand != 0 else 1) * 1.6 + front * 1.0
	var cell := _cell_near(battle.grid, goal)
	return cell


static func _cell_near(grid: BattleGrid, cart: Vector2) -> Vector2i:
	var best := BattleGrid.NO_CELL
	var best_d := INF
	for row in grid.height:
		for col in grid.width:
			var c := BattleGrid.from_offset(col, row)
			if not grid.is_passable(c):
				continue
			var d := BattleGrid.to_cart(Vector2(c)).distance_to(cart)
			if d < best_d:
				best_d = d
				best = c
	return best


# --- What he sees --------------------------------------------------------------

## The enemy standing within `wing_sight` of his wing's standing men.
func _foes_near(battle: Battle) -> Array[Warrior]:
	var out: Array[Warrior] = []
	var sight := battle.rules.wing_sight
	for e in battle.active(1 - side):
		for w in men:
			if w.is_active() and not w.broken and BattleGrid.distance(w.pos, e.pos) <= sight:
				out.append(e)
				break
	return out


## Hexes from his wing's nearest standing man to the nearest enemy.
func _closest_foe(battle: Battle) -> int:
	var best := 99
	for e in battle.active(1 - side):
		if e.broken:
			continue
		for w in men:
			if w.is_active() and not w.broken:
				best = mini(best, BattleGrid.distance(w.pos, e.pos))
	return best


## Whether the enemy's line reaches past his wing's end: its end man
## stands further out on his hand than his own outermost man.
func _overlapped(battle: Battle) -> bool:
	var leader := battle.sworn_leader(side)
	if leader == null or hand == 0:
		return false
	var right := LeaderAI.right_vector(leader.wall_axis(), leader.wall_facing()) * float(hand)
	var ours := -INF
	for w in men:
		if w.is_active() and not w.broken:
			ours = maxf(ours, BattleGrid.to_cart(Vector2(w.pos)).dot(right))
	for e in LeaderAI.standing(battle.active(1 - side)):
		if BattleGrid.to_cart(Vector2(e.pos)).dot(right) > ours + 0.5:
			return true
	return false


## Whether his wing reaches past the end of the enemy's line on his hand
## by a hex or more: there is ground to go round by.
func _overlaps(battle: Battle) -> bool:
	var leader := battle.sworn_leader(side)
	if leader == null or hand == 0:
		return false
	var right := LeaderAI.right_vector(leader.wall_axis(), leader.wall_facing()) * float(hand)
	var ours := -INF
	var theirs := -INF
	for w in men:
		if w.is_active() and not w.broken:
			ours = maxf(ours, BattleGrid.to_cart(Vector2(w.pos)).dot(right))
	for e in LeaderAI.standing(battle.active(1 - side)):
		theirs = maxf(theirs, BattleGrid.to_cart(Vector2(e.pos)).dot(right))
	return ours >= theirs + 0.9


## Whether those men waver: one of them broken, or their mean heart at or
## under `at`.
static func _wavering(near: Array[Warrior], at: float) -> bool:
	if near.is_empty():
		return false
	var sum := 0
	var n := 0
	for e in near:
		if e.broken:
			return true
		sum += e.morale
		n += 1
	return float(sum) / maxf(1.0, float(n)) <= at


static func _all_broken(near: Array[Warrior]) -> bool:
	for e in near:
		if not e.broken:
			return false
	return true


## The mean heart of his wing's standing men.
func _heart(battle: Battle) -> float:
	var sum := 0
	var n := 0
	for w in men:
		if w.is_active() and not w.broken:
			sum += w.morale
			n += 1
	return 10.0 if n == 0 else float(sum) / n


func _engaged(battle: Battle) -> bool:
	for w in men:
		if w.is_active() and not w.broken and not battle.grid.adjacent_warriors(w.pos, 1 - side).is_empty():
			return true
	return false


func _bows(battle: Battle) -> Array[Warrior]:
	var out: Array[Warrior] = []
	for w in battle.active(side):
		if w.role == CombatTypes.Role.MISSILE and not w.broken:
			out.append(w)
	return out


func _threat_to(battle: Battle, bows: Array[Warrior]) -> Warrior:
	var radius := battle.rules.wing_guard_rash if temper == Temper.RASH else battle.rules.wing_guard_radius
	var best: Warrior = null
	var best_d := 99
	for e in battle.active(1 - side):
		if e.broken:
			continue
		for b in bows:
			var d := BattleGrid.distance(e.pos, b.pos)
			if d <= radius and (d < best_d or (d == best_d and e.id < best.id)):
				best = e
				best_d = d
	return best


## The words for the sheet and the view: "Alf (rash): press when they waver".
func describe() -> String:
	var t: String = TEMPER_NAMES[temper]
	return "%s%s: %s" % [lieutenant.display_name, (" (%s)" % t) if t != "" else "", WORD_NAMES[word]]


## The word a sensible leader gives his named men for the fight before
## him (the stand-in player's, and the sheet's first choice), from the
## measured table in battles-2.md: going at them, hold the line (the wing
## stands hard while the wall comes on); waiting for them or meeting them
## as they come, fall back on me (a wing that gives ground and rallies
## outlasts one that breaks).
static func sensible_word(_doctrine: int, attacking: bool, _temper: int = Temper.PLAIN) -> Word:
	return Word.HOLD_LINE if attacking else Word.FALL_BACK
