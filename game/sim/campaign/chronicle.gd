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
