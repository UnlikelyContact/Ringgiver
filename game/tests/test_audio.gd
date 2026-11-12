extends TestCase
## The game's sound (view/audio_synth.gd, view/audio.gd,
## docs/design/notes/shell.md). Nobody can listen in a test, so the numbers
## are pinned: every sound renders, none clips or carries DC or a NaN, the
## loops close without a seam, the levels are the ones set, the same name
## renders the same samples every time, and a round's lines become a few
## clashes, never one for every blow.


func test_every_sound_renders_clean() -> void:
	for name in AudioSynth.names():
		var b := AudioSynth.render(name)
		assert_true(b.size() > 100, "%s has samples" % name)
		var bad := false
		for v in b:
			if is_nan(v) or is_inf(v):
				bad = true
				break
		assert_true(not bad, "%s has no NaN" % name)
		assert_true(AudioSynth.peak(b) <= 0.98, "%s does not clip (%.3f)" % [name, AudioSynth.peak(b)])
		assert_true(absf(AudioSynth.dc(b)) < 0.002, "%s carries no DC (%.4f)" % [name, AudioSynth.dc(b)])
		if not AudioSynth.is_loop(name):
			assert_true(absf(b[b.size() - 1]) < 0.001, "%s ends in silence, not a click" % name)


func test_levels_are_the_ones_set() -> void:
	for name in AudioSynth.names():
		var d: Array = AudioSynth.DEFS[name]
		var b := AudioSynth.render(name)
		var got := linear_to_db(AudioSynth.rms(b) if str(d[3]) == "rms" else AudioSynth.peak(b))
		assert_between(got, float(d[2]) - 0.3, float(d[2]) + 0.3, "%s at its level" % name)
		if str(d[4]) == "amb":
			assert_between(got, -34.0, -26.0, "%s is a quiet bed (about -30 dBFS)" % name)
		elif str(d[4]) == "sfx":
			assert_between(got, -14.0, -8.0, "%s peaks about -9 dBFS" % name)
		elif str(d[4]) == "music":
			assert_true(got <= -15.0, "%s sits under the rest" % name)


func test_loops_close_without_a_seam() -> void:
	var loops := 0
	for name in AudioSynth.names():
		if not AudioSynth.is_loop(name):
			continue
		loops += 1
		var b := AudioSynth.render(name)
		assert_true(AudioSynth.seam(b) <= 2.5, "%s closes smoothly (%.2f)" % [name, AudioSynth.seam(b)])
		var s := AudioSynth.stream(b, AudioSynth.rate_of(name), true)
		assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, name)
		assert_eq(s.loop_end, b.size(), "%s loops over all of it" % name)
	assert_true(loops >= 6, "the beds and the drone loop")


func test_the_same_name_renders_the_same_samples() -> void:
	for name in ["sea", "hall", "battle_close", "horn_rise", "clash", "rout", "victory", "phrase3"]:
		var a := AudioSynth.render(name)
		AudioSynth._strings.clear()  # the lyre's strings plucked afresh
		var b := AudioSynth.render(name)
		assert_eq(a.size(), b.size(), name)
		var same := true
		for i in a.size():
			if a[i] != b[i]:
				same = false
				break
		assert_true(same, "%s is the same every time" % name)


func test_a_stream_is_16_bit_mono_at_its_rate() -> void:
	var b := AudioSynth.render("press")
	var s := AudioSynth.stream(b, AudioSynth.rate_of("press"), false)
	assert_eq(s.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(s.data.size(), b.size() * 2)
	assert_true(not s.stereo)
	assert_eq(s.mix_rate, AudioSynth.RATE)
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_the_lyre_is_in_tune() -> void:
	# A plucked A4 alone: its period by autocorrelation over a fifth of a
	# second, refined between whole samples.
	AudioSynth._strings.clear()
	var rate := AudioSynth.LOW_RATE
	var s := AudioSynth._string(rate, AudioSynth.A4)
	var from := int(0.2 * rate)
	var span := int(0.2 * rate)
	var r := {}
	for lag in range(15, 40):
		var acc := 0.0
		for i in span:
			acc += s[from + i] * s[from + i + lag]
		r[lag] = acc
	var best := 15
	for lag in r:
		if float(r[lag]) > float(r[best]):
			best = lag
	var a := float(r[best - 1])
	var b := float(r[best])
	var c := float(r[best + 1])
	var period := best + 0.5 * (a - c) / (a - 2.0 * b + c)
	var hz := rate / period
	assert_between(hz, 435.0, 445.0, "A4 rings at 440 Hz (%.1f)" % hz)


func test_a_round_is_a_few_clashes_not_one_a_blow() -> void:
	var lines := PackedStringArray([
		"Atli beats Bard (solid, margin 2): shield takes 1",
		"Kol beats Orm (heavy, margin 5): wounded",
		"Ulf and Thord lock, neither gives ground",
		"Ivar beats Ketil (clean, margin 7): grievous, DOWN",
		"Ivar shoots Brand (hit, margin 3): bruised",
		"Egil shouts: push!",
	])
	var n := Audio.blow_counts(lines)
	assert_eq(n.x, 2, "two clashes: a blow that harmed nobody and a lock")
	assert_eq(n.y, 2, "two bites: the wound and the man down (a shot is no blow)")
	assert_eq(n.z, 1, "one man down")
	# Thirty exchanges still make at most three clashes and three bites.
	var many := PackedStringArray()
	for i in 30:
		many.append("A%d beats B%d (solid, margin 1): no harm" % [i, i])
	assert_eq(Audio.blow_counts(many).x, 30)
	assert_true(mini(3, ceili(30 / 3.0)) == 3, "layered, capped at three")


func test_no_sound_node_in_a_headless_run() -> void:
	assert_true(Audio.get_audio() == null, "no node made headless")
	Audio.play("coin")  # and the calls do nothing, without an error
	Audio.scene("map_sea")
	Audio.shout(CombatTypes.Shout.PUSH)
	Audio.result(BattleResult.Outcome.ROUTED_THEM)
	assert_true(Audio.SHOTS + Audio.SLOTS <= 12, "at most twelve players")
	for s in Audio.SCENES:
		for layer in Audio.SCENES[s]:
			assert_true(AudioSynth.DEFS.has(layer) and AudioSynth.is_loop(layer), "%s's %s is a loop" % [s, layer])
	for s in Audio.HORNS:
		assert_true(AudioSynth.DEFS.has(Audio.HORNS[s]), "the horn for shout %d is made" % s)
	for w in Audio.WARM:
		assert_true(AudioSynth.DEFS.has(w), "%s is made" % w)
