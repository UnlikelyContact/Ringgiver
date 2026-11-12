class_name AudioSynth
extends RefCounted
## Every sound in the game, made in code (docs/design/notes/shell.md): there
## are no sound files. Each is rendered once into a short buffer of samples
## (floats, -1..1), mono, at RATE (the stingers and the lyre) or LOW_RATE
## (the ambience loops, whose sound lies low), and turned into an
## AudioStreamWAV by `stream`. Rendering is deterministic: the same name
## gives the same samples on every machine (the noise comes from a seeded
## RandomNumberGenerator), so a test can pin it.
##
## Loops are made seamless one of two ways: anything built of events (a
## drum beat, a crackle) is added round the loop's end and back to its
## start (`_wrap` true), and filtered noise is rendered a little long and
## its tail cross-faded into its head (`_xfade`). Periodic tones are given
## frequencies that fit a whole number of cycles in the loop.
##
## Levels are set here, by name, not by the caller: the ambience to an RMS
## (about -30 dBFS), the stingers to a peak (about -9 dBFS), the music
## under both. tools/audio_check.gd measures what comes out.

const RATE := 22050
const LOW_RATE := 11025
## Envelopes that move slowly are worked out once every this many samples,
## not every sample: the sums are the slow part of rendering.
const CONTROL := 32

## name -> [rate, loop, level dB, "rms" or "peak", group]. The group is
## what the check compares a sound's loudness against.
const DEFS := {
	# The ambience: quiet, seamless loops.
	"sea": [LOW_RATE, true, -30.0, "rms", "amb"],
	"wind": [LOW_RATE, true, -31.0, "rms", "amb"],
	"hall": [LOW_RATE, true, -31.0, "rms", "amb"],
	"battle": [LOW_RATE, true, -30.0, "rms", "amb"],
	"battle_close": [LOW_RATE, true, -28.0, "rms", "amb"],
	# The interface.
	"press": [RATE, false, -16.0, "peak", "ui"],
	"page": [RATE, false, -15.0, "peak", "ui"],
	"tick": [RATE, false, -28.0, "peak", "ui"],
	"arrive": [LOW_RATE, false, -13.0, "peak", "sfx"],
	"coin": [RATE, false, -12.0, "peak", "sfx"],
	"bird": [RATE, false, -24.0, "peak", "ui"],
	# The horn: a fight offered, and one shape for each family of shouts.
	"horn": [LOW_RATE, false, -9.0, "peak", "sfx"],
	"horn_rise": [LOW_RATE, false, -9.0, "peak", "sfx"],
	"horn_fall": [LOW_RATE, false, -9.0, "peak", "sfx"],
	"horn_two": [LOW_RATE, false, -9.0, "peak", "sfx"],
	"horn_three": [LOW_RATE, false, -10.0, "peak", "sfx"],
	# The fight.
	"clash": [RATE, false, -9.0, "peak", "sfx"],
	"blade": [RATE, false, -10.0, "peak", "sfx"],
	"down": [RATE, false, -9.0, "peak", "sfx"],
	"rout": [LOW_RATE, false, -10.0, "peak", "sfx"],
	# The tails after a fight, on the lyre.
	"victory": [LOW_RATE, false, -9.0, "peak", "sfx"],
	"defeat": [LOW_RATE, false, -10.0, "peak", "sfx"],
	"escape": [LOW_RATE, false, -10.0, "peak", "sfx"],
	# The music: a bowed drone, and phrases on the lyre over it.
	"drone": [LOW_RATE, true, -34.0, "rms", "music"],
	"phrase0": [LOW_RATE, false, -17.0, "peak", "music"],
	"phrase1": [LOW_RATE, false, -17.0, "peak", "music"],
	"phrase2": [LOW_RATE, false, -17.0, "peak", "music"],
	"phrase3": [LOW_RATE, false, -17.0, "peak", "music"],
	"phrase4": [LOW_RATE, false, -17.0, "peak", "music"],
	"phrase5": [LOW_RATE, false, -17.0, "peak", "music"],
}

## The lyre's scale: D dorian's pentatonic (D E G A C) from D3 to D5, Hz.
const D3 := 146.83
const E3 := 164.81
const G3 := 196.00
const A3 := 220.00
const C4 := 261.63
const D4 := 293.66
const E4 := 329.63
const G4 := 392.00
const A4 := 440.00
const C5 := 523.25
const D5 := 587.33

## The music's phrases: [seconds from the start, note Hz, loudness 0..1].
## Slow, mostly stepwise, every one coming home to D or resting on A.
const PHRASES := [
	[[0.0, A4, 0.9], [0.55, G4, 0.7], [1.1, E4, 0.75], [1.9, D4, 0.9]],
	[[0.0, D4, 0.8], [0.6, E4, 0.7], [1.2, G4, 0.75], [1.8, A4, 0.9], [2.9, A3, 0.5]],
	[[0.0, C5, 0.7], [0.45, A4, 0.8], [0.9, G4, 0.6], [1.6, A4, 0.85]],
	[[0.0, D3, 0.6], [0.0, A3, 0.5], [0.7, D4, 0.8], [1.5, C4, 0.6], [2.2, D4, 0.75]],
	[[0.0, G4, 0.75], [0.5, A4, 0.8], [1.0, C5, 0.7], [1.6, A4, 0.75], [2.4, G4, 0.6], [3.0, D4, 0.8]],
	[[0.0, E4, 0.7], [0.8, D4, 0.8], [1.6, A3, 0.7], [2.6, D3, 0.6]],
]

## The tails after a fight: [seconds, Hz, loudness].
const TAILS := {
	"victory": [[0.0, D3, 0.6], [0.0, D4, 0.9], [0.26, A4, 0.85], [0.52, D5, 1.0], [0.52, A3, 0.5]],
	"defeat": [[0.0, A3, 0.9], [0.5, G3, 0.8], [1.0, E3, 0.85], [1.75, D3, 1.0]],
	"escape": [[0.0, D4, 0.8], [0.3, E4, 0.75], [0.6, A4, 0.9], [1.25, G4, 0.6]],
}


static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in DEFS:
		out.append(str(k))
	return out


static func is_loop(name: String) -> bool:
	return bool(DEFS[name][1])


static func rate_of(name: String) -> int:
	return int(DEFS[name][0])


## The samples of `name`, at its level.
static func render(name: String) -> PackedFloat32Array:
	var d: Array = DEFS[name]
	var rate: int = d[0]
	var buf: PackedFloat32Array
	match name:
		"sea":
			buf = _sea(rate)
		"wind":
			buf = _wind(rate)
		"hall":
			buf = _hall(rate)
		"battle":
			buf = _drums(rate, 75.0, 8, false)
		"battle_close":
			buf = _drums(rate, 104.0, 8, true)
		"press":
			buf = _knock(rate)
		"page":
			buf = _page(rate)
		"tick":
			buf = _tick(rate)
		"arrive":
			buf = _notes(rate, [[0.0, D4, 0.8], [0.14, A4, 0.9]], 1.7)
		"coin":
			buf = _coin(rate)
		"bird":
			buf = _bird(rate)
		"horn":
			buf = _horn(rate, [[0.0, 1.35, 1.0, 1.0]], 1.7)
		"horn_rise":
			buf = _horn(rate, [[0.0, 0.95, 1.0, 1.5]], 1.25)
		"horn_fall":
			buf = _horn(rate, [[0.0, 0.95, 1.5, 1.0]], 1.25)
		"horn_two":
			buf = _horn(rate, [[0.0, 0.26, 1.0, 1.0], [0.4, 0.3, 1.0, 1.0]], 0.95)
		"horn_three":
			buf = _horn(rate, [[0.0, 0.17, 1.0, 1.0], [0.25, 0.17, 1.12, 1.12], [0.5, 0.24, 1.0, 1.0]], 0.95)
		"clash":
			buf = _clash(rate)
		"blade":
			buf = _blade(rate)
		"down":
			buf = _down(rate)
		"rout":
			buf = _rout(rate)
		"victory", "defeat", "escape":
			buf = _notes(rate, TAILS[name], 3.4 if name == "defeat" else 2.9)
		"drone":
			buf = _drone(rate)
		_:
			if name.begins_with("phrase"):
				var i := int(name.trim_prefix("phrase"))
				buf = _notes(rate, PHRASES[i], float(PHRASES[i][-1][0]) + 2.6)
			else:
				push_warning("AudioSynth: no sound named %s" % name)
				return PackedFloat32Array()
	_dc_block(buf, rate, d[1])
	if str(d[3]) == "rms":
		_scale(buf, db_to_linear(float(d[2])) / maxf(1e-9, rms(buf)))
	else:
		_scale(buf, db_to_linear(float(d[2])) / maxf(1e-9, peak(buf)))
	return buf


## An AudioStreamWAV of `samples` (16-bit, mono), looping when `loop`.
static func stream(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


# --- Measures (the check and the tests read these) --------------------------

static func peak(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for v in buf:
		p = maxf(p, absf(v))
	return p


static func rms(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var s := 0.0
	for v in buf:
		s += v * v
	return sqrt(s / buf.size())


static func dc(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var s := 0.0
	for v in buf:
		s += v
	return s / buf.size()


## How far the loop's last sample is from where its first one would carry
## on, against the signal's own typical step from one sample to the next:
## about 1 or less is seamless, much more is a click.
static func seam(buf: PackedFloat32Array) -> float:
	var n := buf.size()
	if n < 3:
		return 0.0
	var steps := 0.0
	for i in range(1, n):
		steps += absf(buf[i] - buf[i - 1])
	var typical := steps / (n - 1)
	return absf(buf[0] - buf[n - 1]) / maxf(1e-9, typical)


# --- Pieces -----------------------------------------------------------------

static func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	b.fill(0.0)
	return b


static func _rng(seed_in: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_in
	return r


static func _scale(buf: PackedFloat32Array, k: float) -> void:
	for i in buf.size():
		buf[i] *= k


## Takes the DC out (a 20 Hz high-pass); a one-shot also fades its last few
## milliseconds to silence so it never ends on a click.
static func _dc_block(buf: PackedFloat32Array, rate: int, loop: bool) -> void:
	var r := 1.0 - TAU * 20.0 / rate
	var x1 := 0.0
	var y1 := 0.0
	if loop:
		# Run it round once first so the loop's start has settled.
		for i in range(buf.size() - mini(buf.size(), rate), buf.size()):
			var y0 := buf[i] - x1 + r * y1
			x1 = buf[i]
			y1 = y0
	for i in buf.size():
		var y := buf[i] - x1 + r * y1
		x1 = buf[i]
		y1 = y
		buf[i] = y
	if not loop:
		var f := mini(buf.size(), int(0.006 * rate))
		for i in f:
			buf[buf.size() - 1 - i] *= float(i) / f


## Renders `n + fade` samples of noise into `n`: the tail fades into the
## head, so the end runs straight on into the start.
static func _xfade(long: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var f := long.size() - n
	var out := long.slice(0, n)
	for i in f:
		var t := float(i) / f
		out[i] = long[i] * t + long[n + i] * (1.0 - t)
	return out


## Adds a decaying sine at sample `at`: `freq` Hz gliding toward `freq_to`
## over its life, `amp` falling by e every `decay` seconds. Round the end
## to the start when `wrap`.
static func _ping(buf: PackedFloat32Array, rate: int, at: int, freq: float, amp: float, decay: float, freq_to := -1.0, wrap := false) -> void:
	var n := buf.size()
	var length := mini(int(decay * 7.0 * rate), n)
	var phase := 0.0
	var f_end := freq if freq_to <= 0.0 else freq_to
	for i in length:
		var t := float(i) / rate
		var f := f_end + (freq - f_end) * exp(-t / maxf(0.001, decay * 0.5))
		phase += f / rate
		var v := amp * exp(-t / decay) * sin(TAU * phase)
		var j := at + i
		if j >= n:
			if not wrap:
				return
			j -= n
		buf[j] += v


## Adds a burst of filtered noise at `at`: `amp` falling by e every
## `decay` seconds, low-passed at `lp` Hz (0: not), high-passed at `hp`.
static func _burst(buf: PackedFloat32Array, rate: int, rng: RandomNumberGenerator, at: int, amp: float, decay: float, lp: float, hp := 0.0, wrap := false) -> void:
	var n := buf.size()
	var length := mini(int(decay * 6.0 * rate), n)
	var a := 1.0 - exp(-TAU * lp / rate) if lp > 0.0 else 1.0
	var ah := 1.0 - exp(-TAU * hp / rate) if hp > 0.0 else 0.0
	var y := 0.0
	var low := 0.0
	for i in length:
		var x := rng.randf() * 2.0 - 1.0
		y += a * (x - y)
		low += ah * (y - low)
		var v := (y - low) * amp * exp(-float(i) / rate / decay)
		var j := at + i
		if j >= n:
			if not wrap:
				return
			j -= n
		buf[j] += v


## A plucked string (Karplus-Strong): a burst of noise in a delay line one
## period long, averaged and damped round and round; a first-order allpass
## tunes it between whole samples. `bright` 0..1 is how hard and near the
## bridge it is plucked; `t60` the seconds it takes to die away.
static func _pluck(rate: int, freq: float, seconds: float, rng: RandomNumberGenerator, bright := 0.45, t60 := 2.6) -> PackedFloat32Array:
	var out := _buf(seconds, rate)
	var period := float(rate) / freq
	# The loop's delay: the line (p), less half a sample for the average of
	# a sample and the one written after it, plus the allpass's fraction.
	var p := int(floor(period + 0.5 - 0.1))
	var frac := period + 0.5 - p
	var c := (1.0 - frac) / (1.0 + frac)
	var line := PackedFloat32Array()
	line.resize(p)
	# The excitation: noise, softened (a fingertip, not a plectrum), with a
	# little of it cancelled half a period on (plucked off the middle).
	var soft := 1.0 - exp(-TAU * (300.0 + 2600.0 * bright) / rate)
	var y := 0.0
	for i in p:
		y += soft * ((rng.randf() * 2.0 - 1.0) - y)
		line[i] = y
	var half := int(p / 5.0)
	for i in range(p - 1, half - 1, -1):
		line[i] -= 0.5 * line[i - half]
	# No DC in the line: the loop keeps whatever it is given nearly forever.
	var mean := 0.0
	for i in p:
		mean += line[i]
	mean /= p
	for i in p:
		line[i] -= mean
	var gain := pow(10.0, -3.0 / (t60 * freq))
	var idx := 0
	var ax := 0.0
	var ay := 0.0
	for i in out.size():
		var cur := line[idx]
		var nxt := line[idx + 1 if idx + 1 < p else 0]
		var avg := 0.5 * (cur + nxt) * gain
		var ap := c * avg + ax - c * ay
		ax = avg
		ay = ap
		line[idx] = ap
		out[i] = cur
		idx = idx + 1 if idx + 1 < p else 0
	# A soft body: a gentle low-pass takes the wire off it.
	var lp := 1.0 - exp(-TAU * 3200.0 / rate)
	var z := 0.0
	for i in out.size():
		z += lp * (out[i] - z)
		out[i] = z
	return out


## Notes on the lyre, [seconds, Hz, loudness] each, mixed into `seconds`.
## Each pitch is plucked once (`_string`) and the same string sounds
## wherever the note comes again.
static func _notes(rate: int, notes: Array, seconds: float) -> PackedFloat32Array:
	var out := _buf(seconds, rate)
	for nt in notes:
		var at := int(float(nt[0]) * rate)
		var s := _string(rate, float(nt[1]))
		var g := float(nt[2])
		var m := mini(s.size(), out.size() - at)
		for i in m:
			out[at + i] += s[i] * g
	return out


## The lyre's string at `freq`, plucked once and kept: a low string rings
## longer and is plucked softer. Its noise is seeded by its pitch, so it is
## the same however the sounds are asked for.
static var _strings := {}


static func _string(rate: int, freq: float) -> PackedFloat32Array:
	var key := "%d:%d" % [rate, int(freq * 100.0)]
	if _strings.has(key):
		return _strings[key]
	var low := freq < 200.0
	var t60 := 3.4 if low else 2.4
	var s := _pluck(rate, freq, t60 * 1.05, _rng(int(freq * 100.0)), 0.3 if low else 0.45, t60)
	var f := mini(s.size(), int(0.05 * rate))
	for i in f:
		s[s.size() - 1 - i] *= float(i) / f
	_strings[key] = s
	return s


## A sawtooth with its corners smoothed (PolyBLEP), at phase `t` 0..1
## stepping `dt` a sample: cheap, and clean enough not to alias badly.
static func _saw(t: float, dt: float) -> float:
	var v := 2.0 * t - 1.0
	if t < dt:
		var x := t / dt
		v -= x + x - x * x - 1.0
	elif t > 1.0 - dt:
		var x := (t - 1.0) / dt
		v -= x * x + x + x + 1.0
	return v


# --- The ambience -----------------------------------------------------------

## The sea: a low roll that swells and draws back twice a loop, and the
## hiss of the break riding on the top of each swell. The slower rise and
## fall over many loops is the player's (Audio sways its volume).
static func _sea(rate: int) -> PackedFloat32Array:
	var n := 8 * rate
	var long := _buf(8.6, rate)
	var rng := _rng(101)
	var a1 := 1.0 - exp(-TAU * 180.0 / rate)
	var y1 := 0.0
	var y2 := 0.0
	var f := 2.0 * sin(PI * 1200.0 / rate)
	var low := 0.0
	var band := 0.0
	var swell := 0.0
	for i in long.size():
		if i % CONTROL == 0:
			# Two swells a loop, the second a little smaller; each rises over
			# a third of its span and falls slowly, to nothing, so the next
			# begins where it ended. Reckoned from the loop's start, so the
			# rendered tail repeats the head.
			var t := float(i % n) / n
			var ph := fmod(t * 2.0, 1.0)
			var shape := pow(sin(PI * 0.5 * ph / 0.35), 2.0) if ph < 0.35 else pow(1.0 - (ph - 0.35) / 0.65, 2.0)
			swell = 0.35 + 0.65 * shape * (1.0 if t < 0.5 else 0.8)
		var x := rng.randf() * 2.0 - 1.0
		y1 += a1 * (x - y1)
		y2 += a1 * (y1 - y2)
		low += f * band
		var high := x - low - 0.9 * band
		band += f * high
		var hiss := maxf(0.0, swell - 0.6) * 2.4
		long[i] = y2 * 5.0 * swell + band * 0.22 * hiss * hiss
	return _xfade(long, n)


## The wind in the firs: noise through a band that wanders between 450 and
## 900 Hz as the gusts come and go, over a low breath.
static func _wind(rate: int) -> PackedFloat32Array:
	var n := 8 * rate
	var long := _buf(8.6, rate)
	var rng := _rng(202)
	var low := 0.0
	var band := 0.0
	var a1 := 1.0 - exp(-TAU * 120.0 / rate)
	var y1 := 0.0
	var gust := 0.0
	var f := 0.0
	for i in long.size():
		if i % CONTROL == 0:
			var t := float(i % n) / n
			gust = 0.55 + 0.25 * sin(TAU * t) + 0.2 * sin(TAU * 3.0 * t + 1.3)
			f = 2.0 * sin(PI * (450.0 + 450.0 * gust) / rate)
		var x := rng.randf() * 2.0 - 1.0
		low += f * band
		var high := x - low - 0.35 * band
		band += f * high
		y1 += a1 * (x - y1)
		long[i] = band * 0.35 * gust + y1 * 1.2
	return _xfade(long, n)


## The hall's fire: a low roar under, and crackles: little runs of clicks
## at seeded times, wrapped round the loop's end.
static func _hall(rate: int) -> PackedFloat32Array:
	var n := 8 * rate
	var long := _buf(8.5, rate)
	var rng := _rng(303)
	var a1 := 1.0 - exp(-TAU * 260.0 / rate)
	var y1 := 0.0
	var y2 := 0.0
	var breath := 0.0
	for i in long.size():
		if i % CONTROL == 0:
			var t := float(i % n) / n
			breath = 0.75 + 0.25 * sin(TAU * 2.0 * t) * sin(TAU * 3.0 * t)
		y1 += a1 * ((rng.randf() * 2.0 - 1.0) - y1)
		y2 += a1 * (y1 - y2)
		long[i] = y2 * 2.6 * breath
	var out := _xfade(long, n)
	var pops := _rng(304)
	for k in 46:
		var at := pops.randi_range(0, n - 1)
		var clicks := pops.randi_range(1, 5)
		var amp := pops.randf_range(0.08, 0.5)
		for c in clicks:
			_burst(out, rate, pops, at + c * pops.randi_range(int(0.004 * rate), int(0.03 * rate)),
					amp * pops.randf_range(0.4, 1.0), pops.randf_range(0.0012, 0.004), 4500.0, 900.0, true)
	return out


## The battle's bed: a skin drum, `bpm`, `beats` to the loop; the first of
## each four heavy. Close (`close`) the lines have met: faster, every beat
## doubled, and the murmur of men brighter and louder under it.
static func _drums(rate: int, bpm: float, beats: int, close: bool) -> PackedFloat32Array:
	var beat := int(roundf(60.0 / bpm * rate))
	var n := beat * beats
	var long := PackedFloat32Array()
	long.resize(n + int(0.5 * rate))
	long.fill(0.0)
	var rng := _rng(404 if close else 405)
	var f := 2.0 * sin(PI * (650.0 if close else 420.0) / rate)
	var low := 0.0
	var band := 0.0
	for i in long.size():
		var x := rng.randf() * 2.0 - 1.0
		low += f * band
		var high := x - low - 0.8 * band
		band += f * high
		long[i] = band * (0.07 if close else 0.04)
	var out := _xfade(long, n)
	var hits := _rng(406 if close else 407)
	# The beats fall a little after the loop's start, so its seam lies in
	# the last beat's dying tail and not on a stroke.
	var lead := int(0.12 * rate)
	for b in beats:
		var accent := b % 4 == 0
		var amp := 1.0 if accent else 0.55
		_ping(out, rate, lead + b * beat, 105.0 if accent else 125.0, amp, 0.16, 52.0 if accent else 64.0, true)
		_burst(out, rate, hits, lead + b * beat, amp * 0.35, 0.03, 380.0, 0.0, true)
		if close:
			var off := lead + b * beat + int(beat / 2.0)
			_ping(out, rate, off, 120.0, 0.35, 0.11, 70.0, true)
			_burst(out, rate, hits, off, 0.12, 0.02, 500.0, 0.0, true)
	return out


# --- The interface ----------------------------------------------------------

## A soft knock on wood: a few short partials of a board and a tick of noise.
static func _knock(rate: int) -> PackedFloat32Array:
	var b := _buf(0.14, rate)
	var rng := _rng(501)
	_ping(b, rate, 0, 540.0, 1.0, 0.022)
	_ping(b, rate, 0, 1230.0, 0.45, 0.012)
	_ping(b, rate, 0, 2310.0, 0.2, 0.007)
	_burst(b, rate, rng, 0, 0.3, 0.002, 5000.0)
	return b


## A sheet of parchment turned: two rustles of bright noise, uneven.
static func _page(rate: int) -> PackedFloat32Array:
	var b := _buf(0.42, rate)
	var rng := _rng(502)
	var f := 2.0 * sin(PI * 2400.0 / rate)
	var low := 0.0
	var band := 0.0
	var grain := 0.0
	var soft := 1.0 - exp(-TAU * 4500.0 / rate)
	var y := 0.0
	for i in b.size():
		var t := float(i) / rate
		var env := exp(-pow((t - 0.07) / 0.045, 2.0)) + 0.7 * exp(-pow((t - 0.22) / 0.07, 2.0))
		if i % 64 == 0:
			grain = rng.randf_range(0.3, 1.0)
		var x := rng.randf() * 2.0 - 1.0
		low += f * band
		var high := x - low - 1.0 * band
		band += f * high
		y += soft * (band - y)
		b[i] = y * env * grain
	return b


## The day's tick on the map: the faintest tap.
static func _tick(rate: int) -> PackedFloat32Array:
	var b := _buf(0.06, rate)
	_ping(b, rate, 0, 1750.0, 1.0, 0.006)
	_ping(b, rate, 0, 880.0, 0.5, 0.01)
	return b


## Silver counted out: two struck rings of bright, unrelated partials.
static func _coin(rate: int) -> PackedFloat32Array:
	var b := _buf(0.7, rate)
	for k in 2:
		var at := int((0.0 if k == 0 else 0.075) * rate)
		var d := 1.0 if k == 0 else 1.035
		_ping(b, rate, at, 2093.0 * d, 0.7, 0.16)
		_ping(b, rate, at, 3351.0 * d, 0.5, 0.11)
		_ping(b, rate, at, 4797.0 * d, 0.35, 0.07)
		_ping(b, rate, at, 6271.0 * d, 0.2, 0.05)
	return b


## A small bird far off: three quick falling chirps.
static func _bird(rate: int) -> PackedFloat32Array:
	var b := _buf(0.5, rate)
	for k in 3:
		var at := int((0.02 + k * 0.13) * rate)
		var length := int(0.07 * rate)
		var phase := 0.0
		for i in length:
			var t := float(i) / length
			var f := 4300.0 - 1300.0 * t
			phase += f / rate
			b[at + i] += sin(TAU * phase) * sin(PI * t) * (1.0 - 0.25 * k)
	return b


# --- The horn ---------------------------------------------------------------

## A cow-horn, blasts of [start s, length s, pitch from, pitch to] (pitch as
## a ratio of D3), in `seconds`: a smoothed sawtooth through a low-pass that
## opens as the breath swells (the brassy bloom), a breath of noise, a
## slow waver once the note is held.
static func _horn(rate: int, blasts: Array, seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds, rate)
	var rng := _rng(601)
	var base := D3
	for bl in blasts:
		var at := int(float(bl[0]) * rate)
		var length := int(float(bl[1]) * rate)
		var tail := int(0.18 * rate)
		var phase := 0.0
		var low := 0.0
		var band := 0.0
		var breath := 0.0
		var waver := 1.0
		for i in length + tail:
			var t := float(i) / rate
			var u := clampf(float(i) / length, 0.0, 1.0)
			# The breath: up in 60 ms, held, then let go.
			var env := minf(1.0, t / 0.06)
			if i > length:
				env = exp(-float(i - length) / rate / 0.05)
			var glide := float(bl[2]) + (float(bl[3]) - float(bl[2])) * (u * u * (3.0 - 2.0 * u))
			if i % CONTROL == 0:
				waver = 1.0 + 0.004 * sin(TAU * 5.2 * t) * clampf((t - 0.3) / 0.3, 0.0, 1.0)
			var f := base * glide * waver * (0.97 + 0.03 * minf(1.0, t / 0.08))
			var dt := f / rate
			phase = fmod(phase + dt, 1.0)
			var x := _saw(phase, dt)
			var fc := f * (1.2 + 4.5 * env)
			var ff := 2.0 * sin(PI * minf(fc, rate * 0.12) / rate)
			low += ff * band
			var high := x - low - 0.9 * band
			band += ff * high
			breath += 0.2 * ((rng.randf() * 2.0 - 1.0) - breath)
			var j := at + i
			if j < b.size():
				b[j] += (low + 0.06 * breath) * env
	return b


# --- The fight --------------------------------------------------------------

## Shields meeting: the dull thump of limewood, its body ringing low, and
## the iron boss a little above.
static func _clash(rate: int) -> PackedFloat32Array:
	var b := _buf(0.4, rate)
	var rng := _rng(701)
	_burst(b, rate, rng, 0, 1.0, 0.035, 900.0, 60.0)
	_ping(b, rate, 0, 185.0, 0.7, 0.06, 150.0)
	_ping(b, rate, 0, 410.0, 0.45, 0.045)
	_ping(b, rate, int(0.004 * rate), 1270.0, 0.18, 0.09)
	_ping(b, rate, int(0.004 * rate), 2730.0, 0.1, 0.06)
	return b


## A blade biting: a sharp tick and the ring of struck iron, its partials
## not in tune with each other.
static func _blade(rate: int) -> PackedFloat32Array:
	var b := _buf(0.5, rate)
	var rng := _rng(702)
	_burst(b, rate, rng, 0, 0.8, 0.003, 7000.0, 1500.0)
	_ping(b, rate, 0, 1720.0, 0.5, 0.12)
	_ping(b, rate, 0, 2950.0, 0.4, 0.09)
	_ping(b, rate, 0, 4410.0, 0.3, 0.06)
	_ping(b, rate, 0, 6130.0, 0.15, 0.04)
	_burst(b, rate, rng, int(0.01 * rate), 0.3, 0.02, 600.0, 120.0)
	return b


## A man going down: a heavy body on the ground, and his gear after it.
static func _down(rate: int) -> PackedFloat32Array:
	var b := _buf(0.7, rate)
	var rng := _rng(703)
	_ping(b, rate, 0, 78.0, 1.0, 0.13, 40.0)
	_burst(b, rate, rng, 0, 0.8, 0.07, 260.0, 30.0)
	_burst(b, rate, rng, int(0.11 * rate), 0.25, 0.05, 1800.0, 300.0)
	_ping(b, rate, int(0.12 * rate), 1460.0, 0.06, 0.07)
	return b


## A rout: many feet going and men crying out, swelling and passing.
static func _rout(rate: int) -> PackedFloat32Array:
	var seconds := 2.2
	var b := _buf(seconds, rate)
	var rng := _rng(704)
	# The voices: noise through three vowel bands, each wavering on its own.
	var f1 := 2.0 * sin(PI * 560.0 / rate)
	var f2 := 2.0 * sin(PI * 1000.0 / rate)
	var f3 := 2.0 * sin(PI * 1700.0 / rate)
	var l1 := 0.0
	var b1 := 0.0
	var l2 := 0.0
	var b2 := 0.0
	var l3 := 0.0
	var b3 := 0.0
	var env := 0.0
	var w1 := 0.0
	var w2 := 0.0
	var w3 := 0.0
	for i in b.size():
		if i % CONTROL == 0:
			var t := float(i) / rate
			env = sin(PI * minf(1.0, t / seconds)) * minf(1.0, t / 0.4)
			w1 = 0.6 + 0.4 * sin(TAU * 3.1 * t)
			w2 = 0.6 + 0.4 * sin(TAU * 4.8 * t + 1.0)
			w3 = 0.6 + 0.4 * sin(TAU * 6.5 * t + 2.0)
		var x := rng.randf() * 2.0 - 1.0
		l1 += f1 * b1
		b1 += f1 * (x - l1 - 0.5 * b1)
		l2 += f2 * b2
		b2 += f2 * (x - l2 - 0.5 * b2)
		l3 += f3 * b3
		b3 += f3 * (x - l3 - 0.5 * b3)
		b[i] = (b1 * 0.9 * w1 + b2 * 0.6 * w2 + b3 * 0.3 * w3) * 0.08 * env
	# The feet: thuds at seeded times, thickest in the middle.
	for k in 70:
		var t := clampf(rng.randfn(seconds * 0.45, seconds * 0.22), 0.0, seconds - 0.1)
		_burst(b, rate, rng, int(t * rate), rng.randf_range(0.3, 0.9), 0.012, 300.0, 40.0)
	return b


# --- The music --------------------------------------------------------------

## The bowed drone under the music: D2 and A2, a horsehair bow's rasp,
## its pressure coming and going. Each tone fits a whole number of cycles
## in the loop, so it closes without a seam.
static func _drone(rate: int) -> PackedFloat32Array:
	var seconds := 4.0
	var n := int(seconds * rate)
	var long := _buf(seconds + 0.5, rate)
	var rng := _rng(801)
	var fd := roundf(73.42 * seconds) / seconds  # 73.5 Hz: D2, two cents sharp
	var fa := roundf(110.0 * seconds) / seconds
	var low := 0.0
	var band := 0.0
	var f := 2.0 * sin(PI * 700.0 / rate)
	var rasp := 0.0
	var bow := 0.0
	for i in long.size():
		var k := i % n  # the tones and the bow keep to the loop
		if i % CONTROL == 0:
			var u := float(k) / n
			bow = 0.7 + 0.3 * sin(TAU * u) + 0.08 * sin(TAU * 4.0 * u)
		var t := float(k) / rate
		var x := _saw(fmod(fd * t, 1.0), fd / rate) + 0.55 * _saw(fmod(fa * t, 1.0), fa / rate)
		low += f * band
		var high := x - low - 1.1 * band
		band += f * high
		rasp += 0.3 * ((rng.randf() * 2.0 - 1.0) - rasp)
		long[i] = (low + rasp * 0.05) * bow
	# The filter starts from rest: the tail, settled, is faded over the head.
	return _xfade(long, n)
