class_name SaveCodec
extends RefCounted
## Turns a saga (the Journey and everything it reaches) into plain data
## that JSON can carry, and back (docs/design/notes/save.md). It knows no
## class of the sim by heart: it walks every script variable of every
## RefCounted it reaches, so a field added to any class tomorrow is saved
## with no change here. What must not be saved as it stands (a shared
## grid, a lambda, a derived field, the rules when they are the defaults)
## is named in the registry below, in this one place.
##
##   var data := SaveCodec.encode(journey)      # plain data, JSON-safe
##   var j: Journey = SaveCodec.decode(data)    # a new, separate graph
##   SaveCodec.digest(journey)                  # a hash of the encoding
##
## The shape of `data`: {"root": <value>, "objects": [{"c": tag, "p":
## {name: value}}, ...]}. An object is written once, in the table, and
## everywhere else as {"$r": index}, so a man in the band and in a
## decision comes back as one man, and cycles cost nothing. Values:
## null, bools, ints (as JSON numbers within 2^53, else "~i<digits>"),
## floats ("~f" + var_to_str when that reads back exactly, else "~b" and
## the 64 bits), strings (a leading "~" doubled),
## StringNames ("~n"), arrays (a JSON list; a typed one as {"$a": type,
## "v": list}), dictionaries (a JSON object when every key is a String,
## kept in insertion order, a key that starts with "$" or "~" escaped by a
## "~"; otherwise {"$K": keys, "$V": values}, with "$t" for a typed one),
## packed arrays ({"$ps"}, {"$pb"} base64, {"$pi"}, {"$pl"}, {"$pf"},
## {"$pd"}), other built-in values ({"$v": var_to_str}, or {"$vb"} the
## engine's bytes when the text is not exact) and Callables to a static
## function ({"$fn": [tag, method]}). An object's metadata is saved beside
## its properties ("m").
##
## Decoding tolerates a save from an older build: a property the class no
## longer has is ignored, one the save lacks keeps the default `new()`
## gave it, and a value of the wrong type keeps the default too. Each is
## counted in `report`. In `strict` mode (the tests) anything the encoder
## could not encode is an error listed in `errors`; in the game it is
## skipped and logged.

const FORMAT := 1

# --- The registry: what is not saved as it stands ------------------------------------

## Properties never saved, by class tag: derived from other fields, so
## they come back by themselves.
const SKIP := {
	"Band": ["friends"],  # a getter over `standing`
}
## Classes saved as the difference from a fresh instance: the tunables. A
## balance patch then reaches an old save; a test that changed a rule
## still round-trips its change.
const DIFF_FROM_DEFAULT := ["CombatRules", "CampaignRules", "WorldRules"]
## Classes with one shared, deterministic instance built from static data:
## class tag -> the static function that returns it. An instance that is
## that one is saved as a token and found again on load; any other is saved
## in full.
const SHARED := {"MapGrid": "norway"}
## Properties holding a lambda that the class's own `new()` sets again:
## class tag -> names. A Callable to a static function is saved by name
## wherever it is; a lambda anywhere else is an error.
const CALLABLE_DEFAULT := {"Campaign": ["fight_policy"]}
## Lists kept only in part: class tag -> {property: the newest lines kept}.
## The campaign's log is the sim's working record (half a megabyte in
## thirty years), read only by the call that is writing it (a mark and the
## lines since); the player reads `Journey.said` and the chronicles, which
## are kept whole. The digest is of the encoding, so it is trimmed alike.
const TRIM := {"Campaign": {"log": 400}}
## Engine classes that may be reached, and the properties that hold their
## state, in the order they must be set (an RNG's seed resets its state).
const NATIVE := {"RandomNumberGenerator": ["seed", "state"]}

## Static variables in sim/ are not part of any saga and are not saved;
## each must be named here with the reason it needs no saving, or a test
## fails (tests/test_save.gd): a static that the sim writes as it plays
## would be shared by a saga and its loaded copy in one process, so the
## continuation test could not see it, while a real reload would lose it.
const STATICS := {
	"Roam._sea_routes": "a cache of sea routes over the fixed grid: the same answer computed again",
	"Roam._place_days": "a cache of days between places over the fixed grid",
	"MapGrid._norway": "the one grid, built from NorwayData (SHARED)",
	"JourneyBot.let_years": "the stand-in player's habit, set by tests and tools",
	"JourneyBot.ends": "the stand-in player's habit, set by tests and tools",
	"SaveCodec._tags": "the codec's own lookup of classes",
	"SaveCodec._scripts": "the codec's own lookup of classes",
	"SaveCodec._defaults": "fresh rules to diff against",
	"SaveCodec._global_paths": "the codec's own lookup of classes",
	"SaveStore.dir": "where saves go (tests point it elsewhere)",
	"SaveStore.last_usec": "how long the last save took",
}

const _BIG := 9007199254740992  # 2^53: past it a JSON number is not exact

## Fail loudly (tests): every value that could not be encoded is listed in
## `errors`. Off, such values are skipped and pushed as warnings.
var strict := false
var errors := PackedStringArray()
## What decoding met: {unknown_props, missing_props, mismatched, converted,
## unknown_classes, objects}.
var report := {}

var _ids := {}  # Object -> index in _objects
var _objects: Array = []  # encoded entries
var _queue: Array = []  # objects waiting to be written
var _path := ""  # where the encoder is, for the errors
var _decoded: Array = []

static var _tags := {}  # GDScript -> tag
static var _scripts := {}  # tag -> GDScript
static var _defaults := {}  # tag -> a fresh instance, for DIFF_FROM_DEFAULT
static var _global_paths := {}  # class_name -> script path


# --- The front door ----------------------------------------------------------------

## Encodes the graph under `root`. Returns {"root", "objects"}; with
## `strict` the codec's `errors` say what could not be encoded.
static func encode(root: Variant, strict_mode := false, errors_out: PackedStringArray = PackedStringArray()) -> Dictionary:
	var codec := SaveCodec.new()
	codec.strict = strict_mode
	var out := codec.encode_graph(root)
	errors_out.append_array(codec.errors)
	return out


## Decodes what `encode` made into a new graph and returns its root.
## `report_out` receives the codec's report.
static func decode(data: Dictionary, report_out: Dictionary = {}) -> Variant:
	var codec := SaveCodec.new()
	var root: Variant = codec.decode_graph(data)
	report_out.merge(codec.report, true)
	return root


## The canonical text of the graph: JSON of its encoding, keys in the
## order they were made (never sorted: the order is part of the state).
static func to_text(root: Variant) -> String:
	return JSON.stringify(encode(root), "", false)


## A hash of the whole graph's encoding: two graphs with the same digest
## hold the same state, down to the order of every dictionary.
static func digest(root: Variant) -> String:
	return to_text(root).sha256_text()


## Digests of each part of the graph, a level or two down from `root` (the
## properties of the root and of each object the root holds): for finding
## which part of two runs went apart. Returns {path: digest}.
static func digest_parts(root: Object, depth := 2) -> Dictionary:
	var out := {}
	_digest_into(root, "", depth, out)
	return out


static func _digest_into(obj: Object, prefix: String, depth: int, out: Dictionary) -> void:
	for p in obj.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = obj.get(p.name)
		var path := prefix + str(p.name)
		if v is RefCounted and depth > 1 and not (v as Object).get_script() == null:
			_digest_into(v, path + ".", depth - 1, out)
		else:
			out[path] = JSON.stringify(encode(v), "", false).sha256_text()


# --- Encoding --------------------------------------------------------------------

func encode_graph(root: Variant) -> Dictionary:
	_ids.clear()
	_objects.clear()
	_queue.clear()
	errors.clear()
	_path = "root"
	var r: Variant = _enc(root)
	var i := 0
	while i < _queue.size():
		_write_object(_queue[i], i)
		i += 1
	return {"root": r, "objects": _objects}


func _fail(what: String) -> void:
	var line := "%s: %s" % [_path, what]
	if strict:
		errors.append(line)
	else:
		push_warning("SaveCodec: " + line)


func _ref(obj: Object) -> Variant:
	if _ids.has(obj):
		return {"$r": _ids[obj]}
	if obj is Node:
		_fail("a Node is reachable from the sim (%s)" % obj.get_class())
		return null
	var tag := _tag_of(obj)
	if tag == "":
		_fail("an object of a class that cannot be named (%s)" % obj.get_class())
		return null
	var id := _queue.size()
	_ids[obj] = id
	_queue.append(obj)
	_objects.append(null)
	return {"$r": id}


func _write_object(obj: Object, id: int) -> void:
	var tag := _tag_of(obj)
	var entry := {"c": tag}
	_objects[id] = entry
	if tag.begins_with("@"):
		var props := {}
		for name in NATIVE.get(tag.substr(1), []):
			_path = "%s#%d.%s" % [tag, id, name]
			props[name] = _enc(obj.get(name))
		entry["p"] = props
		return
	if SHARED.has(tag):
		var shared: Variant = _script_of(tag).call(SHARED[tag])
		if shared == obj:
			entry["s"] = SHARED[tag]
			return
	var skip: Array = SKIP.get(tag, [])
	var fresh: Object = _default_of(tag) if DIFF_FROM_DEFAULT.has(tag) else null
	var callable_ok: Array = CALLABLE_DEFAULT.get(tag, [])
	var trim: Dictionary = TRIM.get(tag, {})
	var props := {}
	for p in obj.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var name := str(p.name)
		if skip.has(name):
			continue
		var v: Variant = obj.get(name)
		if fresh != null:
			var d: Variant = fresh.get(name)
			if typeof(d) == typeof(v) and d == v:
				continue
		_path = "%s#%d.%s" % [tag, id, name]
		if v is Callable and (v as Callable).is_custom() and callable_ok.has(name):
			continue  # the class's new() sets it again
		if trim.has(name) and (v is PackedStringArray or v is Array) and v.size() > int(trim[name]):
			v = v.slice(v.size() - int(trim[name]))
		props[name] = _enc(v)
	entry["p"] = props
	# Metadata is state too (the chronicle keeps its chapters on the band).
	var metas := obj.get_meta_list()
	if not metas.is_empty():
		var m := {}
		for k in metas:
			_path = "%s#%d@%s" % [tag, id, k]
			m[str(k)] = _enc(obj.get_meta(k))
		entry["m"] = m


func _enc(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			return v
		TYPE_INT:
			var n: int = v
			if n >= _BIG or n <= -_BIG:
				return "~i" + str(n)
			return n
		TYPE_FLOAT:
			return _enc_float(v)
		TYPE_STRING:
			var s: String = v
			return ("~" + s) if s.begins_with("~") else s
		TYPE_STRING_NAME:
			return "~n" + str(v)
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v):
				return null
			return _ref(v)
		TYPE_VECTOR2I:
			return {"$v": "Vector2i(%d, %d)" % [v.x, v.y]}
		TYPE_ARRAY:
			var a: Array = v
			if a.is_typed() and a.get_typed_builtin() == TYPE_VECTOR2I:
				# A route or a list of cells: flat, two ints a cell.
				var xy := PackedInt32Array()
				xy.resize(a.size() * 2)
				for i in a.size():
					xy[i * 2] = a[i].x
					xy[i * 2 + 1] = a[i].y
				return {"$a": [TYPE_VECTOR2I, "", ""], "xy": Array(xy)}
			var list := []
			list.resize(a.size())
			for i in a.size():
				list[i] = _enc(a[i])
			if not a.is_typed():
				return list
			return {"$a": [a.get_typed_builtin(), str(a.get_typed_class_name()), _script_tag(a.get_typed_script())], "v": list}
		TYPE_DICTIONARY:
			return _enc_dict(v)
		TYPE_PACKED_STRING_ARRAY:
			if not "".join(v).contains("~"):
				return {"$ps": Array(v)}  # nothing to escape: the engine copies it at once
			var list := []
			for s in (v as PackedStringArray):
				list.append(_enc(s))
			return {"$ps": list}
		TYPE_PACKED_BYTE_ARRAY:
			return {"$pb": Marshalls.raw_to_base64(v)}
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			var list := []
			for n in v:
				list.append(_enc(n))
			return {("$pi" if typeof(v) == TYPE_PACKED_INT32_ARRAY else "$pl"): list}
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var list := []
			for x in v:
				list.append(_enc_float(x))
			return {("$pf" if typeof(v) == TYPE_PACKED_FLOAT32_ARRAY else "$pd"): list}
		TYPE_CALLABLE:
			var f: Callable = v
			if f.is_null():
				return {"$fn": null}
			var o := f.get_object()
			if not f.is_custom() and o is GDScript and _script_tag(o) != "":
				return {"$fn": [_script_tag(o), str(f.get_method())]}
			_fail("a Callable that is not a static function (a lambda or a bound method)")
			return null
		TYPE_SIGNAL, TYPE_RID:
			_fail("a %s cannot be saved" % type_string(typeof(v)))
			return null
	# Vectors, rects, colours, transforms and the packed arrays of them: as
	# text when the text reads back exactly, else as the engine's bytes.
	var text := var_to_str(v)
	if str_to_var(text) == v:
		return {"$v": text}
	return {"$vb": Marshalls.raw_to_base64(var_to_bytes(v))}


## A float as text when the text reads back to the same bits ("~f0.25"),
## else as its 64 bits ("~b<int>").
static func _enc_float(x: float) -> String:
	var text := var_to_str(x)
	if float(str_to_var(text)) == x or is_nan(x):
		return "~f" + text
	var bytes := PackedFloat64Array([x]).to_byte_array()
	return "~b" + str(bytes.decode_s64(0))


static func _dec_float(s: String) -> float:
	if s.begins_with("~b"):
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_s64(0, s.substr(2).to_int())
		return bytes.decode_double(0)
	return float(str_to_var(s.substr(2)))


func _enc_dict(d: Dictionary) -> Variant:
	var plain := not d.is_typed()
	if plain:
		for k in d:
			if typeof(k) != TYPE_STRING:
				plain = false
				break
	if plain:
		var out := {}
		for k in d:
			var key: String = k
			if key.begins_with("$") or key.begins_with("~"):
				key = "~" + key
			out[key] = _enc(d[k])
		return out
	var keys := []
	var values := []
	for k in d:
		keys.append(_enc(k))
		values.append(_enc(d[k]))
	var out := {"$K": keys, "$V": values}
	if d.is_typed():
		out["$t"] = [d.get_typed_key_builtin(), str(d.get_typed_key_class_name()), _script_tag(d.get_typed_key_script()),
				d.get_typed_value_builtin(), str(d.get_typed_value_class_name()), _script_tag(d.get_typed_value_script())]
	return out


# --- Decoding --------------------------------------------------------------------

func decode_graph(data: Dictionary) -> Variant:
	report = {"unknown_props": 0, "missing_props": 0, "mismatched": 0, "converted": 0, "unknown_classes": 0, "objects": 0,
			"notes": PackedStringArray()}
	var entries: Array = data.get("objects", [])
	_decoded.clear()
	_decoded.resize(entries.size())
	# First every object, so that references (cycles too) can be resolved.
	for i in entries.size():
		_decoded[i] = _instantiate(entries[i])
	report.objects = entries.size()
	for i in entries.size():
		var obj: Variant = _decoded[i]
		if obj == null:
			continue
		var e: Dictionary = entries[i]
		var tag := str(e.c)
		if tag.begins_with("@"):
			var props: Dictionary = e.get("p", {})
			for name in NATIVE.get(tag.substr(1), []):
				if props.has(name):
					(obj as Object).set(name, _dec(props[name]))
			continue
		if e.has("s"):
			continue
		_assign(obj, tag, e.get("p", {}))
		var metas: Dictionary = e.get("m", {})
		for k in metas:
			(obj as Object).set_meta(StringName(k), _dec(metas[k]))
	return _dec(data.get("root"))


func _note(what: String) -> void:
	var notes: PackedStringArray = report.notes
	if notes.size() < 40:
		notes.append(what)


func _instantiate(e: Dictionary) -> Variant:
	var tag := str(e.get("c", ""))
	if tag.begins_with("@"):
		var cls := tag.substr(1)
		if not NATIVE.has(cls) or not ClassDB.can_instantiate(cls):
			report.unknown_classes += 1
			_note("unknown engine class " + cls)
			return null
		return ClassDB.instantiate(cls)
	var script := _script_of(tag)
	if script == null:
		report.unknown_classes += 1
		_note("unknown class " + tag)
		return null
	if e.has("s"):
		return script.call(str(e.s))
	return SaveCodec.make(script)


## A new instance of `script` with `new()`, giving each argument its
## `_init` requires a plain empty value of its type (0, "", null...): the
## saved properties are assigned over whatever the constructor did.
static func make(script: GDScript) -> Object:
	var need: Array = []
	for m in script.get_script_method_list():
		if str(m.name) != "_init":
			continue
		var args: Array = m.args
		var required: int = args.size() - (m.default_args as Array).size()
		for i in required:
			need.append(_empty_of(int(args[i].type)))
		break
	return script.callv("new", need)


static func _empty_of(type: int) -> Variant:
	match type:
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_STRING:
			return ""
		TYPE_BOOL:
			return false
		TYPE_ARRAY:
			return []
		TYPE_DICTIONARY:
			return {}
	if type == TYPE_NIL or type == TYPE_OBJECT:
		return null
	return type_convert(null, type)


func _assign(obj: Object, tag: String, props: Dictionary) -> void:
	var declared := {}
	for p in obj.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			declared[str(p.name)] = p
	var skip: Array = SKIP.get(tag, [])
	for name in props:
		if not declared.has(name):
			report.unknown_props += 1
			_note("%s.%s is no longer a property" % [tag, name])
			continue
		var v: Variant = _dec(props[name])
		var p: Dictionary = declared[name]
		var cur: Variant = obj.get(name)
		var fitted: Array = _fit(v, cur, p)
		if fitted.is_empty():
			report.mismatched += 1
			_note("%s.%s: a %s does not fit, the default is kept" % [tag, name, type_string(typeof(v))])
			continue
		obj.set(name, fitted[0])
	if DIFF_FROM_DEFAULT.has(tag):
		return
	for name in declared:
		if not props.has(name) and not skip.has(name) and not (CALLABLE_DEFAULT.get(tag, []) as Array).has(name):
			report.missing_props += 1


## `v` made to fit property `p` (whose value now is `cur`): [value], or []
## when it cannot.
func _fit(v: Variant, cur: Variant, p: Dictionary) -> Array:
	var want := int(p.type)
	if want == TYPE_NIL:
		return [v]
	var got := typeof(v)
	if want == TYPE_OBJECT:
		if v == null:
			return [null]
		if got != TYPE_OBJECT:
			return []
		var cls := str(p.class_name)
		if cls == "" or _is_a(v, cls):
			return [v]
		return []
	if got == want:
		if want == TYPE_ARRAY and cur is Array:
			return _fit_array(v, cur)
		if want == TYPE_DICTIONARY and cur is Dictionary and (cur as Dictionary).is_typed() and not (v as Dictionary).is_typed():
			var t: Dictionary = (cur as Dictionary).duplicate()
			t.clear()
			for k in v:
				t[k] = v[k]
			report.converted += 1
			return [t]
		return [v]
	if (want == TYPE_INT and got == TYPE_FLOAT) or (want == TYPE_FLOAT and got == TYPE_INT):
		report.converted += 1
		return [type_convert(v, want)]
	if (want == TYPE_STRING and got == TYPE_STRING_NAME) or (want == TYPE_STRING_NAME and got == TYPE_STRING):
		return [type_convert(v, want)]
	if want in [TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
			TYPE_PACKED_FLOAT64_ARRAY] and got == TYPE_ARRAY:
		report.converted += 1
		return [type_convert(v, want)]
	return []


func _fit_array(v: Array, cur: Array) -> Array:
	if not cur.is_typed():
		return [v]
	if v.is_typed() and v.get_typed_builtin() == cur.get_typed_builtin() and v.get_typed_class_name() == cur.get_typed_class_name() \
			and v.get_typed_script() == cur.get_typed_script():
		return [v]
	# An untyped (or differently typed) list for a typed property: every
	# element must be of the property's type.
	var t: Array = cur.duplicate()
	t.clear()
	var builtin := cur.get_typed_builtin()
	for x in v:
		if builtin == TYPE_OBJECT:
			if x != null and not (x is Object and (cur.get_typed_script() == null or _script_is((x as Object).get_script(), cur.get_typed_script()))):
				return []
		elif typeof(x) != builtin:
			if (builtin == TYPE_INT or builtin == TYPE_FLOAT) and (typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT):
				x = type_convert(x, builtin)
			else:
				return []
		t.append(x)
	report.converted += 1
	return [t]


func _dec(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL:
			return v
		TYPE_FLOAT:
			return int(v)  # every float is tagged: a bare number is an int
		TYPE_INT:
			return v
		TYPE_STRING:
			var s: String = v
			if not s.begins_with("~"):
				return s
			match s.substr(1, 1):
				"~":
					return s.substr(1)
				"i":
					return s.substr(2).to_int()
				"f", "b":
					return _dec_float(s)
				"n":
					return StringName(s.substr(2))
			return s
		TYPE_ARRAY:
			var out := []
			out.resize((v as Array).size())
			for i in (v as Array).size():
				out[i] = _dec(v[i])
			return out
		TYPE_DICTIONARY:
			return _dec_dict(v)
	return v


func _dec_dict(d: Dictionary) -> Variant:
	if d.has("$r"):
		var id := int(d["$r"])
		return _decoded[id] if id >= 0 and id < _decoded.size() else null
	if d.has("$a"):
		var t: Array = d["$a"]
		var script: Script = _script_of(str(t[2])) if str(t[2]) != "" else null
		if d.has("xy"):
			var cells: Array[Vector2i] = []
			var xy: Array = d.xy
			for i in range(0, xy.size() - 1, 2):
				cells.append(Vector2i(int(xy[i]), int(xy[i + 1])))
			return cells
		var items: Array = _dec(d.v)
		var cls := StringName(str(t[1]))
		if int(t[0]) == TYPE_OBJECT and script == null and str(t[2]) != "":
			report.unknown_classes += 1
			return items  # the element class is gone: an untyped list
		if int(t[0]) == TYPE_OBJECT and script != null:
			cls = script.get_instance_base_type()
		var out := Array([], int(t[0]), cls, script)
		for x in items:
			if int(t[0]) == TYPE_OBJECT and x != null and script != null and not _script_is((x as Object).get_script(), script):
				continue
			out.append(x)
		return out
	if d.has("$K"):
		var out := {}
		if d.has("$t"):
			var t: Array = d["$t"]
			var ks: Script = _script_of(str(t[2])) if str(t[2]) != "" else null
			var vs: Script = _script_of(str(t[5])) if str(t[5]) != "" else null
			out = Dictionary({}, int(t[0]), ks.get_instance_base_type() if ks != null else StringName(str(t[1])), ks,
					int(t[3]), vs.get_instance_base_type() if vs != null else StringName(str(t[4])), vs)
		var keys: Array = d["$K"]
		var values: Array = d["$V"]
		for i in keys.size():
			out[_dec(keys[i])] = _dec(values[i])
		return out
	if d.has("$ps"):
		var out := PackedStringArray()
		for s in d["$ps"]:
			out.append(str(_dec(s)))
		return out
	if d.has("$pb"):
		return Marshalls.base64_to_raw(str(d["$pb"]))
	if d.has("$pi") or d.has("$pl"):
		var list: Array = d.get("$pi", d.get("$pl"))
		var ints := []
		for n in list:
			ints.append(_dec(n))
		return PackedInt32Array(ints) if d.has("$pi") else PackedInt64Array(ints)
	if d.has("$pf") or d.has("$pd"):
		var list: Array = d.get("$pf", d.get("$pd"))
		var xs := []
		for s in list:
			xs.append(_dec_float(str(s)))
		return PackedFloat32Array(xs) if d.has("$pf") else PackedFloat64Array(xs)
	if d.has("$v"):
		return str_to_var(str(d["$v"]))
	if d.has("$vb"):
		return bytes_to_var(Marshalls.base64_to_raw(str(d["$vb"])))
	if d.has("$fn"):
		var f: Variant = d["$fn"]
		if f == null:
			return Callable()
		var script := _script_of(str(f[0]))
		if script == null or not script.has_method(str(f[1])):
			report.unknown_classes += 1
			return Callable()
		return Callable(script, StringName(str(f[1])))
	var out := {}
	for k in d:
		var key: String = k
		if key.begins_with("~"):
			key = key.substr(1)
		out[key] = _dec(d[k])
	return out


# --- Classes by name ----------------------------------------------------------------

## The tag a class is saved under: its class_name; an inner class as
## "Outer.Inner"; an engine class as "@Name"; a script with no name by its
## path. "" when it cannot be named.
static func _tag_of(obj: Object) -> String:
	var s: Script = obj.get_script()
	if s == null:
		return ("@" + obj.get_class()) if NATIVE.has(obj.get_class()) else ""
	return _script_tag(s)


static func _script_tag(s: Script) -> String:
	if s == null:
		return ""
	if _tags.has(s):
		return _tags[s]
	var tag := str(s.get_global_name())
	if tag == "" and s.resource_path != "" and not s.resource_path.contains("::"):
		tag = s.resource_path
	if tag == "":
		tag = _inner_tag(s)
	_tags[s] = tag
	if tag != "":
		_scripts[tag] = s
	return tag


## An inner class's tag, found among the constants of the global classes.
static func _inner_tag(s: Script) -> String:
	for g in ProjectSettings.get_global_class_list():
		var path := str(g.path)
		if not path.begins_with("res://sim/"):
			continue
		var outer: Script = load(path)
		if outer == null:
			continue
		var consts: Dictionary = outer.get_script_constant_map()
		for k in consts:
			if typeof(consts[k]) == TYPE_OBJECT and consts[k] == s:
				return "%s.%s" % [g["class"], k]
	return ""


static func _script_of(tag: String) -> Script:
	if tag == "":
		return null
	if _scripts.has(tag):
		return _scripts[tag]
	var s: Script = null
	if tag.begins_with("res://"):
		s = load(tag) if ResourceLoader.exists(tag) else null
	else:
		var parts := tag.split(".")
		var path := _global_path(parts[0])
		if path != "":
			s = load(path)
			for i in range(1, parts.size()):
				if s == null:
					break
				var c: Variant = s.get_script_constant_map().get(parts[i])
				s = c if typeof(c) == TYPE_OBJECT and c is Script else null
	if s != null:
		_scripts[tag] = s
		_tags[s] = tag
	return s


static func _global_path(cls: String) -> String:
	if _global_paths.is_empty():
		for g in ProjectSettings.get_global_class_list():
			_global_paths[str(g["class"])] = str(g.path)
	return str(_global_paths.get(cls, ""))


static func _default_of(tag: String) -> Object:
	if not _defaults.has(tag):
		_defaults[tag] = make(_script_of(tag))
	return _defaults[tag]


static func _script_is(s: Script, base: Script) -> bool:
	while s != null:
		if s == base:
			return true
		s = s.get_base_script()
	return false


## Whether `obj` is of class `cls` (a class_name, an inner class's tag or
## an engine class).
static func _is_a(obj: Object, cls: String) -> bool:
	if ClassDB.class_exists(cls):
		return obj.is_class(cls)
	var s := _script_of(cls)
	if s == null:
		return true  # a class the codec cannot find: let the engine judge
	return _script_is(obj.get_script(), s)
