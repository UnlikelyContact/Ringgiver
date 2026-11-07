class_name Fate
extends RefCounted
## Post-battle fate of a man (concept.md, Wounds: "After battle, downed men
## roll: die, maimed for life, or recover").


## 2d6 + Grit against CombatRules.fate_dead_below / fate_maimed_below. A man
## who is not Down recovers without a roll. Sets and returns `w.fate`.
static func roll(rng: SimRng, rules: CombatRules, w: Warrior) -> CombatTypes.Fate:
	if not w.is_down():
		w.fate = CombatTypes.Fate.RECOVERED
		return w.fate
	var total := rng.roll_2d6() + w.grit
	if total < rules.fate_dead_below:
		w.fate = CombatTypes.Fate.DEAD
	elif total < rules.fate_maimed_below:
		w.fate = CombatTypes.Fate.MAIMED
	else:
		w.fate = CombatTypes.Fate.RECOVERED
	return w.fate
