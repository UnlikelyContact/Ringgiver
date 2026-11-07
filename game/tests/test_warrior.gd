extends TestCase


func _rules() -> CombatRules:
	return CombatRules.new()


func test_make_and_stats() -> void:
	var w := Warrior.make("Egil", 0, [6, 5, 4, 3, 2], CombatTypes.Tier.VETERAN)
	assert_eq(w.stat(CombatTypes.Stat.MIGHT), 6)
	assert_eq(w.stat(CombatTypes.Stat.WITS), 2)
	assert_eq(w.tier, CombatTypes.Tier.VETERAN)


func test_wound_steps_cap_at_down() -> void:
	var w := Warrior.make("a", 0, [3, 3, 3, 3, 3])
	w.take_wound_steps(2)
	assert_eq(w.wound, CombatTypes.Wound.WOUNDED)
	w.take_wound_steps(5)
	assert_eq(w.wound, CombatTypes.Wound.DOWN)
	assert_true(w.is_down())
	assert_true(not w.is_active())


func test_breath_and_fatigue_penalty() -> void:
	var r := _rules()
	var w := Warrior.make("a", 0, [3, 3, 3, 3, 3])
	w.reset_for_battle(r)
	assert_eq(w.breath, r.breath_base + 3 * r.breath_per_grit)
	assert_eq(w.fatigue_penalty(r), 0)
	w.spend_breath(100)
	assert_eq(w.breath, 0)
	assert_eq(w.fatigue_penalty(r), r.fatigue_penalty_empty)
	w.recover_breath(1000, r)
	assert_eq(w.breath, w.max_breath(r))


func test_reset_sets_morale_from_nerve() -> void:
	var r := _rules()
	var w := Warrior.make("a", 0, [3, 3, 3, 7, 3])
	w.reset_for_battle(r)
	assert_eq(w.morale, 10, "nerve 7 + start bonus 3, clamped to 10")
	var g := Warrior.make("g", 0, [3, 3, 3, 2, 3])
	g.reset_for_battle(r)
	assert_eq(g.morale, 2 + r.morale_start_bonus, "a green man starts above the break threshold")
	assert_eq(w.shield_hp, r.shield_hp)
