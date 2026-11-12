class_name Audio
extends Node
## The game's sound (docs/design/notes/shell.md): a quiet bed under each
## screen (the sea and the wind on the map, the hall's fire on the night
## and in winter, the drum under a fight), stingers on what happens (a
## knock on every button, parchment for a page, silver, the horn, shields
## and blades, a man down, a rout, the lyre after a fight), and a little
## music on the title and in winter. Nothing is loaded: AudioSynth renders
## every sound once, the first time it is wanted or a frame at a time in
## the background, into AudioStreamWAVs played on a few pooled players.
##
## The view calls the static functions; one Audio node puts itself at the
## root of the tree the first time one is called (not in the headless
## runs). It never throws: with no audio device the players are silent.
## A browser will not play a sound before the player has touched the page,
## so nothing plays until the first press or key.
##
##   Audio.play("coin")
##   Audio.scene("map_sea")            # the bed for where the band is
##   Audio.duck(true)                  # a modal is open: the bed steps back
##   Audio.shout(CombatTypes.Shout.PUSH)
##   Audio.blows(lines)                # a round's exchanges, as a few clashes

## Players for the stingers, round-robin; and slots for the beds. Twelve in
## all: a phone's browser mixes every one of them.
const SHOTS := 8
const SLOTS := 4
## Seconds a bed takes to fade in or out.
const FADE := 1.6
## How far a bed steps back under a modal (linear gain).
const DUCKED := 0.45
## The beds for each scene: layer -> gain. "drone" is the music's bed.
const SCENES := {
	"": {},
	"title": {"hall": 0.45, "drone": 1.0},
	"opening": {"hall": 1.0},
	"map_sea": {"sea": 1.0, "wind": 0.3},
	"map_shore": {"sea": 0.6, "wind": 0.75},
	"map_land": {"wind": 1.0},
	"winter": {"hall": 0.9, "drone": 0.8},
	"battle": {"battle": 1.0},
	"battle_night": {"battle": 0.8, "hall": 0.7},
}
## Which shouts sound which horn: rising for the ones that go forward,
## falling for Fall Back, two short for the ones that hold together, three
## for the taunt.
const HORNS := {
	CombatTypes.Shout.SHIELD_WALL: "horn_two", CombatTypes.Shout.HOLD: "horn_two", CombatTypes.Shout.TO_ME: "horn_two",
	CombatTypes.Shout.PUSH: "horn_rise", CombatTypes.Shout.BREAK_THEM: "horn_rise", CombatTypes.Shout.SVINFYLKING: "horn_rise",
	CombatTypes.Shout.FALL_BACK: "horn_fall", CombatTypes.Shout.TAUNT: "horn_three",
}
## The order the sounds are rendered in the background: what the first
## screens want first.
const WARM := ["press", "page", "hall", "drone", "phrase0", "phrase1", "tick", "wind", "sea", "arrive", "coin", "horn",
	"phrase2", "phrase3", "phrase4", "phrase5", "battle", "battle_close", "horn_two", "horn_rise", "horn_fall",
	"horn_three", "clash", "blade", "down", "rout", "victory", "defeat", "escape", "bird"]

## Off for runs that want no node made (a tool may set it).
static var enabled := true
## The player's settings (Settings.apply sets them).
static var master := 0.8
static var sound_on := true
static var music_on := true
static var _inst: Audio = null

var _streams := {}
var _warm := 0
var _shots: Array[AudioStreamPlayer] = []
var _shot_gain: PackedFloat32Array = PackedFloat32Array()
var _shot_music: Array[bool] = []
var _next := 0
var _slots: Array[AudioStreamPlayer] = []
var _slot_layer: PackedStringArray = PackedStringArray()
## layer -> [gain now, gain wanted]
var _layers := {}
var _scene := ""
var _close := false
var _ducked := false
var _unlocked := false
var _later: Array = []  # [seconds left, name, dB, pitch]
var _clock := 0.0
var _music_wait := 2.0
var _last_phrase := -1
var _bird_wait := 12.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Audio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 866
	for i in SHOTS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_shots.append(p)
		_shot_music.append(false)
	_shot_gain.resize(SHOTS)
	_shot_gain.fill(0.0)
	for i in SLOTS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_slots.append(p)
		_slot_layer.append("")


func _ready() -> void:
	# Every button knocks when pressed: those already made, and every one
	# made from now on.
	get_tree().node_added.connect(_on_node_added)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		_on_node_added(n)
		stack.append_array(n.get_children())


# --- The calls the view makes --------------------------------------------------

## The one Audio node, made and put in the tree the first time; null when
## there is to be no sound (headless, or `enabled` off).
static func get_audio() -> Audio:
	if not enabled:
		return null
	if _inst != null and is_instance_valid(_inst):
		return _inst
	if DisplayServer.get_name() == "headless":
		return null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = Audio.new()
	tree.root.add_child.call_deferred(_inst)
	return _inst


## A stinger: `db` louder or softer than it was made, at `pitch`.
static func play(sound: String, db := 0.0, pitch := 1.0) -> void:
	var a := get_audio()
	if a != null:
		a._play(sound, db, pitch, false)


## A stinger `seconds` from now.
static func later(seconds: float, sound: String, db := 0.0, pitch := 1.0) -> void:
	var a := get_audio()
	if a != null:
		a._later.append([seconds, sound, db, pitch])


## The bed for a screen or a place: a key of SCENES.
static func scene(which: String) -> void:
	var a := get_audio()
	if a != null and SCENES.has(which) and which != a._scene:
		a._scene = which
		a._retarget()


## The lines have met (the battle's drum quickens) or drawn apart.
static func close(on: bool) -> void:
	var a := get_audio()
	if a != null and on != a._close:
		a._close = on
		a._retarget()


## Something to read is open over the screen: the bed steps back.
static func duck(on: bool) -> void:
	var a := get_audio()
	if a != null and on != a._ducked:
		a._ducked = on
		a._retarget()


## The horn for a shout given in battle.
static func shout(s: int) -> void:
	if HORNS.has(s):
		play(str(HORNS[s]), -2.0)


## A round's blows, as the beat of the fight on the screen begins: a few
## layered clashes and bites of iron, never one for every blow.
static func blows(lines: PackedStringArray) -> void:
	var n := blow_counts(lines)
	var at := 0.0
	var r := 0
	for i in mini(3, ceili(n.x / 3.0)):
		later(at, "clash", -3.0 - 2.0 * i, 0.92 + 0.07 * ((i * 5 + r) % 3))
		at += 0.11 + 0.05 * (i % 2)
	at = 0.06
	for i in mini(3, ceili(n.y / 2.0)):
		later(at, "blade", -4.0 - 2.0 * i, 0.95 + 0.06 * (i % 3))
		at += 0.17


## [shield clashes, blows that bit, men down] in a round's lines: an
## exchange that harmed nobody is a clash, one that wounded a bite.
static func blow_counts(lines: PackedStringArray) -> Vector3i:
	var clash := 0
	var bite := 0
	var down := 0
	for line in lines:
		if line.contains(" lock, neither gives ground"):
			clash += 1
		elif line.contains(" beats "):
			if line.contains("DOWN"):
				down += 1
				bite += 1
			elif line.contains("bruised") or line.contains("wounded") or line.contains("grievous"):
				bite += 1
			else:
				clash += 1
	return Vector3i(clash, bite, down)


## The lyre's tail after a fight, by its outcome (BattleResult.Outcome).
static func result(outcome: int) -> void:
	match outcome:
		BattleResult.Outcome.ROUTED_THEM, BattleResult.Outcome.DROVE_THEM_OFF, BattleResult.Outcome.WON_THE_FIELD:
			play("victory")
		BattleResult.Outcome.ESCAPED, BattleResult.Outcome.WITHDREW, BattleResult.Outcome.BOTH_DREW_OFF:
			play("escape")
		_:
			play("defeat")


## The settings changed: every player to its new level.
static func refresh() -> void:
	var a := get_audio()
	if a != null:
		a._retarget()
		for i in SHOTS:
			a._shots[i].volume_db = a._db(a._shot_gain[i], a._shot_music[i])


# --- Inside ----------------------------------------------------------------------

func _stream(sound: String) -> AudioStreamWAV:
	if _streams.has(sound):
		return _streams[sound]
	if not AudioSynth.DEFS.has(sound):
		return null
	var s := AudioSynth.stream(AudioSynth.render(sound), AudioSynth.rate_of(sound), AudioSynth.is_loop(sound))
	_streams[sound] = s
	return s


## The dB to play at, for a gain on a stinger or a bed (music or not).
func _db(gain: float, music: bool) -> float:
	var on := music_on if music else sound_on
	var g := gain * master * (1.0 if on else 0.0)
	return linear_to_db(maxf(g, 0.00001))


func _play(sound: String, db: float, pitch: float, music: bool) -> void:
	if not _unlocked or not is_inside_tree():
		return
	if (music and not music_on) or (not music and not sound_on) or master <= 0.0:
		return
	var s := _stream(sound)
	if s == null:
		return
	# A free player, or the one that has played longest.
	var p: AudioStreamPlayer = null
	for i in SHOTS:
		var k := (_next + i) % SHOTS
		if not _shots[k].playing:
			p = _shots[k]
			_next = (k + 1) % SHOTS
			break
	if p == null:
		p = _shots[_next]
		_next = (_next + 1) % SHOTS
	var idx := _shots.find(p)
	var gain := db_to_linear(db) * ((DUCKED + 1.0) / 2.0 if (music and _ducked) else 1.0)
	_shot_gain[idx] = gain
	_shot_music[idx] = music
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = _db(gain, music)
	p.play()


## The layers wanted now, from the scene, the fight's closeness and the duck.
func _retarget() -> void:
	var want: Dictionary = SCENES.get(_scene, {}).duplicate()
	if want.has("battle") and _close:
		want["battle_close"] = want["battle"]
		want["battle"] = float(want["battle"]) * 0.35
	for layer in _layers:
		(_layers[layer] as Array)[1] = 0.0
	for layer in want:
		if not _layers.has(layer):
			_layers[layer] = [0.0, 0.0]
		var g := float(want[layer])
		if _ducked:
			g *= DUCKED
		(_layers[layer] as Array)[1] = g


func _process(delta: float) -> void:
	# Render one sound a frame until all are ready: no long stall anywhere.
	if _warm < WARM.size():
		_stream(WARM[_warm])
		_warm += 1
		if _warm == WARM.size():
			AudioSynth._strings.clear()  # every phrase is mixed: the strings are not wanted
	if not _unlocked:
		return
	_clock += delta
	_beds(delta)
	# Stingers waiting their moment.
	var i := 0
	while i < _later.size():
		var w: Array = _later[i]
		w[0] = float(w[0]) - delta
		if float(w[0]) <= 0.0:
			_play(str(w[1]), float(w[2]), float(w[3]), false)
			_later.remove_at(i)
		else:
			i += 1
	_music(delta)
	if _scene == "map_land" and sound_on:
		_bird_wait -= delta
		if _bird_wait <= 0.0:
			_bird_wait = _rng.randf_range(9.0, 26.0)
			_play("bird", _rng.randf_range(-6.0, 0.0), _rng.randf_range(0.88, 1.15), false)


## Fades every bed toward what is wanted, gives each a slot while it
## sounds, and sways the sea and the wind slowly.
func _beds(delta: float) -> void:
	var step := delta / FADE
	for layer in _layers:
		var l: Array = _layers[layer]
		var now := float(l[0])
		var want := float(l[1])
		if now == want and now == 0.0:
			continue
		now = move_toward(now, want, step)
		l[0] = now
		var slot := _slot_layer.find(layer)
		if now <= 0.0:
			if slot >= 0:
				_slots[slot].stop()
				_slot_layer[slot] = ""
			continue
		if slot < 0:
			slot = _take_slot(layer)
			if slot < 0:
				continue
		var sway := 1.0
		if layer == "sea":
			sway = 1.0 + 0.3 * sin(TAU * _clock / 23.0)
		elif layer == "wind":
			sway = 1.0 + 0.35 * sin(TAU * _clock / 17.0 + 1.0)
		_slots[slot].volume_db = _db(now * sway, layer == "drone")


func _take_slot(layer: String) -> int:
	var slot := _slot_layer.find("")
	if slot < 0:
		# Every slot sounds: take the quietest.
		var least := INF
		for i in SLOTS:
			var g := float((_layers[_slot_layer[i]] as Array)[0])
			if g < least:
				least = g
				slot = i
		_slots[slot].stop()
	var s := _stream(layer)
	if s == null:
		return -1
	_slot_layer[slot] = layer
	_slots[slot].stream = s
	_slots[slot].volume_db = -80.0
	_slots[slot].play(_rng.randf_range(0.0, s.get_length() * 0.9))  # not every bed from its start
	return slot


## The music: while the drone sounds, a phrase on the lyre now and then,
## chosen by a seeded sequence and never the same twice running, with a
## longer rest now and then.
func _music(delta: float) -> void:
	if not _layers.has("drone") or float((_layers["drone"] as Array)[1]) <= 0.0 or not music_on:
		return
	_music_wait -= delta
	if _music_wait > 0.0:
		return
	var k := _rng.randi_range(0, AudioSynth.PHRASES.size() - 2)
	if k >= _last_phrase:
		k += 1
	k = k % AudioSynth.PHRASES.size()
	_last_phrase = k
	var phrase: Array = AudioSynth.PHRASES[k]
	_play("phrase%d" % k, 0.0, 1.0, true)
	_music_wait = float(phrase[-1][0]) + _rng.randf_range(3.0, 7.0) + (8.0 if _rng.randf() < 0.2 else 0.0)


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	var touched: bool = (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed()
	if touched:
		_unlocked = true
		_retarget()


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_knock):
		(n as BaseButton).pressed.connect(_knock)


func _knock() -> void:
	_play("press", 0.0, _rng.randf_range(0.94, 1.06), false)
