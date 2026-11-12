class_name SaveStore
extends RefCounted
## Saves on disk (docs/design/notes/save.md): the autosave, the one before
## it, and three slots the player keeps, in `user://saves/` (on the web
## build the browser's IndexedDB, synced after every write). Also the text
## a player copies to carry a saga to another device.
##
## A file is three parts: the line MAGIC, one line of JSON (the head:
## {format, game_build, saved_at, summary, bytes, sha}) and the body, the
## JSON of {data: SaveCodec's encoding of the Journey, view: what the
## screens keep} compressed with gzip. The title reads only the head. A
## file that does not begin with MAGIC, whose body does not match its sha,
## or that is of a newer format is reported and left alone, never loaded.
##
##   SaveStore.write("auto", journey, {"hints": {...}})  # -> "" or an error
##   SaveStore.head("auto")    # {} when there is none, {error} when bad
##   SaveStore.read("auto")    # {journey, view, head} or {error}
##   SaveStore.export_text("auto") / SaveStore.import_text(text, "slot1")

const MAGIC := "RINGGIVER-SAVE"
## The save format; a file of a higher one was written by a newer build.
const FORMAT := 1
const DIR := "user://saves/"
const AUTO := "auto"
## The autosave before the last, kept in case the last is bad.
const BACKUP := "auto_prev"
const SLOTS := ["slot1", "slot2", "slot3"]
## The copied text's prefix.
const TEXT_PREFIX := "RINGGIVER1:"

## Where the files go (the tests point it elsewhere).
static var dir := DIR
## How long the last write took, in microseconds: {encode, write}.
static var last_usec := {}


static func path_of(slot: String) -> String:
	return dir + slot + ".save"


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_of(slot))


## The words the title and the slots show for a save: "Egil the Viking,
## summer of 871, at Fitjar, 9 men".
static func summary_line(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	var season := "winter" if bool(summary.get("winter", false)) else "summer"
	var men := int(summary.get("men", 0))
	var line := "%s, %s of %d, %s, %s" % [str(summary.get("leader", "?")), season, int(summary.get("year", 0)),
			_at(str(summary.get("place", ""))), "alone" if men == 0 else ("1 man" if men == 1 else "%d men" % men)]
	if bool(summary.get("over", false)):
		line = "%s, the saga ended in %d" % [str(summary.get("leader", "?")), int(summary.get("year", 0))]
	return line


static func _at(where: String) -> String:
	if where == "at sea" or where == "in the wilds" or where == "":
		return where if where != "" else "abroad"
	return "at " + where


## What a save says of the saga, without loading it.
static func summarize(j: Journey) -> Dictionary:
	var s := j.status()
	return {"leader": str(s.title), "year": int(s.year), "day": int(s.day), "place": str(s.where),
			"men": j.c.band.living_men().size(), "silver": int(s.silver), "generation": Chronicle.chapters(j.c.band).size(),
			"winter": j.in_winter(), "over": j.c.over}


# --- Writing ------------------------------------------------------------------

## The bytes of a save of `j` (with `view`, what the screens keep).
static func pack(j: Journey, view := {}) -> PackedByteArray:
	var t0 := Time.get_ticks_usec()
	var data := SaveCodec.encode(j)
	var body := JSON.stringify({"data": data, "view": view}, "", false).to_utf8_buffer()
	var zipped := body.compress(FileAccess.COMPRESSION_GZIP)
	var head := {"format": FORMAT, "game_build": _build(), "saved_at": int(Time.get_unix_time_from_system()),
			"summary": summarize(j), "bytes": body.size(), "sha": _sha(zipped)}
	var out := (MAGIC + "\n" + JSON.stringify(head, "", false) + "\n").to_utf8_buffer()
	out.append_array(zipped)
	last_usec["encode"] = Time.get_ticks_usec() - t0
	return out


## Writes a save of `j` to `slot`: to a new file first, then put in the
## old one's place, so a write cut short leaves the last save whole. The
## autosave keeps the one before it as BACKUP. Returns "" or what failed.
static func write(slot: String, j: Journey, view := {}) -> String:
	return write_bytes(slot, pack(j, view))


static func write_bytes(slot: String, bytes: PackedByteArray) -> String:
	var t0 := Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var final := path_of(slot)
	var tmp := final + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "could not write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())]
	f.store_buffer(bytes)
	f.close()
	if slot == AUTO and FileAccess.file_exists(final):
		var prev := path_of(BACKUP)
		if FileAccess.file_exists(prev):
			DirAccess.remove_absolute(prev)
		DirAccess.rename_absolute(final, prev)
	elif FileAccess.file_exists(final):
		DirAccess.remove_absolute(final)
	var err := DirAccess.rename_absolute(tmp, final)
	if err != OK:
		return "could not put the save in place (%s)" % error_string(err)
	sync()
	last_usec["write"] = Time.get_ticks_usec() - t0
	return ""


## Removes a save (and nothing else).
static func remove(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path_of(slot))
		sync()


## On the web, user:// lives in memory and is copied to IndexedDB when a
## file written is closed; a rename or a removal after that is copied only
## at the next sync, so it is asked for here. Elsewhere it does nothing.
static func sync() -> void:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		Engine.get_singleton("JavaScriptBridge").call("force_fs_sync")


## Whether what is saved will still be there next visit (false in a
## private window on the web, where IndexedDB is not kept).
static func persistent() -> bool:
	return OS.is_userfs_persistent()


# --- Reading -----------------------------------------------------------------------

## The head of the save in `slot`: {format, game_build, saved_at, summary,
## ...}, {} when there is none, {error} when it cannot be read.
static func head(slot: String) -> Dictionary:
	if not exists(slot):
		return {}
	var parts := _split(FileAccess.get_file_as_bytes(path_of(slot)))
	if parts.has("error"):
		return {"error": parts.error}
	if _sha(parts.body) != str((parts.head as Dictionary).get("sha", "")):
		return {"error": "the save is damaged"}
	return parts.head


## The save in `slot`, loaded: {journey, view, head, report}, or {error}.
static func read(slot: String) -> Dictionary:
	if not exists(slot):
		return {"error": "there is no save there"}
	return unpack(FileAccess.get_file_as_bytes(path_of(slot)))


## A save's bytes, checked and loaded: {journey, view, head, report}, or
## {error} saying what is wrong with it.
static func unpack(bytes: PackedByteArray) -> Dictionary:
	var parts := _split(bytes)
	if parts.has("error"):
		return parts
	var h: Dictionary = parts.head
	var zipped: PackedByteArray = parts.body
	if _sha(zipped) != str(h.get("sha", "")):
		return {"error": "the save is damaged", "head": h}
	var body := zipped.decompress(int(h.get("bytes", 0)), FileAccess.COMPRESSION_GZIP)
	if body.size() != int(h.get("bytes", -1)):
		return {"error": "the save is damaged", "head": h}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("data"):
		return {"error": "the save is damaged", "head": h}
	var rep := {}
	var j: Variant = SaveCodec.decode(parsed.data, rep)
	if not (j is Journey) or (j as Journey).c == null or (j as Journey).roam == null:
		return {"error": "the save does not hold a saga", "head": h}
	if int(rep.get("unknown_classes", 0)) > 0 or int(rep.get("mismatched", 0)) > 0:
		push_warning("SaveStore: loaded with %s" % str(rep))
	var view: Variant = parsed.get("view", {})
	return {"journey": j, "view": view if view is Dictionary else {}, "head": h, "report": rep}


## Splits a save into {head, body}, or {error}.
static func _split(bytes: PackedByteArray) -> Dictionary:
	var first := bytes.find(10)
	if first < 0 or bytes.slice(0, first).get_string_from_utf8() != MAGIC:
		return {"error": "this is not a saga's save"}
	var second := bytes.find(10, first + 1)
	if second < 0:
		return {"error": "the save is damaged"}
	var h: Variant = JSON.parse_string(bytes.slice(first + 1, second).get_string_from_utf8())
	if not (h is Dictionary):
		return {"error": "the save is damaged"}
	if int((h as Dictionary).get("format", 0)) > FORMAT:
		return {"error": "the save was made by a newer build of the game", "head": h}
	return {"head": h, "body": bytes.slice(second + 1)}


# --- Carried by hand ------------------------------------------------------------------

## The save in `slot` as one line of text to copy: TEXT_PREFIX and the
## file in base64 (already compressed). "" when there is none.
static func export_text(slot: String) -> String:
	if not exists(slot):
		return ""
	return TEXT_PREFIX + Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path_of(slot)))


## Text pasted in, checked: {bytes, head} or {error}.
static func parse_text(text: String) -> Dictionary:
	var t := text.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if not t.begins_with(TEXT_PREFIX):
		return {"error": "that is not a saga copied from the game"}
	var bytes := Marshalls.base64_to_raw(t.substr(TEXT_PREFIX.length()))
	var r := unpack(bytes)
	if r.has("error"):
		return r
	return {"bytes": bytes, "head": r.head}


## Text pasted in, checked and written to `slot`. Returns "" or what is
## wrong with it.
static func import_text(text: String, slot: String) -> String:
	var r := parse_text(text)
	if r.has("error"):
		return str(r.error)
	return write_bytes(slot, r.bytes)


static func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _build() -> String:
	if FileAccess.file_exists("res://build.txt"):
		var f := FileAccess.open("res://build.txt", FileAccess.READ)
		if f != null:
			return f.get_as_text().strip_edges()
	return "dev"
