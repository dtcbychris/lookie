extends RefCounted
## Procedural audio: all sounds are synthesized into AudioStreamWAVs at load.
## No external assets — same placeholder philosophy as the pixel textures,
## swappable for real sound design later.

const RATE := 22050

static func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w

static func engine_loop() -> AudioStreamWAV:
	# raspy saw + sub-harmonic + noise; 0.5s with whole cycles so the loop seams
	var n := RATE / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(t * 110.0, 1.0)        # 55 cycles in 0.5s
		var ph2 := fmod(t * 220.0 + 0.3, 1.0)
		var s := (ph * 2.0 - 1.0) * 0.5 + (ph2 * 2.0 - 1.0) * 0.22
		s += (rng.randf() * 2.0 - 1.0) * 0.13
		out[i] = tanh(s * 1.6) * 0.7
	return _wav(out, true)

static func boost_loop() -> AudioStreamWAV:
	# airy filtered-noise whoosh
	var n := RATE / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, rng.randf() * 2.0 - 1.0, 0.35)
		var swirl := 0.6 + 0.4 * sin(TAU * 6.0 * float(i) / RATE)
		out[i] = lp * swirl * 0.8
	return _wav(out, true)

static func thud() -> AudioStreamWAV:
	# wall hit: low sine knock + noise crunch, fast decay
	var n := int(RATE * 0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, rng.randf() * 2.0 - 1.0, 0.5)
		var s := sin(TAU * 70.0 * t) * exp(-t * 14.0) * 0.9
		s += lp * exp(-t * 26.0) * 0.7
		out[i] = s
	return _wav(out)

static func beep(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 60.0, 1.0) * exp(-maxf(t - dur * 0.6, 0.0) * 30.0)
		out[i] = sin(TAU * freq * t) * env * 0.6
	return _wav(out)

static func blip() -> AudioStreamWAV:
	# lap-complete: quick rising two-tone
	var n := int(RATE * 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 660.0 if t < 0.08 else 990.0
		out[i] = sin(TAU * f * t) * exp(-t * 10.0) * 0.55
	return _wav(out)

static func sting() -> AudioStreamWAV:
	# finish jingle: short ascending arpeggio
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var note_len := 0.13
	var n := int(RATE * (note_len * notes.size() + 0.3))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var k := mini(int(t / note_len), notes.size() - 1)
		var nt := t - float(k) * note_len
		var tail := 0.45 if k == notes.size() - 1 else 0.14
		var s := sin(TAU * notes[k] * t) + 0.4 * sin(TAU * notes[k] * 2.0 * t)
		out[i] = s * exp(-nt / tail) * 0.45
	return _wav(out)
