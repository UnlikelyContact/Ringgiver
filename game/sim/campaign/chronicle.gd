class_name Chronicle
extends RefCounted
## The family chronicle (concept.md, The family chronicle): band.chronicle
## holds "<year>: text" lines; this turns them into saga text read at the end
## of each generation. Uneventful years get a line each, the way sagas pass
## over quiet winters.


## Appends "<year>: text" using the band's current year (same as Band.log).
static func line(band: Band, text: String) -> void:
	band.log(text)


## The chronicle lines of one year, unchanged (with their year prefix).
static func year_lines(band: Band, year: int) -> PackedStringArray:
	var prefix := "%d: " % year
	var out := PackedStringArray()
	for l in band.chronicle:
		if l.begins_with(prefix):
			out.append(l)
	return out


## A short saga paragraph for one leader's years. The closing line comes from
## CampaignRules.death_lines by how he died: `death_cause` if given, else the
## cause Succession.succeed recorded for `leader_name`. No known cause, no
## closing line. `rules` defaults to a fresh CampaignRules.
static func generation_text(band: Band, leader_name: String, from_year: int, to_year: int,
		death_cause := "", rules: CampaignRules = null) -> String:
	if rules == null:
		rules = CampaignRules.new()
	var parts := PackedStringArray()
	if from_year == to_year:
		parts.append("This is the saga of %s, who led the band in %d." % [leader_name, from_year])
	else:
		parts.append("This is the saga of %s, who led the band from %d to %d." % [leader_name, from_year, to_year])
	for y in range(from_year, to_year + 1):
		var lines := year_lines(band, y)
		if lines.is_empty():
			parts.append("In %d nothing happened that is worth the telling." % y)
			continue
		var sentences := PackedStringArray()
		for l in lines:
			sentences.append(_sentence(l.substr(("%d: " % y).length())))
		parts.append("In %d: %s" % [y, " ".join(sentences)])
	var cause := death_cause if death_cause != "" else Succession.death_cause_of(band, leader_name)
	if rules.death_lines.has(cause):
		parts.append(str(rules.death_lines[cause]))
	return " ".join(parts)


static func _sentence(text: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return t
	t = t.left(1).to_upper() + t.substr(1)
	if not (t.ends_with(".") or t.ends_with("!") or t.ends_with("?")):
		t += "."
	return t


# --- The saga as an artefact (docs/design/notes/generations.md) ----------------------
#
# Each leader's years are a chapter. The chapter in hand is kept as band
# metadata (CURRENT_META: {name, from, how}); when he dies, steps down or
# loses the high seat `close_chapter` snapshots what the saga tells of him
# (CHAPTERS_META). Men who fell (FALLEN_META), the skald's verses
# (VERSES_META), the years let pass (QUIET_META) and the ending
# (ENDING_META) are kept the same way. `saga` turns it into prose.

const CHAPTERS_META := &"saga_chapters"
const CURRENT_META := &"saga_current"
const FALLEN_META := &"saga_fallen"
const VERSES_META := &"saga_verses"
const QUIET_META := &"saga_quiet_years"
const ENDING_META := &"saga_ending"
const DIED_AT_META := &"saga_died_at"
## The ways a saga can end, and the line that ends it (`over_reason`).
const ENDINGS := {
	"no_heir": "the line died out, and the band scattered",
	"old_age": "he died old, and here the saga ends",
	"vengeance": "the burning was answered, and here the saga ends",
	"jarl": "he was a jarl, and here the saga ends",
	"iceland": "he took land in Iceland, and here the saga ends",
	"chosen": "here the saga ends",
}
## The steps of the reckoning, best first: [least score, the words].
const VERDICTS := [
	[20, "Men will tell of him as long as the North is settled."],
	[15, "His saga was told at every Thing in the west."],
	[11, "His name is remembered in the halls of the west country."],
	[7, "Men in the dales remember his name, and little more."],
	[4, "A few old men remember him."],
	[-100, "His name is not remembered."],
]


static func _current(band: Band) -> Dictionary:
	if band.has_meta(CURRENT_META):
		return band.get_meta(CURRENT_META)
	var from := band.year
	if not band.chronicle.is_empty():
		from = int(band.chronicle[0].get_slice(":", 0))
	return {"name": band.leader.display_name if band.leader != null else "nobody", "from": from, "how": ""}


## A new leader's chapter begins; it tells the chronicle from where the
## last one stopped (so the grave-ale is the first thing told of him).
static func open_chapter(band: Band, leader_name: String, year: int, how: String) -> void:
	var start := 0
	var chs: Array = band.get_meta(CHAPTERS_META, []) if band.has_meta(CHAPTERS_META) else []
	if not chs.is_empty():
		start = int(chs[-1].get("upto", 0))
	band.set_meta(CURRENT_META, {"name": leader_name, "from": year, "how": how, "start": start})


## A man of the band fell (or the leader himself): kept for his leader's chapter.
static func fell(band: Band, m: Man, year: int) -> void:
	var fallen: Array = band.get_meta(FALLEN_META, []) if band.has_meta(FALLEN_META) else []
	fallen.append({"name": m.display_name, "year": year, "woman": m.woman})
	band.set_meta(FALLEN_META, fallen)


## The skald's verse for a winter (WinterHall._tell).
static func keep_verse(band: Band, year: int, lines: PackedStringArray) -> void:
	var verses: Dictionary = band.get_meta(VERSES_META, {}) if band.has_meta(VERSES_META) else {}
	verses[year] = lines.duplicate()
	band.set_meta(VERSES_META, verses)


## A year let pass with nothing told (Years).
static func quiet_year(band: Band, year: int) -> void:
	var quiet: Array = band.get_meta(QUIET_META, []) if band.has_meta(QUIET_META) else []
	if not quiet.has(year):
		quiet.append(year)
	band.set_meta(QUIET_META, quiet)


## Where the leader died, in words, for his chapter ("at Fitjar").
static func died_at(band: Band, where: String) -> void:
	band.set_meta(DIED_AT_META, where)


## An old leader who stepped down died at last: his chapter keeps it.
static func old_man_died(band: Band, leader_name: String, year: int, age: int) -> void:
	for ch in band.get_meta(CHAPTERS_META, []) if band.has_meta(CHAPTERS_META) else []:
		if str(ch.name) == leader_name and str(ch.cause) == "stepped down":
			ch["old_death"] = year
			ch["old_age"] = age


## The leader's chapter is over (`cause`: how it ended: "battle", "old",
## "stepped down", "lost the high seat", "ended" for a saga that ends with
## him alive). Snapshots what the saga tells of him.
static func close_chapter(band: Band, year: int, cause: String) -> void:
	if band.leader == null:
		return
	var ch := _snapshot(band, year, cause)
	var chapters: Array = band.get_meta(CHAPTERS_META, []) if band.has_meta(CHAPTERS_META) else []
	chapters.append(ch)
	band.set_meta(CHAPTERS_META, chapters)
	if band.has_meta(CURRENT_META):
		band.remove_meta(CURRENT_META)
	if band.has_meta(DIED_AT_META):
		band.remove_meta(DIED_AT_META)


static func _snapshot(band: Band, year: int, cause: String) -> Dictionary:
	var cur := _current(band)
	var from := int(cur.from)
	var men := PackedStringArray()
	for m in band.living_men():
		men.append(m.display_name)
	var fallen: Array = []
	for f in band.get_meta(FALLEN_META, []) if band.has_meta(FALLEN_META) else []:
		if int(f.year) >= from and int(f.year) <= year and str(f.name) != str(cur.name):
			fallen.append(f)
	var feuds: Array = []
	for f in band.feuds:
		if int(f.get("year", year)) <= year and (not f.settled or int(f.get("closed", year)) >= from):
			feuds.append({"family": str(f.get("family", f.get("against", ""))), "cause": str(f.get("cause", "")),
					"settled": bool(f.settled), "verdict": str(f.get("verdict", "")), "year": int(f.get("year", year))})
	var verse := PackedStringArray()
	var verses: Dictionary = band.get_meta(VERSES_META, {}) if band.has_meta(VERSES_META) else {}
	var best_year := -1
	for y in verses:
		if int(y) >= from and int(y) <= year and int(y) > best_year:
			best_year = int(y)
	if best_year >= 0:
		verse = verses[best_year]
	var quiet: Array = []
	for y in band.get_meta(QUIET_META, []) if band.has_meta(QUIET_META) else []:
		if int(y) >= from and int(y) <= year:
			quiet.append(int(y))
	var children := PackedStringArray()
	for child in band.sons:
		if child.get("alive", true) and str(child.get("father", cur.name)) == str(cur.name):
			children.append(str(child.name))
	return {"name": str(cur.name), "from": from, "to": year, "how": str(cur.how), "cause": cause,
			"start": int(cur.get("start", 0)), "upto": band.chronicle.size(),
			"title": Way.title(band), "standing": Way.standing(band), "fame": band.fame, "honor": band.honor, "luck": band.luck,
			"rank": int(band.rank), "age": band.leader.age if band.leader != null else 0,
			"where": str(band.get_meta(DIED_AT_META, "")) if band.has_meta(DIED_AT_META) else "",
			"men": men, "fallen": fallen, "feuds": feuds, "verse": verse, "quiet": quiet,
			"wife": band.wife, "children": children, "land": band.land}


## Every chapter of the saga so far: those closed, and the living leader's
## as it stands now (cause "").
static func chapters(band: Band) -> Array:
	var out: Array = []
	for ch in band.get_meta(CHAPTERS_META, []) if band.has_meta(CHAPTERS_META) else []:
		out.append(ch)
	if band.leader != null and not band.has_meta(ENDING_META) \
			and (band.leader.alive or out.is_empty() or str(out[-1].name) != band.leader.display_name):
		out.append(_snapshot(band, band.year, ""))
	return out


## The saga told: {title, chapters: [{heading, years, paragraphs}],
## closing: [lines], text}. `kin` is what the first leader is named by
## ("Hardanger": "Egil Hardanger-son"); the ending (ENDING_META) closes it
## with a reckoning in words. `rules` defaults to a fresh CampaignRules.
static func saga(band: Band, kin := "", rules: CampaignRules = null) -> Dictionary:
	if rules == null:
		rules = CampaignRules.new()
	var chs := chapters(band)
	var first := str(chs[0].name) if not chs.is_empty() else "nobody"
	var title := "The saga of %s%s and his kin" % [first, (" %s-son" % kin) if kin != "" else ""]
	var out_chs: Array = []
	var text := PackedStringArray([title.to_upper(), ""])
	for i in chs.size():
		var ch: Dictionary = chs[i]
		var paras := _chapter_paragraphs(band, ch, i, kin, rules)
		var years := "%d to %d" % [int(ch.from), int(ch.to)] if int(ch.to) > int(ch.from) else str(int(ch.from))
		var heading := "%s. %s" % [_roman(i + 1), str(ch.title) if str(ch.title) != "" else str(ch.name)]
		out_chs.append({"heading": heading, "years": years, "paragraphs": paras, "name": str(ch.name)})
		text.append("%s (%s)" % [heading, years])
		for p in paras:
			text.append(p)
		text.append("")
	var closing := PackedStringArray()
	if band.has_meta(ENDING_META):
		var r := reckoning(band, rules)
		closing.append(str(r.ending))
		for l in r.lines:
			closing.append(l)
		closing.append(str(r.verdict))
		text.append("Here the saga ends.")
		text.append(" ".join(closing))
	return {"title": title, "chapters": out_chs, "closing": closing, "text": "\n".join(text)}


static func _roman(n: int) -> String:
	var vals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var out := ""
	for v in vals:
		while n >= int(v[0]):
			out += str(v[1])
			n -= int(v[0])
	return out


static func _chapter_paragraphs(band: Band, ch: Dictionary, index: int, kin: String, rules: CampaignRules) -> PackedStringArray:
	var paras := PackedStringArray()
	var name := str(ch.name)
	var from := int(ch.from)
	var to := int(ch.to)
	var summers := to - from + 1
	var intro := ""
	if index == 0:
		intro = "There was a man named %s%s." % [name, (", son of the hall at %s" % kin) if kin != "" else ""]
	else:
		intro = "%s took the high seat in %d%s." % [name, from, (", " + str(ch.how)) if str(ch.how) != "" else ""]
	intro += " He led the band %s%s." % [("for %d summers" % summers) if summers > 1 else "for one summer",
			(", from %d" % from) if index == 0 else ""]
	if str(ch.title) != name:
		intro += " Men called him %s." % str(ch.title)
	if str(ch.standing) != "":
		intro += " He was reckoned %s." % str(ch.standing)
	paras.append(intro)
	# The years, as the chronicle has them; years let pass are passed over.
	var quiet: Array = ch.get("quiet", [])
	var told := PackedStringArray()
	var y := from
	while y <= to:
		if quiet.has(y):
			var run := 0
			while quiet.has(y + run):
				run += 1
			told.append("Then nothing is told of %s for %s." % [name, "a winter" if run == 1 else ("%s winters" % _number(run))])
			y += run
			continue
		var sentences := PackedStringArray()
		var joined := 0
		var sworn := 0
		for l in _lines_of(band, ch, y):
			var t := l.substr(("%d: " % y).length())
			if kin != "":
				t = t.replace("your father's hall", "the hall at %s" % kin)
			var came := t.contains(" swears to ") or t.contains("asked to join") or t.contains("asking shelter, and was taken in")
			if came or t.contains(" effort in ") or t.begins_with("the year passed quietly"):
				if came:
					joined += 1
				continue
			# Oath-brotherhoods among the men are told as a count, not pair by
			# pair (a year could have seven of them); the leader's own is told.
			if t.contains("mixed their blood under the turf") and not t.begins_with(name + " and "):
				sworn += 1
				continue
			var said := _sentence(t)
			if sentences.size() < 7 and not sentences.has(said):
				sentences.append(said)
		if sworn > 0:
			sentences.append("%s of his men mixed their blood under the turf that year." % Journey._cap("%s %s" % [_number(sworn), "pair" if sworn == 1 else "pairs"]))
		if joined > 0:
			sentences.append("%s came to his benches that year." % Journey._cap("%s %s" % [_number(joined), "man" if joined == 1 else "men"]))
		if not sentences.is_empty():
			told.append("In %d: %s" % [y, " ".join(sentences)])
		y += 1
	if not told.is_empty():
		paras.append(" ".join(told))
	# The men, the fallen and the feuds.
	var bits := PackedStringArray()
	var men: PackedStringArray = ch.get("men", PackedStringArray())
	if men.size() > 0:
		bits.append("These men stood by him at the last: %s." % _list(men.slice(0, 12)))
	var fallen: Array = ch.get("fallen", [])
	if not fallen.is_empty():
		var names := PackedStringArray()
		for f in fallen.slice(0, 12):
			names.append("%s in %d" % [str(f.name), int(f.year)])
		bits.append("These fell in his service: %s." % _list(names))
	var feuds: Array = ch.get("feuds", [])
	feuds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (not a.settled and b.settled) or (a.settled == b.settled and int(a.year) < int(b.year)))
	for f in feuds.slice(0, 4):
		var how := ""
		if f.settled:
			how = "it was ended by %s" % (str(f.verdict) if str(f.verdict) != "" else "settlement")
		else:
			how = "it was not ended in his day" if str(ch.cause) != "" else "it is not ended yet"
		var cause := str(f.cause).replace("your father's hall", ("the hall at %s" % kin) if kin != "" else "his father's hall")
		bits.append("He had a feud with %s over %s, and %s." % [str(f.family), cause, how])
	if not bits.is_empty():
		paras.append(" ".join(bits))
	var verse: PackedStringArray = ch.get("verse", PackedStringArray())
	if not verse.is_empty():
		paras.append("A skald made this about him:\n  " + "\n  ".join(verse))
	# How it ended.
	var end := ""
	var where := str(ch.get("where", ""))
	match str(ch.cause):
		"":
			end = "He is %d winters old, and his saga is not over." % int(ch.age)
		"stepped down":
			end = "In %d, grown old, he gave the high seat to his son and sat by the fire, and gave counsel." % to
			if ch.has("old_death"):
				end += " He died in his bed in %d, %d winters old." % [int(ch.old_death), int(ch.old_age)]
		"lost the high seat":
			end = "In %d he lost the high seat on the island, and went down to the benches." % to
		"ended":
			end = "Here his saga ends, in %d, when he was %d winters old." % [to, int(ch.age)]
		_:
			end = "He died in %d%s, %d winters old." % [to, (" " + where) if where != "" else "", int(ch.age)]
			if rules.death_lines.has(str(ch.cause)):
				end += " " + str(rules.death_lines[str(ch.cause)])
	paras.append(end)
	return paras


## A year's lines of the chronicle that belong to the chapter: from where
## it began to where it was closed (all of the year for an old chapter).
static func _lines_of(band: Band, ch: Dictionary, y: int) -> PackedStringArray:
	var prefix := "%d: " % y
	var out := PackedStringArray()
	var start := int(ch.get("start", 0))
	var upto := int(ch.get("upto", band.chronicle.size()))
	for i in range(start, mini(upto, band.chronicle.size())):
		if band.chronicle[i].begins_with(prefix):
			out.append(band.chronicle[i])
	return out


static func _list(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "".join(names)
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]


static func _number(n: int) -> String:
	var words := ["no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
	return str(words[n]) if n >= 0 and n < words.size() else str(n)


## The reckoning at the end, in words (no score is shown): what is told of
## the house from its fame and honor, the vengeance taken or owed, land
## held, sons living, rank reached, years lived, the generations; the
## verdict is the step of VERDICTS the whole reaches. {ending, lines, verdict}.
static func reckoning(band: Band, rules: CampaignRules = null) -> Dictionary:
	if rules == null:
		rules = CampaignRules.new()
	var ending: Dictionary = band.get_meta(ENDING_META, {}) if band.has_meta(ENDING_META) else {}
	var kind := str(ending.get("kind", "chosen"))
	var chs := chapters(band)
	var lines := PackedStringArray()
	var score := 0.0
	score += band.fame / 10.0
	score += band.honor / 20.0
	if band.fame >= 60:
		lines.append("His name went before him into every hall.")
	elif band.fame < 20:
		lines.append("Few outside his own dale had heard of him.")
	if band.honor >= 60:
		lines.append("He kept his word, and men knew it.")
	elif band.honor < 25:
		lines.append("Men said his word was worth little.")
	var avenged := bool(ending.get("vengeance_done", false)) or _told(band, "had his vengeance")
	if avenged:
		score += 3
		lines.append("The burning of his father's hall was answered.")
	elif band.vengeance != "":
		score -= 2
		lines.append("The burning was never answered, and %s laughed at it." % band.vengeance)
	if band.land > 0:
		score += 1
		lines.append("He held land of his own.")
	var sons := 0
	for child in band.sons:
		if Family.is_son(child) and child.get("alive", true) and not child.get("seat", false):
			sons += 1
	if sons > 0:
		score += mini(sons, 3)
		lines.append("He left %s living." % ("a son" if sons == 1 else "%s sons" % _number(sons)))
	elif kind == "no_heir":
		lines.append("He left no son, and no man to take up his name.")
	match int(band.rank):
		WorldTypes.Rank.KING:
			score += 6
			lines.append("He was a king.")
		WorldTypes.Rank.JARL:
			score += 4
			lines.append("He was a jarl, and men stood when he came into a hall.")
		WorldTypes.Rank.HERSIR:
			score += 2
			lines.append("He was a hersir, and held men of his own.")
	var first := int(chs[0].from) if not chs.is_empty() else band.year
	var span := band.year - first + 1
	score += mini(3, span / 10)
	if chs.size() > 1:
		score += chs.size() - 1
		lines.append("The saga ran %s winters, through %s generations." % [_number(span), _number(chs.size())])
	else:
		lines.append("The saga ran %s winters." % _number(span))
	if kind == "no_heir":
		score -= 2
	var verdict := str(VERDICTS[-1][1])
	for v in VERDICTS:
		if score >= float(v[0]):
			verdict = str(v[1])
			break
	return {"ending": Journey._cap(str(ENDINGS.get(kind, ENDINGS.chosen))) + ".", "lines": lines, "verdict": verdict, "kind": kind}


static func _told(band: Band, words: String) -> bool:
	for l in band.chronicle:
		if l.contains(words):
			return true
	return false
