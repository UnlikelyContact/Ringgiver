## Renders every sound the game makes (view/audio_synth.gd) and measures
## it, since nobody here can listen: peak and RMS in dBFS, DC offset,
## length, how the loop's seam compares with an ordinary step between two
## samples, and the time it took. Fails (exit 1) on a NaN, on clipping
## (peak over 0.98), on a loop that clicks at its seam, on DC, or on a
## sound whose loudness is far out of line with its group. Writes each
## sound as a WAV to the folder given (default /tmp/ringgiver-audio) for a
## look at its spectrum.
##
##   godot --headless --path game -s tools/audio_check.gd -- [out_dir]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp/ringgiver-audio"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fails := PackedStringArray()
	var rows := {}
	var total_us := 0
	var total_samples := 0
	print("%-13s %6s %5s %7s %7s %8s %6s %7s %6s" % ["sound", "rate", "secs", "peak", "rms", "dc", "seam", "ms", "loop"])
	for name in AudioSynth.names():
		var t0 := Time.get_ticks_usec()
		var buf := AudioSynth.render(name)
		var t1 := Time.get_ticks_usec()
		var s := AudioSynth.stream(buf, AudioSynth.rate_of(name), AudioSynth.is_loop(name))
		var t2 := Time.get_ticks_usec()
		total_us += t2 - t0
		total_samples += buf.size()
		var bad := false
		for v in buf:
			if is_nan(v) or is_inf(v):
				bad = true
				break
		var pk := AudioSynth.peak(buf)
		var r := AudioSynth.rms(buf)
		var d := AudioSynth.dc(buf)
		var loop := AudioSynth.is_loop(name)
		var seam := AudioSynth.seam(buf) if loop else 0.0
		var secs := float(buf.size()) / AudioSynth.rate_of(name)
		rows[name] = {"peak": pk, "rms": r, "group": str(AudioSynth.DEFS[name][4])}
		print("%-13s %6d %5.2f %7.1f %7.1f %8.5f %6.2f %7.1f %6s" % [name, AudioSynth.rate_of(name), secs,
				linear_to_db(maxf(pk, 1e-9)), linear_to_db(maxf(r, 1e-9)), d, seam, (t2 - t0) / 1000.0,
				"loop" if loop else ""])
		if bad:
			fails.append("%s: NaN or infinity in the samples" % name)
		if pk > 0.98:
			fails.append("%s: clips (peak %.3f)" % [name, pk])
		if absf(d) > 0.002:
			fails.append("%s: DC offset %.4f" % [name, d])
		if loop and seam > 2.5:
			fails.append("%s: the loop's seam jumps %.1f ordinary steps" % [name, seam])
		if buf.size() < 100:
			fails.append("%s: empty" % name)
		_write_wav(out_dir.path_join(name + ".wav"), s)
	# Loudness in line: within a group, every sound's RMS within 15 dB of the
	# group's median (the ambience within 4 dB, they are set by RMS).
	var groups := {}
	for name in rows:
		var g: String = rows[name].group
		if not groups.has(g):
			groups[g] = []
		groups[g].append(linear_to_db(maxf(float(rows[name].rms), 1e-9)))
	for name in rows:
		var g: String = rows[name].group
		var list: Array = groups[g].duplicate()
		list.sort()
		var median: float = list[list.size() / 2]
		var db := linear_to_db(maxf(float(rows[name].rms), 1e-9))
		var allow := 4.0 if g == "amb" else 15.0
		if absf(db - median) > allow:
			fails.append("%s: RMS %.1f dB is out of line with its group %s (median %.1f)" % [name, db, g, median])
	print("all sounds: %d samples, %.1f ms to render and pack" % [total_samples, total_us / 1000.0])
	if fails.is_empty():
		print("AUDIO CHECK OK")
		quit(0)
	else:
		for f in fails:
			print("FAIL " + f)
		quit(1)


func _write_wav(path: String, s: AudioStreamWAV) -> void:
	var err := s.save_to_wav(path)
	if err != OK:
		push_warning("could not write %s" % path)
