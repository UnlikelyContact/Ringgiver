class_name VoyageResult
extends RefCounted
## What one call to Voyage.sail did: the planned route, days spent, whether
## the band reached its destination, any wreck, the encounters met, and the
## place where the band now lies (the caller resumes from there).

## Planned route, from the starting place to the destination inclusive.
var route: Array[String] = []
var days := 0
var arrived := false
var wrecked := false
var encounters: Array[Dictionary] = []
var stopped_at := ""
## Why the voyage ended short, "" if it arrived or simply stopped
## ("unknown", "no_ship", "no_route", "season", "wreck", "battle", "ship").
var reason := ""


## The battle request that stopped the voyage, or {}.
func battle() -> Dictionary:
	for e in encounters:
		if e.has("battle_required"):
			return e.battle_required
	return {}


func describe() -> String:
	return "%s: %d days, %s at %s%s" % [
		" > ".join(PackedStringArray(route)), days,
		"arrived" if arrived else "stopped", stopped_at,
		(" (%s)" % reason) if reason != "" else ""]
