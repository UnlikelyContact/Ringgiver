class_name Objective
extends RefCounted
## Something on the field worth fighting over, so that one side must come on
## and the other must stand (concept.md, eighth playtest: on an open field
## the side that waits is favoured). The attacker has a task and a deadline;
## the defender wins by keeping him from it until the time runs out. The
## lines can still break first: Battle checks the objective before its own
## end checks each round, and they stay as they were.
##
##   HOLD_GROUND     the ford: a patch just before the defender's line. At the
##                   end of round `rounds` the side with more standing men on
##                   it has it; ties (and an empty ford) go to the defender.
##   REACH_THE_SHIPS the ships: a strip along the defender's back edge. The
##                   attacker wins the moment `ships_men` of his standing men
##                   are on it; the defender wins if `rounds` pass first.
##   THE_HALL        the hall: a cluster where the defender's rear ranks stand.
##                   The attacker wins once he has stood on at least half its
##                   cells for `hall_streak` rounds running; else the defender.
##
## Built from a seed and a kind; `place` marks its cells on a grid (flat
## ground: no mud on the ford or in the hall). Deterministic like the rest.

enum Kind { HOLD_GROUND, REACH_THE_SHIPS, THE_HALL }

const NAMES := ["the ford", "the ships", "the hall"]
const SHORT := ["ford", "ships", "hall"]

var kind: Kind
var attacker := 0
var cells: Array[Vector2i] = []
var rounds := 16
var name := ""
var ships_men := 4
var hall_streak := 2
## Set when `check` decides: the finish line for the log ("side 0 takes the hall").
var reason := ""
var _seed := 0
var _streak := 0  # rounds running the attacker has held the hall
var _checked_round := -1
var _decision := -1


func _init(p_kind: Kind, p_attacker: int, seed_in: int, rules: CombatRules = null) -> void:
	kind = p_kind
	attacker = p_attacker
	_seed = seed_in
	name = NAMES[kind]
	var r := rules if rules != null else CombatRules.new()
	ships_men = r.objective_ships_men
	hall_streak = r.objective_hall_streak
	match kind:
		Kind.HOLD_GROUND:
			rounds = r.objective_ford_rounds
		Kind.REACH_THE_SHIPS:
			rounds = r.objective_ships_rounds
		Kind.THE_HALL:
			rounds = r.objective_hall_rounds


func defender() -> int:
	return 1 - attacker


func short_name() -> String:
	return SHORT[kind]


## Marks the objective's cells on `grid`. `front_row` is the defender's front
## line (offset row), `back` is +1 or -1, the way his rear lies (toward his
## edge of the map), `centre_col` the column his leader stands on. The patch
## is drawn from the seed: the ford is three to five hexes across the row in
## front of his line, the ships a strip of eight to ten on the edge row behind
## him, the hall four to six where his rear ranks stand.
func place(grid: BattleGrid, front_row: int, back: int, centre_col: int) -> void:
	var r := SimRng.new(_seed).fork("objective-cells")
	var offs: Array[Vector2i] = []  # (column offset, row offset from front, + toward the back)
	match kind:
		Kind.HOLD_GROUND:
			var n := r.randi_range(3, 5)
			var left := -(n / 2)
			for i in n:
				offs.append(Vector2i(left + i, -1))
		Kind.REACH_THE_SHIPS:
			var n := r.randi_range(8, 10)
			var left := -(n / 2)
			var edge_row := (grid.height - 1) if back > 0 else 0
			for i in n:
				offs.append(Vector2i(left + i, (edge_row - front_row) * back))
		Kind.THE_HALL:
			var n := r.randi_range(4, 6)
			# Two rows, the second and third ranks' ground, widest at the back.
			var back_n := (n + 1) / 2
			var front_n := n - back_n
			for i in back_n:
				offs.append(Vector2i(-(back_n / 2) + i, 2))
			for i in front_n:
				offs.append(Vector2i(-(front_n / 2) + i, 1))
	cells.clear()
	for o in offs:
		var col := clampi(centre_col + o.x, 0, grid.width - 1)
		var row := clampi(front_row + o.y * back, 0, grid.height - 1)
		var c := BattleGrid.from_offset(col, row)
		if not cells.has(c):
			cells.append(c)
			grid.set_terrain(c, CombatTypes.Terrain.FLAT)


func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


## Standing (active, unbroken) men of `side` on the objective's cells.
func men_on(battle: Battle, side: int) -> int:
	var n := 0
	for c in cells:
		var w := battle.grid.occupant(c)
		if w != null and w.side == side and w.is_active() and not w.broken:
			n += 1
	return n


## What it asks of a side, in a line ("Take the hall before round 18").
func brief(side: int) -> String:
	var attacking := side == attacker
	match kind:
		Kind.HOLD_GROUND:
			return ("Take the ford and hold it at round %d" % rounds) if attacking else ("Hold the ford until round %d" % rounds)
		Kind.REACH_THE_SHIPS:
			return ("Get %d men to the ships before round %d" % [ships_men, rounds]) if attacking else ("Keep them from the ships until round %d" % rounds)
		_:
			return ("Take the hall before round %d" % rounds) if attacking else ("Hold the hall until round %d" % rounds)


## The state of play for the HUD ("hall: 2 of 5 held, round 9 of 18").
func progress(battle: Battle) -> String:
	var round_text := "round %d of %d" % [battle.round, rounds]
	match kind:
		Kind.HOLD_GROUND:
			return "ford: %d attackers on it to %d, %s" % [men_on(battle, attacker), men_on(battle, defender()), round_text]
		Kind.REACH_THE_SHIPS:
			return "ships: %d of %d there, %s" % [men_on(battle, attacker), ships_men, round_text]
		_:
			return "hall: %d of %d held, %s" % [men_on(battle, attacker), cells.size(), round_text]


## -1 while undecided, else the winning side. Call once a round, after the
## round is fought (Battle does, before its own end checks); a second call in
## the same round returns the same answer without counting again.
func check(battle: Battle) -> int:
	if battle.round == _checked_round:
		return _decision
	_checked_round = battle.round
	_decision = _decide(battle)
	return _decision


func _decide(battle: Battle) -> int:
	var a := men_on(battle, attacker)
	match kind:
		Kind.HOLD_GROUND:
			if battle.round < rounds:
				return -1
			if a > men_on(battle, defender()):
				reason = "side %d holds the ford with more men" % attacker
				return attacker
			reason = "the ford is held: side %d keeps it" % defender()
			return defender()
		Kind.REACH_THE_SHIPS:
			if a >= ships_men:
				reason = "side %d reaches the ships" % attacker
				return attacker
		Kind.THE_HALL:
			_streak = _streak + 1 if a * 2 >= cells.size() and a > 0 else 0
			if _streak >= hall_streak:
				reason = "side %d takes the hall" % attacker
				return attacker
	if battle.round >= rounds:
		reason = time_up_reason()
		return defender()
	return -1


## The finish line when the time runs out on the attacker.
func time_up_reason() -> String:
	match kind:
		Kind.HOLD_GROUND:
			return "the ford is held: side %d keeps it" % defender()
		Kind.REACH_THE_SHIPS:
			return "the ships are safe: side %d holds them" % defender()
		_:
			return "the hall stands: side %d holds it" % defender()


## What an AI leader's men hear when the objective changes his order.
func ai_line(leader_name: String, attacking: bool) -> String:
	if attacking:
		match kind:
			Kind.HOLD_GROUND:
				return "%s will not leave the ford to them" % leader_name
			Kind.REACH_THE_SHIPS:
				return "%s makes for the ships" % leader_name
			_:
				return "%s means to see the hall burn" % leader_name
	return "%s keeps to %s: let them come to him" % [leader_name, name]
