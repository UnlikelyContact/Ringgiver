class_name Origins
extends RefCounted
## Where the saga begins (concept.md, "Character creation"): the burned
## hall, the younger son, the freedman. An origin is a start and an
## unfinished matter, never a way of life: that a man chooses as he goes
## (Way). Nobody begins with a ship.

## key, name, blurb; origin (CampaignTypes.Origin, for his stats and
## trait); followers, silver; `at`: the place he starts; `feud_with`: a
## place whose family he begins at feud with (the burners), or "".
const DEFS := [
	{"key": "burned_hall", "name": "The burned hall", "origin": CampaignTypes.Origin.EXILED_JARLS_SON,
		"followers": 2, "silver": 10, "at": "sogn_farms", "feud_with": "hardanger",
		"blurb": "Your father's hall at Hardanger burned in the night, and men loyal to another lord hold his land. You got out with two men and what you stood in. Kin in Sogn have taken you in. Vengeance is your saga."},
	{"key": "younger_son", "name": "The younger son", "origin": CampaignTypes.Origin.YOUNGER_SON,
		"followers": 1, "silver": 15, "at": "hardanger", "feud_with": "",
		"blurb": "Your brother has the farm and everything on it. You have your father's old spear, a foster-brother who will follow you, and a place by the door for as long as you can stand it."},
	{"key": "freedman", "name": "The freedman", "origin": CampaignTypes.Origin.FREEDMAN,
		"followers": 0, "silver": 5, "at": "fitjar", "feud_with": "",
		"blurb": "You were a thrall at Fitjar until last Yule. You are free, alone, and owe nobody anything but the price of your freedom, which is paid. The hardest start, and the longest climb."},
]


static func def(key: String) -> Dictionary:
	for d in DEFS:
		if d.key == key:
			return d
	return DEFS[0]


static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for d in DEFS:
		out.append(d.key)
	return out
