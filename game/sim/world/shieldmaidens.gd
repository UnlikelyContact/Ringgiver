class_name Shieldmaidens
extends RefCounted
## Shieldmaidens (concept.md, "Shieldmaidens" and the open question near
## its end; docs/design/notes/men-silver.md): rare, notable exceptions,
## a band question and never the player's. Once the band is known
## (`maiden_fame`), in a few summers (`maiden_chance`) a woman comes to it
## with a story (a dead brother's mail, a vow over the cup, her father's
## sword) and asks to swear; never more than `maiden_max` in a saga. She
## fights as any man of her stats does: nothing in the fight differs. Some
## of the men take it ill (the superstitious), some well (the boastful,
## who must now make their boasts good before her); the house whose
## country she came from speaks well of a band that takes up her quarrel.
## After a year a house may send to ask for her hand.

## The stories she may come with: what she brings, and the words.
const STORIES := [
	{"key": "mail", "trait": "wears her dead brother's mail", "text":
		"At %s a woman comes to the band's fire with a mail shirt rolled in a cloak. \"This was my brother %s's. He was killed at the spring Thing, and there is no man of our house left to answer for him. I have sworn to wear it until it is answered.\" Her name is %s. She asks to swear to %s."},
	{"key": "vow", "trait": "vowed over the cup never to marry", "text":
		"At %s a woman stands up at the fire after the cup has gone round. \"My brother %s went out with the levy and did not come home. I vowed over his cup that I would go where he went and take no husband. I can draw a bow and hold a shield.\" Her name is %s. She asks to swear to %s."},
	{"key": "sword", "trait": "carries her father's sword", "text":
		"At %s a woman comes down to the strand with a sword in its sheath across her knees. \"My father had no son but %s, and the sea took him. The sword is mine now, and I will not hang it on the wall.\" Her name is %s. She asks to swear to %s."},
]


## The spring: perhaps a woman comes; perhaps a house asks for one who did.
static func spring(j: Journey) -> void:
	var c := j.c
	var band := c.band
	var rules := c.rules
	var e := Estate.of(band)
	if j.first_summer() or band.leader == null:
		return
	var r := c.rng.fork("maiden:%d" % c.cal.year)
	var at := j.here()
	if e.maidens < rules.maiden_max and band.fame >= rules.maiden_fame and at != null and Journey.SETTLED.has(at.kind) \
			and r.randf() < rules.maiden_chance:
		_offer(j, r, at)
		return
	for m in band.living_men():
		if m.woman and not e.suits.has(m.id) and c.cal.year - m.joined_year >= 1 and r.randf() < rules.maiden_suit_chance:
			_suit(j, r, m)
			return


static func _offer(j: Journey, r: SimRng, at: Place) -> void:
	var c := j.c
	var band := c.band
	var story: Dictionary = STORIES[r.randi_range(0, STORIES.size() - 1)]
	var her := str(c.rules.maiden_names[r.randi_range(0, c.rules.maiden_names.size() - 1)])
	var brother := str(Recruits.NAMES[r.randi_range(0, Recruits.NAMES.size() - 1)])
	var text := str(story.text) % [at.display_name, brother, her, band.leader.display_name]
	var full := band.living_men().size() >= c.room()
	j.decisions.append({"kind": "men_silver", "step": "maiden", "title": "A woman asks to swear", "text": text,
			"name": her, "brother": brother, "story": str(story.key), "trait": str(story.trait), "at": at.id,
			"detail": "She would stand in the line as any of your men: nothing in the fight is different for her. Some of your men may take it ill.",
			"options": [
				{"id": "take", "label": "Take her oath", "enabled": not full,
					"hint": "You have no bench or oar for another: let a man go first." if full else "She joins the band."},
				{"id": "gift", "label": "Send her home with a gift (5 oz)", "enabled": band.silver >= 5, "hint": "No one thinks the less of you."},
				{"id": "refuse", "label": "Send her away", "hint": "She goes to find a better man."}]})


static func _suit(j: Journey, r: SimRng, m: Man) -> void:
	var c := j.c
	var band := c.band
	var fs := c.world.families
	if fs == null:
		return
	var houses: Array[String] = []
	for n in c.rules.marriage_houses:
		if fs.houses.has(n) and str(n) != band.vengeance and not Families.is_foe(c.world_rules, band, str(n)):
			houses.append(str(n))
	if houses.is_empty():
		return
	var house := houses[r.randi_range(0, houses.size() - 1)]
	Estate.of(band).suits[m.id] = c.cal.year
	var head := fs.house(house).head
	j.decisions.append({"kind": "men_silver", "step": "suit", "title": "A house sends word", "man": m, "house": house,
			"text": "%s of %s has heard of %s, who stands in your line, and sends to ask for her hand for his son. It would be a good match, and a tie between your houses." % [head, house, m.display_name],
			"detail": "Given in marriage, she leaves the band, and %s become your kin by marriage. Refused, she stays." % house,
			"options": [
				{"id": "give", "label": "Give her in marriage", "hint": "Standing +%d with %s; she leaves the band." % [c.rules.maiden_suit_standing, house]},
				{"id": "ask", "label": "Let her answer it herself", "hint": "She takes it if her oath is done; else she stays."},
				{"id": "refuse", "label": "Refuse them", "hint": "She stays and thinks the better of you; they take it a little ill."}]})


static func answer(j: Journey, d: Dictionary, id: String) -> void:
	match str(d.step):
		"maiden":
			_answer_maiden(j, d, id)
		"suit":
			_answer_suit(j, d, id)


static func _answer_maiden(j: Journey, d: Dictionary, id: String) -> void:
	var c := j.c
	var band := c.band
	var rules := c.rules
	var who := band.leader.display_name
	var her := str(d.name)
	if id == "gift" and band.silver >= 5:
		band.silver -= 5
		j._say("%s gives %s five ounces and sends her home to her kin; she goes without a word." % [who, her])
		return
	if id != "take" or band.living_men().size() >= c.room():
		j._say("%s will not take her oath. %s goes on along the shore to find a better man." % [who, her])
		return
	var m := Recruits.make(c.rng.fork("maiden_man:%d" % c.cal.year), rules, CampaignTypes.Origin.YOUNGER_SON,
			c.rng.fork("maiden_age:%d" % c.cal.year).randi_range(18, 26), her, band.next_id())
	m.woman = true
	# A woman who comes to a band under arms has stood in a fight before:
	# blooded, quicker with a blade and steadier than a farm lad.
	m.traits.clear()
	m.tier = CombatTypes.Tier.BLOODED
	m.battles_survived = maxi(m.battles_survived, 1)
	for s in [CombatTypes.Stat.SKILL, CombatTypes.Stat.NERVE]:
		m.set_stat(s, m.stats[s] + 1)
		m.potential[s] = maxi(m.potential[s], m.stats[s])
	m.ambition = CampaignTypes.Ambition.VENGEANCE if str(d.story) == "mail" else CampaignTypes.Ambition.FAME
	m.traits.append(str(d.trait))
	m.loyalty = maxi(m.loyalty, 60)
	match str(d.story):
		"mail":
			m.armor = CombatTypes.Armor.MAIL
		"vow":
			m.weapon = CombatTypes.Weapon.BOW
			m.role = CombatTypes.Role.MISSILE
			m.armed = true
		"sword":
			m.weapon = CombatTypes.Weapon.SWORD
	band.add_man(m)
	Estate.of(band).maidens += 1
	j._say("%s takes %s's oath. She %s." % [who, her, str(d.trait)])
	band.log("%s came to %s's band, a woman under arms, and swore to him; she %s" % [her, who, str(d.trait)])
	# What the men make of it: the superstitious mutter, the boastful are
	# pleased to have someone new to boast before.
	var lines := PackedStringArray()
	for other in band.living_men():
		if other == m:
			continue
		if other.has_personality(CombatTypes.Personality.SUPERSTITIOUS):
			Loyalty.adjust(other, -rules.maiden_superstitious)
			lines.append("%s says a woman in the line is an ill sign, and sits apart from the fire that night." % other.display_name)
		elif other.has_personality(CombatTypes.Personality.BOASTFUL):
			Loyalty.adjust(other, rules.maiden_boastful)
			band.add_bond(other, m, 10)
			lines.append("%s laughs and says he will show her how a man fights." % other.display_name)
	for l in lines.slice(0, 2):
		j._say(l)
	# The house of the country she came from speaks well of a band that
	# takes up a woman's quarrel.
	var p: Place = c.world.place(str(d.get("at", "")))
	if p != null and p.family != "" and c.world.families != null and c.world.families.houses.has(p.family) and p.family != band.vengeance:
		c.world.families.shift(c.world_rules, band, p.family, 5)
		j._say("%s speak well of a band that would take up her quarrel." % Journey._cap(p.family))


static func _answer_suit(j: Journey, d: Dictionary, id: String) -> void:
	var c := j.c
	var band := c.band
	var m: Man = d.man
	var house := str(d.house)
	if m == null or not m.alive or not band.men.has(m):
		return
	var who := band.leader.display_name
	var takes := id == "give" or (id == "ask" and (m.ambition_met or m.ambition != CampaignTypes.Ambition.VENGEANCE) and m.loyalty < 80)
	if takes:
		band.remove_man(m)
		c.world.families.shift(c.world_rules, band, house, c.rules.maiden_suit_standing)
		Families._band_tie(band, house, "marriage")
		j._say("%s goes to %s to be married, with a chest of her own and %s's blessing. Their house and his are kin now." % [m.display_name, house, who])
		band.log("%s left the band to marry into %s" % [m.display_name, house])
		return
	if id == "ask":
		Loyalty.adjust(m, 5)
		j._say("%s will not have it: \"My oath is not done.\" She stays with the band." % m.display_name)
		return
	Loyalty.adjust(m, 10)
	c.world.families.shift(c.world_rules, band, house, -3)
	j._say("%s sends %s away with thanks: %s stays with the band, and is the warmer to him for it." % [who, house, m.display_name])
